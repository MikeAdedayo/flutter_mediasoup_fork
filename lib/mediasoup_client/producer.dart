import 'package:flutter_webrtc/webrtc.dart';

class Producer {
  String id;
  MediaStreamTrack track;
  RTCRtpSender sender;
  String kind;
  String localId;
  Map rtpParameters;
  bool enabled = true;
  
  Producer({
    this.id,
    this.track,
    this.sender,
    this.kind,
    this.localId,
    this.rtpParameters
  });

  pause() {
    enabled = false;
    track.enabled = false;
  }

  resume() {
    enabled = true;
    track.enabled = true;
  }
}