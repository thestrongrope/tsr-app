// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'syllabus_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SyllabusItem {

 int get id;@JsonKey(name: 'level_id') int get levelId;@JsonKey(name: 'subject_name') String get subjectName; String? get description;@JsonKey(name: 'link_type') SyllabusLinkType get linkType; String get url;@JsonKey(name: 'sort_order') int get sortOrder;@JsonKey(name: 'is_active') bool get isActive;
/// Create a copy of SyllabusItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyllabusItemCopyWith<SyllabusItem> get copyWith => _$SyllabusItemCopyWithImpl<SyllabusItem>(this as SyllabusItem, _$identity);

  /// Serializes this SyllabusItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyllabusItem&&(identical(other.id, id) || other.id == id)&&(identical(other.levelId, levelId) || other.levelId == levelId)&&(identical(other.subjectName, subjectName) || other.subjectName == subjectName)&&(identical(other.description, description) || other.description == description)&&(identical(other.linkType, linkType) || other.linkType == linkType)&&(identical(other.url, url) || other.url == url)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.isActive, isActive) || other.isActive == isActive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,levelId,subjectName,description,linkType,url,sortOrder,isActive);

@override
String toString() {
  return 'SyllabusItem(id: $id, levelId: $levelId, subjectName: $subjectName, description: $description, linkType: $linkType, url: $url, sortOrder: $sortOrder, isActive: $isActive)';
}


}

/// @nodoc
abstract mixin class $SyllabusItemCopyWith<$Res>  {
  factory $SyllabusItemCopyWith(SyllabusItem value, $Res Function(SyllabusItem) _then) = _$SyllabusItemCopyWithImpl;
@useResult
$Res call({
 int id,@JsonKey(name: 'level_id') int levelId,@JsonKey(name: 'subject_name') String subjectName, String? description,@JsonKey(name: 'link_type') SyllabusLinkType linkType, String url,@JsonKey(name: 'sort_order') int sortOrder,@JsonKey(name: 'is_active') bool isActive
});




}
/// @nodoc
class _$SyllabusItemCopyWithImpl<$Res>
    implements $SyllabusItemCopyWith<$Res> {
  _$SyllabusItemCopyWithImpl(this._self, this._then);

  final SyllabusItem _self;
  final $Res Function(SyllabusItem) _then;

/// Create a copy of SyllabusItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? levelId = null,Object? subjectName = null,Object? description = freezed,Object? linkType = null,Object? url = null,Object? sortOrder = null,Object? isActive = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,levelId: null == levelId ? _self.levelId : levelId // ignore: cast_nullable_to_non_nullable
as int,subjectName: null == subjectName ? _self.subjectName : subjectName // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,linkType: null == linkType ? _self.linkType : linkType // ignore: cast_nullable_to_non_nullable
as SyllabusLinkType,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SyllabusItem].
extension SyllabusItemPatterns on SyllabusItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SyllabusItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SyllabusItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SyllabusItem value)  $default,){
final _that = this;
switch (_that) {
case _SyllabusItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SyllabusItem value)?  $default,){
final _that = this;
switch (_that) {
case _SyllabusItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'level_id')  int levelId, @JsonKey(name: 'subject_name')  String subjectName,  String? description, @JsonKey(name: 'link_type')  SyllabusLinkType linkType,  String url, @JsonKey(name: 'sort_order')  int sortOrder, @JsonKey(name: 'is_active')  bool isActive)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SyllabusItem() when $default != null:
return $default(_that.id,_that.levelId,_that.subjectName,_that.description,_that.linkType,_that.url,_that.sortOrder,_that.isActive);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'level_id')  int levelId, @JsonKey(name: 'subject_name')  String subjectName,  String? description, @JsonKey(name: 'link_type')  SyllabusLinkType linkType,  String url, @JsonKey(name: 'sort_order')  int sortOrder, @JsonKey(name: 'is_active')  bool isActive)  $default,) {final _that = this;
switch (_that) {
case _SyllabusItem():
return $default(_that.id,_that.levelId,_that.subjectName,_that.description,_that.linkType,_that.url,_that.sortOrder,_that.isActive);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id, @JsonKey(name: 'level_id')  int levelId, @JsonKey(name: 'subject_name')  String subjectName,  String? description, @JsonKey(name: 'link_type')  SyllabusLinkType linkType,  String url, @JsonKey(name: 'sort_order')  int sortOrder, @JsonKey(name: 'is_active')  bool isActive)?  $default,) {final _that = this;
switch (_that) {
case _SyllabusItem() when $default != null:
return $default(_that.id,_that.levelId,_that.subjectName,_that.description,_that.linkType,_that.url,_that.sortOrder,_that.isActive);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SyllabusItem implements SyllabusItem {
  const _SyllabusItem({required this.id, @JsonKey(name: 'level_id') required this.levelId, @JsonKey(name: 'subject_name') required this.subjectName, this.description, @JsonKey(name: 'link_type') this.linkType = SyllabusLinkType.pdf, required this.url, @JsonKey(name: 'sort_order') this.sortOrder = 0, @JsonKey(name: 'is_active') this.isActive = true});
  factory _SyllabusItem.fromJson(Map<String, dynamic> json) => _$SyllabusItemFromJson(json);

@override final  int id;
@override@JsonKey(name: 'level_id') final  int levelId;
@override@JsonKey(name: 'subject_name') final  String subjectName;
@override final  String? description;
@override@JsonKey(name: 'link_type') final  SyllabusLinkType linkType;
@override final  String url;
@override@JsonKey(name: 'sort_order') final  int sortOrder;
@override@JsonKey(name: 'is_active') final  bool isActive;

/// Create a copy of SyllabusItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SyllabusItemCopyWith<_SyllabusItem> get copyWith => __$SyllabusItemCopyWithImpl<_SyllabusItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyllabusItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SyllabusItem&&(identical(other.id, id) || other.id == id)&&(identical(other.levelId, levelId) || other.levelId == levelId)&&(identical(other.subjectName, subjectName) || other.subjectName == subjectName)&&(identical(other.description, description) || other.description == description)&&(identical(other.linkType, linkType) || other.linkType == linkType)&&(identical(other.url, url) || other.url == url)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.isActive, isActive) || other.isActive == isActive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,levelId,subjectName,description,linkType,url,sortOrder,isActive);

@override
String toString() {
  return 'SyllabusItem(id: $id, levelId: $levelId, subjectName: $subjectName, description: $description, linkType: $linkType, url: $url, sortOrder: $sortOrder, isActive: $isActive)';
}


}

/// @nodoc
abstract mixin class _$SyllabusItemCopyWith<$Res> implements $SyllabusItemCopyWith<$Res> {
  factory _$SyllabusItemCopyWith(_SyllabusItem value, $Res Function(_SyllabusItem) _then) = __$SyllabusItemCopyWithImpl;
@override @useResult
$Res call({
 int id,@JsonKey(name: 'level_id') int levelId,@JsonKey(name: 'subject_name') String subjectName, String? description,@JsonKey(name: 'link_type') SyllabusLinkType linkType, String url,@JsonKey(name: 'sort_order') int sortOrder,@JsonKey(name: 'is_active') bool isActive
});




}
/// @nodoc
class __$SyllabusItemCopyWithImpl<$Res>
    implements _$SyllabusItemCopyWith<$Res> {
  __$SyllabusItemCopyWithImpl(this._self, this._then);

  final _SyllabusItem _self;
  final $Res Function(_SyllabusItem) _then;

/// Create a copy of SyllabusItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? levelId = null,Object? subjectName = null,Object? description = freezed,Object? linkType = null,Object? url = null,Object? sortOrder = null,Object? isActive = null,}) {
  return _then(_SyllabusItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,levelId: null == levelId ? _self.levelId : levelId // ignore: cast_nullable_to_non_nullable
as int,subjectName: null == subjectName ? _self.subjectName : subjectName // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,linkType: null == linkType ? _self.linkType : linkType // ignore: cast_nullable_to_non_nullable
as SyllabusLinkType,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$SyllabusLevel {

@JsonKey(name: 'level_id') int get levelId;@JsonKey(name: 'level_name') String get levelName;@JsonKey(name: 'level_code') String get levelCode; List<SyllabusItem> get items;
/// Create a copy of SyllabusLevel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyllabusLevelCopyWith<SyllabusLevel> get copyWith => _$SyllabusLevelCopyWithImpl<SyllabusLevel>(this as SyllabusLevel, _$identity);

  /// Serializes this SyllabusLevel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyllabusLevel&&(identical(other.levelId, levelId) || other.levelId == levelId)&&(identical(other.levelName, levelName) || other.levelName == levelName)&&(identical(other.levelCode, levelCode) || other.levelCode == levelCode)&&const DeepCollectionEquality().equals(other.items, items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,levelId,levelName,levelCode,const DeepCollectionEquality().hash(items));

@override
String toString() {
  return 'SyllabusLevel(levelId: $levelId, levelName: $levelName, levelCode: $levelCode, items: $items)';
}


}

/// @nodoc
abstract mixin class $SyllabusLevelCopyWith<$Res>  {
  factory $SyllabusLevelCopyWith(SyllabusLevel value, $Res Function(SyllabusLevel) _then) = _$SyllabusLevelCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'level_id') int levelId,@JsonKey(name: 'level_name') String levelName,@JsonKey(name: 'level_code') String levelCode, List<SyllabusItem> items
});




}
/// @nodoc
class _$SyllabusLevelCopyWithImpl<$Res>
    implements $SyllabusLevelCopyWith<$Res> {
  _$SyllabusLevelCopyWithImpl(this._self, this._then);

  final SyllabusLevel _self;
  final $Res Function(SyllabusLevel) _then;

/// Create a copy of SyllabusLevel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? levelId = null,Object? levelName = null,Object? levelCode = null,Object? items = null,}) {
  return _then(_self.copyWith(
levelId: null == levelId ? _self.levelId : levelId // ignore: cast_nullable_to_non_nullable
as int,levelName: null == levelName ? _self.levelName : levelName // ignore: cast_nullable_to_non_nullable
as String,levelCode: null == levelCode ? _self.levelCode : levelCode // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<SyllabusItem>,
  ));
}

}


/// Adds pattern-matching-related methods to [SyllabusLevel].
extension SyllabusLevelPatterns on SyllabusLevel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SyllabusLevel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SyllabusLevel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SyllabusLevel value)  $default,){
final _that = this;
switch (_that) {
case _SyllabusLevel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SyllabusLevel value)?  $default,){
final _that = this;
switch (_that) {
case _SyllabusLevel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'level_id')  int levelId, @JsonKey(name: 'level_name')  String levelName, @JsonKey(name: 'level_code')  String levelCode,  List<SyllabusItem> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SyllabusLevel() when $default != null:
return $default(_that.levelId,_that.levelName,_that.levelCode,_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'level_id')  int levelId, @JsonKey(name: 'level_name')  String levelName, @JsonKey(name: 'level_code')  String levelCode,  List<SyllabusItem> items)  $default,) {final _that = this;
switch (_that) {
case _SyllabusLevel():
return $default(_that.levelId,_that.levelName,_that.levelCode,_that.items);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'level_id')  int levelId, @JsonKey(name: 'level_name')  String levelName, @JsonKey(name: 'level_code')  String levelCode,  List<SyllabusItem> items)?  $default,) {final _that = this;
switch (_that) {
case _SyllabusLevel() when $default != null:
return $default(_that.levelId,_that.levelName,_that.levelCode,_that.items);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SyllabusLevel implements SyllabusLevel {
  const _SyllabusLevel({@JsonKey(name: 'level_id') required this.levelId, @JsonKey(name: 'level_name') required this.levelName, @JsonKey(name: 'level_code') required this.levelCode, final  List<SyllabusItem> items = const []}): _items = items;
  factory _SyllabusLevel.fromJson(Map<String, dynamic> json) => _$SyllabusLevelFromJson(json);

@override@JsonKey(name: 'level_id') final  int levelId;
@override@JsonKey(name: 'level_name') final  String levelName;
@override@JsonKey(name: 'level_code') final  String levelCode;
 final  List<SyllabusItem> _items;
@override@JsonKey() List<SyllabusItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of SyllabusLevel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SyllabusLevelCopyWith<_SyllabusLevel> get copyWith => __$SyllabusLevelCopyWithImpl<_SyllabusLevel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyllabusLevelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SyllabusLevel&&(identical(other.levelId, levelId) || other.levelId == levelId)&&(identical(other.levelName, levelName) || other.levelName == levelName)&&(identical(other.levelCode, levelCode) || other.levelCode == levelCode)&&const DeepCollectionEquality().equals(other._items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,levelId,levelName,levelCode,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'SyllabusLevel(levelId: $levelId, levelName: $levelName, levelCode: $levelCode, items: $items)';
}


}

/// @nodoc
abstract mixin class _$SyllabusLevelCopyWith<$Res> implements $SyllabusLevelCopyWith<$Res> {
  factory _$SyllabusLevelCopyWith(_SyllabusLevel value, $Res Function(_SyllabusLevel) _then) = __$SyllabusLevelCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'level_id') int levelId,@JsonKey(name: 'level_name') String levelName,@JsonKey(name: 'level_code') String levelCode, List<SyllabusItem> items
});




}
/// @nodoc
class __$SyllabusLevelCopyWithImpl<$Res>
    implements _$SyllabusLevelCopyWith<$Res> {
  __$SyllabusLevelCopyWithImpl(this._self, this._then);

  final _SyllabusLevel _self;
  final $Res Function(_SyllabusLevel) _then;

/// Create a copy of SyllabusLevel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? levelId = null,Object? levelName = null,Object? levelCode = null,Object? items = null,}) {
  return _then(_SyllabusLevel(
levelId: null == levelId ? _self.levelId : levelId // ignore: cast_nullable_to_non_nullable
as int,levelName: null == levelName ? _self.levelName : levelName // ignore: cast_nullable_to_non_nullable
as String,levelCode: null == levelCode ? _self.levelCode : levelCode // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<SyllabusItem>,
  ));
}


}


/// @nodoc
mixin _$ClassLevel {

 int get id; String get code; String get name;@JsonKey(name: 'sort_order') int get sortOrder;
/// Create a copy of ClassLevel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClassLevelCopyWith<ClassLevel> get copyWith => _$ClassLevelCopyWithImpl<ClassLevel>(this as ClassLevel, _$identity);

  /// Serializes this ClassLevel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClassLevel&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,code,name,sortOrder);

@override
String toString() {
  return 'ClassLevel(id: $id, code: $code, name: $name, sortOrder: $sortOrder)';
}


}

/// @nodoc
abstract mixin class $ClassLevelCopyWith<$Res>  {
  factory $ClassLevelCopyWith(ClassLevel value, $Res Function(ClassLevel) _then) = _$ClassLevelCopyWithImpl;
@useResult
$Res call({
 int id, String code, String name,@JsonKey(name: 'sort_order') int sortOrder
});




}
/// @nodoc
class _$ClassLevelCopyWithImpl<$Res>
    implements $ClassLevelCopyWith<$Res> {
  _$ClassLevelCopyWithImpl(this._self, this._then);

  final ClassLevel _self;
  final $Res Function(ClassLevel) _then;

/// Create a copy of ClassLevel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? code = null,Object? name = null,Object? sortOrder = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ClassLevel].
extension ClassLevelPatterns on ClassLevel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClassLevel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClassLevel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClassLevel value)  $default,){
final _that = this;
switch (_that) {
case _ClassLevel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClassLevel value)?  $default,){
final _that = this;
switch (_that) {
case _ClassLevel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String code,  String name, @JsonKey(name: 'sort_order')  int sortOrder)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClassLevel() when $default != null:
return $default(_that.id,_that.code,_that.name,_that.sortOrder);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String code,  String name, @JsonKey(name: 'sort_order')  int sortOrder)  $default,) {final _that = this;
switch (_that) {
case _ClassLevel():
return $default(_that.id,_that.code,_that.name,_that.sortOrder);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String code,  String name, @JsonKey(name: 'sort_order')  int sortOrder)?  $default,) {final _that = this;
switch (_that) {
case _ClassLevel() when $default != null:
return $default(_that.id,_that.code,_that.name,_that.sortOrder);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClassLevel implements ClassLevel {
  const _ClassLevel({required this.id, required this.code, required this.name, @JsonKey(name: 'sort_order') this.sortOrder = 0});
  factory _ClassLevel.fromJson(Map<String, dynamic> json) => _$ClassLevelFromJson(json);

@override final  int id;
@override final  String code;
@override final  String name;
@override@JsonKey(name: 'sort_order') final  int sortOrder;

/// Create a copy of ClassLevel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClassLevelCopyWith<_ClassLevel> get copyWith => __$ClassLevelCopyWithImpl<_ClassLevel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClassLevelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClassLevel&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,code,name,sortOrder);

@override
String toString() {
  return 'ClassLevel(id: $id, code: $code, name: $name, sortOrder: $sortOrder)';
}


}

/// @nodoc
abstract mixin class _$ClassLevelCopyWith<$Res> implements $ClassLevelCopyWith<$Res> {
  factory _$ClassLevelCopyWith(_ClassLevel value, $Res Function(_ClassLevel) _then) = __$ClassLevelCopyWithImpl;
@override @useResult
$Res call({
 int id, String code, String name,@JsonKey(name: 'sort_order') int sortOrder
});




}
/// @nodoc
class __$ClassLevelCopyWithImpl<$Res>
    implements _$ClassLevelCopyWith<$Res> {
  __$ClassLevelCopyWithImpl(this._self, this._then);

  final _ClassLevel _self;
  final $Res Function(_ClassLevel) _then;

/// Create a copy of ClassLevel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? code = null,Object? name = null,Object? sortOrder = null,}) {
  return _then(_ClassLevel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$SyllabusDownloadState {

 int get syllabusId; SyllabusDownloadStatus get status; String? get localPath; String? get errorMessage; double get progress;
/// Create a copy of SyllabusDownloadState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyllabusDownloadStateCopyWith<SyllabusDownloadState> get copyWith => _$SyllabusDownloadStateCopyWithImpl<SyllabusDownloadState>(this as SyllabusDownloadState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyllabusDownloadState&&(identical(other.syllabusId, syllabusId) || other.syllabusId == syllabusId)&&(identical(other.status, status) || other.status == status)&&(identical(other.localPath, localPath) || other.localPath == localPath)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.progress, progress) || other.progress == progress));
}


@override
int get hashCode => Object.hash(runtimeType,syllabusId,status,localPath,errorMessage,progress);

@override
String toString() {
  return 'SyllabusDownloadState(syllabusId: $syllabusId, status: $status, localPath: $localPath, errorMessage: $errorMessage, progress: $progress)';
}


}

/// @nodoc
abstract mixin class $SyllabusDownloadStateCopyWith<$Res>  {
  factory $SyllabusDownloadStateCopyWith(SyllabusDownloadState value, $Res Function(SyllabusDownloadState) _then) = _$SyllabusDownloadStateCopyWithImpl;
@useResult
$Res call({
 int syllabusId, SyllabusDownloadStatus status, String? localPath, String? errorMessage, double progress
});




}
/// @nodoc
class _$SyllabusDownloadStateCopyWithImpl<$Res>
    implements $SyllabusDownloadStateCopyWith<$Res> {
  _$SyllabusDownloadStateCopyWithImpl(this._self, this._then);

  final SyllabusDownloadState _self;
  final $Res Function(SyllabusDownloadState) _then;

/// Create a copy of SyllabusDownloadState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? syllabusId = null,Object? status = null,Object? localPath = freezed,Object? errorMessage = freezed,Object? progress = null,}) {
  return _then(_self.copyWith(
syllabusId: null == syllabusId ? _self.syllabusId : syllabusId // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SyllabusDownloadStatus,localPath: freezed == localPath ? _self.localPath : localPath // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [SyllabusDownloadState].
extension SyllabusDownloadStatePatterns on SyllabusDownloadState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SyllabusDownloadState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SyllabusDownloadState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SyllabusDownloadState value)  $default,){
final _that = this;
switch (_that) {
case _SyllabusDownloadState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SyllabusDownloadState value)?  $default,){
final _that = this;
switch (_that) {
case _SyllabusDownloadState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int syllabusId,  SyllabusDownloadStatus status,  String? localPath,  String? errorMessage,  double progress)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SyllabusDownloadState() when $default != null:
return $default(_that.syllabusId,_that.status,_that.localPath,_that.errorMessage,_that.progress);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int syllabusId,  SyllabusDownloadStatus status,  String? localPath,  String? errorMessage,  double progress)  $default,) {final _that = this;
switch (_that) {
case _SyllabusDownloadState():
return $default(_that.syllabusId,_that.status,_that.localPath,_that.errorMessage,_that.progress);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int syllabusId,  SyllabusDownloadStatus status,  String? localPath,  String? errorMessage,  double progress)?  $default,) {final _that = this;
switch (_that) {
case _SyllabusDownloadState() when $default != null:
return $default(_that.syllabusId,_that.status,_that.localPath,_that.errorMessage,_that.progress);case _:
  return null;

}
}

}

/// @nodoc


class _SyllabusDownloadState implements SyllabusDownloadState {
  const _SyllabusDownloadState({required this.syllabusId, this.status = SyllabusDownloadStatus.notDownloaded, this.localPath, this.errorMessage, this.progress = 0.0});
  

@override final  int syllabusId;
@override@JsonKey() final  SyllabusDownloadStatus status;
@override final  String? localPath;
@override final  String? errorMessage;
@override@JsonKey() final  double progress;

/// Create a copy of SyllabusDownloadState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SyllabusDownloadStateCopyWith<_SyllabusDownloadState> get copyWith => __$SyllabusDownloadStateCopyWithImpl<_SyllabusDownloadState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SyllabusDownloadState&&(identical(other.syllabusId, syllabusId) || other.syllabusId == syllabusId)&&(identical(other.status, status) || other.status == status)&&(identical(other.localPath, localPath) || other.localPath == localPath)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.progress, progress) || other.progress == progress));
}


@override
int get hashCode => Object.hash(runtimeType,syllabusId,status,localPath,errorMessage,progress);

@override
String toString() {
  return 'SyllabusDownloadState(syllabusId: $syllabusId, status: $status, localPath: $localPath, errorMessage: $errorMessage, progress: $progress)';
}


}

/// @nodoc
abstract mixin class _$SyllabusDownloadStateCopyWith<$Res> implements $SyllabusDownloadStateCopyWith<$Res> {
  factory _$SyllabusDownloadStateCopyWith(_SyllabusDownloadState value, $Res Function(_SyllabusDownloadState) _then) = __$SyllabusDownloadStateCopyWithImpl;
@override @useResult
$Res call({
 int syllabusId, SyllabusDownloadStatus status, String? localPath, String? errorMessage, double progress
});




}
/// @nodoc
class __$SyllabusDownloadStateCopyWithImpl<$Res>
    implements _$SyllabusDownloadStateCopyWith<$Res> {
  __$SyllabusDownloadStateCopyWithImpl(this._self, this._then);

  final _SyllabusDownloadState _self;
  final $Res Function(_SyllabusDownloadState) _then;

/// Create a copy of SyllabusDownloadState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? syllabusId = null,Object? status = null,Object? localPath = freezed,Object? errorMessage = freezed,Object? progress = null,}) {
  return _then(_SyllabusDownloadState(
syllabusId: null == syllabusId ? _self.syllabusId : syllabusId // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SyllabusDownloadStatus,localPath: freezed == localPath ? _self.localPath : localPath // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
