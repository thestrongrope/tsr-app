// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_form_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProfileFormData {

 String get name; String get mobile; String get country; String get state; String get city; String get zip; String? get gender;// 'male', 'female'
 int? get ageRange;// 1, 2, 3, 4
 String? get language;
/// Create a copy of ProfileFormData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileFormDataCopyWith<ProfileFormData> get copyWith => _$ProfileFormDataCopyWithImpl<ProfileFormData>(this as ProfileFormData, _$identity);

  /// Serializes this ProfileFormData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileFormData&&(identical(other.name, name) || other.name == name)&&(identical(other.mobile, mobile) || other.mobile == mobile)&&(identical(other.country, country) || other.country == country)&&(identical(other.state, state) || other.state == state)&&(identical(other.city, city) || other.city == city)&&(identical(other.zip, zip) || other.zip == zip)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.ageRange, ageRange) || other.ageRange == ageRange)&&(identical(other.language, language) || other.language == language));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,mobile,country,state,city,zip,gender,ageRange,language);

@override
String toString() {
  return 'ProfileFormData(name: $name, mobile: $mobile, country: $country, state: $state, city: $city, zip: $zip, gender: $gender, ageRange: $ageRange, language: $language)';
}


}

/// @nodoc
abstract mixin class $ProfileFormDataCopyWith<$Res>  {
  factory $ProfileFormDataCopyWith(ProfileFormData value, $Res Function(ProfileFormData) _then) = _$ProfileFormDataCopyWithImpl;
@useResult
$Res call({
 String name, String mobile, String country, String state, String city, String zip, String? gender, int? ageRange, String? language
});




}
/// @nodoc
class _$ProfileFormDataCopyWithImpl<$Res>
    implements $ProfileFormDataCopyWith<$Res> {
  _$ProfileFormDataCopyWithImpl(this._self, this._then);

  final ProfileFormData _self;
  final $Res Function(ProfileFormData) _then;

/// Create a copy of ProfileFormData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? mobile = null,Object? country = null,Object? state = null,Object? city = null,Object? zip = null,Object? gender = freezed,Object? ageRange = freezed,Object? language = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,mobile: null == mobile ? _self.mobile : mobile // ignore: cast_nullable_to_non_nullable
as String,country: null == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,zip: null == zip ? _self.zip : zip // ignore: cast_nullable_to_non_nullable
as String,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as String?,ageRange: freezed == ageRange ? _self.ageRange : ageRange // ignore: cast_nullable_to_non_nullable
as int?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProfileFormData].
extension ProfileFormDataPatterns on ProfileFormData {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileFormData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileFormData() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileFormData value)  $default,){
final _that = this;
switch (_that) {
case _ProfileFormData():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileFormData value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileFormData() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String mobile,  String country,  String state,  String city,  String zip,  String? gender,  int? ageRange,  String? language)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileFormData() when $default != null:
return $default(_that.name,_that.mobile,_that.country,_that.state,_that.city,_that.zip,_that.gender,_that.ageRange,_that.language);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String mobile,  String country,  String state,  String city,  String zip,  String? gender,  int? ageRange,  String? language)  $default,) {final _that = this;
switch (_that) {
case _ProfileFormData():
return $default(_that.name,_that.mobile,_that.country,_that.state,_that.city,_that.zip,_that.gender,_that.ageRange,_that.language);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String mobile,  String country,  String state,  String city,  String zip,  String? gender,  int? ageRange,  String? language)?  $default,) {final _that = this;
switch (_that) {
case _ProfileFormData() when $default != null:
return $default(_that.name,_that.mobile,_that.country,_that.state,_that.city,_that.zip,_that.gender,_that.ageRange,_that.language);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProfileFormData implements ProfileFormData {
  const _ProfileFormData({this.name = '', this.mobile = '', this.country = '', this.state = '', this.city = '', this.zip = '', this.gender, this.ageRange, this.language});
  factory _ProfileFormData.fromJson(Map<String, dynamic> json) => _$ProfileFormDataFromJson(json);

@override@JsonKey() final  String name;
@override@JsonKey() final  String mobile;
@override@JsonKey() final  String country;
@override@JsonKey() final  String state;
@override@JsonKey() final  String city;
@override@JsonKey() final  String zip;
@override final  String? gender;
// 'male', 'female'
@override final  int? ageRange;
// 1, 2, 3, 4
@override final  String? language;

/// Create a copy of ProfileFormData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileFormDataCopyWith<_ProfileFormData> get copyWith => __$ProfileFormDataCopyWithImpl<_ProfileFormData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProfileFormDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileFormData&&(identical(other.name, name) || other.name == name)&&(identical(other.mobile, mobile) || other.mobile == mobile)&&(identical(other.country, country) || other.country == country)&&(identical(other.state, state) || other.state == state)&&(identical(other.city, city) || other.city == city)&&(identical(other.zip, zip) || other.zip == zip)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.ageRange, ageRange) || other.ageRange == ageRange)&&(identical(other.language, language) || other.language == language));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,mobile,country,state,city,zip,gender,ageRange,language);

@override
String toString() {
  return 'ProfileFormData(name: $name, mobile: $mobile, country: $country, state: $state, city: $city, zip: $zip, gender: $gender, ageRange: $ageRange, language: $language)';
}


}

/// @nodoc
abstract mixin class _$ProfileFormDataCopyWith<$Res> implements $ProfileFormDataCopyWith<$Res> {
  factory _$ProfileFormDataCopyWith(_ProfileFormData value, $Res Function(_ProfileFormData) _then) = __$ProfileFormDataCopyWithImpl;
@override @useResult
$Res call({
 String name, String mobile, String country, String state, String city, String zip, String? gender, int? ageRange, String? language
});




}
/// @nodoc
class __$ProfileFormDataCopyWithImpl<$Res>
    implements _$ProfileFormDataCopyWith<$Res> {
  __$ProfileFormDataCopyWithImpl(this._self, this._then);

  final _ProfileFormData _self;
  final $Res Function(_ProfileFormData) _then;

/// Create a copy of ProfileFormData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? mobile = null,Object? country = null,Object? state = null,Object? city = null,Object? zip = null,Object? gender = freezed,Object? ageRange = freezed,Object? language = freezed,}) {
  return _then(_ProfileFormData(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,mobile: null == mobile ? _self.mobile : mobile // ignore: cast_nullable_to_non_nullable
as String,country: null == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,zip: null == zip ? _self.zip : zip // ignore: cast_nullable_to_non_nullable
as String,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as String?,ageRange: freezed == ageRange ? _self.ageRange : ageRange // ignore: cast_nullable_to_non_nullable
as int?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
