// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'class_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ClassSession {

 int get id; DateTime get conductedOn; bool get conducted; int? get duration; int? get attendance; bool get arabicConducted; bool get aqaedConducted; bool get ahkamConducted; bool get akhlaqConducted; String? get nonConductionReason;
/// Create a copy of ClassSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClassSessionCopyWith<ClassSession> get copyWith => _$ClassSessionCopyWithImpl<ClassSession>(this as ClassSession, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClassSession&&(identical(other.id, id) || other.id == id)&&(identical(other.conductedOn, conductedOn) || other.conductedOn == conductedOn)&&(identical(other.conducted, conducted) || other.conducted == conducted)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.attendance, attendance) || other.attendance == attendance)&&(identical(other.arabicConducted, arabicConducted) || other.arabicConducted == arabicConducted)&&(identical(other.aqaedConducted, aqaedConducted) || other.aqaedConducted == aqaedConducted)&&(identical(other.ahkamConducted, ahkamConducted) || other.ahkamConducted == ahkamConducted)&&(identical(other.akhlaqConducted, akhlaqConducted) || other.akhlaqConducted == akhlaqConducted)&&(identical(other.nonConductionReason, nonConductionReason) || other.nonConductionReason == nonConductionReason));
}


@override
int get hashCode => Object.hash(runtimeType,id,conductedOn,conducted,duration,attendance,arabicConducted,aqaedConducted,ahkamConducted,akhlaqConducted,nonConductionReason);

@override
String toString() {
  return 'ClassSession(id: $id, conductedOn: $conductedOn, conducted: $conducted, duration: $duration, attendance: $attendance, arabicConducted: $arabicConducted, aqaedConducted: $aqaedConducted, ahkamConducted: $ahkamConducted, akhlaqConducted: $akhlaqConducted, nonConductionReason: $nonConductionReason)';
}


}

/// @nodoc
abstract mixin class $ClassSessionCopyWith<$Res>  {
  factory $ClassSessionCopyWith(ClassSession value, $Res Function(ClassSession) _then) = _$ClassSessionCopyWithImpl;
@useResult
$Res call({
 int id, DateTime conductedOn, bool conducted, int? duration, int? attendance, bool arabicConducted, bool aqaedConducted, bool ahkamConducted, bool akhlaqConducted, String? nonConductionReason
});




}
/// @nodoc
class _$ClassSessionCopyWithImpl<$Res>
    implements $ClassSessionCopyWith<$Res> {
  _$ClassSessionCopyWithImpl(this._self, this._then);

  final ClassSession _self;
  final $Res Function(ClassSession) _then;

/// Create a copy of ClassSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? conductedOn = null,Object? conducted = null,Object? duration = freezed,Object? attendance = freezed,Object? arabicConducted = null,Object? aqaedConducted = null,Object? ahkamConducted = null,Object? akhlaqConducted = null,Object? nonConductionReason = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,conductedOn: null == conductedOn ? _self.conductedOn : conductedOn // ignore: cast_nullable_to_non_nullable
as DateTime,conducted: null == conducted ? _self.conducted : conducted // ignore: cast_nullable_to_non_nullable
as bool,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as int?,attendance: freezed == attendance ? _self.attendance : attendance // ignore: cast_nullable_to_non_nullable
as int?,arabicConducted: null == arabicConducted ? _self.arabicConducted : arabicConducted // ignore: cast_nullable_to_non_nullable
as bool,aqaedConducted: null == aqaedConducted ? _self.aqaedConducted : aqaedConducted // ignore: cast_nullable_to_non_nullable
as bool,ahkamConducted: null == ahkamConducted ? _self.ahkamConducted : ahkamConducted // ignore: cast_nullable_to_non_nullable
as bool,akhlaqConducted: null == akhlaqConducted ? _self.akhlaqConducted : akhlaqConducted // ignore: cast_nullable_to_non_nullable
as bool,nonConductionReason: freezed == nonConductionReason ? _self.nonConductionReason : nonConductionReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ClassSession].
extension ClassSessionPatterns on ClassSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClassSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClassSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClassSession value)  $default,){
final _that = this;
switch (_that) {
case _ClassSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClassSession value)?  $default,){
final _that = this;
switch (_that) {
case _ClassSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  DateTime conductedOn,  bool conducted,  int? duration,  int? attendance,  bool arabicConducted,  bool aqaedConducted,  bool ahkamConducted,  bool akhlaqConducted,  String? nonConductionReason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClassSession() when $default != null:
return $default(_that.id,_that.conductedOn,_that.conducted,_that.duration,_that.attendance,_that.arabicConducted,_that.aqaedConducted,_that.ahkamConducted,_that.akhlaqConducted,_that.nonConductionReason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  DateTime conductedOn,  bool conducted,  int? duration,  int? attendance,  bool arabicConducted,  bool aqaedConducted,  bool ahkamConducted,  bool akhlaqConducted,  String? nonConductionReason)  $default,) {final _that = this;
switch (_that) {
case _ClassSession():
return $default(_that.id,_that.conductedOn,_that.conducted,_that.duration,_that.attendance,_that.arabicConducted,_that.aqaedConducted,_that.ahkamConducted,_that.akhlaqConducted,_that.nonConductionReason);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  DateTime conductedOn,  bool conducted,  int? duration,  int? attendance,  bool arabicConducted,  bool aqaedConducted,  bool ahkamConducted,  bool akhlaqConducted,  String? nonConductionReason)?  $default,) {final _that = this;
switch (_that) {
case _ClassSession() when $default != null:
return $default(_that.id,_that.conductedOn,_that.conducted,_that.duration,_that.attendance,_that.arabicConducted,_that.aqaedConducted,_that.ahkamConducted,_that.akhlaqConducted,_that.nonConductionReason);case _:
  return null;

}
}

}

/// @nodoc


class _ClassSession extends ClassSession {
  const _ClassSession({required this.id, required this.conductedOn, required this.conducted, this.duration, this.attendance, this.arabicConducted = false, this.aqaedConducted = false, this.ahkamConducted = false, this.akhlaqConducted = false, this.nonConductionReason}): super._();
  

@override final  int id;
@override final  DateTime conductedOn;
@override final  bool conducted;
@override final  int? duration;
@override final  int? attendance;
@override@JsonKey() final  bool arabicConducted;
@override@JsonKey() final  bool aqaedConducted;
@override@JsonKey() final  bool ahkamConducted;
@override@JsonKey() final  bool akhlaqConducted;
@override final  String? nonConductionReason;

/// Create a copy of ClassSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClassSessionCopyWith<_ClassSession> get copyWith => __$ClassSessionCopyWithImpl<_ClassSession>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClassSession&&(identical(other.id, id) || other.id == id)&&(identical(other.conductedOn, conductedOn) || other.conductedOn == conductedOn)&&(identical(other.conducted, conducted) || other.conducted == conducted)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.attendance, attendance) || other.attendance == attendance)&&(identical(other.arabicConducted, arabicConducted) || other.arabicConducted == arabicConducted)&&(identical(other.aqaedConducted, aqaedConducted) || other.aqaedConducted == aqaedConducted)&&(identical(other.ahkamConducted, ahkamConducted) || other.ahkamConducted == ahkamConducted)&&(identical(other.akhlaqConducted, akhlaqConducted) || other.akhlaqConducted == akhlaqConducted)&&(identical(other.nonConductionReason, nonConductionReason) || other.nonConductionReason == nonConductionReason));
}


@override
int get hashCode => Object.hash(runtimeType,id,conductedOn,conducted,duration,attendance,arabicConducted,aqaedConducted,ahkamConducted,akhlaqConducted,nonConductionReason);

@override
String toString() {
  return 'ClassSession(id: $id, conductedOn: $conductedOn, conducted: $conducted, duration: $duration, attendance: $attendance, arabicConducted: $arabicConducted, aqaedConducted: $aqaedConducted, ahkamConducted: $ahkamConducted, akhlaqConducted: $akhlaqConducted, nonConductionReason: $nonConductionReason)';
}


}

/// @nodoc
abstract mixin class _$ClassSessionCopyWith<$Res> implements $ClassSessionCopyWith<$Res> {
  factory _$ClassSessionCopyWith(_ClassSession value, $Res Function(_ClassSession) _then) = __$ClassSessionCopyWithImpl;
@override @useResult
$Res call({
 int id, DateTime conductedOn, bool conducted, int? duration, int? attendance, bool arabicConducted, bool aqaedConducted, bool ahkamConducted, bool akhlaqConducted, String? nonConductionReason
});




}
/// @nodoc
class __$ClassSessionCopyWithImpl<$Res>
    implements _$ClassSessionCopyWith<$Res> {
  __$ClassSessionCopyWithImpl(this._self, this._then);

  final _ClassSession _self;
  final $Res Function(_ClassSession) _then;

/// Create a copy of ClassSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? conductedOn = null,Object? conducted = null,Object? duration = freezed,Object? attendance = freezed,Object? arabicConducted = null,Object? aqaedConducted = null,Object? ahkamConducted = null,Object? akhlaqConducted = null,Object? nonConductionReason = freezed,}) {
  return _then(_ClassSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,conductedOn: null == conductedOn ? _self.conductedOn : conductedOn // ignore: cast_nullable_to_non_nullable
as DateTime,conducted: null == conducted ? _self.conducted : conducted // ignore: cast_nullable_to_non_nullable
as bool,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as int?,attendance: freezed == attendance ? _self.attendance : attendance // ignore: cast_nullable_to_non_nullable
as int?,arabicConducted: null == arabicConducted ? _self.arabicConducted : arabicConducted // ignore: cast_nullable_to_non_nullable
as bool,aqaedConducted: null == aqaedConducted ? _self.aqaedConducted : aqaedConducted // ignore: cast_nullable_to_non_nullable
as bool,ahkamConducted: null == ahkamConducted ? _self.ahkamConducted : ahkamConducted // ignore: cast_nullable_to_non_nullable
as bool,akhlaqConducted: null == akhlaqConducted ? _self.akhlaqConducted : akhlaqConducted // ignore: cast_nullable_to_non_nullable
as bool,nonConductionReason: freezed == nonConductionReason ? _self.nonConductionReason : nonConductionReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$StudentAttendance {

 int get sessionId; DateTime get conductedOn; bool get present; int get recitation;
/// Create a copy of StudentAttendance
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StudentAttendanceCopyWith<StudentAttendance> get copyWith => _$StudentAttendanceCopyWithImpl<StudentAttendance>(this as StudentAttendance, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StudentAttendance&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.conductedOn, conductedOn) || other.conductedOn == conductedOn)&&(identical(other.present, present) || other.present == present)&&(identical(other.recitation, recitation) || other.recitation == recitation));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId,conductedOn,present,recitation);

@override
String toString() {
  return 'StudentAttendance(sessionId: $sessionId, conductedOn: $conductedOn, present: $present, recitation: $recitation)';
}


}

/// @nodoc
abstract mixin class $StudentAttendanceCopyWith<$Res>  {
  factory $StudentAttendanceCopyWith(StudentAttendance value, $Res Function(StudentAttendance) _then) = _$StudentAttendanceCopyWithImpl;
@useResult
$Res call({
 int sessionId, DateTime conductedOn, bool present, int recitation
});




}
/// @nodoc
class _$StudentAttendanceCopyWithImpl<$Res>
    implements $StudentAttendanceCopyWith<$Res> {
  _$StudentAttendanceCopyWithImpl(this._self, this._then);

  final StudentAttendance _self;
  final $Res Function(StudentAttendance) _then;

/// Create a copy of StudentAttendance
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? conductedOn = null,Object? present = null,Object? recitation = null,}) {
  return _then(_self.copyWith(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as int,conductedOn: null == conductedOn ? _self.conductedOn : conductedOn // ignore: cast_nullable_to_non_nullable
as DateTime,present: null == present ? _self.present : present // ignore: cast_nullable_to_non_nullable
as bool,recitation: null == recitation ? _self.recitation : recitation // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [StudentAttendance].
extension StudentAttendancePatterns on StudentAttendance {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StudentAttendance value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StudentAttendance() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StudentAttendance value)  $default,){
final _that = this;
switch (_that) {
case _StudentAttendance():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StudentAttendance value)?  $default,){
final _that = this;
switch (_that) {
case _StudentAttendance() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int sessionId,  DateTime conductedOn,  bool present,  int recitation)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StudentAttendance() when $default != null:
return $default(_that.sessionId,_that.conductedOn,_that.present,_that.recitation);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int sessionId,  DateTime conductedOn,  bool present,  int recitation)  $default,) {final _that = this;
switch (_that) {
case _StudentAttendance():
return $default(_that.sessionId,_that.conductedOn,_that.present,_that.recitation);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int sessionId,  DateTime conductedOn,  bool present,  int recitation)?  $default,) {final _that = this;
switch (_that) {
case _StudentAttendance() when $default != null:
return $default(_that.sessionId,_that.conductedOn,_that.present,_that.recitation);case _:
  return null;

}
}

}

/// @nodoc


class _StudentAttendance extends StudentAttendance {
  const _StudentAttendance({required this.sessionId, required this.conductedOn, required this.present, this.recitation = 0}): super._();
  

@override final  int sessionId;
@override final  DateTime conductedOn;
@override final  bool present;
@override@JsonKey() final  int recitation;

/// Create a copy of StudentAttendance
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StudentAttendanceCopyWith<_StudentAttendance> get copyWith => __$StudentAttendanceCopyWithImpl<_StudentAttendance>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StudentAttendance&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.conductedOn, conductedOn) || other.conductedOn == conductedOn)&&(identical(other.present, present) || other.present == present)&&(identical(other.recitation, recitation) || other.recitation == recitation));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId,conductedOn,present,recitation);

@override
String toString() {
  return 'StudentAttendance(sessionId: $sessionId, conductedOn: $conductedOn, present: $present, recitation: $recitation)';
}


}

/// @nodoc
abstract mixin class _$StudentAttendanceCopyWith<$Res> implements $StudentAttendanceCopyWith<$Res> {
  factory _$StudentAttendanceCopyWith(_StudentAttendance value, $Res Function(_StudentAttendance) _then) = __$StudentAttendanceCopyWithImpl;
@override @useResult
$Res call({
 int sessionId, DateTime conductedOn, bool present, int recitation
});




}
/// @nodoc
class __$StudentAttendanceCopyWithImpl<$Res>
    implements _$StudentAttendanceCopyWith<$Res> {
  __$StudentAttendanceCopyWithImpl(this._self, this._then);

  final _StudentAttendance _self;
  final $Res Function(_StudentAttendance) _then;

/// Create a copy of StudentAttendance
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? conductedOn = null,Object? present = null,Object? recitation = null,}) {
  return _then(_StudentAttendance(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as int,conductedOn: null == conductedOn ? _self.conductedOn : conductedOn // ignore: cast_nullable_to_non_nullable
as DateTime,present: null == present ? _self.present : present // ignore: cast_nullable_to_non_nullable
as bool,recitation: null == recitation ? _self.recitation : recitation // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
