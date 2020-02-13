

import 'package:serializable/serializable.dart';

part 'fingerprint.g.dart';

@serializable
class Fingerprint extends _$FingerprintSerializable {
  String algorithm;
  String value;
}