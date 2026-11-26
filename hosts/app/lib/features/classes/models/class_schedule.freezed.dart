// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'class_schedule.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ClassSchedule {

 int get day; int get hour; int get minute; String? get timezone;
/// Create a copy of ClassSchedule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClassScheduleCopyWith<ClassSchedule> get copyWith => _$ClassScheduleCopyWithImpl<ClassSchedule>(this as ClassSchedule, _$identity);

  /// Serializes this ClassSchedule to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClassSchedule&&(identical(other.day, day) || other.day == day)&&(identical(other.hour, hour) || other.hour == hour)&&(identical(other.minute, minute) || other.minute == minute)&&(identical(other.timezone, timezone) || other.timezone == timezone));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,day,hour,minute,timezone);

@override
String toString() {
  return 'ClassSchedule(day: $day, hour: $hour, minute: $minute, timezone: $timezone)';
}


}

/// @nodoc
abstract mixin class $ClassScheduleCopyWith<$Res>  {
  factory $ClassScheduleCopyWith(ClassSchedule value, $Res Function(ClassSchedule) _then) = _$ClassScheduleCopyWithImpl;
@useResult
$Res call({
 int day, int hour, int minute, String? timezone
});




}
/// @nodoc
class _$ClassScheduleCopyWithImpl<$Res>
    implements $ClassScheduleCopyWith<$Res> {
  _$ClassScheduleCopyWithImpl(this._self, this._then);

  final ClassSchedule _self;
  final $Res Function(ClassSchedule) _then;

/// Create a copy of ClassSchedule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? day = null,Object? hour = null,Object? minute = null,Object? timezone = freezed,}) {
  return _then(_self.copyWith(
day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as int,hour: null == hour ? _self.hour : hour // ignore: cast_nullable_to_non_nullable
as int,minute: null == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as int,timezone: freezed == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ClassSchedule].
extension ClassSchedulePatterns on ClassSchedule {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClassSchedule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClassSchedule() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClassSchedule value)  $default,){
final _that = this;
switch (_that) {
case _ClassSchedule():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClassSchedule value)?  $default,){
final _that = this;
switch (_that) {
case _ClassSchedule() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int day,  int hour,  int minute,  String? timezone)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClassSchedule() when $default != null:
return $default(_that.day,_that.hour,_that.minute,_that.timezone);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int day,  int hour,  int minute,  String? timezone)  $default,) {final _that = this;
switch (_that) {
case _ClassSchedule():
return $default(_that.day,_that.hour,_that.minute,_that.timezone);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int day,  int hour,  int minute,  String? timezone)?  $default,) {final _that = this;
switch (_that) {
case _ClassSchedule() when $default != null:
return $default(_that.day,_that.hour,_that.minute,_that.timezone);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClassSchedule implements ClassSchedule {
  const _ClassSchedule({required this.day, required this.hour, required this.minute, this.timezone});
  factory _ClassSchedule.fromJson(Map<String, dynamic> json) => _$ClassScheduleFromJson(json);

@override final  int day;
@override final  int hour;
@override final  int minute;
@override final  String? timezone;

/// Create a copy of ClassSchedule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClassScheduleCopyWith<_ClassSchedule> get copyWith => __$ClassScheduleCopyWithImpl<_ClassSchedule>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClassScheduleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClassSchedule&&(identical(other.day, day) || other.day == day)&&(identical(other.hour, hour) || other.hour == hour)&&(identical(other.minute, minute) || other.minute == minute)&&(identical(other.timezone, timezone) || other.timezone == timezone));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,day,hour,minute,timezone);

@override
String toString() {
  return 'ClassSchedule(day: $day, hour: $hour, minute: $minute, timezone: $timezone)';
}


}

/// @nodoc
abstract mixin class _$ClassScheduleCopyWith<$Res> implements $ClassScheduleCopyWith<$Res> {
  factory _$ClassScheduleCopyWith(_ClassSchedule value, $Res Function(_ClassSchedule) _then) = __$ClassScheduleCopyWithImpl;
@override @useResult
$Res call({
 int day, int hour, int minute, String? timezone
});




}
/// @nodoc
class __$ClassScheduleCopyWithImpl<$Res>
    implements _$ClassScheduleCopyWith<$Res> {
  __$ClassScheduleCopyWithImpl(this._self, this._then);

  final _ClassSchedule _self;
  final $Res Function(_ClassSchedule) _then;

/// Create a copy of ClassSchedule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? day = null,Object? hour = null,Object? minute = null,Object? timezone = freezed,}) {
  return _then(_ClassSchedule(
day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as int,hour: null == hour ? _self.hour : hour // ignore: cast_nullable_to_non_nullable
as int,minute: null == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as int,timezone: freezed == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
