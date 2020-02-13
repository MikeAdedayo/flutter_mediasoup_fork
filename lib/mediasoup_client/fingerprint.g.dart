// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fingerprint.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

abstract class _$FingerprintSerializable extends SerializableMap {
  String get algorithm;
  String get value;
  set algorithm(String v);
  set value(String v);

  operator [](Object __key) {
    switch (__key) {
      case 'algorithm':
        return algorithm;
      case 'value':
        return value;
    }
    throwFieldNotFoundException(__key, 'Fingerprint');
  }

  operator []=(Object __key, __value) {
    switch (__key) {
      case 'algorithm':
        algorithm = __value;
        return;
      case 'value':
        value = __value;
        return;
    }
    throwFieldNotFoundException(__key, 'Fingerprint');
  }

  Iterable<String> get keys => const ['algorithm', 'value'];
}
