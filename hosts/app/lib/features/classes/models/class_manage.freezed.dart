// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'class_manage.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ManageOption {

 int get id; String get name;
/// Create a copy of ManageOption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ManageOptionCopyWith<ManageOption> get copyWith => _$ManageOptionCopyWithImpl<ManageOption>(this as ManageOption, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ManageOption&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode => Object.hash(runtimeType,id,name);

@override
String toString() {
  return 'ManageOption(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class $ManageOptionCopyWith<$Res>  {
  factory $ManageOptionCopyWith(ManageOption value, $Res Function(ManageOption) _then) = _$ManageOptionCopyWithImpl;
@useResult
$Res call({
 int id, String name
});




}
/// @nodoc
class _$ManageOptionCopyWithImpl<$Res>
    implements $ManageOptionCopyWith<$Res> {
  _$ManageOptionCopyWithImpl(this._self, this._then);

  final ManageOption _self;
  final $Res Function(ManageOption) _then;

/// Create a copy of ManageOption
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ManageOption].
extension ManageOptionPatterns on ManageOption {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ManageOption value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ManageOption() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ManageOption value)  $default,){
final _that = this;
switch (_that) {
case _ManageOption():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ManageOption value)?  $default,){
final _that = this;
switch (_that) {
case _ManageOption() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ManageOption() when $default != null:
return $default(_that.id,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name)  $default,) {final _that = this;
switch (_that) {
case _ManageOption():
return $default(_that.id,_that.name);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name)?  $default,) {final _that = this;
switch (_that) {
case _ManageOption() when $default != null:
return $default(_that.id,_that.name);case _:
  return null;

}
}

}

/// @nodoc


class _ManageOption implements ManageOption {
  const _ManageOption({required this.id, required this.name});
  

@override final  int id;
@override final  String name;

/// Create a copy of ManageOption
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ManageOptionCopyWith<_ManageOption> get copyWith => __$ManageOptionCopyWithImpl<_ManageOption>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ManageOption&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode => Object.hash(runtimeType,id,name);

@override
String toString() {
  return 'ManageOption(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class _$ManageOptionCopyWith<$Res> implements $ManageOptionCopyWith<$Res> {
  factory _$ManageOptionCopyWith(_ManageOption value, $Res Function(_ManageOption) _then) = __$ManageOptionCopyWithImpl;
@override @useResult
$Res call({
 int id, String name
});




}
/// @nodoc
class __$ManageOptionCopyWithImpl<$Res>
    implements _$ManageOptionCopyWith<$Res> {
  __$ManageOptionCopyWithImpl(this._self, this._then);

  final _ManageOption _self;
  final $Res Function(_ManageOption) _then;

/// Create a copy of ManageOption
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,}) {
  return _then(_ManageOption(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$ManageTimezone {

 String get timezone; String get label;
/// Create a copy of ManageTimezone
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ManageTimezoneCopyWith<ManageTimezone> get copyWith => _$ManageTimezoneCopyWithImpl<ManageTimezone>(this as ManageTimezone, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ManageTimezone&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.label, label) || other.label == label));
}


@override
int get hashCode => Object.hash(runtimeType,timezone,label);

@override
String toString() {
  return 'ManageTimezone(timezone: $timezone, label: $label)';
}


}

/// @nodoc
abstract mixin class $ManageTimezoneCopyWith<$Res>  {
  factory $ManageTimezoneCopyWith(ManageTimezone value, $Res Function(ManageTimezone) _then) = _$ManageTimezoneCopyWithImpl;
@useResult
$Res call({
 String timezone, String label
});




}
/// @nodoc
class _$ManageTimezoneCopyWithImpl<$Res>
    implements $ManageTimezoneCopyWith<$Res> {
  _$ManageTimezoneCopyWithImpl(this._self, this._then);

  final ManageTimezone _self;
  final $Res Function(ManageTimezone) _then;

/// Create a copy of ManageTimezone
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? timezone = null,Object? label = null,}) {
  return _then(_self.copyWith(
timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ManageTimezone].
extension ManageTimezonePatterns on ManageTimezone {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ManageTimezone value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ManageTimezone() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ManageTimezone value)  $default,){
final _that = this;
switch (_that) {
case _ManageTimezone():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ManageTimezone value)?  $default,){
final _that = this;
switch (_that) {
case _ManageTimezone() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String timezone,  String label)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ManageTimezone() when $default != null:
return $default(_that.timezone,_that.label);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String timezone,  String label)  $default,) {final _that = this;
switch (_that) {
case _ManageTimezone():
return $default(_that.timezone,_that.label);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String timezone,  String label)?  $default,) {final _that = this;
switch (_that) {
case _ManageTimezone() when $default != null:
return $default(_that.timezone,_that.label);case _:
  return null;

}
}

}

/// @nodoc


class _ManageTimezone implements ManageTimezone {
  const _ManageTimezone({required this.timezone, required this.label});
  

@override final  String timezone;
@override final  String label;

/// Create a copy of ManageTimezone
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ManageTimezoneCopyWith<_ManageTimezone> get copyWith => __$ManageTimezoneCopyWithImpl<_ManageTimezone>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ManageTimezone&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.label, label) || other.label == label));
}


@override
int get hashCode => Object.hash(runtimeType,timezone,label);

@override
String toString() {
  return 'ManageTimezone(timezone: $timezone, label: $label)';
}


}

/// @nodoc
abstract mixin class _$ManageTimezoneCopyWith<$Res> implements $ManageTimezoneCopyWith<$Res> {
  factory _$ManageTimezoneCopyWith(_ManageTimezone value, $Res Function(_ManageTimezone) _then) = __$ManageTimezoneCopyWithImpl;
@override @useResult
$Res call({
 String timezone, String label
});




}
/// @nodoc
class __$ManageTimezoneCopyWithImpl<$Res>
    implements _$ManageTimezoneCopyWith<$Res> {
  __$ManageTimezoneCopyWithImpl(this._self, this._then);

  final _ManageTimezone _self;
  final $Res Function(_ManageTimezone) _then;

/// Create a copy of ManageTimezone
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timezone = null,Object? label = null,}) {
  return _then(_ManageTimezone(
timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$ManagedClass {

 int get id; String get code; String get name; String get levelName; int get gender; String get genderName; int? get languageId;/// `YYYY-MM-DD`, as the API sends and accepts it.
 String? get startedOn; String get format; String? get address; String? get city; String? get country; String? get location; int get teacher; String? get teacherName; String? get joinUrl;
/// Create a copy of ManagedClass
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ManagedClassCopyWith<ManagedClass> get copyWith => _$ManagedClassCopyWithImpl<ManagedClass>(this as ManagedClass, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ManagedClass&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.levelName, levelName) || other.levelName == levelName)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.genderName, genderName) || other.genderName == genderName)&&(identical(other.languageId, languageId) || other.languageId == languageId)&&(identical(other.startedOn, startedOn) || other.startedOn == startedOn)&&(identical(other.format, format) || other.format == format)&&(identical(other.address, address) || other.address == address)&&(identical(other.city, city) || other.city == city)&&(identical(other.country, country) || other.country == country)&&(identical(other.location, location) || other.location == location)&&(identical(other.teacher, teacher) || other.teacher == teacher)&&(identical(other.teacherName, teacherName) || other.teacherName == teacherName)&&(identical(other.joinUrl, joinUrl) || other.joinUrl == joinUrl));
}


@override
int get hashCode => Object.hash(runtimeType,id,code,name,levelName,gender,genderName,languageId,startedOn,format,address,city,country,location,teacher,teacherName,joinUrl);

@override
String toString() {
  return 'ManagedClass(id: $id, code: $code, name: $name, levelName: $levelName, gender: $gender, genderName: $genderName, languageId: $languageId, startedOn: $startedOn, format: $format, address: $address, city: $city, country: $country, location: $location, teacher: $teacher, teacherName: $teacherName, joinUrl: $joinUrl)';
}


}

/// @nodoc
abstract mixin class $ManagedClassCopyWith<$Res>  {
  factory $ManagedClassCopyWith(ManagedClass value, $Res Function(ManagedClass) _then) = _$ManagedClassCopyWithImpl;
@useResult
$Res call({
 int id, String code, String name, String levelName, int gender, String genderName, int? languageId, String? startedOn, String format, String? address, String? city, String? country, String? location, int teacher, String? teacherName, String? joinUrl
});




}
/// @nodoc
class _$ManagedClassCopyWithImpl<$Res>
    implements $ManagedClassCopyWith<$Res> {
  _$ManagedClassCopyWithImpl(this._self, this._then);

  final ManagedClass _self;
  final $Res Function(ManagedClass) _then;

/// Create a copy of ManagedClass
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? code = null,Object? name = null,Object? levelName = null,Object? gender = null,Object? genderName = null,Object? languageId = freezed,Object? startedOn = freezed,Object? format = null,Object? address = freezed,Object? city = freezed,Object? country = freezed,Object? location = freezed,Object? teacher = null,Object? teacherName = freezed,Object? joinUrl = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,levelName: null == levelName ? _self.levelName : levelName // ignore: cast_nullable_to_non_nullable
as String,gender: null == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as int,genderName: null == genderName ? _self.genderName : genderName // ignore: cast_nullable_to_non_nullable
as String,languageId: freezed == languageId ? _self.languageId : languageId // ignore: cast_nullable_to_non_nullable
as int?,startedOn: freezed == startedOn ? _self.startedOn : startedOn // ignore: cast_nullable_to_non_nullable
as String?,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,teacher: null == teacher ? _self.teacher : teacher // ignore: cast_nullable_to_non_nullable
as int,teacherName: freezed == teacherName ? _self.teacherName : teacherName // ignore: cast_nullable_to_non_nullable
as String?,joinUrl: freezed == joinUrl ? _self.joinUrl : joinUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ManagedClass].
extension ManagedClassPatterns on ManagedClass {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ManagedClass value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ManagedClass() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ManagedClass value)  $default,){
final _that = this;
switch (_that) {
case _ManagedClass():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ManagedClass value)?  $default,){
final _that = this;
switch (_that) {
case _ManagedClass() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String code,  String name,  String levelName,  int gender,  String genderName,  int? languageId,  String? startedOn,  String format,  String? address,  String? city,  String? country,  String? location,  int teacher,  String? teacherName,  String? joinUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ManagedClass() when $default != null:
return $default(_that.id,_that.code,_that.name,_that.levelName,_that.gender,_that.genderName,_that.languageId,_that.startedOn,_that.format,_that.address,_that.city,_that.country,_that.location,_that.teacher,_that.teacherName,_that.joinUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String code,  String name,  String levelName,  int gender,  String genderName,  int? languageId,  String? startedOn,  String format,  String? address,  String? city,  String? country,  String? location,  int teacher,  String? teacherName,  String? joinUrl)  $default,) {final _that = this;
switch (_that) {
case _ManagedClass():
return $default(_that.id,_that.code,_that.name,_that.levelName,_that.gender,_that.genderName,_that.languageId,_that.startedOn,_that.format,_that.address,_that.city,_that.country,_that.location,_that.teacher,_that.teacherName,_that.joinUrl);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String code,  String name,  String levelName,  int gender,  String genderName,  int? languageId,  String? startedOn,  String format,  String? address,  String? city,  String? country,  String? location,  int teacher,  String? teacherName,  String? joinUrl)?  $default,) {final _that = this;
switch (_that) {
case _ManagedClass() when $default != null:
return $default(_that.id,_that.code,_that.name,_that.levelName,_that.gender,_that.genderName,_that.languageId,_that.startedOn,_that.format,_that.address,_that.city,_that.country,_that.location,_that.teacher,_that.teacherName,_that.joinUrl);case _:
  return null;

}
}

}

/// @nodoc


class _ManagedClass implements ManagedClass {
  const _ManagedClass({required this.id, required this.code, required this.name, required this.levelName, required this.gender, required this.genderName, this.languageId, this.startedOn, this.format = 'Offline', this.address, this.city, this.country, this.location, required this.teacher, this.teacherName, this.joinUrl});
  

@override final  int id;
@override final  String code;
@override final  String name;
@override final  String levelName;
@override final  int gender;
@override final  String genderName;
@override final  int? languageId;
/// `YYYY-MM-DD`, as the API sends and accepts it.
@override final  String? startedOn;
@override@JsonKey() final  String format;
@override final  String? address;
@override final  String? city;
@override final  String? country;
@override final  String? location;
@override final  int teacher;
@override final  String? teacherName;
@override final  String? joinUrl;

/// Create a copy of ManagedClass
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ManagedClassCopyWith<_ManagedClass> get copyWith => __$ManagedClassCopyWithImpl<_ManagedClass>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ManagedClass&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.levelName, levelName) || other.levelName == levelName)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.genderName, genderName) || other.genderName == genderName)&&(identical(other.languageId, languageId) || other.languageId == languageId)&&(identical(other.startedOn, startedOn) || other.startedOn == startedOn)&&(identical(other.format, format) || other.format == format)&&(identical(other.address, address) || other.address == address)&&(identical(other.city, city) || other.city == city)&&(identical(other.country, country) || other.country == country)&&(identical(other.location, location) || other.location == location)&&(identical(other.teacher, teacher) || other.teacher == teacher)&&(identical(other.teacherName, teacherName) || other.teacherName == teacherName)&&(identical(other.joinUrl, joinUrl) || other.joinUrl == joinUrl));
}


@override
int get hashCode => Object.hash(runtimeType,id,code,name,levelName,gender,genderName,languageId,startedOn,format,address,city,country,location,teacher,teacherName,joinUrl);

@override
String toString() {
  return 'ManagedClass(id: $id, code: $code, name: $name, levelName: $levelName, gender: $gender, genderName: $genderName, languageId: $languageId, startedOn: $startedOn, format: $format, address: $address, city: $city, country: $country, location: $location, teacher: $teacher, teacherName: $teacherName, joinUrl: $joinUrl)';
}


}

/// @nodoc
abstract mixin class _$ManagedClassCopyWith<$Res> implements $ManagedClassCopyWith<$Res> {
  factory _$ManagedClassCopyWith(_ManagedClass value, $Res Function(_ManagedClass) _then) = __$ManagedClassCopyWithImpl;
@override @useResult
$Res call({
 int id, String code, String name, String levelName, int gender, String genderName, int? languageId, String? startedOn, String format, String? address, String? city, String? country, String? location, int teacher, String? teacherName, String? joinUrl
});




}
/// @nodoc
class __$ManagedClassCopyWithImpl<$Res>
    implements _$ManagedClassCopyWith<$Res> {
  __$ManagedClassCopyWithImpl(this._self, this._then);

  final _ManagedClass _self;
  final $Res Function(_ManagedClass) _then;

/// Create a copy of ManagedClass
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? code = null,Object? name = null,Object? levelName = null,Object? gender = null,Object? genderName = null,Object? languageId = freezed,Object? startedOn = freezed,Object? format = null,Object? address = freezed,Object? city = freezed,Object? country = freezed,Object? location = freezed,Object? teacher = null,Object? teacherName = freezed,Object? joinUrl = freezed,}) {
  return _then(_ManagedClass(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,levelName: null == levelName ? _self.levelName : levelName // ignore: cast_nullable_to_non_nullable
as String,gender: null == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as int,genderName: null == genderName ? _self.genderName : genderName // ignore: cast_nullable_to_non_nullable
as String,languageId: freezed == languageId ? _self.languageId : languageId // ignore: cast_nullable_to_non_nullable
as int?,startedOn: freezed == startedOn ? _self.startedOn : startedOn // ignore: cast_nullable_to_non_nullable
as String?,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,teacher: null == teacher ? _self.teacher : teacher // ignore: cast_nullable_to_non_nullable
as int,teacherName: freezed == teacherName ? _self.teacherName : teacherName // ignore: cast_nullable_to_non_nullable
as String?,joinUrl: freezed == joinUrl ? _self.joinUrl : joinUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$ManageTopic {

 int? get id; int get topicId;
/// Create a copy of ManageTopic
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ManageTopicCopyWith<ManageTopic> get copyWith => _$ManageTopicCopyWithImpl<ManageTopic>(this as ManageTopic, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ManageTopic&&(identical(other.id, id) || other.id == id)&&(identical(other.topicId, topicId) || other.topicId == topicId));
}


@override
int get hashCode => Object.hash(runtimeType,id,topicId);

@override
String toString() {
  return 'ManageTopic(id: $id, topicId: $topicId)';
}


}

/// @nodoc
abstract mixin class $ManageTopicCopyWith<$Res>  {
  factory $ManageTopicCopyWith(ManageTopic value, $Res Function(ManageTopic) _then) = _$ManageTopicCopyWithImpl;
@useResult
$Res call({
 int? id, int topicId
});




}
/// @nodoc
class _$ManageTopicCopyWithImpl<$Res>
    implements $ManageTopicCopyWith<$Res> {
  _$ManageTopicCopyWithImpl(this._self, this._then);

  final ManageTopic _self;
  final $Res Function(ManageTopic) _then;

/// Create a copy of ManageTopic
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? topicId = null,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,topicId: null == topicId ? _self.topicId : topicId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ManageTopic].
extension ManageTopicPatterns on ManageTopic {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ManageTopic value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ManageTopic() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ManageTopic value)  $default,){
final _that = this;
switch (_that) {
case _ManageTopic():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ManageTopic value)?  $default,){
final _that = this;
switch (_that) {
case _ManageTopic() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id,  int topicId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ManageTopic() when $default != null:
return $default(_that.id,_that.topicId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id,  int topicId)  $default,) {final _that = this;
switch (_that) {
case _ManageTopic():
return $default(_that.id,_that.topicId);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id,  int topicId)?  $default,) {final _that = this;
switch (_that) {
case _ManageTopic() when $default != null:
return $default(_that.id,_that.topicId);case _:
  return null;

}
}

}

/// @nodoc


class _ManageTopic extends ManageTopic {
  const _ManageTopic({this.id, required this.topicId}): super._();
  

@override final  int? id;
@override final  int topicId;

/// Create a copy of ManageTopic
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ManageTopicCopyWith<_ManageTopic> get copyWith => __$ManageTopicCopyWithImpl<_ManageTopic>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ManageTopic&&(identical(other.id, id) || other.id == id)&&(identical(other.topicId, topicId) || other.topicId == topicId));
}


@override
int get hashCode => Object.hash(runtimeType,id,topicId);

@override
String toString() {
  return 'ManageTopic(id: $id, topicId: $topicId)';
}


}

/// @nodoc
abstract mixin class _$ManageTopicCopyWith<$Res> implements $ManageTopicCopyWith<$Res> {
  factory _$ManageTopicCopyWith(_ManageTopic value, $Res Function(_ManageTopic) _then) = __$ManageTopicCopyWithImpl;
@override @useResult
$Res call({
 int? id, int topicId
});




}
/// @nodoc
class __$ManageTopicCopyWithImpl<$Res>
    implements _$ManageTopicCopyWith<$Res> {
  __$ManageTopicCopyWithImpl(this._self, this._then);

  final _ManageTopic _self;
  final $Res Function(_ManageTopic) _then;

/// Create a copy of ManageTopic
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? topicId = null,}) {
  return _then(_ManageTopic(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,topicId: null == topicId ? _self.topicId : topicId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$ManageSchedule {

 int? get id;/// 1 = Monday ... 7 = Sunday.
 int get day; int get hour; int get minute; String get timezone; List<ManageTopic> get topics;
/// Create a copy of ManageSchedule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ManageScheduleCopyWith<ManageSchedule> get copyWith => _$ManageScheduleCopyWithImpl<ManageSchedule>(this as ManageSchedule, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ManageSchedule&&(identical(other.id, id) || other.id == id)&&(identical(other.day, day) || other.day == day)&&(identical(other.hour, hour) || other.hour == hour)&&(identical(other.minute, minute) || other.minute == minute)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&const DeepCollectionEquality().equals(other.topics, topics));
}


@override
int get hashCode => Object.hash(runtimeType,id,day,hour,minute,timezone,const DeepCollectionEquality().hash(topics));

@override
String toString() {
  return 'ManageSchedule(id: $id, day: $day, hour: $hour, minute: $minute, timezone: $timezone, topics: $topics)';
}


}

/// @nodoc
abstract mixin class $ManageScheduleCopyWith<$Res>  {
  factory $ManageScheduleCopyWith(ManageSchedule value, $Res Function(ManageSchedule) _then) = _$ManageScheduleCopyWithImpl;
@useResult
$Res call({
 int? id, int day, int hour, int minute, String timezone, List<ManageTopic> topics
});




}
/// @nodoc
class _$ManageScheduleCopyWithImpl<$Res>
    implements $ManageScheduleCopyWith<$Res> {
  _$ManageScheduleCopyWithImpl(this._self, this._then);

  final ManageSchedule _self;
  final $Res Function(ManageSchedule) _then;

/// Create a copy of ManageSchedule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? day = null,Object? hour = null,Object? minute = null,Object? timezone = null,Object? topics = null,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as int,hour: null == hour ? _self.hour : hour // ignore: cast_nullable_to_non_nullable
as int,minute: null == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as int,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,topics: null == topics ? _self.topics : topics // ignore: cast_nullable_to_non_nullable
as List<ManageTopic>,
  ));
}

}


/// Adds pattern-matching-related methods to [ManageSchedule].
extension ManageSchedulePatterns on ManageSchedule {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ManageSchedule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ManageSchedule() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ManageSchedule value)  $default,){
final _that = this;
switch (_that) {
case _ManageSchedule():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ManageSchedule value)?  $default,){
final _that = this;
switch (_that) {
case _ManageSchedule() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id,  int day,  int hour,  int minute,  String timezone,  List<ManageTopic> topics)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ManageSchedule() when $default != null:
return $default(_that.id,_that.day,_that.hour,_that.minute,_that.timezone,_that.topics);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id,  int day,  int hour,  int minute,  String timezone,  List<ManageTopic> topics)  $default,) {final _that = this;
switch (_that) {
case _ManageSchedule():
return $default(_that.id,_that.day,_that.hour,_that.minute,_that.timezone,_that.topics);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id,  int day,  int hour,  int minute,  String timezone,  List<ManageTopic> topics)?  $default,) {final _that = this;
switch (_that) {
case _ManageSchedule() when $default != null:
return $default(_that.id,_that.day,_that.hour,_that.minute,_that.timezone,_that.topics);case _:
  return null;

}
}

}

/// @nodoc


class _ManageSchedule extends ManageSchedule {
  const _ManageSchedule({this.id, required this.day, required this.hour, required this.minute, required this.timezone, final  List<ManageTopic> topics = const []}): _topics = topics,super._();
  

@override final  int? id;
/// 1 = Monday ... 7 = Sunday.
@override final  int day;
@override final  int hour;
@override final  int minute;
@override final  String timezone;
 final  List<ManageTopic> _topics;
@override@JsonKey() List<ManageTopic> get topics {
  if (_topics is EqualUnmodifiableListView) return _topics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_topics);
}


/// Create a copy of ManageSchedule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ManageScheduleCopyWith<_ManageSchedule> get copyWith => __$ManageScheduleCopyWithImpl<_ManageSchedule>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ManageSchedule&&(identical(other.id, id) || other.id == id)&&(identical(other.day, day) || other.day == day)&&(identical(other.hour, hour) || other.hour == hour)&&(identical(other.minute, minute) || other.minute == minute)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&const DeepCollectionEquality().equals(other._topics, _topics));
}


@override
int get hashCode => Object.hash(runtimeType,id,day,hour,minute,timezone,const DeepCollectionEquality().hash(_topics));

@override
String toString() {
  return 'ManageSchedule(id: $id, day: $day, hour: $hour, minute: $minute, timezone: $timezone, topics: $topics)';
}


}

/// @nodoc
abstract mixin class _$ManageScheduleCopyWith<$Res> implements $ManageScheduleCopyWith<$Res> {
  factory _$ManageScheduleCopyWith(_ManageSchedule value, $Res Function(_ManageSchedule) _then) = __$ManageScheduleCopyWithImpl;
@override @useResult
$Res call({
 int? id, int day, int hour, int minute, String timezone, List<ManageTopic> topics
});




}
/// @nodoc
class __$ManageScheduleCopyWithImpl<$Res>
    implements _$ManageScheduleCopyWith<$Res> {
  __$ManageScheduleCopyWithImpl(this._self, this._then);

  final _ManageSchedule _self;
  final $Res Function(_ManageSchedule) _then;

/// Create a copy of ManageSchedule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? day = null,Object? hour = null,Object? minute = null,Object? timezone = null,Object? topics = null,}) {
  return _then(_ManageSchedule(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as int,hour: null == hour ? _self.hour : hour // ignore: cast_nullable_to_non_nullable
as int,minute: null == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as int,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,topics: null == topics ? _self._topics : topics // ignore: cast_nullable_to_non_nullable
as List<ManageTopic>,
  ));
}


}

/// @nodoc
mixin _$ManagedStudent {

 int get token; String get name; String? get email; String? get mobile; String? get joinedOn; String? get notes; bool get mcqAdmin;/// No sign-in and no real email: a record a super admin may link to a
/// member (#1135).
 bool get extraStudent;
/// Create a copy of ManagedStudent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ManagedStudentCopyWith<ManagedStudent> get copyWith => _$ManagedStudentCopyWithImpl<ManagedStudent>(this as ManagedStudent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ManagedStudent&&(identical(other.token, token) || other.token == token)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.mobile, mobile) || other.mobile == mobile)&&(identical(other.joinedOn, joinedOn) || other.joinedOn == joinedOn)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.mcqAdmin, mcqAdmin) || other.mcqAdmin == mcqAdmin)&&(identical(other.extraStudent, extraStudent) || other.extraStudent == extraStudent));
}


@override
int get hashCode => Object.hash(runtimeType,token,name,email,mobile,joinedOn,notes,mcqAdmin,extraStudent);

@override
String toString() {
  return 'ManagedStudent(token: $token, name: $name, email: $email, mobile: $mobile, joinedOn: $joinedOn, notes: $notes, mcqAdmin: $mcqAdmin, extraStudent: $extraStudent)';
}


}

/// @nodoc
abstract mixin class $ManagedStudentCopyWith<$Res>  {
  factory $ManagedStudentCopyWith(ManagedStudent value, $Res Function(ManagedStudent) _then) = _$ManagedStudentCopyWithImpl;
@useResult
$Res call({
 int token, String name, String? email, String? mobile, String? joinedOn, String? notes, bool mcqAdmin, bool extraStudent
});




}
/// @nodoc
class _$ManagedStudentCopyWithImpl<$Res>
    implements $ManagedStudentCopyWith<$Res> {
  _$ManagedStudentCopyWithImpl(this._self, this._then);

  final ManagedStudent _self;
  final $Res Function(ManagedStudent) _then;

/// Create a copy of ManagedStudent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? token = null,Object? name = null,Object? email = freezed,Object? mobile = freezed,Object? joinedOn = freezed,Object? notes = freezed,Object? mcqAdmin = null,Object? extraStudent = null,}) {
  return _then(_self.copyWith(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,mobile: freezed == mobile ? _self.mobile : mobile // ignore: cast_nullable_to_non_nullable
as String?,joinedOn: freezed == joinedOn ? _self.joinedOn : joinedOn // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,mcqAdmin: null == mcqAdmin ? _self.mcqAdmin : mcqAdmin // ignore: cast_nullable_to_non_nullable
as bool,extraStudent: null == extraStudent ? _self.extraStudent : extraStudent // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ManagedStudent].
extension ManagedStudentPatterns on ManagedStudent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ManagedStudent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ManagedStudent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ManagedStudent value)  $default,){
final _that = this;
switch (_that) {
case _ManagedStudent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ManagedStudent value)?  $default,){
final _that = this;
switch (_that) {
case _ManagedStudent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int token,  String name,  String? email,  String? mobile,  String? joinedOn,  String? notes,  bool mcqAdmin,  bool extraStudent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ManagedStudent() when $default != null:
return $default(_that.token,_that.name,_that.email,_that.mobile,_that.joinedOn,_that.notes,_that.mcqAdmin,_that.extraStudent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int token,  String name,  String? email,  String? mobile,  String? joinedOn,  String? notes,  bool mcqAdmin,  bool extraStudent)  $default,) {final _that = this;
switch (_that) {
case _ManagedStudent():
return $default(_that.token,_that.name,_that.email,_that.mobile,_that.joinedOn,_that.notes,_that.mcqAdmin,_that.extraStudent);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int token,  String name,  String? email,  String? mobile,  String? joinedOn,  String? notes,  bool mcqAdmin,  bool extraStudent)?  $default,) {final _that = this;
switch (_that) {
case _ManagedStudent() when $default != null:
return $default(_that.token,_that.name,_that.email,_that.mobile,_that.joinedOn,_that.notes,_that.mcqAdmin,_that.extraStudent);case _:
  return null;

}
}

}

/// @nodoc


class _ManagedStudent implements ManagedStudent {
  const _ManagedStudent({required this.token, required this.name, this.email, this.mobile, this.joinedOn, this.notes, this.mcqAdmin = false, this.extraStudent = false});
  

@override final  int token;
@override final  String name;
@override final  String? email;
@override final  String? mobile;
@override final  String? joinedOn;
@override final  String? notes;
@override@JsonKey() final  bool mcqAdmin;
/// No sign-in and no real email: a record a super admin may link to a
/// member (#1135).
@override@JsonKey() final  bool extraStudent;

/// Create a copy of ManagedStudent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ManagedStudentCopyWith<_ManagedStudent> get copyWith => __$ManagedStudentCopyWithImpl<_ManagedStudent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ManagedStudent&&(identical(other.token, token) || other.token == token)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.mobile, mobile) || other.mobile == mobile)&&(identical(other.joinedOn, joinedOn) || other.joinedOn == joinedOn)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.mcqAdmin, mcqAdmin) || other.mcqAdmin == mcqAdmin)&&(identical(other.extraStudent, extraStudent) || other.extraStudent == extraStudent));
}


@override
int get hashCode => Object.hash(runtimeType,token,name,email,mobile,joinedOn,notes,mcqAdmin,extraStudent);

@override
String toString() {
  return 'ManagedStudent(token: $token, name: $name, email: $email, mobile: $mobile, joinedOn: $joinedOn, notes: $notes, mcqAdmin: $mcqAdmin, extraStudent: $extraStudent)';
}


}

/// @nodoc
abstract mixin class _$ManagedStudentCopyWith<$Res> implements $ManagedStudentCopyWith<$Res> {
  factory _$ManagedStudentCopyWith(_ManagedStudent value, $Res Function(_ManagedStudent) _then) = __$ManagedStudentCopyWithImpl;
@override @useResult
$Res call({
 int token, String name, String? email, String? mobile, String? joinedOn, String? notes, bool mcqAdmin, bool extraStudent
});




}
/// @nodoc
class __$ManagedStudentCopyWithImpl<$Res>
    implements _$ManagedStudentCopyWith<$Res> {
  __$ManagedStudentCopyWithImpl(this._self, this._then);

  final _ManagedStudent _self;
  final $Res Function(_ManagedStudent) _then;

/// Create a copy of ManagedStudent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? token = null,Object? name = null,Object? email = freezed,Object? mobile = freezed,Object? joinedOn = freezed,Object? notes = freezed,Object? mcqAdmin = null,Object? extraStudent = null,}) {
  return _then(_ManagedStudent(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,mobile: freezed == mobile ? _self.mobile : mobile // ignore: cast_nullable_to_non_nullable
as String?,joinedOn: freezed == joinedOn ? _self.joinedOn : joinedOn // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,mcqAdmin: null == mcqAdmin ? _self.mcqAdmin : mcqAdmin // ignore: cast_nullable_to_non_nullable
as bool,extraStudent: null == extraStudent ? _self.extraStudent : extraStudent // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$RemovedStudent {

 int get token; String get name; String? get email; String? get mobile; String? get removedAt; String? get removedReason; String? get removedByName;
/// Create a copy of RemovedStudent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RemovedStudentCopyWith<RemovedStudent> get copyWith => _$RemovedStudentCopyWithImpl<RemovedStudent>(this as RemovedStudent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RemovedStudent&&(identical(other.token, token) || other.token == token)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.mobile, mobile) || other.mobile == mobile)&&(identical(other.removedAt, removedAt) || other.removedAt == removedAt)&&(identical(other.removedReason, removedReason) || other.removedReason == removedReason)&&(identical(other.removedByName, removedByName) || other.removedByName == removedByName));
}


@override
int get hashCode => Object.hash(runtimeType,token,name,email,mobile,removedAt,removedReason,removedByName);

@override
String toString() {
  return 'RemovedStudent(token: $token, name: $name, email: $email, mobile: $mobile, removedAt: $removedAt, removedReason: $removedReason, removedByName: $removedByName)';
}


}

/// @nodoc
abstract mixin class $RemovedStudentCopyWith<$Res>  {
  factory $RemovedStudentCopyWith(RemovedStudent value, $Res Function(RemovedStudent) _then) = _$RemovedStudentCopyWithImpl;
@useResult
$Res call({
 int token, String name, String? email, String? mobile, String? removedAt, String? removedReason, String? removedByName
});




}
/// @nodoc
class _$RemovedStudentCopyWithImpl<$Res>
    implements $RemovedStudentCopyWith<$Res> {
  _$RemovedStudentCopyWithImpl(this._self, this._then);

  final RemovedStudent _self;
  final $Res Function(RemovedStudent) _then;

/// Create a copy of RemovedStudent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? token = null,Object? name = null,Object? email = freezed,Object? mobile = freezed,Object? removedAt = freezed,Object? removedReason = freezed,Object? removedByName = freezed,}) {
  return _then(_self.copyWith(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,mobile: freezed == mobile ? _self.mobile : mobile // ignore: cast_nullable_to_non_nullable
as String?,removedAt: freezed == removedAt ? _self.removedAt : removedAt // ignore: cast_nullable_to_non_nullable
as String?,removedReason: freezed == removedReason ? _self.removedReason : removedReason // ignore: cast_nullable_to_non_nullable
as String?,removedByName: freezed == removedByName ? _self.removedByName : removedByName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RemovedStudent].
extension RemovedStudentPatterns on RemovedStudent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RemovedStudent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RemovedStudent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RemovedStudent value)  $default,){
final _that = this;
switch (_that) {
case _RemovedStudent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RemovedStudent value)?  $default,){
final _that = this;
switch (_that) {
case _RemovedStudent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int token,  String name,  String? email,  String? mobile,  String? removedAt,  String? removedReason,  String? removedByName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RemovedStudent() when $default != null:
return $default(_that.token,_that.name,_that.email,_that.mobile,_that.removedAt,_that.removedReason,_that.removedByName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int token,  String name,  String? email,  String? mobile,  String? removedAt,  String? removedReason,  String? removedByName)  $default,) {final _that = this;
switch (_that) {
case _RemovedStudent():
return $default(_that.token,_that.name,_that.email,_that.mobile,_that.removedAt,_that.removedReason,_that.removedByName);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int token,  String name,  String? email,  String? mobile,  String? removedAt,  String? removedReason,  String? removedByName)?  $default,) {final _that = this;
switch (_that) {
case _RemovedStudent() when $default != null:
return $default(_that.token,_that.name,_that.email,_that.mobile,_that.removedAt,_that.removedReason,_that.removedByName);case _:
  return null;

}
}

}

/// @nodoc


class _RemovedStudent implements RemovedStudent {
  const _RemovedStudent({required this.token, required this.name, this.email, this.mobile, this.removedAt, this.removedReason, this.removedByName});
  

@override final  int token;
@override final  String name;
@override final  String? email;
@override final  String? mobile;
@override final  String? removedAt;
@override final  String? removedReason;
@override final  String? removedByName;

/// Create a copy of RemovedStudent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RemovedStudentCopyWith<_RemovedStudent> get copyWith => __$RemovedStudentCopyWithImpl<_RemovedStudent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RemovedStudent&&(identical(other.token, token) || other.token == token)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.mobile, mobile) || other.mobile == mobile)&&(identical(other.removedAt, removedAt) || other.removedAt == removedAt)&&(identical(other.removedReason, removedReason) || other.removedReason == removedReason)&&(identical(other.removedByName, removedByName) || other.removedByName == removedByName));
}


@override
int get hashCode => Object.hash(runtimeType,token,name,email,mobile,removedAt,removedReason,removedByName);

@override
String toString() {
  return 'RemovedStudent(token: $token, name: $name, email: $email, mobile: $mobile, removedAt: $removedAt, removedReason: $removedReason, removedByName: $removedByName)';
}


}

/// @nodoc
abstract mixin class _$RemovedStudentCopyWith<$Res> implements $RemovedStudentCopyWith<$Res> {
  factory _$RemovedStudentCopyWith(_RemovedStudent value, $Res Function(_RemovedStudent) _then) = __$RemovedStudentCopyWithImpl;
@override @useResult
$Res call({
 int token, String name, String? email, String? mobile, String? removedAt, String? removedReason, String? removedByName
});




}
/// @nodoc
class __$RemovedStudentCopyWithImpl<$Res>
    implements _$RemovedStudentCopyWith<$Res> {
  __$RemovedStudentCopyWithImpl(this._self, this._then);

  final _RemovedStudent _self;
  final $Res Function(_RemovedStudent) _then;

/// Create a copy of RemovedStudent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? token = null,Object? name = null,Object? email = freezed,Object? mobile = freezed,Object? removedAt = freezed,Object? removedReason = freezed,Object? removedByName = freezed,}) {
  return _then(_RemovedStudent(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,mobile: freezed == mobile ? _self.mobile : mobile // ignore: cast_nullable_to_non_nullable
as String?,removedAt: freezed == removedAt ? _self.removedAt : removedAt // ignore: cast_nullable_to_non_nullable
as String?,removedReason: freezed == removedReason ? _self.removedReason : removedReason // ignore: cast_nullable_to_non_nullable
as String?,removedByName: freezed == removedByName ? _self.removedByName : removedByName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$AddCandidate {

 int get token; String get name; String? get email; String? get mobile;
/// Create a copy of AddCandidate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AddCandidateCopyWith<AddCandidate> get copyWith => _$AddCandidateCopyWithImpl<AddCandidate>(this as AddCandidate, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AddCandidate&&(identical(other.token, token) || other.token == token)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.mobile, mobile) || other.mobile == mobile));
}


@override
int get hashCode => Object.hash(runtimeType,token,name,email,mobile);

@override
String toString() {
  return 'AddCandidate(token: $token, name: $name, email: $email, mobile: $mobile)';
}


}

/// @nodoc
abstract mixin class $AddCandidateCopyWith<$Res>  {
  factory $AddCandidateCopyWith(AddCandidate value, $Res Function(AddCandidate) _then) = _$AddCandidateCopyWithImpl;
@useResult
$Res call({
 int token, String name, String? email, String? mobile
});




}
/// @nodoc
class _$AddCandidateCopyWithImpl<$Res>
    implements $AddCandidateCopyWith<$Res> {
  _$AddCandidateCopyWithImpl(this._self, this._then);

  final AddCandidate _self;
  final $Res Function(AddCandidate) _then;

/// Create a copy of AddCandidate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? token = null,Object? name = null,Object? email = freezed,Object? mobile = freezed,}) {
  return _then(_self.copyWith(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,mobile: freezed == mobile ? _self.mobile : mobile // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AddCandidate].
extension AddCandidatePatterns on AddCandidate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AddCandidate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AddCandidate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AddCandidate value)  $default,){
final _that = this;
switch (_that) {
case _AddCandidate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AddCandidate value)?  $default,){
final _that = this;
switch (_that) {
case _AddCandidate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int token,  String name,  String? email,  String? mobile)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AddCandidate() when $default != null:
return $default(_that.token,_that.name,_that.email,_that.mobile);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int token,  String name,  String? email,  String? mobile)  $default,) {final _that = this;
switch (_that) {
case _AddCandidate():
return $default(_that.token,_that.name,_that.email,_that.mobile);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int token,  String name,  String? email,  String? mobile)?  $default,) {final _that = this;
switch (_that) {
case _AddCandidate() when $default != null:
return $default(_that.token,_that.name,_that.email,_that.mobile);case _:
  return null;

}
}

}

/// @nodoc


class _AddCandidate implements AddCandidate {
  const _AddCandidate({required this.token, required this.name, this.email, this.mobile});
  

@override final  int token;
@override final  String name;
@override final  String? email;
@override final  String? mobile;

/// Create a copy of AddCandidate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AddCandidateCopyWith<_AddCandidate> get copyWith => __$AddCandidateCopyWithImpl<_AddCandidate>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AddCandidate&&(identical(other.token, token) || other.token == token)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.mobile, mobile) || other.mobile == mobile));
}


@override
int get hashCode => Object.hash(runtimeType,token,name,email,mobile);

@override
String toString() {
  return 'AddCandidate(token: $token, name: $name, email: $email, mobile: $mobile)';
}


}

/// @nodoc
abstract mixin class _$AddCandidateCopyWith<$Res> implements $AddCandidateCopyWith<$Res> {
  factory _$AddCandidateCopyWith(_AddCandidate value, $Res Function(_AddCandidate) _then) = __$AddCandidateCopyWithImpl;
@override @useResult
$Res call({
 int token, String name, String? email, String? mobile
});




}
/// @nodoc
class __$AddCandidateCopyWithImpl<$Res>
    implements _$AddCandidateCopyWith<$Res> {
  __$AddCandidateCopyWithImpl(this._self, this._then);

  final _AddCandidate _self;
  final $Res Function(_AddCandidate) _then;

/// Create a copy of AddCandidate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? token = null,Object? name = null,Object? email = freezed,Object? mobile = freezed,}) {
  return _then(_AddCandidate(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,mobile: freezed == mobile ? _self.mobile : mobile // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$TransferRecord {

 int get studentToken; String get studentName; String get fromClassCode; String get toClassCode; String get type; String? get reason; String? get transferredBy; String? get transferredAt;
/// Create a copy of TransferRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransferRecordCopyWith<TransferRecord> get copyWith => _$TransferRecordCopyWithImpl<TransferRecord>(this as TransferRecord, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransferRecord&&(identical(other.studentToken, studentToken) || other.studentToken == studentToken)&&(identical(other.studentName, studentName) || other.studentName == studentName)&&(identical(other.fromClassCode, fromClassCode) || other.fromClassCode == fromClassCode)&&(identical(other.toClassCode, toClassCode) || other.toClassCode == toClassCode)&&(identical(other.type, type) || other.type == type)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.transferredBy, transferredBy) || other.transferredBy == transferredBy)&&(identical(other.transferredAt, transferredAt) || other.transferredAt == transferredAt));
}


@override
int get hashCode => Object.hash(runtimeType,studentToken,studentName,fromClassCode,toClassCode,type,reason,transferredBy,transferredAt);

@override
String toString() {
  return 'TransferRecord(studentToken: $studentToken, studentName: $studentName, fromClassCode: $fromClassCode, toClassCode: $toClassCode, type: $type, reason: $reason, transferredBy: $transferredBy, transferredAt: $transferredAt)';
}


}

/// @nodoc
abstract mixin class $TransferRecordCopyWith<$Res>  {
  factory $TransferRecordCopyWith(TransferRecord value, $Res Function(TransferRecord) _then) = _$TransferRecordCopyWithImpl;
@useResult
$Res call({
 int studentToken, String studentName, String fromClassCode, String toClassCode, String type, String? reason, String? transferredBy, String? transferredAt
});




}
/// @nodoc
class _$TransferRecordCopyWithImpl<$Res>
    implements $TransferRecordCopyWith<$Res> {
  _$TransferRecordCopyWithImpl(this._self, this._then);

  final TransferRecord _self;
  final $Res Function(TransferRecord) _then;

/// Create a copy of TransferRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? studentToken = null,Object? studentName = null,Object? fromClassCode = null,Object? toClassCode = null,Object? type = null,Object? reason = freezed,Object? transferredBy = freezed,Object? transferredAt = freezed,}) {
  return _then(_self.copyWith(
studentToken: null == studentToken ? _self.studentToken : studentToken // ignore: cast_nullable_to_non_nullable
as int,studentName: null == studentName ? _self.studentName : studentName // ignore: cast_nullable_to_non_nullable
as String,fromClassCode: null == fromClassCode ? _self.fromClassCode : fromClassCode // ignore: cast_nullable_to_non_nullable
as String,toClassCode: null == toClassCode ? _self.toClassCode : toClassCode // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,transferredBy: freezed == transferredBy ? _self.transferredBy : transferredBy // ignore: cast_nullable_to_non_nullable
as String?,transferredAt: freezed == transferredAt ? _self.transferredAt : transferredAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TransferRecord].
extension TransferRecordPatterns on TransferRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TransferRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TransferRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TransferRecord value)  $default,){
final _that = this;
switch (_that) {
case _TransferRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TransferRecord value)?  $default,){
final _that = this;
switch (_that) {
case _TransferRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int studentToken,  String studentName,  String fromClassCode,  String toClassCode,  String type,  String? reason,  String? transferredBy,  String? transferredAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TransferRecord() when $default != null:
return $default(_that.studentToken,_that.studentName,_that.fromClassCode,_that.toClassCode,_that.type,_that.reason,_that.transferredBy,_that.transferredAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int studentToken,  String studentName,  String fromClassCode,  String toClassCode,  String type,  String? reason,  String? transferredBy,  String? transferredAt)  $default,) {final _that = this;
switch (_that) {
case _TransferRecord():
return $default(_that.studentToken,_that.studentName,_that.fromClassCode,_that.toClassCode,_that.type,_that.reason,_that.transferredBy,_that.transferredAt);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int studentToken,  String studentName,  String fromClassCode,  String toClassCode,  String type,  String? reason,  String? transferredBy,  String? transferredAt)?  $default,) {final _that = this;
switch (_that) {
case _TransferRecord() when $default != null:
return $default(_that.studentToken,_that.studentName,_that.fromClassCode,_that.toClassCode,_that.type,_that.reason,_that.transferredBy,_that.transferredAt);case _:
  return null;

}
}

}

/// @nodoc


class _TransferRecord implements TransferRecord {
  const _TransferRecord({required this.studentToken, required this.studentName, required this.fromClassCode, required this.toClassCode, required this.type, this.reason, this.transferredBy, this.transferredAt});
  

@override final  int studentToken;
@override final  String studentName;
@override final  String fromClassCode;
@override final  String toClassCode;
@override final  String type;
@override final  String? reason;
@override final  String? transferredBy;
@override final  String? transferredAt;

/// Create a copy of TransferRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TransferRecordCopyWith<_TransferRecord> get copyWith => __$TransferRecordCopyWithImpl<_TransferRecord>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TransferRecord&&(identical(other.studentToken, studentToken) || other.studentToken == studentToken)&&(identical(other.studentName, studentName) || other.studentName == studentName)&&(identical(other.fromClassCode, fromClassCode) || other.fromClassCode == fromClassCode)&&(identical(other.toClassCode, toClassCode) || other.toClassCode == toClassCode)&&(identical(other.type, type) || other.type == type)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.transferredBy, transferredBy) || other.transferredBy == transferredBy)&&(identical(other.transferredAt, transferredAt) || other.transferredAt == transferredAt));
}


@override
int get hashCode => Object.hash(runtimeType,studentToken,studentName,fromClassCode,toClassCode,type,reason,transferredBy,transferredAt);

@override
String toString() {
  return 'TransferRecord(studentToken: $studentToken, studentName: $studentName, fromClassCode: $fromClassCode, toClassCode: $toClassCode, type: $type, reason: $reason, transferredBy: $transferredBy, transferredAt: $transferredAt)';
}


}

/// @nodoc
abstract mixin class _$TransferRecordCopyWith<$Res> implements $TransferRecordCopyWith<$Res> {
  factory _$TransferRecordCopyWith(_TransferRecord value, $Res Function(_TransferRecord) _then) = __$TransferRecordCopyWithImpl;
@override @useResult
$Res call({
 int studentToken, String studentName, String fromClassCode, String toClassCode, String type, String? reason, String? transferredBy, String? transferredAt
});




}
/// @nodoc
class __$TransferRecordCopyWithImpl<$Res>
    implements _$TransferRecordCopyWith<$Res> {
  __$TransferRecordCopyWithImpl(this._self, this._then);

  final _TransferRecord _self;
  final $Res Function(_TransferRecord) _then;

/// Create a copy of TransferRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? studentToken = null,Object? studentName = null,Object? fromClassCode = null,Object? toClassCode = null,Object? type = null,Object? reason = freezed,Object? transferredBy = freezed,Object? transferredAt = freezed,}) {
  return _then(_TransferRecord(
studentToken: null == studentToken ? _self.studentToken : studentToken // ignore: cast_nullable_to_non_nullable
as int,studentName: null == studentName ? _self.studentName : studentName // ignore: cast_nullable_to_non_nullable
as String,fromClassCode: null == fromClassCode ? _self.fromClassCode : fromClassCode // ignore: cast_nullable_to_non_nullable
as String,toClassCode: null == toClassCode ? _self.toClassCode : toClassCode // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,transferredBy: freezed == transferredBy ? _self.transferredBy : transferredBy // ignore: cast_nullable_to_non_nullable
as String?,transferredAt: freezed == transferredAt ? _self.transferredAt : transferredAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$TransferDestination {

 int get id; String get code; String get name;
/// Create a copy of TransferDestination
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransferDestinationCopyWith<TransferDestination> get copyWith => _$TransferDestinationCopyWithImpl<TransferDestination>(this as TransferDestination, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransferDestination&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode => Object.hash(runtimeType,id,code,name);

@override
String toString() {
  return 'TransferDestination(id: $id, code: $code, name: $name)';
}


}

/// @nodoc
abstract mixin class $TransferDestinationCopyWith<$Res>  {
  factory $TransferDestinationCopyWith(TransferDestination value, $Res Function(TransferDestination) _then) = _$TransferDestinationCopyWithImpl;
@useResult
$Res call({
 int id, String code, String name
});




}
/// @nodoc
class _$TransferDestinationCopyWithImpl<$Res>
    implements $TransferDestinationCopyWith<$Res> {
  _$TransferDestinationCopyWithImpl(this._self, this._then);

  final TransferDestination _self;
  final $Res Function(TransferDestination) _then;

/// Create a copy of TransferDestination
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? code = null,Object? name = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TransferDestination].
extension TransferDestinationPatterns on TransferDestination {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TransferDestination value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TransferDestination() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TransferDestination value)  $default,){
final _that = this;
switch (_that) {
case _TransferDestination():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TransferDestination value)?  $default,){
final _that = this;
switch (_that) {
case _TransferDestination() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String code,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TransferDestination() when $default != null:
return $default(_that.id,_that.code,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String code,  String name)  $default,) {final _that = this;
switch (_that) {
case _TransferDestination():
return $default(_that.id,_that.code,_that.name);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String code,  String name)?  $default,) {final _that = this;
switch (_that) {
case _TransferDestination() when $default != null:
return $default(_that.id,_that.code,_that.name);case _:
  return null;

}
}

}

/// @nodoc


class _TransferDestination implements TransferDestination {
  const _TransferDestination({required this.id, required this.code, required this.name});
  

@override final  int id;
@override final  String code;
@override final  String name;

/// Create a copy of TransferDestination
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TransferDestinationCopyWith<_TransferDestination> get copyWith => __$TransferDestinationCopyWithImpl<_TransferDestination>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TransferDestination&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode => Object.hash(runtimeType,id,code,name);

@override
String toString() {
  return 'TransferDestination(id: $id, code: $code, name: $name)';
}


}

/// @nodoc
abstract mixin class _$TransferDestinationCopyWith<$Res> implements $TransferDestinationCopyWith<$Res> {
  factory _$TransferDestinationCopyWith(_TransferDestination value, $Res Function(_TransferDestination) _then) = __$TransferDestinationCopyWithImpl;
@override @useResult
$Res call({
 int id, String code, String name
});




}
/// @nodoc
class __$TransferDestinationCopyWithImpl<$Res>
    implements _$TransferDestinationCopyWith<$Res> {
  __$TransferDestinationCopyWithImpl(this._self, this._then);

  final _TransferDestination _self;
  final $Res Function(_TransferDestination) _then;

/// Create a copy of TransferDestination
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? code = null,Object? name = null,}) {
  return _then(_TransferDestination(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$ManageCan {

 bool get update; bool get enrol; bool get setClassAdmin; bool get transfer; bool get link;
/// Create a copy of ManageCan
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ManageCanCopyWith<ManageCan> get copyWith => _$ManageCanCopyWithImpl<ManageCan>(this as ManageCan, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ManageCan&&(identical(other.update, update) || other.update == update)&&(identical(other.enrol, enrol) || other.enrol == enrol)&&(identical(other.setClassAdmin, setClassAdmin) || other.setClassAdmin == setClassAdmin)&&(identical(other.transfer, transfer) || other.transfer == transfer)&&(identical(other.link, link) || other.link == link));
}


@override
int get hashCode => Object.hash(runtimeType,update,enrol,setClassAdmin,transfer,link);

@override
String toString() {
  return 'ManageCan(update: $update, enrol: $enrol, setClassAdmin: $setClassAdmin, transfer: $transfer, link: $link)';
}


}

/// @nodoc
abstract mixin class $ManageCanCopyWith<$Res>  {
  factory $ManageCanCopyWith(ManageCan value, $Res Function(ManageCan) _then) = _$ManageCanCopyWithImpl;
@useResult
$Res call({
 bool update, bool enrol, bool setClassAdmin, bool transfer, bool link
});




}
/// @nodoc
class _$ManageCanCopyWithImpl<$Res>
    implements $ManageCanCopyWith<$Res> {
  _$ManageCanCopyWithImpl(this._self, this._then);

  final ManageCan _self;
  final $Res Function(ManageCan) _then;

/// Create a copy of ManageCan
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? update = null,Object? enrol = null,Object? setClassAdmin = null,Object? transfer = null,Object? link = null,}) {
  return _then(_self.copyWith(
update: null == update ? _self.update : update // ignore: cast_nullable_to_non_nullable
as bool,enrol: null == enrol ? _self.enrol : enrol // ignore: cast_nullable_to_non_nullable
as bool,setClassAdmin: null == setClassAdmin ? _self.setClassAdmin : setClassAdmin // ignore: cast_nullable_to_non_nullable
as bool,transfer: null == transfer ? _self.transfer : transfer // ignore: cast_nullable_to_non_nullable
as bool,link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ManageCan].
extension ManageCanPatterns on ManageCan {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ManageCan value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ManageCan() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ManageCan value)  $default,){
final _that = this;
switch (_that) {
case _ManageCan():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ManageCan value)?  $default,){
final _that = this;
switch (_that) {
case _ManageCan() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool update,  bool enrol,  bool setClassAdmin,  bool transfer,  bool link)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ManageCan() when $default != null:
return $default(_that.update,_that.enrol,_that.setClassAdmin,_that.transfer,_that.link);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool update,  bool enrol,  bool setClassAdmin,  bool transfer,  bool link)  $default,) {final _that = this;
switch (_that) {
case _ManageCan():
return $default(_that.update,_that.enrol,_that.setClassAdmin,_that.transfer,_that.link);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool update,  bool enrol,  bool setClassAdmin,  bool transfer,  bool link)?  $default,) {final _that = this;
switch (_that) {
case _ManageCan() when $default != null:
return $default(_that.update,_that.enrol,_that.setClassAdmin,_that.transfer,_that.link);case _:
  return null;

}
}

}

/// @nodoc


class _ManageCan implements ManageCan {
  const _ManageCan({this.update = false, this.enrol = false, this.setClassAdmin = false, this.transfer = false, this.link = false});
  

@override@JsonKey() final  bool update;
@override@JsonKey() final  bool enrol;
@override@JsonKey() final  bool setClassAdmin;
@override@JsonKey() final  bool transfer;
@override@JsonKey() final  bool link;

/// Create a copy of ManageCan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ManageCanCopyWith<_ManageCan> get copyWith => __$ManageCanCopyWithImpl<_ManageCan>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ManageCan&&(identical(other.update, update) || other.update == update)&&(identical(other.enrol, enrol) || other.enrol == enrol)&&(identical(other.setClassAdmin, setClassAdmin) || other.setClassAdmin == setClassAdmin)&&(identical(other.transfer, transfer) || other.transfer == transfer)&&(identical(other.link, link) || other.link == link));
}


@override
int get hashCode => Object.hash(runtimeType,update,enrol,setClassAdmin,transfer,link);

@override
String toString() {
  return 'ManageCan(update: $update, enrol: $enrol, setClassAdmin: $setClassAdmin, transfer: $transfer, link: $link)';
}


}

/// @nodoc
abstract mixin class _$ManageCanCopyWith<$Res> implements $ManageCanCopyWith<$Res> {
  factory _$ManageCanCopyWith(_ManageCan value, $Res Function(_ManageCan) _then) = __$ManageCanCopyWithImpl;
@override @useResult
$Res call({
 bool update, bool enrol, bool setClassAdmin, bool transfer, bool link
});




}
/// @nodoc
class __$ManageCanCopyWithImpl<$Res>
    implements _$ManageCanCopyWith<$Res> {
  __$ManageCanCopyWithImpl(this._self, this._then);

  final _ManageCan _self;
  final $Res Function(_ManageCan) _then;

/// Create a copy of ManageCan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? update = null,Object? enrol = null,Object? setClassAdmin = null,Object? transfer = null,Object? link = null,}) {
  return _then(_ManageCan(
update: null == update ? _self.update : update // ignore: cast_nullable_to_non_nullable
as bool,enrol: null == enrol ? _self.enrol : enrol // ignore: cast_nullable_to_non_nullable
as bool,setClassAdmin: null == setClassAdmin ? _self.setClassAdmin : setClassAdmin // ignore: cast_nullable_to_non_nullable
as bool,transfer: null == transfer ? _self.transfer : transfer // ignore: cast_nullable_to_non_nullable
as bool,link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$ManageLookups {

 List<ManageOption> get languages; List<ManageOption> get tags; List<ManageOption> get topics; List<ManageTimezone> get timezones;
/// Create a copy of ManageLookups
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ManageLookupsCopyWith<ManageLookups> get copyWith => _$ManageLookupsCopyWithImpl<ManageLookups>(this as ManageLookups, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ManageLookups&&const DeepCollectionEquality().equals(other.languages, languages)&&const DeepCollectionEquality().equals(other.tags, tags)&&const DeepCollectionEquality().equals(other.topics, topics)&&const DeepCollectionEquality().equals(other.timezones, timezones));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(languages),const DeepCollectionEquality().hash(tags),const DeepCollectionEquality().hash(topics),const DeepCollectionEquality().hash(timezones));

@override
String toString() {
  return 'ManageLookups(languages: $languages, tags: $tags, topics: $topics, timezones: $timezones)';
}


}

/// @nodoc
abstract mixin class $ManageLookupsCopyWith<$Res>  {
  factory $ManageLookupsCopyWith(ManageLookups value, $Res Function(ManageLookups) _then) = _$ManageLookupsCopyWithImpl;
@useResult
$Res call({
 List<ManageOption> languages, List<ManageOption> tags, List<ManageOption> topics, List<ManageTimezone> timezones
});




}
/// @nodoc
class _$ManageLookupsCopyWithImpl<$Res>
    implements $ManageLookupsCopyWith<$Res> {
  _$ManageLookupsCopyWithImpl(this._self, this._then);

  final ManageLookups _self;
  final $Res Function(ManageLookups) _then;

/// Create a copy of ManageLookups
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? languages = null,Object? tags = null,Object? topics = null,Object? timezones = null,}) {
  return _then(_self.copyWith(
languages: null == languages ? _self.languages : languages // ignore: cast_nullable_to_non_nullable
as List<ManageOption>,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<ManageOption>,topics: null == topics ? _self.topics : topics // ignore: cast_nullable_to_non_nullable
as List<ManageOption>,timezones: null == timezones ? _self.timezones : timezones // ignore: cast_nullable_to_non_nullable
as List<ManageTimezone>,
  ));
}

}


/// Adds pattern-matching-related methods to [ManageLookups].
extension ManageLookupsPatterns on ManageLookups {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ManageLookups value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ManageLookups() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ManageLookups value)  $default,){
final _that = this;
switch (_that) {
case _ManageLookups():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ManageLookups value)?  $default,){
final _that = this;
switch (_that) {
case _ManageLookups() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ManageOption> languages,  List<ManageOption> tags,  List<ManageOption> topics,  List<ManageTimezone> timezones)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ManageLookups() when $default != null:
return $default(_that.languages,_that.tags,_that.topics,_that.timezones);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ManageOption> languages,  List<ManageOption> tags,  List<ManageOption> topics,  List<ManageTimezone> timezones)  $default,) {final _that = this;
switch (_that) {
case _ManageLookups():
return $default(_that.languages,_that.tags,_that.topics,_that.timezones);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ManageOption> languages,  List<ManageOption> tags,  List<ManageOption> topics,  List<ManageTimezone> timezones)?  $default,) {final _that = this;
switch (_that) {
case _ManageLookups() when $default != null:
return $default(_that.languages,_that.tags,_that.topics,_that.timezones);case _:
  return null;

}
}

}

/// @nodoc


class _ManageLookups implements ManageLookups {
  const _ManageLookups({final  List<ManageOption> languages = const [], final  List<ManageOption> tags = const [], final  List<ManageOption> topics = const [], final  List<ManageTimezone> timezones = const []}): _languages = languages,_tags = tags,_topics = topics,_timezones = timezones;
  

 final  List<ManageOption> _languages;
@override@JsonKey() List<ManageOption> get languages {
  if (_languages is EqualUnmodifiableListView) return _languages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_languages);
}

 final  List<ManageOption> _tags;
@override@JsonKey() List<ManageOption> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

 final  List<ManageOption> _topics;
@override@JsonKey() List<ManageOption> get topics {
  if (_topics is EqualUnmodifiableListView) return _topics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_topics);
}

 final  List<ManageTimezone> _timezones;
@override@JsonKey() List<ManageTimezone> get timezones {
  if (_timezones is EqualUnmodifiableListView) return _timezones;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_timezones);
}


/// Create a copy of ManageLookups
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ManageLookupsCopyWith<_ManageLookups> get copyWith => __$ManageLookupsCopyWithImpl<_ManageLookups>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ManageLookups&&const DeepCollectionEquality().equals(other._languages, _languages)&&const DeepCollectionEquality().equals(other._tags, _tags)&&const DeepCollectionEquality().equals(other._topics, _topics)&&const DeepCollectionEquality().equals(other._timezones, _timezones));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_languages),const DeepCollectionEquality().hash(_tags),const DeepCollectionEquality().hash(_topics),const DeepCollectionEquality().hash(_timezones));

@override
String toString() {
  return 'ManageLookups(languages: $languages, tags: $tags, topics: $topics, timezones: $timezones)';
}


}

/// @nodoc
abstract mixin class _$ManageLookupsCopyWith<$Res> implements $ManageLookupsCopyWith<$Res> {
  factory _$ManageLookupsCopyWith(_ManageLookups value, $Res Function(_ManageLookups) _then) = __$ManageLookupsCopyWithImpl;
@override @useResult
$Res call({
 List<ManageOption> languages, List<ManageOption> tags, List<ManageOption> topics, List<ManageTimezone> timezones
});




}
/// @nodoc
class __$ManageLookupsCopyWithImpl<$Res>
    implements _$ManageLookupsCopyWith<$Res> {
  __$ManageLookupsCopyWithImpl(this._self, this._then);

  final _ManageLookups _self;
  final $Res Function(_ManageLookups) _then;

/// Create a copy of ManageLookups
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? languages = null,Object? tags = null,Object? topics = null,Object? timezones = null,}) {
  return _then(_ManageLookups(
languages: null == languages ? _self._languages : languages // ignore: cast_nullable_to_non_nullable
as List<ManageOption>,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<ManageOption>,topics: null == topics ? _self._topics : topics // ignore: cast_nullable_to_non_nullable
as List<ManageOption>,timezones: null == timezones ? _self._timezones : timezones // ignore: cast_nullable_to_non_nullable
as List<ManageTimezone>,
  ));
}


}

/// @nodoc
mixin _$ManageRoster {

 List<ManagedStudent> get students; List<RemovedStudent> get removedStudents; List<AddCandidate> get mcqStudents; List<TransferRecord> get transferHistory;
/// Create a copy of ManageRoster
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ManageRosterCopyWith<ManageRoster> get copyWith => _$ManageRosterCopyWithImpl<ManageRoster>(this as ManageRoster, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ManageRoster&&const DeepCollectionEquality().equals(other.students, students)&&const DeepCollectionEquality().equals(other.removedStudents, removedStudents)&&const DeepCollectionEquality().equals(other.mcqStudents, mcqStudents)&&const DeepCollectionEquality().equals(other.transferHistory, transferHistory));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(students),const DeepCollectionEquality().hash(removedStudents),const DeepCollectionEquality().hash(mcqStudents),const DeepCollectionEquality().hash(transferHistory));

@override
String toString() {
  return 'ManageRoster(students: $students, removedStudents: $removedStudents, mcqStudents: $mcqStudents, transferHistory: $transferHistory)';
}


}

/// @nodoc
abstract mixin class $ManageRosterCopyWith<$Res>  {
  factory $ManageRosterCopyWith(ManageRoster value, $Res Function(ManageRoster) _then) = _$ManageRosterCopyWithImpl;
@useResult
$Res call({
 List<ManagedStudent> students, List<RemovedStudent> removedStudents, List<AddCandidate> mcqStudents, List<TransferRecord> transferHistory
});




}
/// @nodoc
class _$ManageRosterCopyWithImpl<$Res>
    implements $ManageRosterCopyWith<$Res> {
  _$ManageRosterCopyWithImpl(this._self, this._then);

  final ManageRoster _self;
  final $Res Function(ManageRoster) _then;

/// Create a copy of ManageRoster
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? students = null,Object? removedStudents = null,Object? mcqStudents = null,Object? transferHistory = null,}) {
  return _then(_self.copyWith(
students: null == students ? _self.students : students // ignore: cast_nullable_to_non_nullable
as List<ManagedStudent>,removedStudents: null == removedStudents ? _self.removedStudents : removedStudents // ignore: cast_nullable_to_non_nullable
as List<RemovedStudent>,mcqStudents: null == mcqStudents ? _self.mcqStudents : mcqStudents // ignore: cast_nullable_to_non_nullable
as List<AddCandidate>,transferHistory: null == transferHistory ? _self.transferHistory : transferHistory // ignore: cast_nullable_to_non_nullable
as List<TransferRecord>,
  ));
}

}


/// Adds pattern-matching-related methods to [ManageRoster].
extension ManageRosterPatterns on ManageRoster {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ManageRoster value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ManageRoster() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ManageRoster value)  $default,){
final _that = this;
switch (_that) {
case _ManageRoster():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ManageRoster value)?  $default,){
final _that = this;
switch (_that) {
case _ManageRoster() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ManagedStudent> students,  List<RemovedStudent> removedStudents,  List<AddCandidate> mcqStudents,  List<TransferRecord> transferHistory)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ManageRoster() when $default != null:
return $default(_that.students,_that.removedStudents,_that.mcqStudents,_that.transferHistory);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ManagedStudent> students,  List<RemovedStudent> removedStudents,  List<AddCandidate> mcqStudents,  List<TransferRecord> transferHistory)  $default,) {final _that = this;
switch (_that) {
case _ManageRoster():
return $default(_that.students,_that.removedStudents,_that.mcqStudents,_that.transferHistory);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ManagedStudent> students,  List<RemovedStudent> removedStudents,  List<AddCandidate> mcqStudents,  List<TransferRecord> transferHistory)?  $default,) {final _that = this;
switch (_that) {
case _ManageRoster() when $default != null:
return $default(_that.students,_that.removedStudents,_that.mcqStudents,_that.transferHistory);case _:
  return null;

}
}

}

/// @nodoc


class _ManageRoster implements ManageRoster {
  const _ManageRoster({final  List<ManagedStudent> students = const [], final  List<RemovedStudent> removedStudents = const [], final  List<AddCandidate> mcqStudents = const [], final  List<TransferRecord> transferHistory = const []}): _students = students,_removedStudents = removedStudents,_mcqStudents = mcqStudents,_transferHistory = transferHistory;
  

 final  List<ManagedStudent> _students;
@override@JsonKey() List<ManagedStudent> get students {
  if (_students is EqualUnmodifiableListView) return _students;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_students);
}

 final  List<RemovedStudent> _removedStudents;
@override@JsonKey() List<RemovedStudent> get removedStudents {
  if (_removedStudents is EqualUnmodifiableListView) return _removedStudents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_removedStudents);
}

 final  List<AddCandidate> _mcqStudents;
@override@JsonKey() List<AddCandidate> get mcqStudents {
  if (_mcqStudents is EqualUnmodifiableListView) return _mcqStudents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_mcqStudents);
}

 final  List<TransferRecord> _transferHistory;
@override@JsonKey() List<TransferRecord> get transferHistory {
  if (_transferHistory is EqualUnmodifiableListView) return _transferHistory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_transferHistory);
}


/// Create a copy of ManageRoster
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ManageRosterCopyWith<_ManageRoster> get copyWith => __$ManageRosterCopyWithImpl<_ManageRoster>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ManageRoster&&const DeepCollectionEquality().equals(other._students, _students)&&const DeepCollectionEquality().equals(other._removedStudents, _removedStudents)&&const DeepCollectionEquality().equals(other._mcqStudents, _mcqStudents)&&const DeepCollectionEquality().equals(other._transferHistory, _transferHistory));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_students),const DeepCollectionEquality().hash(_removedStudents),const DeepCollectionEquality().hash(_mcqStudents),const DeepCollectionEquality().hash(_transferHistory));

@override
String toString() {
  return 'ManageRoster(students: $students, removedStudents: $removedStudents, mcqStudents: $mcqStudents, transferHistory: $transferHistory)';
}


}

/// @nodoc
abstract mixin class _$ManageRosterCopyWith<$Res> implements $ManageRosterCopyWith<$Res> {
  factory _$ManageRosterCopyWith(_ManageRoster value, $Res Function(_ManageRoster) _then) = __$ManageRosterCopyWithImpl;
@override @useResult
$Res call({
 List<ManagedStudent> students, List<RemovedStudent> removedStudents, List<AddCandidate> mcqStudents, List<TransferRecord> transferHistory
});




}
/// @nodoc
class __$ManageRosterCopyWithImpl<$Res>
    implements _$ManageRosterCopyWith<$Res> {
  __$ManageRosterCopyWithImpl(this._self, this._then);

  final _ManageRoster _self;
  final $Res Function(_ManageRoster) _then;

/// Create a copy of ManageRoster
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? students = null,Object? removedStudents = null,Object? mcqStudents = null,Object? transferHistory = null,}) {
  return _then(_ManageRoster(
students: null == students ? _self._students : students // ignore: cast_nullable_to_non_nullable
as List<ManagedStudent>,removedStudents: null == removedStudents ? _self._removedStudents : removedStudents // ignore: cast_nullable_to_non_nullable
as List<RemovedStudent>,mcqStudents: null == mcqStudents ? _self._mcqStudents : mcqStudents // ignore: cast_nullable_to_non_nullable
as List<AddCandidate>,transferHistory: null == transferHistory ? _self._transferHistory : transferHistory // ignore: cast_nullable_to_non_nullable
as List<TransferRecord>,
  ));
}


}

/// @nodoc
mixin _$ClassManagePayload {

 ManagedClass get classInfo; List<ManageOption> get tags; List<ManageSchedule> get schedules; ManageLookups get lookups; ManageCan get can; ManageRoster get roster; List<TransferDestination> get destinations;
/// Create a copy of ClassManagePayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClassManagePayloadCopyWith<ClassManagePayload> get copyWith => _$ClassManagePayloadCopyWithImpl<ClassManagePayload>(this as ClassManagePayload, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClassManagePayload&&(identical(other.classInfo, classInfo) || other.classInfo == classInfo)&&const DeepCollectionEquality().equals(other.tags, tags)&&const DeepCollectionEquality().equals(other.schedules, schedules)&&(identical(other.lookups, lookups) || other.lookups == lookups)&&(identical(other.can, can) || other.can == can)&&(identical(other.roster, roster) || other.roster == roster)&&const DeepCollectionEquality().equals(other.destinations, destinations));
}


@override
int get hashCode => Object.hash(runtimeType,classInfo,const DeepCollectionEquality().hash(tags),const DeepCollectionEquality().hash(schedules),lookups,can,roster,const DeepCollectionEquality().hash(destinations));

@override
String toString() {
  return 'ClassManagePayload(classInfo: $classInfo, tags: $tags, schedules: $schedules, lookups: $lookups, can: $can, roster: $roster, destinations: $destinations)';
}


}

/// @nodoc
abstract mixin class $ClassManagePayloadCopyWith<$Res>  {
  factory $ClassManagePayloadCopyWith(ClassManagePayload value, $Res Function(ClassManagePayload) _then) = _$ClassManagePayloadCopyWithImpl;
@useResult
$Res call({
 ManagedClass classInfo, List<ManageOption> tags, List<ManageSchedule> schedules, ManageLookups lookups, ManageCan can, ManageRoster roster, List<TransferDestination> destinations
});


$ManagedClassCopyWith<$Res> get classInfo;$ManageLookupsCopyWith<$Res> get lookups;$ManageCanCopyWith<$Res> get can;$ManageRosterCopyWith<$Res> get roster;

}
/// @nodoc
class _$ClassManagePayloadCopyWithImpl<$Res>
    implements $ClassManagePayloadCopyWith<$Res> {
  _$ClassManagePayloadCopyWithImpl(this._self, this._then);

  final ClassManagePayload _self;
  final $Res Function(ClassManagePayload) _then;

/// Create a copy of ClassManagePayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? classInfo = null,Object? tags = null,Object? schedules = null,Object? lookups = null,Object? can = null,Object? roster = null,Object? destinations = null,}) {
  return _then(_self.copyWith(
classInfo: null == classInfo ? _self.classInfo : classInfo // ignore: cast_nullable_to_non_nullable
as ManagedClass,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<ManageOption>,schedules: null == schedules ? _self.schedules : schedules // ignore: cast_nullable_to_non_nullable
as List<ManageSchedule>,lookups: null == lookups ? _self.lookups : lookups // ignore: cast_nullable_to_non_nullable
as ManageLookups,can: null == can ? _self.can : can // ignore: cast_nullable_to_non_nullable
as ManageCan,roster: null == roster ? _self.roster : roster // ignore: cast_nullable_to_non_nullable
as ManageRoster,destinations: null == destinations ? _self.destinations : destinations // ignore: cast_nullable_to_non_nullable
as List<TransferDestination>,
  ));
}
/// Create a copy of ClassManagePayload
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ManagedClassCopyWith<$Res> get classInfo {
  
  return $ManagedClassCopyWith<$Res>(_self.classInfo, (value) {
    return _then(_self.copyWith(classInfo: value));
  });
}/// Create a copy of ClassManagePayload
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ManageLookupsCopyWith<$Res> get lookups {
  
  return $ManageLookupsCopyWith<$Res>(_self.lookups, (value) {
    return _then(_self.copyWith(lookups: value));
  });
}/// Create a copy of ClassManagePayload
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ManageCanCopyWith<$Res> get can {
  
  return $ManageCanCopyWith<$Res>(_self.can, (value) {
    return _then(_self.copyWith(can: value));
  });
}/// Create a copy of ClassManagePayload
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ManageRosterCopyWith<$Res> get roster {
  
  return $ManageRosterCopyWith<$Res>(_self.roster, (value) {
    return _then(_self.copyWith(roster: value));
  });
}
}


/// Adds pattern-matching-related methods to [ClassManagePayload].
extension ClassManagePayloadPatterns on ClassManagePayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClassManagePayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClassManagePayload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClassManagePayload value)  $default,){
final _that = this;
switch (_that) {
case _ClassManagePayload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClassManagePayload value)?  $default,){
final _that = this;
switch (_that) {
case _ClassManagePayload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ManagedClass classInfo,  List<ManageOption> tags,  List<ManageSchedule> schedules,  ManageLookups lookups,  ManageCan can,  ManageRoster roster,  List<TransferDestination> destinations)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClassManagePayload() when $default != null:
return $default(_that.classInfo,_that.tags,_that.schedules,_that.lookups,_that.can,_that.roster,_that.destinations);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ManagedClass classInfo,  List<ManageOption> tags,  List<ManageSchedule> schedules,  ManageLookups lookups,  ManageCan can,  ManageRoster roster,  List<TransferDestination> destinations)  $default,) {final _that = this;
switch (_that) {
case _ClassManagePayload():
return $default(_that.classInfo,_that.tags,_that.schedules,_that.lookups,_that.can,_that.roster,_that.destinations);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ManagedClass classInfo,  List<ManageOption> tags,  List<ManageSchedule> schedules,  ManageLookups lookups,  ManageCan can,  ManageRoster roster,  List<TransferDestination> destinations)?  $default,) {final _that = this;
switch (_that) {
case _ClassManagePayload() when $default != null:
return $default(_that.classInfo,_that.tags,_that.schedules,_that.lookups,_that.can,_that.roster,_that.destinations);case _:
  return null;

}
}

}

/// @nodoc


class _ClassManagePayload implements ClassManagePayload {
  const _ClassManagePayload({required this.classInfo, final  List<ManageOption> tags = const [], final  List<ManageSchedule> schedules = const [], this.lookups = const ManageLookups(), this.can = const ManageCan(), this.roster = const ManageRoster(), final  List<TransferDestination> destinations = const []}): _tags = tags,_schedules = schedules,_destinations = destinations;
  

@override final  ManagedClass classInfo;
 final  List<ManageOption> _tags;
@override@JsonKey() List<ManageOption> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

 final  List<ManageSchedule> _schedules;
@override@JsonKey() List<ManageSchedule> get schedules {
  if (_schedules is EqualUnmodifiableListView) return _schedules;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_schedules);
}

@override@JsonKey() final  ManageLookups lookups;
@override@JsonKey() final  ManageCan can;
@override@JsonKey() final  ManageRoster roster;
 final  List<TransferDestination> _destinations;
@override@JsonKey() List<TransferDestination> get destinations {
  if (_destinations is EqualUnmodifiableListView) return _destinations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_destinations);
}


/// Create a copy of ClassManagePayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClassManagePayloadCopyWith<_ClassManagePayload> get copyWith => __$ClassManagePayloadCopyWithImpl<_ClassManagePayload>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClassManagePayload&&(identical(other.classInfo, classInfo) || other.classInfo == classInfo)&&const DeepCollectionEquality().equals(other._tags, _tags)&&const DeepCollectionEquality().equals(other._schedules, _schedules)&&(identical(other.lookups, lookups) || other.lookups == lookups)&&(identical(other.can, can) || other.can == can)&&(identical(other.roster, roster) || other.roster == roster)&&const DeepCollectionEquality().equals(other._destinations, _destinations));
}


@override
int get hashCode => Object.hash(runtimeType,classInfo,const DeepCollectionEquality().hash(_tags),const DeepCollectionEquality().hash(_schedules),lookups,can,roster,const DeepCollectionEquality().hash(_destinations));

@override
String toString() {
  return 'ClassManagePayload(classInfo: $classInfo, tags: $tags, schedules: $schedules, lookups: $lookups, can: $can, roster: $roster, destinations: $destinations)';
}


}

/// @nodoc
abstract mixin class _$ClassManagePayloadCopyWith<$Res> implements $ClassManagePayloadCopyWith<$Res> {
  factory _$ClassManagePayloadCopyWith(_ClassManagePayload value, $Res Function(_ClassManagePayload) _then) = __$ClassManagePayloadCopyWithImpl;
@override @useResult
$Res call({
 ManagedClass classInfo, List<ManageOption> tags, List<ManageSchedule> schedules, ManageLookups lookups, ManageCan can, ManageRoster roster, List<TransferDestination> destinations
});


@override $ManagedClassCopyWith<$Res> get classInfo;@override $ManageLookupsCopyWith<$Res> get lookups;@override $ManageCanCopyWith<$Res> get can;@override $ManageRosterCopyWith<$Res> get roster;

}
/// @nodoc
class __$ClassManagePayloadCopyWithImpl<$Res>
    implements _$ClassManagePayloadCopyWith<$Res> {
  __$ClassManagePayloadCopyWithImpl(this._self, this._then);

  final _ClassManagePayload _self;
  final $Res Function(_ClassManagePayload) _then;

/// Create a copy of ClassManagePayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? classInfo = null,Object? tags = null,Object? schedules = null,Object? lookups = null,Object? can = null,Object? roster = null,Object? destinations = null,}) {
  return _then(_ClassManagePayload(
classInfo: null == classInfo ? _self.classInfo : classInfo // ignore: cast_nullable_to_non_nullable
as ManagedClass,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<ManageOption>,schedules: null == schedules ? _self._schedules : schedules // ignore: cast_nullable_to_non_nullable
as List<ManageSchedule>,lookups: null == lookups ? _self.lookups : lookups // ignore: cast_nullable_to_non_nullable
as ManageLookups,can: null == can ? _self.can : can // ignore: cast_nullable_to_non_nullable
as ManageCan,roster: null == roster ? _self.roster : roster // ignore: cast_nullable_to_non_nullable
as ManageRoster,destinations: null == destinations ? _self._destinations : destinations // ignore: cast_nullable_to_non_nullable
as List<TransferDestination>,
  ));
}

/// Create a copy of ClassManagePayload
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ManagedClassCopyWith<$Res> get classInfo {
  
  return $ManagedClassCopyWith<$Res>(_self.classInfo, (value) {
    return _then(_self.copyWith(classInfo: value));
  });
}/// Create a copy of ClassManagePayload
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ManageLookupsCopyWith<$Res> get lookups {
  
  return $ManageLookupsCopyWith<$Res>(_self.lookups, (value) {
    return _then(_self.copyWith(lookups: value));
  });
}/// Create a copy of ClassManagePayload
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ManageCanCopyWith<$Res> get can {
  
  return $ManageCanCopyWith<$Res>(_self.can, (value) {
    return _then(_self.copyWith(can: value));
  });
}/// Create a copy of ClassManagePayload
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ManageRosterCopyWith<$Res> get roster {
  
  return $ManageRosterCopyWith<$Res>(_self.roster, (value) {
    return _then(_self.copyWith(roster: value));
  });
}
}

/// @nodoc
mixin _$ClassDraft {

 int? get languageId; String? get startedOn; String get format; String? get address; String? get city; String? get country; String? get location; int get teacher; String? get teacherName; List<int> get tags; List<ManageSchedule> get schedules;
/// Create a copy of ClassDraft
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClassDraftCopyWith<ClassDraft> get copyWith => _$ClassDraftCopyWithImpl<ClassDraft>(this as ClassDraft, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClassDraft&&(identical(other.languageId, languageId) || other.languageId == languageId)&&(identical(other.startedOn, startedOn) || other.startedOn == startedOn)&&(identical(other.format, format) || other.format == format)&&(identical(other.address, address) || other.address == address)&&(identical(other.city, city) || other.city == city)&&(identical(other.country, country) || other.country == country)&&(identical(other.location, location) || other.location == location)&&(identical(other.teacher, teacher) || other.teacher == teacher)&&(identical(other.teacherName, teacherName) || other.teacherName == teacherName)&&const DeepCollectionEquality().equals(other.tags, tags)&&const DeepCollectionEquality().equals(other.schedules, schedules));
}


@override
int get hashCode => Object.hash(runtimeType,languageId,startedOn,format,address,city,country,location,teacher,teacherName,const DeepCollectionEquality().hash(tags),const DeepCollectionEquality().hash(schedules));

@override
String toString() {
  return 'ClassDraft(languageId: $languageId, startedOn: $startedOn, format: $format, address: $address, city: $city, country: $country, location: $location, teacher: $teacher, teacherName: $teacherName, tags: $tags, schedules: $schedules)';
}


}

/// @nodoc
abstract mixin class $ClassDraftCopyWith<$Res>  {
  factory $ClassDraftCopyWith(ClassDraft value, $Res Function(ClassDraft) _then) = _$ClassDraftCopyWithImpl;
@useResult
$Res call({
 int? languageId, String? startedOn, String format, String? address, String? city, String? country, String? location, int teacher, String? teacherName, List<int> tags, List<ManageSchedule> schedules
});




}
/// @nodoc
class _$ClassDraftCopyWithImpl<$Res>
    implements $ClassDraftCopyWith<$Res> {
  _$ClassDraftCopyWithImpl(this._self, this._then);

  final ClassDraft _self;
  final $Res Function(ClassDraft) _then;

/// Create a copy of ClassDraft
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? languageId = freezed,Object? startedOn = freezed,Object? format = null,Object? address = freezed,Object? city = freezed,Object? country = freezed,Object? location = freezed,Object? teacher = null,Object? teacherName = freezed,Object? tags = null,Object? schedules = null,}) {
  return _then(_self.copyWith(
languageId: freezed == languageId ? _self.languageId : languageId // ignore: cast_nullable_to_non_nullable
as int?,startedOn: freezed == startedOn ? _self.startedOn : startedOn // ignore: cast_nullable_to_non_nullable
as String?,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,teacher: null == teacher ? _self.teacher : teacher // ignore: cast_nullable_to_non_nullable
as int,teacherName: freezed == teacherName ? _self.teacherName : teacherName // ignore: cast_nullable_to_non_nullable
as String?,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<int>,schedules: null == schedules ? _self.schedules : schedules // ignore: cast_nullable_to_non_nullable
as List<ManageSchedule>,
  ));
}

}


/// Adds pattern-matching-related methods to [ClassDraft].
extension ClassDraftPatterns on ClassDraft {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClassDraft value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClassDraft() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClassDraft value)  $default,){
final _that = this;
switch (_that) {
case _ClassDraft():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClassDraft value)?  $default,){
final _that = this;
switch (_that) {
case _ClassDraft() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? languageId,  String? startedOn,  String format,  String? address,  String? city,  String? country,  String? location,  int teacher,  String? teacherName,  List<int> tags,  List<ManageSchedule> schedules)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClassDraft() when $default != null:
return $default(_that.languageId,_that.startedOn,_that.format,_that.address,_that.city,_that.country,_that.location,_that.teacher,_that.teacherName,_that.tags,_that.schedules);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? languageId,  String? startedOn,  String format,  String? address,  String? city,  String? country,  String? location,  int teacher,  String? teacherName,  List<int> tags,  List<ManageSchedule> schedules)  $default,) {final _that = this;
switch (_that) {
case _ClassDraft():
return $default(_that.languageId,_that.startedOn,_that.format,_that.address,_that.city,_that.country,_that.location,_that.teacher,_that.teacherName,_that.tags,_that.schedules);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? languageId,  String? startedOn,  String format,  String? address,  String? city,  String? country,  String? location,  int teacher,  String? teacherName,  List<int> tags,  List<ManageSchedule> schedules)?  $default,) {final _that = this;
switch (_that) {
case _ClassDraft() when $default != null:
return $default(_that.languageId,_that.startedOn,_that.format,_that.address,_that.city,_that.country,_that.location,_that.teacher,_that.teacherName,_that.tags,_that.schedules);case _:
  return null;

}
}

}

/// @nodoc


class _ClassDraft extends ClassDraft {
  const _ClassDraft({this.languageId, this.startedOn, required this.format, this.address, this.city, this.country, this.location, required this.teacher, this.teacherName, final  List<int> tags = const [], final  List<ManageSchedule> schedules = const []}): _tags = tags,_schedules = schedules,super._();
  

@override final  int? languageId;
@override final  String? startedOn;
@override final  String format;
@override final  String? address;
@override final  String? city;
@override final  String? country;
@override final  String? location;
@override final  int teacher;
@override final  String? teacherName;
 final  List<int> _tags;
@override@JsonKey() List<int> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

 final  List<ManageSchedule> _schedules;
@override@JsonKey() List<ManageSchedule> get schedules {
  if (_schedules is EqualUnmodifiableListView) return _schedules;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_schedules);
}


/// Create a copy of ClassDraft
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClassDraftCopyWith<_ClassDraft> get copyWith => __$ClassDraftCopyWithImpl<_ClassDraft>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClassDraft&&(identical(other.languageId, languageId) || other.languageId == languageId)&&(identical(other.startedOn, startedOn) || other.startedOn == startedOn)&&(identical(other.format, format) || other.format == format)&&(identical(other.address, address) || other.address == address)&&(identical(other.city, city) || other.city == city)&&(identical(other.country, country) || other.country == country)&&(identical(other.location, location) || other.location == location)&&(identical(other.teacher, teacher) || other.teacher == teacher)&&(identical(other.teacherName, teacherName) || other.teacherName == teacherName)&&const DeepCollectionEquality().equals(other._tags, _tags)&&const DeepCollectionEquality().equals(other._schedules, _schedules));
}


@override
int get hashCode => Object.hash(runtimeType,languageId,startedOn,format,address,city,country,location,teacher,teacherName,const DeepCollectionEquality().hash(_tags),const DeepCollectionEquality().hash(_schedules));

@override
String toString() {
  return 'ClassDraft(languageId: $languageId, startedOn: $startedOn, format: $format, address: $address, city: $city, country: $country, location: $location, teacher: $teacher, teacherName: $teacherName, tags: $tags, schedules: $schedules)';
}


}

/// @nodoc
abstract mixin class _$ClassDraftCopyWith<$Res> implements $ClassDraftCopyWith<$Res> {
  factory _$ClassDraftCopyWith(_ClassDraft value, $Res Function(_ClassDraft) _then) = __$ClassDraftCopyWithImpl;
@override @useResult
$Res call({
 int? languageId, String? startedOn, String format, String? address, String? city, String? country, String? location, int teacher, String? teacherName, List<int> tags, List<ManageSchedule> schedules
});




}
/// @nodoc
class __$ClassDraftCopyWithImpl<$Res>
    implements _$ClassDraftCopyWith<$Res> {
  __$ClassDraftCopyWithImpl(this._self, this._then);

  final _ClassDraft _self;
  final $Res Function(_ClassDraft) _then;

/// Create a copy of ClassDraft
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? languageId = freezed,Object? startedOn = freezed,Object? format = null,Object? address = freezed,Object? city = freezed,Object? country = freezed,Object? location = freezed,Object? teacher = null,Object? teacherName = freezed,Object? tags = null,Object? schedules = null,}) {
  return _then(_ClassDraft(
languageId: freezed == languageId ? _self.languageId : languageId // ignore: cast_nullable_to_non_nullable
as int?,startedOn: freezed == startedOn ? _self.startedOn : startedOn // ignore: cast_nullable_to_non_nullable
as String?,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,teacher: null == teacher ? _self.teacher : teacher // ignore: cast_nullable_to_non_nullable
as int,teacherName: freezed == teacherName ? _self.teacherName : teacherName // ignore: cast_nullable_to_non_nullable
as String?,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<int>,schedules: null == schedules ? _self._schedules : schedules // ignore: cast_nullable_to_non_nullable
as List<ManageSchedule>,
  ));
}


}

/// @nodoc
mixin _$LinkClass {

 int get id; String get code; String get name; bool get current;
/// Create a copy of LinkClass
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LinkClassCopyWith<LinkClass> get copyWith => _$LinkClassCopyWithImpl<LinkClass>(this as LinkClass, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LinkClass&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.current, current) || other.current == current));
}


@override
int get hashCode => Object.hash(runtimeType,id,code,name,current);

@override
String toString() {
  return 'LinkClass(id: $id, code: $code, name: $name, current: $current)';
}


}

/// @nodoc
abstract mixin class $LinkClassCopyWith<$Res>  {
  factory $LinkClassCopyWith(LinkClass value, $Res Function(LinkClass) _then) = _$LinkClassCopyWithImpl;
@useResult
$Res call({
 int id, String code, String name, bool current
});




}
/// @nodoc
class _$LinkClassCopyWithImpl<$Res>
    implements $LinkClassCopyWith<$Res> {
  _$LinkClassCopyWithImpl(this._self, this._then);

  final LinkClass _self;
  final $Res Function(LinkClass) _then;

/// Create a copy of LinkClass
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? code = null,Object? name = null,Object? current = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LinkClass].
extension LinkClassPatterns on LinkClass {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LinkClass value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LinkClass() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LinkClass value)  $default,){
final _that = this;
switch (_that) {
case _LinkClass():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LinkClass value)?  $default,){
final _that = this;
switch (_that) {
case _LinkClass() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String code,  String name,  bool current)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LinkClass() when $default != null:
return $default(_that.id,_that.code,_that.name,_that.current);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String code,  String name,  bool current)  $default,) {final _that = this;
switch (_that) {
case _LinkClass():
return $default(_that.id,_that.code,_that.name,_that.current);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String code,  String name,  bool current)?  $default,) {final _that = this;
switch (_that) {
case _LinkClass() when $default != null:
return $default(_that.id,_that.code,_that.name,_that.current);case _:
  return null;

}
}

}

/// @nodoc


class _LinkClass implements LinkClass {
  const _LinkClass({required this.id, required this.code, required this.name, this.current = false});
  

@override final  int id;
@override final  String code;
@override final  String name;
@override@JsonKey() final  bool current;

/// Create a copy of LinkClass
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LinkClassCopyWith<_LinkClass> get copyWith => __$LinkClassCopyWithImpl<_LinkClass>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LinkClass&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.current, current) || other.current == current));
}


@override
int get hashCode => Object.hash(runtimeType,id,code,name,current);

@override
String toString() {
  return 'LinkClass(id: $id, code: $code, name: $name, current: $current)';
}


}

/// @nodoc
abstract mixin class _$LinkClassCopyWith<$Res> implements $LinkClassCopyWith<$Res> {
  factory _$LinkClassCopyWith(_LinkClass value, $Res Function(_LinkClass) _then) = __$LinkClassCopyWithImpl;
@override @useResult
$Res call({
 int id, String code, String name, bool current
});




}
/// @nodoc
class __$LinkClassCopyWithImpl<$Res>
    implements _$LinkClassCopyWith<$Res> {
  __$LinkClassCopyWithImpl(this._self, this._then);

  final _LinkClass _self;
  final $Res Function(_LinkClass) _then;

/// Create a copy of LinkClass
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? code = null,Object? name = null,Object? current = null,}) {
  return _then(_LinkClass(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$LinkExtra {

 int get token; String get name; List<LinkClass> get classes;
/// Create a copy of LinkExtra
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LinkExtraCopyWith<LinkExtra> get copyWith => _$LinkExtraCopyWithImpl<LinkExtra>(this as LinkExtra, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LinkExtra&&(identical(other.token, token) || other.token == token)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.classes, classes));
}


@override
int get hashCode => Object.hash(runtimeType,token,name,const DeepCollectionEquality().hash(classes));

@override
String toString() {
  return 'LinkExtra(token: $token, name: $name, classes: $classes)';
}


}

/// @nodoc
abstract mixin class $LinkExtraCopyWith<$Res>  {
  factory $LinkExtraCopyWith(LinkExtra value, $Res Function(LinkExtra) _then) = _$LinkExtraCopyWithImpl;
@useResult
$Res call({
 int token, String name, List<LinkClass> classes
});




}
/// @nodoc
class _$LinkExtraCopyWithImpl<$Res>
    implements $LinkExtraCopyWith<$Res> {
  _$LinkExtraCopyWithImpl(this._self, this._then);

  final LinkExtra _self;
  final $Res Function(LinkExtra) _then;

/// Create a copy of LinkExtra
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? token = null,Object? name = null,Object? classes = null,}) {
  return _then(_self.copyWith(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,classes: null == classes ? _self.classes : classes // ignore: cast_nullable_to_non_nullable
as List<LinkClass>,
  ));
}

}


/// Adds pattern-matching-related methods to [LinkExtra].
extension LinkExtraPatterns on LinkExtra {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LinkExtra value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LinkExtra() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LinkExtra value)  $default,){
final _that = this;
switch (_that) {
case _LinkExtra():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LinkExtra value)?  $default,){
final _that = this;
switch (_that) {
case _LinkExtra() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int token,  String name,  List<LinkClass> classes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LinkExtra() when $default != null:
return $default(_that.token,_that.name,_that.classes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int token,  String name,  List<LinkClass> classes)  $default,) {final _that = this;
switch (_that) {
case _LinkExtra():
return $default(_that.token,_that.name,_that.classes);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int token,  String name,  List<LinkClass> classes)?  $default,) {final _that = this;
switch (_that) {
case _LinkExtra() when $default != null:
return $default(_that.token,_that.name,_that.classes);case _:
  return null;

}
}

}

/// @nodoc


class _LinkExtra implements LinkExtra {
  const _LinkExtra({required this.token, required this.name, final  List<LinkClass> classes = const []}): _classes = classes;
  

@override final  int token;
@override final  String name;
 final  List<LinkClass> _classes;
@override@JsonKey() List<LinkClass> get classes {
  if (_classes is EqualUnmodifiableListView) return _classes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_classes);
}


/// Create a copy of LinkExtra
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LinkExtraCopyWith<_LinkExtra> get copyWith => __$LinkExtraCopyWithImpl<_LinkExtra>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LinkExtra&&(identical(other.token, token) || other.token == token)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other._classes, _classes));
}


@override
int get hashCode => Object.hash(runtimeType,token,name,const DeepCollectionEquality().hash(_classes));

@override
String toString() {
  return 'LinkExtra(token: $token, name: $name, classes: $classes)';
}


}

/// @nodoc
abstract mixin class _$LinkExtraCopyWith<$Res> implements $LinkExtraCopyWith<$Res> {
  factory _$LinkExtraCopyWith(_LinkExtra value, $Res Function(_LinkExtra) _then) = __$LinkExtraCopyWithImpl;
@override @useResult
$Res call({
 int token, String name, List<LinkClass> classes
});




}
/// @nodoc
class __$LinkExtraCopyWithImpl<$Res>
    implements _$LinkExtraCopyWith<$Res> {
  __$LinkExtraCopyWithImpl(this._self, this._then);

  final _LinkExtra _self;
  final $Res Function(_LinkExtra) _then;

/// Create a copy of LinkExtra
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? token = null,Object? name = null,Object? classes = null,}) {
  return _then(_LinkExtra(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,classes: null == classes ? _self._classes : classes // ignore: cast_nullable_to_non_nullable
as List<LinkClass>,
  ));
}


}

/// @nodoc
mixin _$LinkConflict {

 String get kind; int get itemId; String? get classCode; String get label; Map<String, dynamic> get member; Map<String, dynamic> get extra;
/// Create a copy of LinkConflict
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LinkConflictCopyWith<LinkConflict> get copyWith => _$LinkConflictCopyWithImpl<LinkConflict>(this as LinkConflict, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LinkConflict&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.itemId, itemId) || other.itemId == itemId)&&(identical(other.classCode, classCode) || other.classCode == classCode)&&(identical(other.label, label) || other.label == label)&&const DeepCollectionEquality().equals(other.member, member)&&const DeepCollectionEquality().equals(other.extra, extra));
}


@override
int get hashCode => Object.hash(runtimeType,kind,itemId,classCode,label,const DeepCollectionEquality().hash(member),const DeepCollectionEquality().hash(extra));

@override
String toString() {
  return 'LinkConflict(kind: $kind, itemId: $itemId, classCode: $classCode, label: $label, member: $member, extra: $extra)';
}


}

/// @nodoc
abstract mixin class $LinkConflictCopyWith<$Res>  {
  factory $LinkConflictCopyWith(LinkConflict value, $Res Function(LinkConflict) _then) = _$LinkConflictCopyWithImpl;
@useResult
$Res call({
 String kind, int itemId, String? classCode, String label, Map<String, dynamic> member, Map<String, dynamic> extra
});




}
/// @nodoc
class _$LinkConflictCopyWithImpl<$Res>
    implements $LinkConflictCopyWith<$Res> {
  _$LinkConflictCopyWithImpl(this._self, this._then);

  final LinkConflict _self;
  final $Res Function(LinkConflict) _then;

/// Create a copy of LinkConflict
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? itemId = null,Object? classCode = freezed,Object? label = null,Object? member = null,Object? extra = null,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,itemId: null == itemId ? _self.itemId : itemId // ignore: cast_nullable_to_non_nullable
as int,classCode: freezed == classCode ? _self.classCode : classCode // ignore: cast_nullable_to_non_nullable
as String?,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,member: null == member ? _self.member : member // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,extra: null == extra ? _self.extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [LinkConflict].
extension LinkConflictPatterns on LinkConflict {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LinkConflict value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LinkConflict() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LinkConflict value)  $default,){
final _that = this;
switch (_that) {
case _LinkConflict():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LinkConflict value)?  $default,){
final _that = this;
switch (_that) {
case _LinkConflict() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String kind,  int itemId,  String? classCode,  String label,  Map<String, dynamic> member,  Map<String, dynamic> extra)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LinkConflict() when $default != null:
return $default(_that.kind,_that.itemId,_that.classCode,_that.label,_that.member,_that.extra);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String kind,  int itemId,  String? classCode,  String label,  Map<String, dynamic> member,  Map<String, dynamic> extra)  $default,) {final _that = this;
switch (_that) {
case _LinkConflict():
return $default(_that.kind,_that.itemId,_that.classCode,_that.label,_that.member,_that.extra);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String kind,  int itemId,  String? classCode,  String label,  Map<String, dynamic> member,  Map<String, dynamic> extra)?  $default,) {final _that = this;
switch (_that) {
case _LinkConflict() when $default != null:
return $default(_that.kind,_that.itemId,_that.classCode,_that.label,_that.member,_that.extra);case _:
  return null;

}
}

}

/// @nodoc


class _LinkConflict implements LinkConflict {
  const _LinkConflict({required this.kind, required this.itemId, this.classCode, required this.label, final  Map<String, dynamic> member = const {}, final  Map<String, dynamic> extra = const {}}): _member = member,_extra = extra;
  

@override final  String kind;
@override final  int itemId;
@override final  String? classCode;
@override final  String label;
 final  Map<String, dynamic> _member;
@override@JsonKey() Map<String, dynamic> get member {
  if (_member is EqualUnmodifiableMapView) return _member;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_member);
}

 final  Map<String, dynamic> _extra;
@override@JsonKey() Map<String, dynamic> get extra {
  if (_extra is EqualUnmodifiableMapView) return _extra;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_extra);
}


/// Create a copy of LinkConflict
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LinkConflictCopyWith<_LinkConflict> get copyWith => __$LinkConflictCopyWithImpl<_LinkConflict>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LinkConflict&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.itemId, itemId) || other.itemId == itemId)&&(identical(other.classCode, classCode) || other.classCode == classCode)&&(identical(other.label, label) || other.label == label)&&const DeepCollectionEquality().equals(other._member, _member)&&const DeepCollectionEquality().equals(other._extra, _extra));
}


@override
int get hashCode => Object.hash(runtimeType,kind,itemId,classCode,label,const DeepCollectionEquality().hash(_member),const DeepCollectionEquality().hash(_extra));

@override
String toString() {
  return 'LinkConflict(kind: $kind, itemId: $itemId, classCode: $classCode, label: $label, member: $member, extra: $extra)';
}


}

/// @nodoc
abstract mixin class _$LinkConflictCopyWith<$Res> implements $LinkConflictCopyWith<$Res> {
  factory _$LinkConflictCopyWith(_LinkConflict value, $Res Function(_LinkConflict) _then) = __$LinkConflictCopyWithImpl;
@override @useResult
$Res call({
 String kind, int itemId, String? classCode, String label, Map<String, dynamic> member, Map<String, dynamic> extra
});




}
/// @nodoc
class __$LinkConflictCopyWithImpl<$Res>
    implements _$LinkConflictCopyWith<$Res> {
  __$LinkConflictCopyWithImpl(this._self, this._then);

  final _LinkConflict _self;
  final $Res Function(_LinkConflict) _then;

/// Create a copy of LinkConflict
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? itemId = null,Object? classCode = freezed,Object? label = null,Object? member = null,Object? extra = null,}) {
  return _then(_LinkConflict(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,itemId: null == itemId ? _self.itemId : itemId // ignore: cast_nullable_to_non_nullable
as int,classCode: freezed == classCode ? _self.classCode : classCode // ignore: cast_nullable_to_non_nullable
as String?,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,member: null == member ? _self._member : member // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,extra: null == extra ? _self._extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

/// @nodoc
mixin _$LinkPreview {

 MemberDetails get member; LinkExtra get extra; List<LinkConflict> get conflicts;
/// Create a copy of LinkPreview
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LinkPreviewCopyWith<LinkPreview> get copyWith => _$LinkPreviewCopyWithImpl<LinkPreview>(this as LinkPreview, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LinkPreview&&(identical(other.member, member) || other.member == member)&&(identical(other.extra, extra) || other.extra == extra)&&const DeepCollectionEquality().equals(other.conflicts, conflicts));
}


@override
int get hashCode => Object.hash(runtimeType,member,extra,const DeepCollectionEquality().hash(conflicts));

@override
String toString() {
  return 'LinkPreview(member: $member, extra: $extra, conflicts: $conflicts)';
}


}

/// @nodoc
abstract mixin class $LinkPreviewCopyWith<$Res>  {
  factory $LinkPreviewCopyWith(LinkPreview value, $Res Function(LinkPreview) _then) = _$LinkPreviewCopyWithImpl;
@useResult
$Res call({
 MemberDetails member, LinkExtra extra, List<LinkConflict> conflicts
});


$LinkExtraCopyWith<$Res> get extra;

}
/// @nodoc
class _$LinkPreviewCopyWithImpl<$Res>
    implements $LinkPreviewCopyWith<$Res> {
  _$LinkPreviewCopyWithImpl(this._self, this._then);

  final LinkPreview _self;
  final $Res Function(LinkPreview) _then;

/// Create a copy of LinkPreview
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? member = null,Object? extra = null,Object? conflicts = null,}) {
  return _then(_self.copyWith(
member: null == member ? _self.member : member // ignore: cast_nullable_to_non_nullable
as MemberDetails,extra: null == extra ? _self.extra : extra // ignore: cast_nullable_to_non_nullable
as LinkExtra,conflicts: null == conflicts ? _self.conflicts : conflicts // ignore: cast_nullable_to_non_nullable
as List<LinkConflict>,
  ));
}
/// Create a copy of LinkPreview
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LinkExtraCopyWith<$Res> get extra {
  
  return $LinkExtraCopyWith<$Res>(_self.extra, (value) {
    return _then(_self.copyWith(extra: value));
  });
}
}


/// Adds pattern-matching-related methods to [LinkPreview].
extension LinkPreviewPatterns on LinkPreview {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LinkPreview value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LinkPreview() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LinkPreview value)  $default,){
final _that = this;
switch (_that) {
case _LinkPreview():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LinkPreview value)?  $default,){
final _that = this;
switch (_that) {
case _LinkPreview() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MemberDetails member,  LinkExtra extra,  List<LinkConflict> conflicts)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LinkPreview() when $default != null:
return $default(_that.member,_that.extra,_that.conflicts);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MemberDetails member,  LinkExtra extra,  List<LinkConflict> conflicts)  $default,) {final _that = this;
switch (_that) {
case _LinkPreview():
return $default(_that.member,_that.extra,_that.conflicts);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MemberDetails member,  LinkExtra extra,  List<LinkConflict> conflicts)?  $default,) {final _that = this;
switch (_that) {
case _LinkPreview() when $default != null:
return $default(_that.member,_that.extra,_that.conflicts);case _:
  return null;

}
}

}

/// @nodoc


class _LinkPreview implements LinkPreview {
  const _LinkPreview({required this.member, required this.extra, final  List<LinkConflict> conflicts = const []}): _conflicts = conflicts;
  

@override final  MemberDetails member;
@override final  LinkExtra extra;
 final  List<LinkConflict> _conflicts;
@override@JsonKey() List<LinkConflict> get conflicts {
  if (_conflicts is EqualUnmodifiableListView) return _conflicts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_conflicts);
}


/// Create a copy of LinkPreview
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LinkPreviewCopyWith<_LinkPreview> get copyWith => __$LinkPreviewCopyWithImpl<_LinkPreview>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LinkPreview&&(identical(other.member, member) || other.member == member)&&(identical(other.extra, extra) || other.extra == extra)&&const DeepCollectionEquality().equals(other._conflicts, _conflicts));
}


@override
int get hashCode => Object.hash(runtimeType,member,extra,const DeepCollectionEquality().hash(_conflicts));

@override
String toString() {
  return 'LinkPreview(member: $member, extra: $extra, conflicts: $conflicts)';
}


}

/// @nodoc
abstract mixin class _$LinkPreviewCopyWith<$Res> implements $LinkPreviewCopyWith<$Res> {
  factory _$LinkPreviewCopyWith(_LinkPreview value, $Res Function(_LinkPreview) _then) = __$LinkPreviewCopyWithImpl;
@override @useResult
$Res call({
 MemberDetails member, LinkExtra extra, List<LinkConflict> conflicts
});


@override $LinkExtraCopyWith<$Res> get extra;

}
/// @nodoc
class __$LinkPreviewCopyWithImpl<$Res>
    implements _$LinkPreviewCopyWith<$Res> {
  __$LinkPreviewCopyWithImpl(this._self, this._then);

  final _LinkPreview _self;
  final $Res Function(_LinkPreview) _then;

/// Create a copy of LinkPreview
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? member = null,Object? extra = null,Object? conflicts = null,}) {
  return _then(_LinkPreview(
member: null == member ? _self.member : member // ignore: cast_nullable_to_non_nullable
as MemberDetails,extra: null == extra ? _self.extra : extra // ignore: cast_nullable_to_non_nullable
as LinkExtra,conflicts: null == conflicts ? _self._conflicts : conflicts // ignore: cast_nullable_to_non_nullable
as List<LinkConflict>,
  ));
}

/// Create a copy of LinkPreview
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LinkExtraCopyWith<$Res> get extra {
  
  return $LinkExtraCopyWith<$Res>(_self.extra, (value) {
    return _then(_self.copyWith(extra: value));
  });
}
}

/// @nodoc
mixin _$LinkResolution {

 String get kind; int get itemId; String get keep;
/// Create a copy of LinkResolution
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LinkResolutionCopyWith<LinkResolution> get copyWith => _$LinkResolutionCopyWithImpl<LinkResolution>(this as LinkResolution, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LinkResolution&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.itemId, itemId) || other.itemId == itemId)&&(identical(other.keep, keep) || other.keep == keep));
}


@override
int get hashCode => Object.hash(runtimeType,kind,itemId,keep);

@override
String toString() {
  return 'LinkResolution(kind: $kind, itemId: $itemId, keep: $keep)';
}


}

/// @nodoc
abstract mixin class $LinkResolutionCopyWith<$Res>  {
  factory $LinkResolutionCopyWith(LinkResolution value, $Res Function(LinkResolution) _then) = _$LinkResolutionCopyWithImpl;
@useResult
$Res call({
 String kind, int itemId, String keep
});




}
/// @nodoc
class _$LinkResolutionCopyWithImpl<$Res>
    implements $LinkResolutionCopyWith<$Res> {
  _$LinkResolutionCopyWithImpl(this._self, this._then);

  final LinkResolution _self;
  final $Res Function(LinkResolution) _then;

/// Create a copy of LinkResolution
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? itemId = null,Object? keep = null,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,itemId: null == itemId ? _self.itemId : itemId // ignore: cast_nullable_to_non_nullable
as int,keep: null == keep ? _self.keep : keep // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [LinkResolution].
extension LinkResolutionPatterns on LinkResolution {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LinkResolution value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LinkResolution() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LinkResolution value)  $default,){
final _that = this;
switch (_that) {
case _LinkResolution():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LinkResolution value)?  $default,){
final _that = this;
switch (_that) {
case _LinkResolution() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String kind,  int itemId,  String keep)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LinkResolution() when $default != null:
return $default(_that.kind,_that.itemId,_that.keep);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String kind,  int itemId,  String keep)  $default,) {final _that = this;
switch (_that) {
case _LinkResolution():
return $default(_that.kind,_that.itemId,_that.keep);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String kind,  int itemId,  String keep)?  $default,) {final _that = this;
switch (_that) {
case _LinkResolution() when $default != null:
return $default(_that.kind,_that.itemId,_that.keep);case _:
  return null;

}
}

}

/// @nodoc


class _LinkResolution extends LinkResolution {
  const _LinkResolution({required this.kind, required this.itemId, required this.keep}): super._();
  

@override final  String kind;
@override final  int itemId;
@override final  String keep;

/// Create a copy of LinkResolution
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LinkResolutionCopyWith<_LinkResolution> get copyWith => __$LinkResolutionCopyWithImpl<_LinkResolution>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LinkResolution&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.itemId, itemId) || other.itemId == itemId)&&(identical(other.keep, keep) || other.keep == keep));
}


@override
int get hashCode => Object.hash(runtimeType,kind,itemId,keep);

@override
String toString() {
  return 'LinkResolution(kind: $kind, itemId: $itemId, keep: $keep)';
}


}

/// @nodoc
abstract mixin class _$LinkResolutionCopyWith<$Res> implements $LinkResolutionCopyWith<$Res> {
  factory _$LinkResolutionCopyWith(_LinkResolution value, $Res Function(_LinkResolution) _then) = __$LinkResolutionCopyWithImpl;
@override @useResult
$Res call({
 String kind, int itemId, String keep
});




}
/// @nodoc
class __$LinkResolutionCopyWithImpl<$Res>
    implements _$LinkResolutionCopyWith<$Res> {
  __$LinkResolutionCopyWithImpl(this._self, this._then);

  final _LinkResolution _self;
  final $Res Function(_LinkResolution) _then;

/// Create a copy of LinkResolution
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? itemId = null,Object? keep = null,}) {
  return _then(_LinkResolution(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,itemId: null == itemId ? _self.itemId : itemId // ignore: cast_nullable_to_non_nullable
as int,keep: null == keep ? _self.keep : keep // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
