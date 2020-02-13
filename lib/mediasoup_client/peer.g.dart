// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'peer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Peer _$PeerFromJson(Map<String, dynamic> json) {
  return Peer()
    ..id = json['id'] as String
    ..displayName = json['displayName'] as String
    ..device = Device.fromJson(json['device'] as Map<String, dynamic>);
}

Map<String, dynamic> _$PeerToJson(Peer instance) => <String, dynamic>{
      'id': instance.id,
      'displayName': instance.displayName,
      'device': instance.device,
    };
