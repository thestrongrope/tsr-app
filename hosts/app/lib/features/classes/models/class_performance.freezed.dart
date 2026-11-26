// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'class_performance.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ClassPerformance {

 int get totalSessions; int get attendedSessions; double get attendancePercent; int get totalRecitation; double get averageRecitation; int get quizzesAttempted; double get quizAverageScore;
/// Create a copy of ClassPerformance
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClassPerformanceCopyWith<ClassPerformance> get copyWith => _$ClassPerformanceCopyWithImpl<ClassPerformance>(this as ClassPerformance, _$identity);

  /// Serializes this ClassPerformance to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClassPerformance&&(identical(other.totalSessions, totalSessions) || other.totalSessions == totalSessions)&&(identical(other.attendedSessions, attendedSessions) || other.attendedSessions == attendedSessions)&&(identical(other.attendancePercent, attendancePercent) || other.attendancePercent == attendancePercent)&&(identical(other.totalRecitation, totalRecitation) || other.totalRecitation == totalRecitation)&&(identical(other.averageRecitation, averageRecitation) || other.averageRecitation == averageRecitation)&&(identical(other.quizzesAttempted, quizzesAttempted) || other.quizzesAttempted == quizzesAttempted)&&(identical(other.quizAverageScore, quizAverageScore) || other.quizAverageScore == quizAverageScore));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalSessions,attendedSessions,attendancePercent,totalRecitation,averageRecitation,quizzesAttempted,quizAverageScore);

@override
String toString() {
  return 'ClassPerformance(totalSessions: $totalSessions, attendedSessions: $attendedSessions, attendancePercent: $attendancePercent, totalRecitation: $totalRecitation, averageRecitation: $averageRecitation, quizzesAttempted: $quizzesAttempted, quizAverageScore: $quizAverageScore)';
}


}

/// @nodoc
abstract mixin class $ClassPerformanceCopyWith<$Res>  {
  factory $ClassPerformanceCopyWith(ClassPerformance value, $Res Function(ClassPerformance) _then) = _$ClassPerformanceCopyWithImpl;
@useResult
$Res call({
 int totalSessions, int attendedSessions, double attendancePercent, int totalRecitation, double averageRecitation, int quizzesAttempted, double quizAverageScore
});




}
/// @nodoc
class _$ClassPerformanceCopyWithImpl<$Res>
    implements $ClassPerformanceCopyWith<$Res> {
  _$ClassPerformanceCopyWithImpl(this._self, this._then);

  final ClassPerformance _self;
  final $Res Function(ClassPerformance) _then;

/// Create a copy of ClassPerformance
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totalSessions = null,Object? attendedSessions = null,Object? attendancePercent = null,Object? totalRecitation = null,Object? averageRecitation = null,Object? quizzesAttempted = null,Object? quizAverageScore = null,}) {
  return _then(_self.copyWith(
totalSessions: null == totalSessions ? _self.totalSessions : totalSessions // ignore: cast_nullable_to_non_nullable
as int,attendedSessions: null == attendedSessions ? _self.attendedSessions : attendedSessions // ignore: cast_nullable_to_non_nullable
as int,attendancePercent: null == attendancePercent ? _self.attendancePercent : attendancePercent // ignore: cast_nullable_to_non_nullable
as double,totalRecitation: null == totalRecitation ? _self.totalRecitation : totalRecitation // ignore: cast_nullable_to_non_nullable
as int,averageRecitation: null == averageRecitation ? _self.averageRecitation : averageRecitation // ignore: cast_nullable_to_non_nullable
as double,quizzesAttempted: null == quizzesAttempted ? _self.quizzesAttempted : quizzesAttempted // ignore: cast_nullable_to_non_nullable
as int,quizAverageScore: null == quizAverageScore ? _self.quizAverageScore : quizAverageScore // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [ClassPerformance].
extension ClassPerformancePatterns on ClassPerformance {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClassPerformance value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClassPerformance() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClassPerformance value)  $default,){
final _that = this;
switch (_that) {
case _ClassPerformance():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClassPerformance value)?  $default,){
final _that = this;
switch (_that) {
case _ClassPerformance() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int totalSessions,  int attendedSessions,  double attendancePercent,  int totalRecitation,  double averageRecitation,  int quizzesAttempted,  double quizAverageScore)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClassPerformance() when $default != null:
return $default(_that.totalSessions,_that.attendedSessions,_that.attendancePercent,_that.totalRecitation,_that.averageRecitation,_that.quizzesAttempted,_that.quizAverageScore);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int totalSessions,  int attendedSessions,  double attendancePercent,  int totalRecitation,  double averageRecitation,  int quizzesAttempted,  double quizAverageScore)  $default,) {final _that = this;
switch (_that) {
case _ClassPerformance():
return $default(_that.totalSessions,_that.attendedSessions,_that.attendancePercent,_that.totalRecitation,_that.averageRecitation,_that.quizzesAttempted,_that.quizAverageScore);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int totalSessions,  int attendedSessions,  double attendancePercent,  int totalRecitation,  double averageRecitation,  int quizzesAttempted,  double quizAverageScore)?  $default,) {final _that = this;
switch (_that) {
case _ClassPerformance() when $default != null:
return $default(_that.totalSessions,_that.attendedSessions,_that.attendancePercent,_that.totalRecitation,_that.averageRecitation,_that.quizzesAttempted,_that.quizAverageScore);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClassPerformance extends ClassPerformance {
  const _ClassPerformance({required this.totalSessions, required this.attendedSessions, required this.attendancePercent, required this.totalRecitation, required this.averageRecitation, required this.quizzesAttempted, required this.quizAverageScore}): super._();
  factory _ClassPerformance.fromJson(Map<String, dynamic> json) => _$ClassPerformanceFromJson(json);

@override final  int totalSessions;
@override final  int attendedSessions;
@override final  double attendancePercent;
@override final  int totalRecitation;
@override final  double averageRecitation;
@override final  int quizzesAttempted;
@override final  double quizAverageScore;

/// Create a copy of ClassPerformance
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClassPerformanceCopyWith<_ClassPerformance> get copyWith => __$ClassPerformanceCopyWithImpl<_ClassPerformance>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClassPerformanceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClassPerformance&&(identical(other.totalSessions, totalSessions) || other.totalSessions == totalSessions)&&(identical(other.attendedSessions, attendedSessions) || other.attendedSessions == attendedSessions)&&(identical(other.attendancePercent, attendancePercent) || other.attendancePercent == attendancePercent)&&(identical(other.totalRecitation, totalRecitation) || other.totalRecitation == totalRecitation)&&(identical(other.averageRecitation, averageRecitation) || other.averageRecitation == averageRecitation)&&(identical(other.quizzesAttempted, quizzesAttempted) || other.quizzesAttempted == quizzesAttempted)&&(identical(other.quizAverageScore, quizAverageScore) || other.quizAverageScore == quizAverageScore));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalSessions,attendedSessions,attendancePercent,totalRecitation,averageRecitation,quizzesAttempted,quizAverageScore);

@override
String toString() {
  return 'ClassPerformance(totalSessions: $totalSessions, attendedSessions: $attendedSessions, attendancePercent: $attendancePercent, totalRecitation: $totalRecitation, averageRecitation: $averageRecitation, quizzesAttempted: $quizzesAttempted, quizAverageScore: $quizAverageScore)';
}


}

/// @nodoc
abstract mixin class _$ClassPerformanceCopyWith<$Res> implements $ClassPerformanceCopyWith<$Res> {
  factory _$ClassPerformanceCopyWith(_ClassPerformance value, $Res Function(_ClassPerformance) _then) = __$ClassPerformanceCopyWithImpl;
@override @useResult
$Res call({
 int totalSessions, int attendedSessions, double attendancePercent, int totalRecitation, double averageRecitation, int quizzesAttempted, double quizAverageScore
});




}
/// @nodoc
class __$ClassPerformanceCopyWithImpl<$Res>
    implements _$ClassPerformanceCopyWith<$Res> {
  __$ClassPerformanceCopyWithImpl(this._self, this._then);

  final _ClassPerformance _self;
  final $Res Function(_ClassPerformance) _then;

/// Create a copy of ClassPerformance
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totalSessions = null,Object? attendedSessions = null,Object? attendancePercent = null,Object? totalRecitation = null,Object? averageRecitation = null,Object? quizzesAttempted = null,Object? quizAverageScore = null,}) {
  return _then(_ClassPerformance(
totalSessions: null == totalSessions ? _self.totalSessions : totalSessions // ignore: cast_nullable_to_non_nullable
as int,attendedSessions: null == attendedSessions ? _self.attendedSessions : attendedSessions // ignore: cast_nullable_to_non_nullable
as int,attendancePercent: null == attendancePercent ? _self.attendancePercent : attendancePercent // ignore: cast_nullable_to_non_nullable
as double,totalRecitation: null == totalRecitation ? _self.totalRecitation : totalRecitation // ignore: cast_nullable_to_non_nullable
as int,averageRecitation: null == averageRecitation ? _self.averageRecitation : averageRecitation // ignore: cast_nullable_to_non_nullable
as double,quizzesAttempted: null == quizzesAttempted ? _self.quizzesAttempted : quizzesAttempted // ignore: cast_nullable_to_non_nullable
as int,quizAverageScore: null == quizAverageScore ? _self.quizAverageScore : quizAverageScore // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
