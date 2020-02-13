import 'dart:async';

import 'package:flutter/services.dart';

export 'package:flutter_mediasoup/mediasoup_client/transport.dart';
export 'package:flutter_mediasoup/mediasoup_client/peer.dart';
export 'package:flutter_mediasoup/mediasoup_client/request.dart';
export 'package:flutter_mediasoup/mediasoup_client/device.dart';

class FlutterMediasoup {
  static const MethodChannel _channel =
      const MethodChannel('flutter_mediasoup');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
