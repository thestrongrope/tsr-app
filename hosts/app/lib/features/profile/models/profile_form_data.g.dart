// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_form_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProfileFormData _$ProfileFormDataFromJson(Map<String, dynamic> json) =>
    _ProfileFormData(
      name: json['name'] as String? ?? '',
      mobile: json['mobile'] as String? ?? '',
      country: json['country'] as String? ?? '',
      state: json['state'] as String? ?? '',
      city: json['city'] as String? ?? '',
      zip: json['zip'] as String? ?? '',
      gender: json['gender'] as String?,
      ageRange: (json['ageRange'] as num?)?.toInt(),
      language: json['language'] as String?,
    );

Map<String, dynamic> _$ProfileFormDataToJson(_ProfileFormData instance) =>
    <String, dynamic>{
      'name': instance.name,
      'mobile': instance.mobile,
      'country': instance.country,
      'state': instance.state,
      'city': instance.city,
      'zip': instance.zip,
      'gender': instance.gender,
      'ageRange': instance.ageRange,
      'language': instance.language,
    };
