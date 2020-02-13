

import 'package:serializable/serializable.dart';
import 'fingerprint.dart';

part 'dtls_parameters.g.dart';

@serializable
class DtlsParameters extends _$DtlsParametersSerializable {
  String role;
  List<Fingerprint> fingerprints;

  DtlsParameters();

  factory DtlsParameters.fromJson(json) => DtlsParameters()..fromMap(json);
}