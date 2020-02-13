
import 'package:serializable/serializable.dart';

part 'ice_candidate.g.dart';

@serializable
class IceCandidate extends _$IceCandidateSerializable {
  String foundation;
  String ip;
  int port;
  int priority;
  String protocol;
  String type;
  String tcpType;

  IceCandidate();

  factory IceCandidate.fromJson(json) => IceCandidate()..fromMap(json);
}