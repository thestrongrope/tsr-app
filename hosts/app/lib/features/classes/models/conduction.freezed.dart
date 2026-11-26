// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'conduction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$HolyQuranSurah {

 int get id; String get surah; String? get arabic; int get verses;
/// Create a copy of HolyQuranSurah
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HolyQuranSurahCopyWith<HolyQuranSurah> get copyWith => _$HolyQuranSurahCopyWithImpl<HolyQuranSurah>(this as HolyQuranSurah, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HolyQuranSurah&&(identical(other.id, id) || other.id == id)&&(identical(other.surah, surah) || other.surah == surah)&&(identical(other.arabic, arabic) || other.arabic == arabic)&&(identical(other.verses, verses) || other.verses == verses));
}


@override
int get hashCode => Object.hash(runtimeType,id,surah,arabic,verses);

@override
String toString() {
  return 'HolyQuranSurah(id: $id, surah: $surah, arabic: $arabic, verses: $verses)';
}


}

/// @nodoc
abstract mixin class $HolyQuranSurahCopyWith<$Res>  {
  factory $HolyQuranSurahCopyWith(HolyQuranSurah value, $Res Function(HolyQuranSurah) _then) = _$HolyQuranSurahCopyWithImpl;
@useResult
$Res call({
 int id, String surah, String? arabic, int verses
});




}
/// @nodoc
class _$HolyQuranSurahCopyWithImpl<$Res>
    implements $HolyQuranSurahCopyWith<$Res> {
  _$HolyQuranSurahCopyWithImpl(this._self, this._then);

  final HolyQuranSurah _self;
  final $Res Function(HolyQuranSurah) _then;

/// Create a copy of HolyQuranSurah
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? surah = null,Object? arabic = freezed,Object? verses = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,surah: null == surah ? _self.surah : surah // ignore: cast_nullable_to_non_nullable
as String,arabic: freezed == arabic ? _self.arabic : arabic // ignore: cast_nullable_to_non_nullable
as String?,verses: null == verses ? _self.verses : verses // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [HolyQuranSurah].
extension HolyQuranSurahPatterns on HolyQuranSurah {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HolyQuranSurah value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HolyQuranSurah() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HolyQuranSurah value)  $default,){
final _that = this;
switch (_that) {
case _HolyQuranSurah():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HolyQuranSurah value)?  $default,){
final _that = this;
switch (_that) {
case _HolyQuranSurah() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String surah,  String? arabic,  int verses)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HolyQuranSurah() when $default != null:
return $default(_that.id,_that.surah,_that.arabic,_that.verses);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String surah,  String? arabic,  int verses)  $default,) {final _that = this;
switch (_that) {
case _HolyQuranSurah():
return $default(_that.id,_that.surah,_that.arabic,_that.verses);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String surah,  String? arabic,  int verses)?  $default,) {final _that = this;
switch (_that) {
case _HolyQuranSurah() when $default != null:
return $default(_that.id,_that.surah,_that.arabic,_that.verses);case _:
  return null;

}
}

}

/// @nodoc


class _HolyQuranSurah extends HolyQuranSurah {
  const _HolyQuranSurah({required this.id, required this.surah, this.arabic, this.verses = 0}): super._();
  

@override final  int id;
@override final  String surah;
@override final  String? arabic;
@override@JsonKey() final  int verses;

/// Create a copy of HolyQuranSurah
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HolyQuranSurahCopyWith<_HolyQuranSurah> get copyWith => __$HolyQuranSurahCopyWithImpl<_HolyQuranSurah>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HolyQuranSurah&&(identical(other.id, id) || other.id == id)&&(identical(other.surah, surah) || other.surah == surah)&&(identical(other.arabic, arabic) || other.arabic == arabic)&&(identical(other.verses, verses) || other.verses == verses));
}


@override
int get hashCode => Object.hash(runtimeType,id,surah,arabic,verses);

@override
String toString() {
  return 'HolyQuranSurah(id: $id, surah: $surah, arabic: $arabic, verses: $verses)';
}


}

/// @nodoc
abstract mixin class _$HolyQuranSurahCopyWith<$Res> implements $HolyQuranSurahCopyWith<$Res> {
  factory _$HolyQuranSurahCopyWith(_HolyQuranSurah value, $Res Function(_HolyQuranSurah) _then) = __$HolyQuranSurahCopyWithImpl;
@override @useResult
$Res call({
 int id, String surah, String? arabic, int verses
});




}
/// @nodoc
class __$HolyQuranSurahCopyWithImpl<$Res>
    implements _$HolyQuranSurahCopyWith<$Res> {
  __$HolyQuranSurahCopyWithImpl(this._self, this._then);

  final _HolyQuranSurah _self;
  final $Res Function(_HolyQuranSurah) _then;

/// Create a copy of HolyQuranSurah
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? surah = null,Object? arabic = freezed,Object? verses = null,}) {
  return _then(_HolyQuranSurah(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,surah: null == surah ? _self.surah : surah // ignore: cast_nullable_to_non_nullable
as String,arabic: freezed == arabic ? _self.arabic : arabic // ignore: cast_nullable_to_non_nullable
as String?,verses: null == verses ? _self.verses : verses // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$ConductionStudent {

 int get token; String get name; bool get present; int get recitation; bool get extra;
/// Create a copy of ConductionStudent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConductionStudentCopyWith<ConductionStudent> get copyWith => _$ConductionStudentCopyWithImpl<ConductionStudent>(this as ConductionStudent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConductionStudent&&(identical(other.token, token) || other.token == token)&&(identical(other.name, name) || other.name == name)&&(identical(other.present, present) || other.present == present)&&(identical(other.recitation, recitation) || other.recitation == recitation)&&(identical(other.extra, extra) || other.extra == extra));
}


@override
int get hashCode => Object.hash(runtimeType,token,name,present,recitation,extra);

@override
String toString() {
  return 'ConductionStudent(token: $token, name: $name, present: $present, recitation: $recitation, extra: $extra)';
}


}

/// @nodoc
abstract mixin class $ConductionStudentCopyWith<$Res>  {
  factory $ConductionStudentCopyWith(ConductionStudent value, $Res Function(ConductionStudent) _then) = _$ConductionStudentCopyWithImpl;
@useResult
$Res call({
 int token, String name, bool present, int recitation, bool extra
});




}
/// @nodoc
class _$ConductionStudentCopyWithImpl<$Res>
    implements $ConductionStudentCopyWith<$Res> {
  _$ConductionStudentCopyWithImpl(this._self, this._then);

  final ConductionStudent _self;
  final $Res Function(ConductionStudent) _then;

/// Create a copy of ConductionStudent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? token = null,Object? name = null,Object? present = null,Object? recitation = null,Object? extra = null,}) {
  return _then(_self.copyWith(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,present: null == present ? _self.present : present // ignore: cast_nullable_to_non_nullable
as bool,recitation: null == recitation ? _self.recitation : recitation // ignore: cast_nullable_to_non_nullable
as int,extra: null == extra ? _self.extra : extra // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ConductionStudent].
extension ConductionStudentPatterns on ConductionStudent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConductionStudent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConductionStudent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConductionStudent value)  $default,){
final _that = this;
switch (_that) {
case _ConductionStudent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConductionStudent value)?  $default,){
final _that = this;
switch (_that) {
case _ConductionStudent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int token,  String name,  bool present,  int recitation,  bool extra)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConductionStudent() when $default != null:
return $default(_that.token,_that.name,_that.present,_that.recitation,_that.extra);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int token,  String name,  bool present,  int recitation,  bool extra)  $default,) {final _that = this;
switch (_that) {
case _ConductionStudent():
return $default(_that.token,_that.name,_that.present,_that.recitation,_that.extra);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int token,  String name,  bool present,  int recitation,  bool extra)?  $default,) {final _that = this;
switch (_that) {
case _ConductionStudent() when $default != null:
return $default(_that.token,_that.name,_that.present,_that.recitation,_that.extra);case _:
  return null;

}
}

}

/// @nodoc


class _ConductionStudent extends ConductionStudent {
  const _ConductionStudent({required this.token, required this.name, this.present = false, this.recitation = 0, this.extra = false}): super._();
  

@override final  int token;
@override final  String name;
@override@JsonKey() final  bool present;
@override@JsonKey() final  int recitation;
@override@JsonKey() final  bool extra;

/// Create a copy of ConductionStudent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConductionStudentCopyWith<_ConductionStudent> get copyWith => __$ConductionStudentCopyWithImpl<_ConductionStudent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConductionStudent&&(identical(other.token, token) || other.token == token)&&(identical(other.name, name) || other.name == name)&&(identical(other.present, present) || other.present == present)&&(identical(other.recitation, recitation) || other.recitation == recitation)&&(identical(other.extra, extra) || other.extra == extra));
}


@override
int get hashCode => Object.hash(runtimeType,token,name,present,recitation,extra);

@override
String toString() {
  return 'ConductionStudent(token: $token, name: $name, present: $present, recitation: $recitation, extra: $extra)';
}


}

/// @nodoc
abstract mixin class _$ConductionStudentCopyWith<$Res> implements $ConductionStudentCopyWith<$Res> {
  factory _$ConductionStudentCopyWith(_ConductionStudent value, $Res Function(_ConductionStudent) _then) = __$ConductionStudentCopyWithImpl;
@override @useResult
$Res call({
 int token, String name, bool present, int recitation, bool extra
});




}
/// @nodoc
class __$ConductionStudentCopyWithImpl<$Res>
    implements _$ConductionStudentCopyWith<$Res> {
  __$ConductionStudentCopyWithImpl(this._self, this._then);

  final _ConductionStudent _self;
  final $Res Function(_ConductionStudent) _then;

/// Create a copy of ConductionStudent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? token = null,Object? name = null,Object? present = null,Object? recitation = null,Object? extra = null,}) {
  return _then(_ConductionStudent(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,present: null == present ? _self.present : present // ignore: cast_nullable_to_non_nullable
as bool,recitation: null == recitation ? _self.recitation : recitation // ignore: cast_nullable_to_non_nullable
as int,extra: null == extra ? _self.extra : extra // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$ConductionClass {

 int get id; String get code; String get name; int get level; String? get levelName; int get gender; String? get status; String? get teacherName; List<ConductionStudent> get students; List<ConductionStudent> get extraStudents; int get totalStudents;
/// Create a copy of ConductionClass
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConductionClassCopyWith<ConductionClass> get copyWith => _$ConductionClassCopyWithImpl<ConductionClass>(this as ConductionClass, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConductionClass&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.level, level) || other.level == level)&&(identical(other.levelName, levelName) || other.levelName == levelName)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.status, status) || other.status == status)&&(identical(other.teacherName, teacherName) || other.teacherName == teacherName)&&const DeepCollectionEquality().equals(other.students, students)&&const DeepCollectionEquality().equals(other.extraStudents, extraStudents)&&(identical(other.totalStudents, totalStudents) || other.totalStudents == totalStudents));
}


@override
int get hashCode => Object.hash(runtimeType,id,code,name,level,levelName,gender,status,teacherName,const DeepCollectionEquality().hash(students),const DeepCollectionEquality().hash(extraStudents),totalStudents);

@override
String toString() {
  return 'ConductionClass(id: $id, code: $code, name: $name, level: $level, levelName: $levelName, gender: $gender, status: $status, teacherName: $teacherName, students: $students, extraStudents: $extraStudents, totalStudents: $totalStudents)';
}


}

/// @nodoc
abstract mixin class $ConductionClassCopyWith<$Res>  {
  factory $ConductionClassCopyWith(ConductionClass value, $Res Function(ConductionClass) _then) = _$ConductionClassCopyWithImpl;
@useResult
$Res call({
 int id, String code, String name, int level, String? levelName, int gender, String? status, String? teacherName, List<ConductionStudent> students, List<ConductionStudent> extraStudents, int totalStudents
});




}
/// @nodoc
class _$ConductionClassCopyWithImpl<$Res>
    implements $ConductionClassCopyWith<$Res> {
  _$ConductionClassCopyWithImpl(this._self, this._then);

  final ConductionClass _self;
  final $Res Function(ConductionClass) _then;

/// Create a copy of ConductionClass
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? code = null,Object? name = null,Object? level = null,Object? levelName = freezed,Object? gender = null,Object? status = freezed,Object? teacherName = freezed,Object? students = null,Object? extraStudents = null,Object? totalStudents = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,levelName: freezed == levelName ? _self.levelName : levelName // ignore: cast_nullable_to_non_nullable
as String?,gender: null == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as int,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,teacherName: freezed == teacherName ? _self.teacherName : teacherName // ignore: cast_nullable_to_non_nullable
as String?,students: null == students ? _self.students : students // ignore: cast_nullable_to_non_nullable
as List<ConductionStudent>,extraStudents: null == extraStudents ? _self.extraStudents : extraStudents // ignore: cast_nullable_to_non_nullable
as List<ConductionStudent>,totalStudents: null == totalStudents ? _self.totalStudents : totalStudents // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ConductionClass].
extension ConductionClassPatterns on ConductionClass {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConductionClass value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConductionClass() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConductionClass value)  $default,){
final _that = this;
switch (_that) {
case _ConductionClass():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConductionClass value)?  $default,){
final _that = this;
switch (_that) {
case _ConductionClass() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String code,  String name,  int level,  String? levelName,  int gender,  String? status,  String? teacherName,  List<ConductionStudent> students,  List<ConductionStudent> extraStudents,  int totalStudents)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConductionClass() when $default != null:
return $default(_that.id,_that.code,_that.name,_that.level,_that.levelName,_that.gender,_that.status,_that.teacherName,_that.students,_that.extraStudents,_that.totalStudents);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String code,  String name,  int level,  String? levelName,  int gender,  String? status,  String? teacherName,  List<ConductionStudent> students,  List<ConductionStudent> extraStudents,  int totalStudents)  $default,) {final _that = this;
switch (_that) {
case _ConductionClass():
return $default(_that.id,_that.code,_that.name,_that.level,_that.levelName,_that.gender,_that.status,_that.teacherName,_that.students,_that.extraStudents,_that.totalStudents);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String code,  String name,  int level,  String? levelName,  int gender,  String? status,  String? teacherName,  List<ConductionStudent> students,  List<ConductionStudent> extraStudents,  int totalStudents)?  $default,) {final _that = this;
switch (_that) {
case _ConductionClass() when $default != null:
return $default(_that.id,_that.code,_that.name,_that.level,_that.levelName,_that.gender,_that.status,_that.teacherName,_that.students,_that.extraStudents,_that.totalStudents);case _:
  return null;

}
}

}

/// @nodoc


class _ConductionClass extends ConductionClass {
  const _ConductionClass({required this.id, required this.code, required this.name, this.level = 0, this.levelName, this.gender = 0, this.status, this.teacherName, final  List<ConductionStudent> students = const <ConductionStudent>[], final  List<ConductionStudent> extraStudents = const <ConductionStudent>[], this.totalStudents = 0}): _students = students,_extraStudents = extraStudents,super._();
  

@override final  int id;
@override final  String code;
@override final  String name;
@override@JsonKey() final  int level;
@override final  String? levelName;
@override@JsonKey() final  int gender;
@override final  String? status;
@override final  String? teacherName;
 final  List<ConductionStudent> _students;
@override@JsonKey() List<ConductionStudent> get students {
  if (_students is EqualUnmodifiableListView) return _students;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_students);
}

 final  List<ConductionStudent> _extraStudents;
@override@JsonKey() List<ConductionStudent> get extraStudents {
  if (_extraStudents is EqualUnmodifiableListView) return _extraStudents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_extraStudents);
}

@override@JsonKey() final  int totalStudents;

/// Create a copy of ConductionClass
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConductionClassCopyWith<_ConductionClass> get copyWith => __$ConductionClassCopyWithImpl<_ConductionClass>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConductionClass&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.level, level) || other.level == level)&&(identical(other.levelName, levelName) || other.levelName == levelName)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.status, status) || other.status == status)&&(identical(other.teacherName, teacherName) || other.teacherName == teacherName)&&const DeepCollectionEquality().equals(other._students, _students)&&const DeepCollectionEquality().equals(other._extraStudents, _extraStudents)&&(identical(other.totalStudents, totalStudents) || other.totalStudents == totalStudents));
}


@override
int get hashCode => Object.hash(runtimeType,id,code,name,level,levelName,gender,status,teacherName,const DeepCollectionEquality().hash(_students),const DeepCollectionEquality().hash(_extraStudents),totalStudents);

@override
String toString() {
  return 'ConductionClass(id: $id, code: $code, name: $name, level: $level, levelName: $levelName, gender: $gender, status: $status, teacherName: $teacherName, students: $students, extraStudents: $extraStudents, totalStudents: $totalStudents)';
}


}

/// @nodoc
abstract mixin class _$ConductionClassCopyWith<$Res> implements $ConductionClassCopyWith<$Res> {
  factory _$ConductionClassCopyWith(_ConductionClass value, $Res Function(_ConductionClass) _then) = __$ConductionClassCopyWithImpl;
@override @useResult
$Res call({
 int id, String code, String name, int level, String? levelName, int gender, String? status, String? teacherName, List<ConductionStudent> students, List<ConductionStudent> extraStudents, int totalStudents
});




}
/// @nodoc
class __$ConductionClassCopyWithImpl<$Res>
    implements _$ConductionClassCopyWith<$Res> {
  __$ConductionClassCopyWithImpl(this._self, this._then);

  final _ConductionClass _self;
  final $Res Function(_ConductionClass) _then;

/// Create a copy of ConductionClass
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? code = null,Object? name = null,Object? level = null,Object? levelName = freezed,Object? gender = null,Object? status = freezed,Object? teacherName = freezed,Object? students = null,Object? extraStudents = null,Object? totalStudents = null,}) {
  return _then(_ConductionClass(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,levelName: freezed == levelName ? _self.levelName : levelName // ignore: cast_nullable_to_non_nullable
as String?,gender: null == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as int,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,teacherName: freezed == teacherName ? _self.teacherName : teacherName // ignore: cast_nullable_to_non_nullable
as String?,students: null == students ? _self._students : students // ignore: cast_nullable_to_non_nullable
as List<ConductionStudent>,extraStudents: null == extraStudents ? _self._extraStudents : extraStudents // ignore: cast_nullable_to_non_nullable
as List<ConductionStudent>,totalStudents: null == totalStudents ? _self.totalStudents : totalStudents // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$ConductionSession {

 int get id; DateTime get conductedOn; bool get conducted; int? get duration; int? get attendance; int? get quranRecitationSurah; int? get quranRecitationVerse; bool get arabicConducted; bool get aqaedConducted; bool get ahkamConducted; bool get akhlaqConducted; bool get otherConducted; String? get arabicTopic; String? get aqaedTopic; String? get ahkamTopic; String? get akhlaqTopic; String? get otherTopic; String? get nonConductionReason; bool get editable;
/// Create a copy of ConductionSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConductionSessionCopyWith<ConductionSession> get copyWith => _$ConductionSessionCopyWithImpl<ConductionSession>(this as ConductionSession, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConductionSession&&(identical(other.id, id) || other.id == id)&&(identical(other.conductedOn, conductedOn) || other.conductedOn == conductedOn)&&(identical(other.conducted, conducted) || other.conducted == conducted)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.attendance, attendance) || other.attendance == attendance)&&(identical(other.quranRecitationSurah, quranRecitationSurah) || other.quranRecitationSurah == quranRecitationSurah)&&(identical(other.quranRecitationVerse, quranRecitationVerse) || other.quranRecitationVerse == quranRecitationVerse)&&(identical(other.arabicConducted, arabicConducted) || other.arabicConducted == arabicConducted)&&(identical(other.aqaedConducted, aqaedConducted) || other.aqaedConducted == aqaedConducted)&&(identical(other.ahkamConducted, ahkamConducted) || other.ahkamConducted == ahkamConducted)&&(identical(other.akhlaqConducted, akhlaqConducted) || other.akhlaqConducted == akhlaqConducted)&&(identical(other.otherConducted, otherConducted) || other.otherConducted == otherConducted)&&(identical(other.arabicTopic, arabicTopic) || other.arabicTopic == arabicTopic)&&(identical(other.aqaedTopic, aqaedTopic) || other.aqaedTopic == aqaedTopic)&&(identical(other.ahkamTopic, ahkamTopic) || other.ahkamTopic == ahkamTopic)&&(identical(other.akhlaqTopic, akhlaqTopic) || other.akhlaqTopic == akhlaqTopic)&&(identical(other.otherTopic, otherTopic) || other.otherTopic == otherTopic)&&(identical(other.nonConductionReason, nonConductionReason) || other.nonConductionReason == nonConductionReason)&&(identical(other.editable, editable) || other.editable == editable));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,conductedOn,conducted,duration,attendance,quranRecitationSurah,quranRecitationVerse,arabicConducted,aqaedConducted,ahkamConducted,akhlaqConducted,otherConducted,arabicTopic,aqaedTopic,ahkamTopic,akhlaqTopic,otherTopic,nonConductionReason,editable]);

@override
String toString() {
  return 'ConductionSession(id: $id, conductedOn: $conductedOn, conducted: $conducted, duration: $duration, attendance: $attendance, quranRecitationSurah: $quranRecitationSurah, quranRecitationVerse: $quranRecitationVerse, arabicConducted: $arabicConducted, aqaedConducted: $aqaedConducted, ahkamConducted: $ahkamConducted, akhlaqConducted: $akhlaqConducted, otherConducted: $otherConducted, arabicTopic: $arabicTopic, aqaedTopic: $aqaedTopic, ahkamTopic: $ahkamTopic, akhlaqTopic: $akhlaqTopic, otherTopic: $otherTopic, nonConductionReason: $nonConductionReason, editable: $editable)';
}


}

/// @nodoc
abstract mixin class $ConductionSessionCopyWith<$Res>  {
  factory $ConductionSessionCopyWith(ConductionSession value, $Res Function(ConductionSession) _then) = _$ConductionSessionCopyWithImpl;
@useResult
$Res call({
 int id, DateTime conductedOn, bool conducted, int? duration, int? attendance, int? quranRecitationSurah, int? quranRecitationVerse, bool arabicConducted, bool aqaedConducted, bool ahkamConducted, bool akhlaqConducted, bool otherConducted, String? arabicTopic, String? aqaedTopic, String? ahkamTopic, String? akhlaqTopic, String? otherTopic, String? nonConductionReason, bool editable
});




}
/// @nodoc
class _$ConductionSessionCopyWithImpl<$Res>
    implements $ConductionSessionCopyWith<$Res> {
  _$ConductionSessionCopyWithImpl(this._self, this._then);

  final ConductionSession _self;
  final $Res Function(ConductionSession) _then;

/// Create a copy of ConductionSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? conductedOn = null,Object? conducted = null,Object? duration = freezed,Object? attendance = freezed,Object? quranRecitationSurah = freezed,Object? quranRecitationVerse = freezed,Object? arabicConducted = null,Object? aqaedConducted = null,Object? ahkamConducted = null,Object? akhlaqConducted = null,Object? otherConducted = null,Object? arabicTopic = freezed,Object? aqaedTopic = freezed,Object? ahkamTopic = freezed,Object? akhlaqTopic = freezed,Object? otherTopic = freezed,Object? nonConductionReason = freezed,Object? editable = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,conductedOn: null == conductedOn ? _self.conductedOn : conductedOn // ignore: cast_nullable_to_non_nullable
as DateTime,conducted: null == conducted ? _self.conducted : conducted // ignore: cast_nullable_to_non_nullable
as bool,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as int?,attendance: freezed == attendance ? _self.attendance : attendance // ignore: cast_nullable_to_non_nullable
as int?,quranRecitationSurah: freezed == quranRecitationSurah ? _self.quranRecitationSurah : quranRecitationSurah // ignore: cast_nullable_to_non_nullable
as int?,quranRecitationVerse: freezed == quranRecitationVerse ? _self.quranRecitationVerse : quranRecitationVerse // ignore: cast_nullable_to_non_nullable
as int?,arabicConducted: null == arabicConducted ? _self.arabicConducted : arabicConducted // ignore: cast_nullable_to_non_nullable
as bool,aqaedConducted: null == aqaedConducted ? _self.aqaedConducted : aqaedConducted // ignore: cast_nullable_to_non_nullable
as bool,ahkamConducted: null == ahkamConducted ? _self.ahkamConducted : ahkamConducted // ignore: cast_nullable_to_non_nullable
as bool,akhlaqConducted: null == akhlaqConducted ? _self.akhlaqConducted : akhlaqConducted // ignore: cast_nullable_to_non_nullable
as bool,otherConducted: null == otherConducted ? _self.otherConducted : otherConducted // ignore: cast_nullable_to_non_nullable
as bool,arabicTopic: freezed == arabicTopic ? _self.arabicTopic : arabicTopic // ignore: cast_nullable_to_non_nullable
as String?,aqaedTopic: freezed == aqaedTopic ? _self.aqaedTopic : aqaedTopic // ignore: cast_nullable_to_non_nullable
as String?,ahkamTopic: freezed == ahkamTopic ? _self.ahkamTopic : ahkamTopic // ignore: cast_nullable_to_non_nullable
as String?,akhlaqTopic: freezed == akhlaqTopic ? _self.akhlaqTopic : akhlaqTopic // ignore: cast_nullable_to_non_nullable
as String?,otherTopic: freezed == otherTopic ? _self.otherTopic : otherTopic // ignore: cast_nullable_to_non_nullable
as String?,nonConductionReason: freezed == nonConductionReason ? _self.nonConductionReason : nonConductionReason // ignore: cast_nullable_to_non_nullable
as String?,editable: null == editable ? _self.editable : editable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ConductionSession].
extension ConductionSessionPatterns on ConductionSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConductionSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConductionSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConductionSession value)  $default,){
final _that = this;
switch (_that) {
case _ConductionSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConductionSession value)?  $default,){
final _that = this;
switch (_that) {
case _ConductionSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  DateTime conductedOn,  bool conducted,  int? duration,  int? attendance,  int? quranRecitationSurah,  int? quranRecitationVerse,  bool arabicConducted,  bool aqaedConducted,  bool ahkamConducted,  bool akhlaqConducted,  bool otherConducted,  String? arabicTopic,  String? aqaedTopic,  String? ahkamTopic,  String? akhlaqTopic,  String? otherTopic,  String? nonConductionReason,  bool editable)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConductionSession() when $default != null:
return $default(_that.id,_that.conductedOn,_that.conducted,_that.duration,_that.attendance,_that.quranRecitationSurah,_that.quranRecitationVerse,_that.arabicConducted,_that.aqaedConducted,_that.ahkamConducted,_that.akhlaqConducted,_that.otherConducted,_that.arabicTopic,_that.aqaedTopic,_that.ahkamTopic,_that.akhlaqTopic,_that.otherTopic,_that.nonConductionReason,_that.editable);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  DateTime conductedOn,  bool conducted,  int? duration,  int? attendance,  int? quranRecitationSurah,  int? quranRecitationVerse,  bool arabicConducted,  bool aqaedConducted,  bool ahkamConducted,  bool akhlaqConducted,  bool otherConducted,  String? arabicTopic,  String? aqaedTopic,  String? ahkamTopic,  String? akhlaqTopic,  String? otherTopic,  String? nonConductionReason,  bool editable)  $default,) {final _that = this;
switch (_that) {
case _ConductionSession():
return $default(_that.id,_that.conductedOn,_that.conducted,_that.duration,_that.attendance,_that.quranRecitationSurah,_that.quranRecitationVerse,_that.arabicConducted,_that.aqaedConducted,_that.ahkamConducted,_that.akhlaqConducted,_that.otherConducted,_that.arabicTopic,_that.aqaedTopic,_that.ahkamTopic,_that.akhlaqTopic,_that.otherTopic,_that.nonConductionReason,_that.editable);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  DateTime conductedOn,  bool conducted,  int? duration,  int? attendance,  int? quranRecitationSurah,  int? quranRecitationVerse,  bool arabicConducted,  bool aqaedConducted,  bool ahkamConducted,  bool akhlaqConducted,  bool otherConducted,  String? arabicTopic,  String? aqaedTopic,  String? ahkamTopic,  String? akhlaqTopic,  String? otherTopic,  String? nonConductionReason,  bool editable)?  $default,) {final _that = this;
switch (_that) {
case _ConductionSession() when $default != null:
return $default(_that.id,_that.conductedOn,_that.conducted,_that.duration,_that.attendance,_that.quranRecitationSurah,_that.quranRecitationVerse,_that.arabicConducted,_that.aqaedConducted,_that.ahkamConducted,_that.akhlaqConducted,_that.otherConducted,_that.arabicTopic,_that.aqaedTopic,_that.ahkamTopic,_that.akhlaqTopic,_that.otherTopic,_that.nonConductionReason,_that.editable);case _:
  return null;

}
}

}

/// @nodoc


class _ConductionSession extends ConductionSession {
  const _ConductionSession({required this.id, required this.conductedOn, required this.conducted, this.duration, this.attendance, this.quranRecitationSurah, this.quranRecitationVerse, this.arabicConducted = false, this.aqaedConducted = false, this.ahkamConducted = false, this.akhlaqConducted = false, this.otherConducted = false, this.arabicTopic, this.aqaedTopic, this.ahkamTopic, this.akhlaqTopic, this.otherTopic, this.nonConductionReason, this.editable = false}): super._();
  

@override final  int id;
@override final  DateTime conductedOn;
@override final  bool conducted;
@override final  int? duration;
@override final  int? attendance;
@override final  int? quranRecitationSurah;
@override final  int? quranRecitationVerse;
@override@JsonKey() final  bool arabicConducted;
@override@JsonKey() final  bool aqaedConducted;
@override@JsonKey() final  bool ahkamConducted;
@override@JsonKey() final  bool akhlaqConducted;
@override@JsonKey() final  bool otherConducted;
@override final  String? arabicTopic;
@override final  String? aqaedTopic;
@override final  String? ahkamTopic;
@override final  String? akhlaqTopic;
@override final  String? otherTopic;
@override final  String? nonConductionReason;
@override@JsonKey() final  bool editable;

/// Create a copy of ConductionSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConductionSessionCopyWith<_ConductionSession> get copyWith => __$ConductionSessionCopyWithImpl<_ConductionSession>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConductionSession&&(identical(other.id, id) || other.id == id)&&(identical(other.conductedOn, conductedOn) || other.conductedOn == conductedOn)&&(identical(other.conducted, conducted) || other.conducted == conducted)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.attendance, attendance) || other.attendance == attendance)&&(identical(other.quranRecitationSurah, quranRecitationSurah) || other.quranRecitationSurah == quranRecitationSurah)&&(identical(other.quranRecitationVerse, quranRecitationVerse) || other.quranRecitationVerse == quranRecitationVerse)&&(identical(other.arabicConducted, arabicConducted) || other.arabicConducted == arabicConducted)&&(identical(other.aqaedConducted, aqaedConducted) || other.aqaedConducted == aqaedConducted)&&(identical(other.ahkamConducted, ahkamConducted) || other.ahkamConducted == ahkamConducted)&&(identical(other.akhlaqConducted, akhlaqConducted) || other.akhlaqConducted == akhlaqConducted)&&(identical(other.otherConducted, otherConducted) || other.otherConducted == otherConducted)&&(identical(other.arabicTopic, arabicTopic) || other.arabicTopic == arabicTopic)&&(identical(other.aqaedTopic, aqaedTopic) || other.aqaedTopic == aqaedTopic)&&(identical(other.ahkamTopic, ahkamTopic) || other.ahkamTopic == ahkamTopic)&&(identical(other.akhlaqTopic, akhlaqTopic) || other.akhlaqTopic == akhlaqTopic)&&(identical(other.otherTopic, otherTopic) || other.otherTopic == otherTopic)&&(identical(other.nonConductionReason, nonConductionReason) || other.nonConductionReason == nonConductionReason)&&(identical(other.editable, editable) || other.editable == editable));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,conductedOn,conducted,duration,attendance,quranRecitationSurah,quranRecitationVerse,arabicConducted,aqaedConducted,ahkamConducted,akhlaqConducted,otherConducted,arabicTopic,aqaedTopic,ahkamTopic,akhlaqTopic,otherTopic,nonConductionReason,editable]);

@override
String toString() {
  return 'ConductionSession(id: $id, conductedOn: $conductedOn, conducted: $conducted, duration: $duration, attendance: $attendance, quranRecitationSurah: $quranRecitationSurah, quranRecitationVerse: $quranRecitationVerse, arabicConducted: $arabicConducted, aqaedConducted: $aqaedConducted, ahkamConducted: $ahkamConducted, akhlaqConducted: $akhlaqConducted, otherConducted: $otherConducted, arabicTopic: $arabicTopic, aqaedTopic: $aqaedTopic, ahkamTopic: $ahkamTopic, akhlaqTopic: $akhlaqTopic, otherTopic: $otherTopic, nonConductionReason: $nonConductionReason, editable: $editable)';
}


}

/// @nodoc
abstract mixin class _$ConductionSessionCopyWith<$Res> implements $ConductionSessionCopyWith<$Res> {
  factory _$ConductionSessionCopyWith(_ConductionSession value, $Res Function(_ConductionSession) _then) = __$ConductionSessionCopyWithImpl;
@override @useResult
$Res call({
 int id, DateTime conductedOn, bool conducted, int? duration, int? attendance, int? quranRecitationSurah, int? quranRecitationVerse, bool arabicConducted, bool aqaedConducted, bool ahkamConducted, bool akhlaqConducted, bool otherConducted, String? arabicTopic, String? aqaedTopic, String? ahkamTopic, String? akhlaqTopic, String? otherTopic, String? nonConductionReason, bool editable
});




}
/// @nodoc
class __$ConductionSessionCopyWithImpl<$Res>
    implements _$ConductionSessionCopyWith<$Res> {
  __$ConductionSessionCopyWithImpl(this._self, this._then);

  final _ConductionSession _self;
  final $Res Function(_ConductionSession) _then;

/// Create a copy of ConductionSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? conductedOn = null,Object? conducted = null,Object? duration = freezed,Object? attendance = freezed,Object? quranRecitationSurah = freezed,Object? quranRecitationVerse = freezed,Object? arabicConducted = null,Object? aqaedConducted = null,Object? ahkamConducted = null,Object? akhlaqConducted = null,Object? otherConducted = null,Object? arabicTopic = freezed,Object? aqaedTopic = freezed,Object? ahkamTopic = freezed,Object? akhlaqTopic = freezed,Object? otherTopic = freezed,Object? nonConductionReason = freezed,Object? editable = null,}) {
  return _then(_ConductionSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,conductedOn: null == conductedOn ? _self.conductedOn : conductedOn // ignore: cast_nullable_to_non_nullable
as DateTime,conducted: null == conducted ? _self.conducted : conducted // ignore: cast_nullable_to_non_nullable
as bool,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as int?,attendance: freezed == attendance ? _self.attendance : attendance // ignore: cast_nullable_to_non_nullable
as int?,quranRecitationSurah: freezed == quranRecitationSurah ? _self.quranRecitationSurah : quranRecitationSurah // ignore: cast_nullable_to_non_nullable
as int?,quranRecitationVerse: freezed == quranRecitationVerse ? _self.quranRecitationVerse : quranRecitationVerse // ignore: cast_nullable_to_non_nullable
as int?,arabicConducted: null == arabicConducted ? _self.arabicConducted : arabicConducted // ignore: cast_nullable_to_non_nullable
as bool,aqaedConducted: null == aqaedConducted ? _self.aqaedConducted : aqaedConducted // ignore: cast_nullable_to_non_nullable
as bool,ahkamConducted: null == ahkamConducted ? _self.ahkamConducted : ahkamConducted // ignore: cast_nullable_to_non_nullable
as bool,akhlaqConducted: null == akhlaqConducted ? _self.akhlaqConducted : akhlaqConducted // ignore: cast_nullable_to_non_nullable
as bool,otherConducted: null == otherConducted ? _self.otherConducted : otherConducted // ignore: cast_nullable_to_non_nullable
as bool,arabicTopic: freezed == arabicTopic ? _self.arabicTopic : arabicTopic // ignore: cast_nullable_to_non_nullable
as String?,aqaedTopic: freezed == aqaedTopic ? _self.aqaedTopic : aqaedTopic // ignore: cast_nullable_to_non_nullable
as String?,ahkamTopic: freezed == ahkamTopic ? _self.ahkamTopic : ahkamTopic // ignore: cast_nullable_to_non_nullable
as String?,akhlaqTopic: freezed == akhlaqTopic ? _self.akhlaqTopic : akhlaqTopic // ignore: cast_nullable_to_non_nullable
as String?,otherTopic: freezed == otherTopic ? _self.otherTopic : otherTopic // ignore: cast_nullable_to_non_nullable
as String?,nonConductionReason: freezed == nonConductionReason ? _self.nonConductionReason : nonConductionReason // ignore: cast_nullable_to_non_nullable
as String?,editable: null == editable ? _self.editable : editable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$ConductionListResponse {

 ConductionClass? get classInfo; List<ConductionSession> get sessions; int get totalRecords; int get totalPages; int get page;
/// Create a copy of ConductionListResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConductionListResponseCopyWith<ConductionListResponse> get copyWith => _$ConductionListResponseCopyWithImpl<ConductionListResponse>(this as ConductionListResponse, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConductionListResponse&&(identical(other.classInfo, classInfo) || other.classInfo == classInfo)&&const DeepCollectionEquality().equals(other.sessions, sessions)&&(identical(other.totalRecords, totalRecords) || other.totalRecords == totalRecords)&&(identical(other.totalPages, totalPages) || other.totalPages == totalPages)&&(identical(other.page, page) || other.page == page));
}


@override
int get hashCode => Object.hash(runtimeType,classInfo,const DeepCollectionEquality().hash(sessions),totalRecords,totalPages,page);

@override
String toString() {
  return 'ConductionListResponse(classInfo: $classInfo, sessions: $sessions, totalRecords: $totalRecords, totalPages: $totalPages, page: $page)';
}


}

/// @nodoc
abstract mixin class $ConductionListResponseCopyWith<$Res>  {
  factory $ConductionListResponseCopyWith(ConductionListResponse value, $Res Function(ConductionListResponse) _then) = _$ConductionListResponseCopyWithImpl;
@useResult
$Res call({
 ConductionClass? classInfo, List<ConductionSession> sessions, int totalRecords, int totalPages, int page
});


$ConductionClassCopyWith<$Res>? get classInfo;

}
/// @nodoc
class _$ConductionListResponseCopyWithImpl<$Res>
    implements $ConductionListResponseCopyWith<$Res> {
  _$ConductionListResponseCopyWithImpl(this._self, this._then);

  final ConductionListResponse _self;
  final $Res Function(ConductionListResponse) _then;

/// Create a copy of ConductionListResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? classInfo = freezed,Object? sessions = null,Object? totalRecords = null,Object? totalPages = null,Object? page = null,}) {
  return _then(_self.copyWith(
classInfo: freezed == classInfo ? _self.classInfo : classInfo // ignore: cast_nullable_to_non_nullable
as ConductionClass?,sessions: null == sessions ? _self.sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<ConductionSession>,totalRecords: null == totalRecords ? _self.totalRecords : totalRecords // ignore: cast_nullable_to_non_nullable
as int,totalPages: null == totalPages ? _self.totalPages : totalPages // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of ConductionListResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConductionClassCopyWith<$Res>? get classInfo {
    if (_self.classInfo == null) {
    return null;
  }

  return $ConductionClassCopyWith<$Res>(_self.classInfo!, (value) {
    return _then(_self.copyWith(classInfo: value));
  });
}
}


/// Adds pattern-matching-related methods to [ConductionListResponse].
extension ConductionListResponsePatterns on ConductionListResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConductionListResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConductionListResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConductionListResponse value)  $default,){
final _that = this;
switch (_that) {
case _ConductionListResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConductionListResponse value)?  $default,){
final _that = this;
switch (_that) {
case _ConductionListResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ConductionClass? classInfo,  List<ConductionSession> sessions,  int totalRecords,  int totalPages,  int page)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConductionListResponse() when $default != null:
return $default(_that.classInfo,_that.sessions,_that.totalRecords,_that.totalPages,_that.page);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ConductionClass? classInfo,  List<ConductionSession> sessions,  int totalRecords,  int totalPages,  int page)  $default,) {final _that = this;
switch (_that) {
case _ConductionListResponse():
return $default(_that.classInfo,_that.sessions,_that.totalRecords,_that.totalPages,_that.page);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ConductionClass? classInfo,  List<ConductionSession> sessions,  int totalRecords,  int totalPages,  int page)?  $default,) {final _that = this;
switch (_that) {
case _ConductionListResponse() when $default != null:
return $default(_that.classInfo,_that.sessions,_that.totalRecords,_that.totalPages,_that.page);case _:
  return null;

}
}

}

/// @nodoc


class _ConductionListResponse extends ConductionListResponse {
  const _ConductionListResponse({this.classInfo, final  List<ConductionSession> sessions = const <ConductionSession>[], this.totalRecords = 0, this.totalPages = 1, this.page = 1}): _sessions = sessions,super._();
  

@override final  ConductionClass? classInfo;
 final  List<ConductionSession> _sessions;
@override@JsonKey() List<ConductionSession> get sessions {
  if (_sessions is EqualUnmodifiableListView) return _sessions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sessions);
}

@override@JsonKey() final  int totalRecords;
@override@JsonKey() final  int totalPages;
@override@JsonKey() final  int page;

/// Create a copy of ConductionListResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConductionListResponseCopyWith<_ConductionListResponse> get copyWith => __$ConductionListResponseCopyWithImpl<_ConductionListResponse>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConductionListResponse&&(identical(other.classInfo, classInfo) || other.classInfo == classInfo)&&const DeepCollectionEquality().equals(other._sessions, _sessions)&&(identical(other.totalRecords, totalRecords) || other.totalRecords == totalRecords)&&(identical(other.totalPages, totalPages) || other.totalPages == totalPages)&&(identical(other.page, page) || other.page == page));
}


@override
int get hashCode => Object.hash(runtimeType,classInfo,const DeepCollectionEquality().hash(_sessions),totalRecords,totalPages,page);

@override
String toString() {
  return 'ConductionListResponse(classInfo: $classInfo, sessions: $sessions, totalRecords: $totalRecords, totalPages: $totalPages, page: $page)';
}


}

/// @nodoc
abstract mixin class _$ConductionListResponseCopyWith<$Res> implements $ConductionListResponseCopyWith<$Res> {
  factory _$ConductionListResponseCopyWith(_ConductionListResponse value, $Res Function(_ConductionListResponse) _then) = __$ConductionListResponseCopyWithImpl;
@override @useResult
$Res call({
 ConductionClass? classInfo, List<ConductionSession> sessions, int totalRecords, int totalPages, int page
});


@override $ConductionClassCopyWith<$Res>? get classInfo;

}
/// @nodoc
class __$ConductionListResponseCopyWithImpl<$Res>
    implements _$ConductionListResponseCopyWith<$Res> {
  __$ConductionListResponseCopyWithImpl(this._self, this._then);

  final _ConductionListResponse _self;
  final $Res Function(_ConductionListResponse) _then;

/// Create a copy of ConductionListResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? classInfo = freezed,Object? sessions = null,Object? totalRecords = null,Object? totalPages = null,Object? page = null,}) {
  return _then(_ConductionListResponse(
classInfo: freezed == classInfo ? _self.classInfo : classInfo // ignore: cast_nullable_to_non_nullable
as ConductionClass?,sessions: null == sessions ? _self._sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<ConductionSession>,totalRecords: null == totalRecords ? _self.totalRecords : totalRecords // ignore: cast_nullable_to_non_nullable
as int,totalPages: null == totalPages ? _self.totalPages : totalPages // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of ConductionListResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConductionClassCopyWith<$Res>? get classInfo {
    if (_self.classInfo == null) {
    return null;
  }

  return $ConductionClassCopyWith<$Res>(_self.classInfo!, (value) {
    return _then(_self.copyWith(classInfo: value));
  });
}
}

/// @nodoc
mixin _$ConductionFormData {

 ConductionClass? get classInfo; DateTime? get lastSessionDate; DateTime? get nextSessionDate; DateTime? get futureDate;/// The last topic the class recorded for each subject, keyed by subject
/// code ('arabic', 'aqaed', …). A subject the class has never recorded is
/// absent rather than empty.
 Map<String, String> get latestTopics;/// The Surah of the class's most recent earlier conduction that has one,
/// or null when there is none (or the server predates the prefill).
 int? get latestSurah; List<HolyQuranSurah> get holyQuran;
/// Create a copy of ConductionFormData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConductionFormDataCopyWith<ConductionFormData> get copyWith => _$ConductionFormDataCopyWithImpl<ConductionFormData>(this as ConductionFormData, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConductionFormData&&(identical(other.classInfo, classInfo) || other.classInfo == classInfo)&&(identical(other.lastSessionDate, lastSessionDate) || other.lastSessionDate == lastSessionDate)&&(identical(other.nextSessionDate, nextSessionDate) || other.nextSessionDate == nextSessionDate)&&(identical(other.futureDate, futureDate) || other.futureDate == futureDate)&&const DeepCollectionEquality().equals(other.latestTopics, latestTopics)&&(identical(other.latestSurah, latestSurah) || other.latestSurah == latestSurah)&&const DeepCollectionEquality().equals(other.holyQuran, holyQuran));
}


@override
int get hashCode => Object.hash(runtimeType,classInfo,lastSessionDate,nextSessionDate,futureDate,const DeepCollectionEquality().hash(latestTopics),latestSurah,const DeepCollectionEquality().hash(holyQuran));

@override
String toString() {
  return 'ConductionFormData(classInfo: $classInfo, lastSessionDate: $lastSessionDate, nextSessionDate: $nextSessionDate, futureDate: $futureDate, latestTopics: $latestTopics, latestSurah: $latestSurah, holyQuran: $holyQuran)';
}


}

/// @nodoc
abstract mixin class $ConductionFormDataCopyWith<$Res>  {
  factory $ConductionFormDataCopyWith(ConductionFormData value, $Res Function(ConductionFormData) _then) = _$ConductionFormDataCopyWithImpl;
@useResult
$Res call({
 ConductionClass? classInfo, DateTime? lastSessionDate, DateTime? nextSessionDate, DateTime? futureDate, Map<String, String> latestTopics, int? latestSurah, List<HolyQuranSurah> holyQuran
});


$ConductionClassCopyWith<$Res>? get classInfo;

}
/// @nodoc
class _$ConductionFormDataCopyWithImpl<$Res>
    implements $ConductionFormDataCopyWith<$Res> {
  _$ConductionFormDataCopyWithImpl(this._self, this._then);

  final ConductionFormData _self;
  final $Res Function(ConductionFormData) _then;

/// Create a copy of ConductionFormData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? classInfo = freezed,Object? lastSessionDate = freezed,Object? nextSessionDate = freezed,Object? futureDate = freezed,Object? latestTopics = null,Object? latestSurah = freezed,Object? holyQuran = null,}) {
  return _then(_self.copyWith(
classInfo: freezed == classInfo ? _self.classInfo : classInfo // ignore: cast_nullable_to_non_nullable
as ConductionClass?,lastSessionDate: freezed == lastSessionDate ? _self.lastSessionDate : lastSessionDate // ignore: cast_nullable_to_non_nullable
as DateTime?,nextSessionDate: freezed == nextSessionDate ? _self.nextSessionDate : nextSessionDate // ignore: cast_nullable_to_non_nullable
as DateTime?,futureDate: freezed == futureDate ? _self.futureDate : futureDate // ignore: cast_nullable_to_non_nullable
as DateTime?,latestTopics: null == latestTopics ? _self.latestTopics : latestTopics // ignore: cast_nullable_to_non_nullable
as Map<String, String>,latestSurah: freezed == latestSurah ? _self.latestSurah : latestSurah // ignore: cast_nullable_to_non_nullable
as int?,holyQuran: null == holyQuran ? _self.holyQuran : holyQuran // ignore: cast_nullable_to_non_nullable
as List<HolyQuranSurah>,
  ));
}
/// Create a copy of ConductionFormData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConductionClassCopyWith<$Res>? get classInfo {
    if (_self.classInfo == null) {
    return null;
  }

  return $ConductionClassCopyWith<$Res>(_self.classInfo!, (value) {
    return _then(_self.copyWith(classInfo: value));
  });
}
}


/// Adds pattern-matching-related methods to [ConductionFormData].
extension ConductionFormDataPatterns on ConductionFormData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConductionFormData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConductionFormData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConductionFormData value)  $default,){
final _that = this;
switch (_that) {
case _ConductionFormData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConductionFormData value)?  $default,){
final _that = this;
switch (_that) {
case _ConductionFormData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ConductionClass? classInfo,  DateTime? lastSessionDate,  DateTime? nextSessionDate,  DateTime? futureDate,  Map<String, String> latestTopics,  int? latestSurah,  List<HolyQuranSurah> holyQuran)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConductionFormData() when $default != null:
return $default(_that.classInfo,_that.lastSessionDate,_that.nextSessionDate,_that.futureDate,_that.latestTopics,_that.latestSurah,_that.holyQuran);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ConductionClass? classInfo,  DateTime? lastSessionDate,  DateTime? nextSessionDate,  DateTime? futureDate,  Map<String, String> latestTopics,  int? latestSurah,  List<HolyQuranSurah> holyQuran)  $default,) {final _that = this;
switch (_that) {
case _ConductionFormData():
return $default(_that.classInfo,_that.lastSessionDate,_that.nextSessionDate,_that.futureDate,_that.latestTopics,_that.latestSurah,_that.holyQuran);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ConductionClass? classInfo,  DateTime? lastSessionDate,  DateTime? nextSessionDate,  DateTime? futureDate,  Map<String, String> latestTopics,  int? latestSurah,  List<HolyQuranSurah> holyQuran)?  $default,) {final _that = this;
switch (_that) {
case _ConductionFormData() when $default != null:
return $default(_that.classInfo,_that.lastSessionDate,_that.nextSessionDate,_that.futureDate,_that.latestTopics,_that.latestSurah,_that.holyQuran);case _:
  return null;

}
}

}

/// @nodoc


class _ConductionFormData extends ConductionFormData {
  const _ConductionFormData({this.classInfo, this.lastSessionDate, this.nextSessionDate, this.futureDate, final  Map<String, String> latestTopics = const <String, String>{}, this.latestSurah, final  List<HolyQuranSurah> holyQuran = const <HolyQuranSurah>[]}): _latestTopics = latestTopics,_holyQuran = holyQuran,super._();
  

@override final  ConductionClass? classInfo;
@override final  DateTime? lastSessionDate;
@override final  DateTime? nextSessionDate;
@override final  DateTime? futureDate;
/// The last topic the class recorded for each subject, keyed by subject
/// code ('arabic', 'aqaed', …). A subject the class has never recorded is
/// absent rather than empty.
 final  Map<String, String> _latestTopics;
/// The last topic the class recorded for each subject, keyed by subject
/// code ('arabic', 'aqaed', …). A subject the class has never recorded is
/// absent rather than empty.
@override@JsonKey() Map<String, String> get latestTopics {
  if (_latestTopics is EqualUnmodifiableMapView) return _latestTopics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_latestTopics);
}

/// The Surah of the class's most recent earlier conduction that has one,
/// or null when there is none (or the server predates the prefill).
@override final  int? latestSurah;
 final  List<HolyQuranSurah> _holyQuran;
@override@JsonKey() List<HolyQuranSurah> get holyQuran {
  if (_holyQuran is EqualUnmodifiableListView) return _holyQuran;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_holyQuran);
}


/// Create a copy of ConductionFormData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConductionFormDataCopyWith<_ConductionFormData> get copyWith => __$ConductionFormDataCopyWithImpl<_ConductionFormData>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConductionFormData&&(identical(other.classInfo, classInfo) || other.classInfo == classInfo)&&(identical(other.lastSessionDate, lastSessionDate) || other.lastSessionDate == lastSessionDate)&&(identical(other.nextSessionDate, nextSessionDate) || other.nextSessionDate == nextSessionDate)&&(identical(other.futureDate, futureDate) || other.futureDate == futureDate)&&const DeepCollectionEquality().equals(other._latestTopics, _latestTopics)&&(identical(other.latestSurah, latestSurah) || other.latestSurah == latestSurah)&&const DeepCollectionEquality().equals(other._holyQuran, _holyQuran));
}


@override
int get hashCode => Object.hash(runtimeType,classInfo,lastSessionDate,nextSessionDate,futureDate,const DeepCollectionEquality().hash(_latestTopics),latestSurah,const DeepCollectionEquality().hash(_holyQuran));

@override
String toString() {
  return 'ConductionFormData(classInfo: $classInfo, lastSessionDate: $lastSessionDate, nextSessionDate: $nextSessionDate, futureDate: $futureDate, latestTopics: $latestTopics, latestSurah: $latestSurah, holyQuran: $holyQuran)';
}


}

/// @nodoc
abstract mixin class _$ConductionFormDataCopyWith<$Res> implements $ConductionFormDataCopyWith<$Res> {
  factory _$ConductionFormDataCopyWith(_ConductionFormData value, $Res Function(_ConductionFormData) _then) = __$ConductionFormDataCopyWithImpl;
@override @useResult
$Res call({
 ConductionClass? classInfo, DateTime? lastSessionDate, DateTime? nextSessionDate, DateTime? futureDate, Map<String, String> latestTopics, int? latestSurah, List<HolyQuranSurah> holyQuran
});


@override $ConductionClassCopyWith<$Res>? get classInfo;

}
/// @nodoc
class __$ConductionFormDataCopyWithImpl<$Res>
    implements _$ConductionFormDataCopyWith<$Res> {
  __$ConductionFormDataCopyWithImpl(this._self, this._then);

  final _ConductionFormData _self;
  final $Res Function(_ConductionFormData) _then;

/// Create a copy of ConductionFormData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? classInfo = freezed,Object? lastSessionDate = freezed,Object? nextSessionDate = freezed,Object? futureDate = freezed,Object? latestTopics = null,Object? latestSurah = freezed,Object? holyQuran = null,}) {
  return _then(_ConductionFormData(
classInfo: freezed == classInfo ? _self.classInfo : classInfo // ignore: cast_nullable_to_non_nullable
as ConductionClass?,lastSessionDate: freezed == lastSessionDate ? _self.lastSessionDate : lastSessionDate // ignore: cast_nullable_to_non_nullable
as DateTime?,nextSessionDate: freezed == nextSessionDate ? _self.nextSessionDate : nextSessionDate // ignore: cast_nullable_to_non_nullable
as DateTime?,futureDate: freezed == futureDate ? _self.futureDate : futureDate // ignore: cast_nullable_to_non_nullable
as DateTime?,latestTopics: null == latestTopics ? _self._latestTopics : latestTopics // ignore: cast_nullable_to_non_nullable
as Map<String, String>,latestSurah: freezed == latestSurah ? _self.latestSurah : latestSurah // ignore: cast_nullable_to_non_nullable
as int?,holyQuran: null == holyQuran ? _self._holyQuran : holyQuran // ignore: cast_nullable_to_non_nullable
as List<HolyQuranSurah>,
  ));
}

/// Create a copy of ConductionFormData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConductionClassCopyWith<$Res>? get classInfo {
    if (_self.classInfo == null) {
    return null;
  }

  return $ConductionClassCopyWith<$Res>(_self.classInfo!, (value) {
    return _then(_self.copyWith(classInfo: value));
  });
}
}

/// @nodoc
mixin _$ConductionEditData {

 ConductionClass? get classInfo; ConductionSession? get session; List<ConductionStudent> get attendance; List<HolyQuranSurah> get holyQuran;
/// Create a copy of ConductionEditData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConductionEditDataCopyWith<ConductionEditData> get copyWith => _$ConductionEditDataCopyWithImpl<ConductionEditData>(this as ConductionEditData, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConductionEditData&&(identical(other.classInfo, classInfo) || other.classInfo == classInfo)&&(identical(other.session, session) || other.session == session)&&const DeepCollectionEquality().equals(other.attendance, attendance)&&const DeepCollectionEquality().equals(other.holyQuran, holyQuran));
}


@override
int get hashCode => Object.hash(runtimeType,classInfo,session,const DeepCollectionEquality().hash(attendance),const DeepCollectionEquality().hash(holyQuran));

@override
String toString() {
  return 'ConductionEditData(classInfo: $classInfo, session: $session, attendance: $attendance, holyQuran: $holyQuran)';
}


}

/// @nodoc
abstract mixin class $ConductionEditDataCopyWith<$Res>  {
  factory $ConductionEditDataCopyWith(ConductionEditData value, $Res Function(ConductionEditData) _then) = _$ConductionEditDataCopyWithImpl;
@useResult
$Res call({
 ConductionClass? classInfo, ConductionSession? session, List<ConductionStudent> attendance, List<HolyQuranSurah> holyQuran
});


$ConductionClassCopyWith<$Res>? get classInfo;$ConductionSessionCopyWith<$Res>? get session;

}
/// @nodoc
class _$ConductionEditDataCopyWithImpl<$Res>
    implements $ConductionEditDataCopyWith<$Res> {
  _$ConductionEditDataCopyWithImpl(this._self, this._then);

  final ConductionEditData _self;
  final $Res Function(ConductionEditData) _then;

/// Create a copy of ConductionEditData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? classInfo = freezed,Object? session = freezed,Object? attendance = null,Object? holyQuran = null,}) {
  return _then(_self.copyWith(
classInfo: freezed == classInfo ? _self.classInfo : classInfo // ignore: cast_nullable_to_non_nullable
as ConductionClass?,session: freezed == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as ConductionSession?,attendance: null == attendance ? _self.attendance : attendance // ignore: cast_nullable_to_non_nullable
as List<ConductionStudent>,holyQuran: null == holyQuran ? _self.holyQuran : holyQuran // ignore: cast_nullable_to_non_nullable
as List<HolyQuranSurah>,
  ));
}
/// Create a copy of ConductionEditData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConductionClassCopyWith<$Res>? get classInfo {
    if (_self.classInfo == null) {
    return null;
  }

  return $ConductionClassCopyWith<$Res>(_self.classInfo!, (value) {
    return _then(_self.copyWith(classInfo: value));
  });
}/// Create a copy of ConductionEditData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConductionSessionCopyWith<$Res>? get session {
    if (_self.session == null) {
    return null;
  }

  return $ConductionSessionCopyWith<$Res>(_self.session!, (value) {
    return _then(_self.copyWith(session: value));
  });
}
}


/// Adds pattern-matching-related methods to [ConductionEditData].
extension ConductionEditDataPatterns on ConductionEditData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConductionEditData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConductionEditData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConductionEditData value)  $default,){
final _that = this;
switch (_that) {
case _ConductionEditData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConductionEditData value)?  $default,){
final _that = this;
switch (_that) {
case _ConductionEditData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ConductionClass? classInfo,  ConductionSession? session,  List<ConductionStudent> attendance,  List<HolyQuranSurah> holyQuran)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConductionEditData() when $default != null:
return $default(_that.classInfo,_that.session,_that.attendance,_that.holyQuran);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ConductionClass? classInfo,  ConductionSession? session,  List<ConductionStudent> attendance,  List<HolyQuranSurah> holyQuran)  $default,) {final _that = this;
switch (_that) {
case _ConductionEditData():
return $default(_that.classInfo,_that.session,_that.attendance,_that.holyQuran);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ConductionClass? classInfo,  ConductionSession? session,  List<ConductionStudent> attendance,  List<HolyQuranSurah> holyQuran)?  $default,) {final _that = this;
switch (_that) {
case _ConductionEditData() when $default != null:
return $default(_that.classInfo,_that.session,_that.attendance,_that.holyQuran);case _:
  return null;

}
}

}

/// @nodoc


class _ConductionEditData extends ConductionEditData {
  const _ConductionEditData({this.classInfo, this.session, final  List<ConductionStudent> attendance = const <ConductionStudent>[], final  List<HolyQuranSurah> holyQuran = const <HolyQuranSurah>[]}): _attendance = attendance,_holyQuran = holyQuran,super._();
  

@override final  ConductionClass? classInfo;
@override final  ConductionSession? session;
 final  List<ConductionStudent> _attendance;
@override@JsonKey() List<ConductionStudent> get attendance {
  if (_attendance is EqualUnmodifiableListView) return _attendance;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attendance);
}

 final  List<HolyQuranSurah> _holyQuran;
@override@JsonKey() List<HolyQuranSurah> get holyQuran {
  if (_holyQuran is EqualUnmodifiableListView) return _holyQuran;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_holyQuran);
}


/// Create a copy of ConductionEditData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConductionEditDataCopyWith<_ConductionEditData> get copyWith => __$ConductionEditDataCopyWithImpl<_ConductionEditData>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConductionEditData&&(identical(other.classInfo, classInfo) || other.classInfo == classInfo)&&(identical(other.session, session) || other.session == session)&&const DeepCollectionEquality().equals(other._attendance, _attendance)&&const DeepCollectionEquality().equals(other._holyQuran, _holyQuran));
}


@override
int get hashCode => Object.hash(runtimeType,classInfo,session,const DeepCollectionEquality().hash(_attendance),const DeepCollectionEquality().hash(_holyQuran));

@override
String toString() {
  return 'ConductionEditData(classInfo: $classInfo, session: $session, attendance: $attendance, holyQuran: $holyQuran)';
}


}

/// @nodoc
abstract mixin class _$ConductionEditDataCopyWith<$Res> implements $ConductionEditDataCopyWith<$Res> {
  factory _$ConductionEditDataCopyWith(_ConductionEditData value, $Res Function(_ConductionEditData) _then) = __$ConductionEditDataCopyWithImpl;
@override @useResult
$Res call({
 ConductionClass? classInfo, ConductionSession? session, List<ConductionStudent> attendance, List<HolyQuranSurah> holyQuran
});


@override $ConductionClassCopyWith<$Res>? get classInfo;@override $ConductionSessionCopyWith<$Res>? get session;

}
/// @nodoc
class __$ConductionEditDataCopyWithImpl<$Res>
    implements _$ConductionEditDataCopyWith<$Res> {
  __$ConductionEditDataCopyWithImpl(this._self, this._then);

  final _ConductionEditData _self;
  final $Res Function(_ConductionEditData) _then;

/// Create a copy of ConductionEditData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? classInfo = freezed,Object? session = freezed,Object? attendance = null,Object? holyQuran = null,}) {
  return _then(_ConductionEditData(
classInfo: freezed == classInfo ? _self.classInfo : classInfo // ignore: cast_nullable_to_non_nullable
as ConductionClass?,session: freezed == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as ConductionSession?,attendance: null == attendance ? _self._attendance : attendance // ignore: cast_nullable_to_non_nullable
as List<ConductionStudent>,holyQuran: null == holyQuran ? _self._holyQuran : holyQuran // ignore: cast_nullable_to_non_nullable
as List<HolyQuranSurah>,
  ));
}

/// Create a copy of ConductionEditData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConductionClassCopyWith<$Res>? get classInfo {
    if (_self.classInfo == null) {
    return null;
  }

  return $ConductionClassCopyWith<$Res>(_self.classInfo!, (value) {
    return _then(_self.copyWith(classInfo: value));
  });
}/// Create a copy of ConductionEditData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConductionSessionCopyWith<$Res>? get session {
    if (_self.session == null) {
    return null;
  }

  return $ConductionSessionCopyWith<$Res>(_self.session!, (value) {
    return _then(_self.copyWith(session: value));
  });
}
}

/// @nodoc
mixin _$ConductionDateCheck {

 bool get alreadyConducted; bool get sameWeek;
/// Create a copy of ConductionDateCheck
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConductionDateCheckCopyWith<ConductionDateCheck> get copyWith => _$ConductionDateCheckCopyWithImpl<ConductionDateCheck>(this as ConductionDateCheck, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConductionDateCheck&&(identical(other.alreadyConducted, alreadyConducted) || other.alreadyConducted == alreadyConducted)&&(identical(other.sameWeek, sameWeek) || other.sameWeek == sameWeek));
}


@override
int get hashCode => Object.hash(runtimeType,alreadyConducted,sameWeek);

@override
String toString() {
  return 'ConductionDateCheck(alreadyConducted: $alreadyConducted, sameWeek: $sameWeek)';
}


}

/// @nodoc
abstract mixin class $ConductionDateCheckCopyWith<$Res>  {
  factory $ConductionDateCheckCopyWith(ConductionDateCheck value, $Res Function(ConductionDateCheck) _then) = _$ConductionDateCheckCopyWithImpl;
@useResult
$Res call({
 bool alreadyConducted, bool sameWeek
});




}
/// @nodoc
class _$ConductionDateCheckCopyWithImpl<$Res>
    implements $ConductionDateCheckCopyWith<$Res> {
  _$ConductionDateCheckCopyWithImpl(this._self, this._then);

  final ConductionDateCheck _self;
  final $Res Function(ConductionDateCheck) _then;

/// Create a copy of ConductionDateCheck
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? alreadyConducted = null,Object? sameWeek = null,}) {
  return _then(_self.copyWith(
alreadyConducted: null == alreadyConducted ? _self.alreadyConducted : alreadyConducted // ignore: cast_nullable_to_non_nullable
as bool,sameWeek: null == sameWeek ? _self.sameWeek : sameWeek // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ConductionDateCheck].
extension ConductionDateCheckPatterns on ConductionDateCheck {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConductionDateCheck value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConductionDateCheck() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConductionDateCheck value)  $default,){
final _that = this;
switch (_that) {
case _ConductionDateCheck():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConductionDateCheck value)?  $default,){
final _that = this;
switch (_that) {
case _ConductionDateCheck() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool alreadyConducted,  bool sameWeek)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConductionDateCheck() when $default != null:
return $default(_that.alreadyConducted,_that.sameWeek);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool alreadyConducted,  bool sameWeek)  $default,) {final _that = this;
switch (_that) {
case _ConductionDateCheck():
return $default(_that.alreadyConducted,_that.sameWeek);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool alreadyConducted,  bool sameWeek)?  $default,) {final _that = this;
switch (_that) {
case _ConductionDateCheck() when $default != null:
return $default(_that.alreadyConducted,_that.sameWeek);case _:
  return null;

}
}

}

/// @nodoc


class _ConductionDateCheck extends ConductionDateCheck {
  const _ConductionDateCheck({this.alreadyConducted = false, this.sameWeek = false}): super._();
  

@override@JsonKey() final  bool alreadyConducted;
@override@JsonKey() final  bool sameWeek;

/// Create a copy of ConductionDateCheck
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConductionDateCheckCopyWith<_ConductionDateCheck> get copyWith => __$ConductionDateCheckCopyWithImpl<_ConductionDateCheck>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConductionDateCheck&&(identical(other.alreadyConducted, alreadyConducted) || other.alreadyConducted == alreadyConducted)&&(identical(other.sameWeek, sameWeek) || other.sameWeek == sameWeek));
}


@override
int get hashCode => Object.hash(runtimeType,alreadyConducted,sameWeek);

@override
String toString() {
  return 'ConductionDateCheck(alreadyConducted: $alreadyConducted, sameWeek: $sameWeek)';
}


}

/// @nodoc
abstract mixin class _$ConductionDateCheckCopyWith<$Res> implements $ConductionDateCheckCopyWith<$Res> {
  factory _$ConductionDateCheckCopyWith(_ConductionDateCheck value, $Res Function(_ConductionDateCheck) _then) = __$ConductionDateCheckCopyWithImpl;
@override @useResult
$Res call({
 bool alreadyConducted, bool sameWeek
});




}
/// @nodoc
class __$ConductionDateCheckCopyWithImpl<$Res>
    implements _$ConductionDateCheckCopyWith<$Res> {
  __$ConductionDateCheckCopyWithImpl(this._self, this._then);

  final _ConductionDateCheck _self;
  final $Res Function(_ConductionDateCheck) _then;

/// Create a copy of ConductionDateCheck
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? alreadyConducted = null,Object? sameWeek = null,}) {
  return _then(_ConductionDateCheck(
alreadyConducted: null == alreadyConducted ? _self.alreadyConducted : alreadyConducted // ignore: cast_nullable_to_non_nullable
as bool,sameWeek: null == sameWeek ? _self.sameWeek : sameWeek // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
