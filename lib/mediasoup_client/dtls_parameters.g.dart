// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dtls_parameters.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

abstract class _$DtlsParametersSerializable extends SerializableMap {
  String get role;
  List<Fingerprint> get fingerprints;
  set role(String v);
  set fingerprints(List<Fingerprint> v);

  operator [](Object __key) {
    switch (__key) {
      case 'role':
        return role;
      case 'fingerprints':
        return fingerprints;
    }
    throwFieldNotFoundException(__key, 'DtlsParameters');
  }

  operator []=(Object __key, __value) {
    switch (__key) {
      case 'role':
        role = __value;
        return;
      case 'fingerprints':
        fingerprints = fromSerialized(
            __value, [() => List<Fingerprint>(), () => Fingerprint()]);
        return;
    }
    throwFieldNotFoundException(__key, 'DtlsParameters');
  }

  Iterable<String> get keys => const ['role', 'fingerprints'];
}
