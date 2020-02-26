import 'dart:async';

import 'package:flutter_mediasoup/mediasoup_client/dtls_parameters.dart';
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
    'iceServers'         : [{"url": "stun:stun.l.google.com:19302"},],
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

  createSendTransport(peerId, {
    id,
    iceParameters,
    iceCandidates,
    dtlsParameters,
    sctpParameters,
  }) async {
    return _createTransport("send", peerId,
      id: id,
      iceParameters: iceParameters,
      iceCandidates: iceCandidates,
      dtlsParameters: dtlsParameters,
      sctpParameters: sctpParameters);
  }

  createRecvTransport(peerId, {
    id,
    iceParameters,
    iceCandidates,
    dtlsParameters,
    sctpParameters,
  }) async {
    return _createTransport("recv", peerId,
      id: id,
      iceParameters: iceParameters,
      iceCandidates: iceCandidates,
      dtlsParameters: dtlsParameters,
      sctpParameters: sctpParameters);
  }

  _createTransport(direction, peerId, {
    id,
    iceParameters,
    iceCandidates,
    dtlsParameters,
    sctpParameters,
  }) {
    return Transport.fromMap({
      "id": id,
      "iceParameters": iceParameters,
      "iceCandidates": iceCandidates,
      "dtlsParameters": dtlsParameters,
      "sctpParameters": sctpParameters,
      "direction": direction
    });
  
  }
  
  static fromJson(Map json) => _$DeviceFromJson(json);
}