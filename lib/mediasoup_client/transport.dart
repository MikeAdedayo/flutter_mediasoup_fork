import 'dart:async';
import 'dart:convert';

import 'package:eventify/eventify.dart';
import 'package:executor/executor.dart';
import 'package:flutter_mediasoup/mediasoup_client/sdp_unified_plan.dart';
import 'package:flutter_mediasoup/mediasoup_client/sdp_utils.dart';
import 'package:flutter_mediasoup/mediasoup_client/remote_sdp.dart';
import 'package:flutter_webrtc/rtc_peerconnection.dart';
import 'package:flutter_webrtc/webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';
import 'package:serializable/serializable.dart';
import 'dtls_parameters.dart';
import 'ice_candidate.dart';

@serializable
class Transport extends EventEmitter {
  String id;
  List<IceCandidate> iceCandidates;
  DtlsParameters dtlsParameters;
  Map iceParameters;
  Map sctpParameters;
  RemoteSdp _remoteSdp;

  RTCPeerConnection pc;
  static num nextMidId = 1000;

  Function onAddRemoteStream;
  RTCSignalingState state;
  bool _transportReady;
  String direction;

  Completer initCompleter = Completer();

  Executor executor = new Executor(concurrency: 1);

  Transport({
    this.id,
    this.direction,
    this.iceParameters, 
    this.iceCandidates,
    this.dtlsParameters,
    this.sctpParameters}) {
    _transportReady = false;
    _init();
  }

  _init() async {
    _remoteSdp = RemoteSdp(
        iceParameters: iceParameters,
        iceCandidates: iceCandidates,
        dtlsParameters: dtlsParameters,
        sctpParameters: sctpParameters,
        planB: false);

    pc = await createPeerConnection(Map<String, dynamic>.from(_config), Map<String, dynamic>.from(_constraints));

    pc.onIceCandidate = (candidate) async {
      await pc.addCandidate(candidate);
    };

    pc.onIceConnectionState = (state) {
      print("Ice state: $state");
    };

    pc.onSignalingState = (_state) {
      print("State: $_state");
      state = _state;
    };

    pc.onAddStream = (stream) {
      print("Add stream!");
      if (onAddRemoteStream != null) onAddRemoteStream(stream);
      // //_remoteStreams.add(stream);
      MediaStreamTrack track = stream.getAudioTracks()[0];
      _showTrackStats(track);
    };

    pc.onAddTrack2 = (RTCRtpReceiver receiver, [List<MediaStream> mediaStreams]) {
      print("on Add track2");
    };

    pc.onAddTrack = (MediaStream stream, MediaStreamTrack track) {
      print("on Add track");

      // track.enabled = true;
      // track.setVolume(10);
      // track.enableSpeakerphone(true);
    };

    pc.onRemoveStream = (stream) {
      print("Remove stream!");
      
    };

    pc.onDataChannel = (channel) {
      // _addDataChannel(id, channel);
    };

    initCompleter.complete();
  }

  Map<String, dynamic> _config = {
    'iceServers'         : [],
    'iceTransportPolicy' : 'all',
    'bundlePolicy'       : 'max-bundle',
    'sdpSemantics'       : 'unified-plan',
    'rtcpMuxPolicy'      : 'require'
  };

  final Map<String, dynamic> _constraints = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  _showTrackStats(MediaStreamTrack track) async {
    while(true) {
      List<StatsReport> reportList = await pc.getStats(track);
      for (StatsReport report in reportList) {
        // print(report.values);
      }
      await Future.delayed(Duration(seconds: 5));
    }
  }

  _emitPromise(String eventName, dynamic eventData) async {
    Completer eventCompleter = Completer();
    emit(eventName, null, {
      "data": eventData,
      "cb": () {
        eventCompleter.complete();
      }
    });

    return eventCompleter.future;
  }

  _setupTransport(localDtlsRole, localSdpObject) async {
		// Get our local DTLS parameters.
		Map dtlsParameters = extractDtlsParameters(localSdpObject);

		// Set our DTLS role.
		dtlsParameters["role"] = localDtlsRole;

		// Update the remote DTLS role in the SDP.
		_remoteSdp.updateDtlsRole(localDtlsRole == 'client' ? 'server' : 'client');

		// Need to tell the remote transport about our parameters.
		// await this.safeEmitAsPromise('@connect', { dtlsParameters });

		_transportReady = true;


    await _emitPromise('connect', dtlsParameters);
	}

  produce({
    String kind,
    MediaStream stream,
    Map encodings,
    Map codecOptions,
    Map sendingRemoteRtpParameters
  }) async {
    await initCompleter.future;

    executor.scheduleTask(() async {
      Map mediaSectionIdx = _remoteSdp.getNextMediaSectionIdx();

      MediaStreamTrack track;
      RTCRtpMediaType mediaType;
      if (kind == "video") {
        track = stream.getVideoTracks().first;
        mediaType = RTCRtpMediaType.RTCRtpMediaTypeVideo;
      }
      if (kind == "audio") {
        track = stream.getAudioTracks().first;
        mediaType = RTCRtpMediaType.RTCRtpMediaTypeAudio;
      }

      // RTCRtpTransceiverInit init = RTCRtpTransceiverInit(
      //   RTCRtpTransceiverDirection.RTCRtpTransceiverDirectionSendOnly, 
      //   [stream.id]
      // );
      // RTCRtpTransceiver transceiver = await pc.addTransceiverOfType(mediaType, init);
      // transceiver.sender.setTrack(track, true);
      RTCRtpSender sender = await pc.addTrack(track, [stream.id]);
      // await pc.addStream(stream);

      RTCSessionDescription offer = await pc.createOffer({
          'mandatory': {
            'OfferToReceiveAudio': false,
            'OfferToReceiveVideo': false,
          },
          'optional': [],
        }
      );
      Map localSdpObject = parse(offer.sdp);
      if (!_transportReady) {
        await _setupTransport('server', localSdpObject);
      }

      await pc.setLocalDescription(offer);

      Map sendingRtpParameters = Map.from(sendingRemoteRtpParameters);

      String offerSdp = (await pc.getLocalDescription()).sdp;
      localSdpObject = parse(offerSdp);
      
      Map offerMediaObject = localSdpObject["media"][mediaSectionIdx["idx"]];

      // Set MID
      String localId = (nextMidId++).toString();
      sendingRtpParameters["mid"] = localId;

      // Set RTCP CNAME
      sendingRtpParameters["rtcp"]["cname"] = getCname(offerMediaObject);

      if (encodings == null) {
        sendingRtpParameters["encodings"] = getRtpEncodings(offerMediaObject);
      } // TODO: handle else
      
      _remoteSdp.send(
        offerMediaObject,
        mediaSectionIdx["reuseMid"],
        sendingRtpParameters,
        sendingRemoteRtpParameters, codecOptions, true
      );

      RTCSessionDescription answer = RTCSessionDescription(_remoteSdp.getSdp(), 'answer');

      pc.setRemoteDescription(answer);

      emit('produce', null, {
        "kind": kind,
        "localId": localId,
        "rtpParameters": sendingRtpParameters
      });
    });
  }

  consume({
      String id,
      String kind,
      Map rtpParameters,
    }) async {
      await initCompleter.future;

      executor.scheduleTask(() async {
        String localId = (nextMidId++).toString();

        _remoteSdp.receive(
          mid: localId,
          kind: kind, 
          offerRtpParameters: rtpParameters,
          streamId: rtpParameters["rtcp"]["cname"],
          trackId: id
        );
        
        RTCSessionDescription offer = RTCSessionDescription(_remoteSdp.getSdp(), 'offer');

        await pc.setRemoteDescription(offer);

        RTCSessionDescription answer = await pc.createAnswer({});

        Map localSdpObject = parse(answer.sdp);
        Map answerMediaObject = localSdpObject["media"]
          .firstWhere((m) => m["mid"].toString() == localId, orElse: () => null);

        applyCodecParameters(
          offerRtpParameters: rtpParameters,
          answerMediaObject: answerMediaObject
        );

        answer.sdp = write(localSdpObject, null);

        if (!_transportReady) {
          await _setupTransport('client', localSdpObject);
        }

        print("State: $state");
        await pc.setLocalDescription(answer);
      });
      
  }

  factory Transport.fromMap(Map map) {
    List<IceCandidate> iceCandidates = List<IceCandidate>.from((map["iceCandidates"] as List).map((candidate) => IceCandidate.fromJson(candidate)));
    Map iceParameters  = map["iceParameters"];
    DtlsParameters dtlsParameters = DtlsParameters.fromJson(map["dtlsParameters"]);
    Map sctpParameters = map["sctpParameters"];
    String direction = map["direction"];
    String id = map["id"];
    
    Transport transport = Transport(
      id: id,
      direction: direction,
      iceCandidates: iceCandidates,
      iceParameters: iceParameters,
      dtlsParameters: dtlsParameters,
      sctpParameters: sctpParameters
    );


    return transport;
  }
}