// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Device _$DeviceFromJson(Map<String, dynamic> json) {
  return Device()
    ..flag = json['flag'] as String
    ..name = json['name'] as String
    ..version = json['version'] as String;
}

Map<String, dynamic> _$DeviceToJson(Device instance) => <String, dynamic>{
      'flag': instance.flag,
      'name': instance.name,
      'version': instance.version,
    };
