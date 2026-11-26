// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$User {

@HiveField(0) int get id;@HiveField(1) int get token;@HiveField(2) String get email;@HiveField(3) String get name;@HiveField(4) int get roleId;@HiveField(5) String? get picture;@HiveField(6) int? get gender;@HiveField(7) int? get ageRange;@HiveField(8) String? get mobile;@HiveField(9) String? get country;@HiveField(10) String? get state;@HiveField(11) String? get city;@HiveField(12) int? get language;@HiveField(13) String? get zip;@HiveField(14) String? get sendupdates;@HiveField(15) String? get unsubscribe;
/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserCopyWith<User> get copyWith => _$UserCopyWithImpl<User>(this as User, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is User&&(identical(other.id, id) || other.id == id)&&(identical(other.token, token) || other.token == token)&&(identical(other.email, email) || other.email == email)&&(identical(other.name, name) || other.name == name)&&(identical(other.roleId, roleId) || other.roleId == roleId)&&(identical(other.picture, picture) || other.picture == picture)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.ageRange, ageRange) || other.ageRange == ageRange)&&(identical(other.mobile, mobile) || other.mobile == mobile)&&(identical(other.country, country) || other.country == country)&&(identical(other.state, state) || other.state == state)&&(identical(other.city, city) || other.city == city)&&(identical(other.language, language) || other.language == language)&&(identical(other.zip, zip) || other.zip == zip)&&(identical(other.sendupdates, sendupdates) || other.sendupdates == sendupdates)&&(identical(other.unsubscribe, unsubscribe) || other.unsubscribe == unsubscribe));
}


@override
int get hashCode => Object.hash(runtimeType,id,token,email,name,roleId,picture,gender,ageRange,mobile,country,state,city,language,zip,sendupdates,unsubscribe);

@override
String toString() {
  return 'User(id: $id, token: $token, email: $email, name: $name, roleId: $roleId, picture: $picture, gender: $gender, ageRange: $ageRange, mobile: $mobile, country: $country, state: $state, city: $city, language: $language, zip: $zip, sendupdates: $sendupdates, unsubscribe: $unsubscribe)';
}


}

/// @nodoc
abstract mixin class $UserCopyWith<$Res>  {
  factory $UserCopyWith(User value, $Res Function(User) _then) = _$UserCopyWithImpl;
@useResult
$Res call({
@HiveField(0) int id,@HiveField(1) int token,@HiveField(2) String email,@HiveField(3) String name,@HiveField(4) int roleId,@HiveField(5) String? picture,@HiveField(6) int? gender,@HiveField(7) int? ageRange,@HiveField(8) String? mobile,@HiveField(9) String? country,@HiveField(10) String? state,@HiveField(11) String? city,@HiveField(12) int? language,@HiveField(13) String? zip,@HiveField(14) String? sendupdates,@HiveField(15) String? unsubscribe
});




}
/// @nodoc
class _$UserCopyWithImpl<$Res>
    implements $UserCopyWith<$Res> {
  _$UserCopyWithImpl(this._self, this._then);

  final User _self;
  final $Res Function(User) _then;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? token = null,Object? email = null,Object? name = null,Object? roleId = null,Object? picture = freezed,Object? gender = freezed,Object? ageRange = freezed,Object? mobile = freezed,Object? country = freezed,Object? state = freezed,Object? city = freezed,Object? language = freezed,Object? zip = freezed,Object? sendupdates = freezed,Object? unsubscribe = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as int,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,roleId: null == roleId ? _self.roleId : roleId // ignore: cast_nullable_to_non_nullable
as int,picture: freezed == picture ? _self.picture : picture // ignore: cast_nullable_to_non_nullable
as String?,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as int?,ageRange: freezed == ageRange ? _self.ageRange : ageRange // ignore: cast_nullable_to_non_nullable
as int?,mobile: freezed == mobile ? _self.mobile : mobile // ignore: cast_nullable_to_non_nullable
as String?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as int?,zip: freezed == zip ? _self.zip : zip // ignore: cast_nullable_to_non_nullable
as String?,sendupdates: freezed == sendupdates ? _self.sendupdates : sendupdates // ignore: cast_nullable_to_non_nullable
as String?,unsubscribe: freezed == unsubscribe ? _self.unsubscribe : unsubscribe // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [User].
extension UserPatterns on User {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _User value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _User() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _User value)  $default,){
final _that = this;
switch (_that) {
case _User():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _User value)?  $default,){
final _that = this;
switch (_that) {
case _User() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HiveField(0)  int id, @HiveField(1)  int token, @HiveField(2)  String email, @HiveField(3)  String name, @HiveField(4)  int roleId, @HiveField(5)  String? picture, @HiveField(6)  int? gender, @HiveField(7)  int? ageRange, @HiveField(8)  String? mobile, @HiveField(9)  String? country, @HiveField(10)  String? state, @HiveField(11)  String? city, @HiveField(12)  int? language, @HiveField(13)  String? zip, @HiveField(14)  String? sendupdates, @HiveField(15)  String? unsubscribe)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that.id,_that.token,_that.email,_that.name,_that.roleId,_that.picture,_that.gender,_that.ageRange,_that.mobile,_that.country,_that.state,_that.city,_that.language,_that.zip,_that.sendupdates,_that.unsubscribe);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HiveField(0)  int id, @HiveField(1)  int token, @HiveField(2)  String email, @HiveField(3)  String name, @HiveField(4)  int roleId, @HiveField(5)  String? picture, @HiveField(6)  int? gender, @HiveField(7)  int? ageRange, @HiveField(8)  String? mobile, @HiveField(9)  String? country, @HiveField(10)  String? state, @HiveField(11)  String? city, @HiveField(12)  int? language, @HiveField(13)  String? zip, @HiveField(14)  String? sendupdates, @HiveField(15)  String? unsubscribe)  $default,) {final _that = this;
switch (_that) {
case _User():
return $default(_that.id,_that.token,_that.email,_that.name,_that.roleId,_that.picture,_that.gender,_that.ageRange,_that.mobile,_that.country,_that.state,_that.city,_that.language,_that.zip,_that.sendupdates,_that.unsubscribe);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HiveField(0)  int id, @HiveField(1)  int token, @HiveField(2)  String email, @HiveField(3)  String name, @HiveField(4)  int roleId, @HiveField(5)  String? picture, @HiveField(6)  int? gender, @HiveField(7)  int? ageRange, @HiveField(8)  String? mobile, @HiveField(9)  String? country, @HiveField(10)  String? state, @HiveField(11)  String? city, @HiveField(12)  int? language, @HiveField(13)  String? zip, @HiveField(14)  String? sendupdates, @HiveField(15)  String? unsubscribe)?  $default,) {final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that.id,_that.token,_that.email,_that.name,_that.roleId,_that.picture,_that.gender,_that.ageRange,_that.mobile,_that.country,_that.state,_that.city,_that.language,_that.zip,_that.sendupdates,_that.unsubscribe);case _:
  return null;

}
}

}

/// @nodoc


class _User extends User {
  const _User({@HiveField(0) required this.id, @HiveField(1) required this.token, @HiveField(2) required this.email, @HiveField(3) required this.name, @HiveField(4) required this.roleId, @HiveField(5) this.picture, @HiveField(6) this.gender, @HiveField(7) this.ageRange, @HiveField(8) this.mobile, @HiveField(9) this.country, @HiveField(10) this.state, @HiveField(11) this.city, @HiveField(12) this.language, @HiveField(13) this.zip, @HiveField(14) this.sendupdates, @HiveField(15) this.unsubscribe}): super._();
  

@override@HiveField(0) final  int id;
@override@HiveField(1) final  int token;
@override@HiveField(2) final  String email;
@override@HiveField(3) final  String name;
@override@HiveField(4) final  int roleId;
@override@HiveField(5) final  String? picture;
@override@HiveField(6) final  int? gender;
@override@HiveField(7) final  int? ageRange;
@override@HiveField(8) final  String? mobile;
@override@HiveField(9) final  String? country;
@override@HiveField(10) final  String? state;
@override@HiveField(11) final  String? city;
@override@HiveField(12) final  int? language;
@override@HiveField(13) final  String? zip;
@override@HiveField(14) final  String? sendupdates;
@override@HiveField(15) final  String? unsubscribe;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserCopyWith<_User> get copyWith => __$UserCopyWithImpl<_User>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _User&&(identical(other.id, id) || other.id == id)&&(identical(other.token, token) || other.token == token)&&(identical(other.email, email) || other.email == email)&&(identical(other.name, name) || other.name == name)&&(identical(other.roleId, roleId) || other.roleId == roleId)&&(identical(other.picture, picture) || other.picture == picture)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.ageRange, ageRange) || other.ageRange == ageRange)&&(identical(other.mobile, mobile) || other.mobile == mobile)&&(identical(other.country, country) || other.country == country)&&(identical(other.state, state) || other.state == state)&&(identical(other.city, city) || other.city == city)&&(identical(other.language, language) || other.language == language)&&(identical(other.zip, zip) || other.zip == zip)&&(identical(other.sendupdates, sendupdates) || other.sendupdates == sendupdates)&&(identical(other.unsubscribe, unsubscribe) || other.unsubscribe == unsubscribe));
}


@override
int get hashCode => Object.hash(runtimeType,id,token,email,name,roleId,picture,gender,ageRange,mobile,country,state,city,language,zip,sendupdates,unsubscribe);

@override
String toString() {
  return 'User(id: $id, token: $token, email: $email, name: $name, roleId: $roleId, picture: $picture, gender: $gender, ageRange: $ageRange, mobile: $mobile, country: $country, state: $state, city: $city, language: $language, zip: $zip, sendupdates: $sendupdates, unsubscribe: $unsubscribe)';
}


}

/// @nodoc
abstract mixin class _$UserCopyWith<$Res> implements $UserCopyWith<$Res> {
  factory _$UserCopyWith(_User value, $Res Function(_User) _then) = __$UserCopyWithImpl;
@override @useResult
$Res call({
@HiveField(0) int id,@HiveField(1) int token,@HiveField(2) String email,@HiveField(3) String name,@HiveField(4) int roleId,@HiveField(5) String? picture,@HiveField(6) int? gender,@HiveField(7) int? ageRange,@HiveField(8) String? mobile,@HiveField(9) String? country,@HiveField(10) String? state,@HiveField(11) String? city,@HiveField(12) int? language,@HiveField(13) String? zip,@HiveField(14) String? sendupdates,@HiveField(15) String? unsubscribe
});




}
/// @nodoc
class __$UserCopyWithImpl<$Res>
    implements _$UserCopyWith<$Res> {
  __$UserCopyWithImpl(this._self, this._then);

  final _User _self;
  final $Res Function(_User) _then;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? token = null,Object? email = null,Object? name = null,Object? roleId = null,Object? picture = freezed,Object? gender = freezed,Object? ageRange = freezed,Object? mobile = freezed,Object? country = freezed,Object? state = freezed,Object? city = freezed,Object? language = freezed,Object? zip = freezed,Object? sendupdates = freezed,Object? unsubscribe = freezed,}) {
  return _then(_User(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as int,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,roleId: null == roleId ? _self.roleId : roleId // ignore: cast_nullable_to_non_nullable
as int,picture: freezed == picture ? _self.picture : picture // ignore: cast_nullable_to_non_nullable
as String?,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as int?,ageRange: freezed == ageRange ? _self.ageRange : ageRange // ignore: cast_nullable_to_non_nullable
as int?,mobile: freezed == mobile ? _self.mobile : mobile // ignore: cast_nullable_to_non_nullable
as String?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as int?,zip: freezed == zip ? _self.zip : zip // ignore: cast_nullable_to_non_nullable
as String?,sendupdates: freezed == sendupdates ? _self.sendupdates : sendupdates // ignore: cast_nullable_to_non_nullable
as String?,unsubscribe: freezed == unsubscribe ? _self.unsubscribe : unsubscribe // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
