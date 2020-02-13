import 'package:flutter_webrtc/webrtc.dart';

class Consumer {
  String id;
  String localId;
  String producerId;
  RTCPeerConnection rtpReceiver;
  MediaStreamTrack track;
  Map rtpParameters;

  Consumer({
    this.id,
    this.localId,
    this.producerId,
    this.rtpReceiver,
    this.track,
    this.rtpParameters
  });
}