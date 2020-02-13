import 'package:flutter_mediasoup/mediasoup_client/sdp_utils.dart';
import 'package:flutter_mediasoup/mediasoup_client/transport.dart';
import 'package:flutter_webrtc/webrtc.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:sdp_transform/sdp_transform.dart';
import 'ortc.dart';

part 'device.g.dart';

@JsonSerializable(nullable: false)
class Device {
  String flag;
  String name;
  String version;

  Map _extendedRtpCapabilities;
  Map _recvRtpCapabilities;
  Map _sendingRemoteRtpParametersByKind;

  Map<String, dynamic> config = {
    'iceServers'         : [],
    'iceTransportPolicy' : 'all',
    'bundlePolicy'       : 'max-bundle',
    'rtcpMuxPolicy'      : 'require',
    'sdpSemantics'       : 'plan-b'
  };

  final Map<String, dynamic> constraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': [
      {'`DtlsSrtpKeyAgreement`': true},
    ],
  };

  toMap() => _$DeviceToJson(this);

  get rtpCapabilities => _recvRtpCapabilities;

  getNativeRtpCapabilities() async {
    RTCPeerConnection pc = await createPeerConnection(config, constraints);

    RTCSessionDescription offer = await pc.createOffer(constraints);
    await pc.close();

    Map sdpObject = parse(offer.sdp);
    return extractRtpCapabilities(sdpObject);
  }

  load(Map routerRtpCapabilities) async {
    Map nativeRtpCapabilities = await getNativeRtpCapabilities();

    _extendedRtpCapabilities = getExtendedRtpCapabilities(nativeRtpCapabilities, routerRtpCapabilities);

    _sendingRemoteRtpParametersByKind = Map();
    _sendingRemoteRtpParametersByKind["video"] = getSendingRemoteRtpParameters("video", _extendedRtpCapabilities);
    _sendingRemoteRtpParametersByKind["audio"] = getSendingRemoteRtpParameters("audio", _extendedRtpCapabilities);

    _recvRtpCapabilities = getRecvRtpCapabilities(_extendedRtpCapabilities);
  }

  sendingRemoteRtpParameters(String kind) => _sendingRemoteRtpParametersByKind[kind];

  createSendTransport(peerId, media, {
    id,
    iceParameters,
    iceCandidates,
    dtlsParameters,
    sctpParameters,
  }) async {
    return Transport.fromMap({
      "id": id,
      "iceParameters": iceParameters,
      "iceCandidates": iceCandidates,
      "dtlsParameters": dtlsParameters,
      "sctpParameters": sctpParameters,
      "direction": "send"
    });
  }

  createRecvTransport(peerId, media, {
    id,
    iceParameters,
    iceCandidates,
    dtlsParameters,
    sctpParameters,
  }) async {
    return Transport.fromMap({
      "id": id,
      "iceParameters": iceParameters,
      "iceCandidates": iceCandidates,
      "dtlsParameters": dtlsParameters,
      "sctpParameters": sctpParameters,
      "direction": "recv"
    });
  }

  _createTransport() {

  }

  // _createPeerConnection(id, media, userScreen) async {
  //   if (media != 'data') _localStream = await createStream(media, userScreen);
  //   print("creating peer connection");
  //   RTCPeerConnection pc = await createPeerConnection(_iceServers, _config);
  //   print("Adding local stream");
  //   if (media != 'data') pc.addStream(_localStream);
  //   pc.onIceCandidate = (candidate) async {
  //     print(candidate);
  //     await pc.addCandidate(candidate);
  //   };

  //   pc.onIceConnectionState = (state) {
  //     print("Ice state: $state");
  //   };

  //   pc.onSignalingState = (state) {
  //     print("State: $state");
  //   };

  //   pc.onAddStream = (stream) {
  //     // if (this.onAddRemoteStream != null) this.onAddRemoteStream(stream);
  //     //_remoteStreams.add(stream);
  //   };

  //   pc.onRemoveStream = (stream) {
  //     // if (this.onRemoveRemoteStream != null) this.onRemoveRemoteStream(stream);
  //     // _remoteStreams.removeWhere((it) {
  //     //   return (it.id == stream.id);
  //     // });
  //   };

  //   pc.onDataChannel = (channel) {
  //     // _addDataChannel(id, channel);
  //   };

  //   return pc;
  // }

  // _createOffer(String id, RTCPeerConnection pc, String media) async {
  //   DtlsParameters dtlsParameters;
  //   try {
  //     RTCSessionDescription s = await pc
  //         .createOffer(media == 'data' ? _dcConstraints : _constraints);
  //     print(parse(s.sdp));
  //     dynamic parsedSDP = parse(s.sdp);
  //     dtlsParameters = extractDtlsParameters(parsedSDP);
  //     await pc.setLocalDescription(s);
  //   } catch (e) {
  //     print(e.toString());
  //   }
  //   return dtlsParameters;
  // }

  // _createAnswer(String id, RTCPeerConnection pc, media) async {
  //   try {
  //     RTCSessionDescription s = await pc
  //         .createAnswer(media == 'data' ? _dcConstraints : _constraints);
  //     pc.setLocalDescription(s);
  //     _send('answer', {
  //       'to': id,
  //       'description': {'sdp': s.sdp, 'type': s.type},
  //       'session_id': this._sessionId,
  //     });
  //   } catch (e) {
  //     print(e.toString());
  //   }
  // }
  
  static fromJson(Map json) => _$DeviceFromJson(json);
}