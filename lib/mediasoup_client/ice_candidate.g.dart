// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ice_candidate.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

abstract class _$IceCandidateSerializable extends SerializableMap {
  String get foundation;
  String get ip;
  int get port;
  int get priority;
  String get protocol;
  String get type;
  String get tcpType;
  set foundation(String v);
  set ip(String v);
  set port(int v);
  set priority(int v);
  set protocol(String v);
  set type(String v);
  set tcpType(String v);

  operator [](Object __key) {
    switch (__key) {
      case 'foundation':
        return foundation;
      case 'ip':
        return ip;
      case 'port':
        return port;
      case 'priority':
        return priority;
      case 'protocol':
        return protocol;
      case 'type':
        return type;
      case 'tcpType':
        return tcpType;
    }
    throwFieldNotFoundException(__key, 'IceCandidate');
  }

  operator []=(Object __key, __value) {
    switch (__key) {
      case 'foundation':
        foundation = __value;
        return;
      case 'ip':
        ip = __value;
        return;
      case 'port':
        port = __value;
        return;
      case 'priority':
        priority = __value;
        return;
      case 'protocol':
        protocol = __value;
        return;
      case 'type':
        type = __value;
        return;
      case 'tcpType':
        tcpType = __value;
        return;
    }
    throwFieldNotFoundException(__key, 'IceCandidate');
  }

  Iterable<String> get keys => const [
        'foundation',
        'ip',
        'port',
        'priority',
        'protocol',
        'type',
        'tcpType'
      ];
}
