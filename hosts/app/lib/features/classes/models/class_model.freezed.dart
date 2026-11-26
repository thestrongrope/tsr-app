// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'class_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ClassModel {

 int get id; String get code; String get name; int get level; String? get levelName; int? get language; int get gender; String get status; String? get location; String? get teacherName; String? get teacherMobile; String? get format; DateTime? get startedOn;// 'conducting' when the user is the class teacher, 'managing' when they
// manage the class without attending or teaching it, else 'attending'.
 String? get role;// The class join link to share; the server sends it to the class
// teacher only, null for everyone else.
 String? get joinUrl;// Where the class meets and how it is tagged, for search and the card.
 String? get city; String? get country; List<String> get tags;// Enrolled students; the server sends it for managed classes only.
 int? get studentCount; List<ClassSchedule> get schedules;
/// Create a copy of ClassModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClassModelCopyWith<ClassModel> get copyWith => _$ClassModelCopyWithImpl<ClassModel>(this as ClassModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClassModel&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.level, level) || other.level == level)&&(identical(other.levelName, levelName) || other.levelName == levelName)&&(identical(other.language, language) || other.language == language)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.status, status) || other.status == status)&&(identical(other.location, location) || other.location == location)&&(identical(other.teacherName, teacherName) || other.teacherName == teacherName)&&(identical(other.teacherMobile, teacherMobile) || other.teacherMobile == teacherMobile)&&(identical(other.format, format) || other.format == format)&&(identical(other.startedOn, startedOn) || other.startedOn == startedOn)&&(identical(other.role, role) || other.role == role)&&(identical(other.joinUrl, joinUrl) || other.joinUrl == joinUrl)&&(identical(other.city, city) || other.city == city)&&(identical(other.country, country) || other.country == country)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.studentCount, studentCount) || other.studentCount == studentCount)&&const DeepCollectionEquality().equals(other.schedules, schedules));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,code,name,level,levelName,language,gender,status,location,teacherName,teacherMobile,format,startedOn,role,joinUrl,city,country,const DeepCollectionEquality().hash(tags),studentCount,const DeepCollectionEquality().hash(schedules)]);

@override
String toString() {
  return 'ClassModel(id: $id, code: $code, name: $name, level: $level, levelName: $levelName, language: $language, gender: $gender, status: $status, location: $location, teacherName: $teacherName, teacherMobile: $teacherMobile, format: $format, startedOn: $startedOn, role: $role, joinUrl: $joinUrl, city: $city, country: $country, tags: $tags, studentCount: $studentCount, schedules: $schedules)';
}


}

/// @nodoc
abstract mixin class $ClassModelCopyWith<$Res>  {
  factory $ClassModelCopyWith(ClassModel value, $Res Function(ClassModel) _then) = _$ClassModelCopyWithImpl;
@useResult
$Res call({
 int id, String code, String name, int level, String? levelName, int? language, int gender, String status, String? location, String? teacherName, String? teacherMobile, String? format, DateTime? startedOn, String? role, String? joinUrl, String? city, String? country, List<String> tags, int? studentCount, List<ClassSchedule> schedules
});




}
/// @nodoc
class _$ClassModelCopyWithImpl<$Res>
    implements $ClassModelCopyWith<$Res> {
  _$ClassModelCopyWithImpl(this._self, this._then);

  final ClassModel _self;
  final $Res Function(ClassModel) _then;

/// Create a copy of ClassModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? code = null,Object? name = null,Object? level = null,Object? levelName = freezed,Object? language = freezed,Object? gender = null,Object? status = null,Object? location = freezed,Object? teacherName = freezed,Object? teacherMobile = freezed,Object? format = freezed,Object? startedOn = freezed,Object? role = freezed,Object? joinUrl = freezed,Object? city = freezed,Object? country = freezed,Object? tags = null,Object? studentCount = freezed,Object? schedules = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,levelName: freezed == levelName ? _self.levelName : levelName // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as int?,gender: null == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,teacherName: freezed == teacherName ? _self.teacherName : teacherName // ignore: cast_nullable_to_non_nullable
as String?,teacherMobile: freezed == teacherMobile ? _self.teacherMobile : teacherMobile // ignore: cast_nullable_to_non_nullable
as String?,format: freezed == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String?,startedOn: freezed == startedOn ? _self.startedOn : startedOn // ignore: cast_nullable_to_non_nullable
as DateTime?,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,joinUrl: freezed == joinUrl ? _self.joinUrl : joinUrl // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,studentCount: freezed == studentCount ? _self.studentCount : studentCount // ignore: cast_nullable_to_non_nullable
as int?,schedules: null == schedules ? _self.schedules : schedules // ignore: cast_nullable_to_non_nullable
as List<ClassSchedule>,
  ));
}

}


/// Adds pattern-matching-related methods to [ClassModel].
extension ClassModelPatterns on ClassModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClassModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClassModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClassModel value)  $default,){
final _that = this;
switch (_that) {
case _ClassModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClassModel value)?  $default,){
final _that = this;
switch (_that) {
case _ClassModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String code,  String name,  int level,  String? levelName,  int? language,  int gender,  String status,  String? location,  String? teacherName,  String? teacherMobile,  String? format,  DateTime? startedOn,  String? role,  String? joinUrl,  String? city,  String? country,  List<String> tags,  int? studentCount,  List<ClassSchedule> schedules)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClassModel() when $default != null:
return $default(_that.id,_that.code,_that.name,_that.level,_that.levelName,_that.language,_that.gender,_that.status,_that.location,_that.teacherName,_that.teacherMobile,_that.format,_that.startedOn,_that.role,_that.joinUrl,_that.city,_that.country,_that.tags,_that.studentCount,_that.schedules);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String code,  String name,  int level,  String? levelName,  int? language,  int gender,  String status,  String? location,  String? teacherName,  String? teacherMobile,  String? format,  DateTime? startedOn,  String? role,  String? joinUrl,  String? city,  String? country,  List<String> tags,  int? studentCount,  List<ClassSchedule> schedules)  $default,) {final _that = this;
switch (_that) {
case _ClassModel():
return $default(_that.id,_that.code,_that.name,_that.level,_that.levelName,_that.language,_that.gender,_that.status,_that.location,_that.teacherName,_that.teacherMobile,_that.format,_that.startedOn,_that.role,_that.joinUrl,_that.city,_that.country,_that.tags,_that.studentCount,_that.schedules);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String code,  String name,  int level,  String? levelName,  int? language,  int gender,  String status,  String? location,  String? teacherName,  String? teacherMobile,  String? format,  DateTime? startedOn,  String? role,  String? joinUrl,  String? city,  String? country,  List<String> tags,  int? studentCount,  List<ClassSchedule> schedules)?  $default,) {final _that = this;
switch (_that) {
case _ClassModel() when $default != null:
return $default(_that.id,_that.code,_that.name,_that.level,_that.levelName,_that.language,_that.gender,_that.status,_that.location,_that.teacherName,_that.teacherMobile,_that.format,_that.startedOn,_that.role,_that.joinUrl,_that.city,_that.country,_that.tags,_that.studentCount,_that.schedules);case _:
  return null;

}
}

}

/// @nodoc


class _ClassModel extends ClassModel {
  const _ClassModel({required this.id, required this.code, required this.name, required this.level, this.levelName, this.language, required this.gender, required this.status, this.location, this.teacherName, this.teacherMobile, this.format, this.startedOn, this.role, this.joinUrl, this.city, this.country, final  List<String> tags = const [], this.studentCount, final  List<ClassSchedule> schedules = const []}): _tags = tags,_schedules = schedules,super._();
  

@override final  int id;
@override final  String code;
@override final  String name;
@override final  int level;
@override final  String? levelName;
@override final  int? language;
@override final  int gender;
@override final  String status;
@override final  String? location;
@override final  String? teacherName;
@override final  String? teacherMobile;
@override final  String? format;
@override final  DateTime? startedOn;
// 'conducting' when the user is the class teacher, 'managing' when they
// manage the class without attending or teaching it, else 'attending'.
@override final  String? role;
// The class join link to share; the server sends it to the class
// teacher only, null for everyone else.
@override final  String? joinUrl;
// Where the class meets and how it is tagged, for search and the card.
@override final  String? city;
@override final  String? country;
 final  List<String> _tags;
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

// Enrolled students; the server sends it for managed classes only.
@override final  int? studentCount;
 final  List<ClassSchedule> _schedules;
@override@JsonKey() List<ClassSchedule> get schedules {
  if (_schedules is EqualUnmodifiableListView) return _schedules;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_schedules);
}


/// Create a copy of ClassModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClassModelCopyWith<_ClassModel> get copyWith => __$ClassModelCopyWithImpl<_ClassModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClassModel&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.level, level) || other.level == level)&&(identical(other.levelName, levelName) || other.levelName == levelName)&&(identical(other.language, language) || other.language == language)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.status, status) || other.status == status)&&(identical(other.location, location) || other.location == location)&&(identical(other.teacherName, teacherName) || other.teacherName == teacherName)&&(identical(other.teacherMobile, teacherMobile) || other.teacherMobile == teacherMobile)&&(identical(other.format, format) || other.format == format)&&(identical(other.startedOn, startedOn) || other.startedOn == startedOn)&&(identical(other.role, role) || other.role == role)&&(identical(other.joinUrl, joinUrl) || other.joinUrl == joinUrl)&&(identical(other.city, city) || other.city == city)&&(identical(other.country, country) || other.country == country)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.studentCount, studentCount) || other.studentCount == studentCount)&&const DeepCollectionEquality().equals(other._schedules, _schedules));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,code,name,level,levelName,language,gender,status,location,teacherName,teacherMobile,format,startedOn,role,joinUrl,city,country,const DeepCollectionEquality().hash(_tags),studentCount,const DeepCollectionEquality().hash(_schedules)]);

@override
String toString() {
  return 'ClassModel(id: $id, code: $code, name: $name, level: $level, levelName: $levelName, language: $language, gender: $gender, status: $status, location: $location, teacherName: $teacherName, teacherMobile: $teacherMobile, format: $format, startedOn: $startedOn, role: $role, joinUrl: $joinUrl, city: $city, country: $country, tags: $tags, studentCount: $studentCount, schedules: $schedules)';
}


}

/// @nodoc
abstract mixin class _$ClassModelCopyWith<$Res> implements $ClassModelCopyWith<$Res> {
  factory _$ClassModelCopyWith(_ClassModel value, $Res Function(_ClassModel) _then) = __$ClassModelCopyWithImpl;
@override @useResult
$Res call({
 int id, String code, String name, int level, String? levelName, int? language, int gender, String status, String? location, String? teacherName, String? teacherMobile, String? format, DateTime? startedOn, String? role, String? joinUrl, String? city, String? country, List<String> tags, int? studentCount, List<ClassSchedule> schedules
});




}
/// @nodoc
class __$ClassModelCopyWithImpl<$Res>
    implements _$ClassModelCopyWith<$Res> {
  __$ClassModelCopyWithImpl(this._self, this._then);

  final _ClassModel _self;
  final $Res Function(_ClassModel) _then;

/// Create a copy of ClassModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? code = null,Object? name = null,Object? level = null,Object? levelName = freezed,Object? language = freezed,Object? gender = null,Object? status = null,Object? location = freezed,Object? teacherName = freezed,Object? teacherMobile = freezed,Object? format = freezed,Object? startedOn = freezed,Object? role = freezed,Object? joinUrl = freezed,Object? city = freezed,Object? country = freezed,Object? tags = null,Object? studentCount = freezed,Object? schedules = null,}) {
  return _then(_ClassModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,levelName: freezed == levelName ? _self.levelName : levelName // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as int?,gender: null == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,teacherName: freezed == teacherName ? _self.teacherName : teacherName // ignore: cast_nullable_to_non_nullable
as String?,teacherMobile: freezed == teacherMobile ? _self.teacherMobile : teacherMobile // ignore: cast_nullable_to_non_nullable
as String?,format: freezed == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String?,startedOn: freezed == startedOn ? _self.startedOn : startedOn // ignore: cast_nullable_to_non_nullable
as DateTime?,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,joinUrl: freezed == joinUrl ? _self.joinUrl : joinUrl // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,studentCount: freezed == studentCount ? _self.studentCount : studentCount // ignore: cast_nullable_to_non_nullable
as int?,schedules: null == schedules ? _self._schedules : schedules // ignore: cast_nullable_to_non_nullable
as List<ClassSchedule>,
  ));
}


}


/// @nodoc
mixin _$ClassJoinResponse {

 bool get success; String get message; int? get classId; String? get className;
/// Create a copy of ClassJoinResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClassJoinResponseCopyWith<ClassJoinResponse> get copyWith => _$ClassJoinResponseCopyWithImpl<ClassJoinResponse>(this as ClassJoinResponse, _$identity);

  /// Serializes this ClassJoinResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClassJoinResponse&&(identical(other.success, success) || other.success == success)&&(identical(other.message, message) || other.message == message)&&(identical(other.classId, classId) || other.classId == classId)&&(identical(other.className, className) || other.className == className));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,success,message,classId,className);

@override
String toString() {
  return 'ClassJoinResponse(success: $success, message: $message, classId: $classId, className: $className)';
}


}

/// @nodoc
abstract mixin class $ClassJoinResponseCopyWith<$Res>  {
  factory $ClassJoinResponseCopyWith(ClassJoinResponse value, $Res Function(ClassJoinResponse) _then) = _$ClassJoinResponseCopyWithImpl;
@useResult
$Res call({
 bool success, String message, int? classId, String? className
});




}
/// @nodoc
class _$ClassJoinResponseCopyWithImpl<$Res>
    implements $ClassJoinResponseCopyWith<$Res> {
  _$ClassJoinResponseCopyWithImpl(this._self, this._then);

  final ClassJoinResponse _self;
  final $Res Function(ClassJoinResponse) _then;

/// Create a copy of ClassJoinResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? success = null,Object? message = null,Object? classId = freezed,Object? className = freezed,}) {
  return _then(_self.copyWith(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,classId: freezed == classId ? _self.classId : classId // ignore: cast_nullable_to_non_nullable
as int?,className: freezed == className ? _self.className : className // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ClassJoinResponse].
extension ClassJoinResponsePatterns on ClassJoinResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClassJoinResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClassJoinResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClassJoinResponse value)  $default,){
final _that = this;
switch (_that) {
case _ClassJoinResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClassJoinResponse value)?  $default,){
final _that = this;
switch (_that) {
case _ClassJoinResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool success,  String message,  int? classId,  String? className)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClassJoinResponse() when $default != null:
return $default(_that.success,_that.message,_that.classId,_that.className);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool success,  String message,  int? classId,  String? className)  $default,) {final _that = this;
switch (_that) {
case _ClassJoinResponse():
return $default(_that.success,_that.message,_that.classId,_that.className);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool success,  String message,  int? classId,  String? className)?  $default,) {final _that = this;
switch (_that) {
case _ClassJoinResponse() when $default != null:
return $default(_that.success,_that.message,_that.classId,_that.className);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClassJoinResponse implements ClassJoinResponse {
  const _ClassJoinResponse({required this.success, required this.message, this.classId, this.className});
  factory _ClassJoinResponse.fromJson(Map<String, dynamic> json) => _$ClassJoinResponseFromJson(json);

@override final  bool success;
@override final  String message;
@override final  int? classId;
@override final  String? className;

/// Create a copy of ClassJoinResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClassJoinResponseCopyWith<_ClassJoinResponse> get copyWith => __$ClassJoinResponseCopyWithImpl<_ClassJoinResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClassJoinResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClassJoinResponse&&(identical(other.success, success) || other.success == success)&&(identical(other.message, message) || other.message == message)&&(identical(other.classId, classId) || other.classId == classId)&&(identical(other.className, className) || other.className == className));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,success,message,classId,className);

@override
String toString() {
  return 'ClassJoinResponse(success: $success, message: $message, classId: $classId, className: $className)';
}


}

/// @nodoc
abstract mixin class _$ClassJoinResponseCopyWith<$Res> implements $ClassJoinResponseCopyWith<$Res> {
  factory _$ClassJoinResponseCopyWith(_ClassJoinResponse value, $Res Function(_ClassJoinResponse) _then) = __$ClassJoinResponseCopyWithImpl;
@override @useResult
$Res call({
 bool success, String message, int? classId, String? className
});




}
/// @nodoc
class __$ClassJoinResponseCopyWithImpl<$Res>
    implements _$ClassJoinResponseCopyWith<$Res> {
  __$ClassJoinResponseCopyWithImpl(this._self, this._then);

  final _ClassJoinResponse _self;
  final $Res Function(_ClassJoinResponse) _then;

/// Create a copy of ClassJoinResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? success = null,Object? message = null,Object? classId = freezed,Object? className = freezed,}) {
  return _then(_ClassJoinResponse(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,classId: freezed == classId ? _self.classId : classId // ignore: cast_nullable_to_non_nullable
as int?,className: freezed == className ? _self.className : className // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
