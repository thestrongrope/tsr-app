// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'publication.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Publication {

 String get title; String? get summary; String? get type; String? get size; String? get updated; String? get language; String? get file; String? get readOnlineUrl;
/// Create a copy of Publication
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PublicationCopyWith<Publication> get copyWith => _$PublicationCopyWithImpl<Publication>(this as Publication, _$identity);

  /// Serializes this Publication to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Publication&&(identical(other.title, title) || other.title == title)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.type, type) || other.type == type)&&(identical(other.size, size) || other.size == size)&&(identical(other.updated, updated) || other.updated == updated)&&(identical(other.language, language) || other.language == language)&&(identical(other.file, file) || other.file == file)&&(identical(other.readOnlineUrl, readOnlineUrl) || other.readOnlineUrl == readOnlineUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,summary,type,size,updated,language,file,readOnlineUrl);

@override
String toString() {
  return 'Publication(title: $title, summary: $summary, type: $type, size: $size, updated: $updated, language: $language, file: $file, readOnlineUrl: $readOnlineUrl)';
}


}

/// @nodoc
abstract mixin class $PublicationCopyWith<$Res>  {
  factory $PublicationCopyWith(Publication value, $Res Function(Publication) _then) = _$PublicationCopyWithImpl;
@useResult
$Res call({
 String title, String? summary, String? type, String? size, String? updated, String? language, String? file, String? readOnlineUrl
});




}
/// @nodoc
class _$PublicationCopyWithImpl<$Res>
    implements $PublicationCopyWith<$Res> {
  _$PublicationCopyWithImpl(this._self, this._then);

  final Publication _self;
  final $Res Function(Publication) _then;

/// Create a copy of Publication
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? summary = freezed,Object? type = freezed,Object? size = freezed,Object? updated = freezed,Object? language = freezed,Object? file = freezed,Object? readOnlineUrl = freezed,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as String?,updated: freezed == updated ? _self.updated : updated // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,file: freezed == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String?,readOnlineUrl: freezed == readOnlineUrl ? _self.readOnlineUrl : readOnlineUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Publication].
extension PublicationPatterns on Publication {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Publication value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Publication() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Publication value)  $default,){
final _that = this;
switch (_that) {
case _Publication():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Publication value)?  $default,){
final _that = this;
switch (_that) {
case _Publication() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  String? summary,  String? type,  String? size,  String? updated,  String? language,  String? file,  String? readOnlineUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Publication() when $default != null:
return $default(_that.title,_that.summary,_that.type,_that.size,_that.updated,_that.language,_that.file,_that.readOnlineUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  String? summary,  String? type,  String? size,  String? updated,  String? language,  String? file,  String? readOnlineUrl)  $default,) {final _that = this;
switch (_that) {
case _Publication():
return $default(_that.title,_that.summary,_that.type,_that.size,_that.updated,_that.language,_that.file,_that.readOnlineUrl);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  String? summary,  String? type,  String? size,  String? updated,  String? language,  String? file,  String? readOnlineUrl)?  $default,) {final _that = this;
switch (_that) {
case _Publication() when $default != null:
return $default(_that.title,_that.summary,_that.type,_that.size,_that.updated,_that.language,_that.file,_that.readOnlineUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Publication extends Publication {
  const _Publication({required this.title, this.summary, this.type, this.size, this.updated, this.language, this.file, this.readOnlineUrl}): super._();
  factory _Publication.fromJson(Map<String, dynamic> json) => _$PublicationFromJson(json);

@override final  String title;
@override final  String? summary;
@override final  String? type;
@override final  String? size;
@override final  String? updated;
@override final  String? language;
@override final  String? file;
@override final  String? readOnlineUrl;

/// Create a copy of Publication
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PublicationCopyWith<_Publication> get copyWith => __$PublicationCopyWithImpl<_Publication>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PublicationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Publication&&(identical(other.title, title) || other.title == title)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.type, type) || other.type == type)&&(identical(other.size, size) || other.size == size)&&(identical(other.updated, updated) || other.updated == updated)&&(identical(other.language, language) || other.language == language)&&(identical(other.file, file) || other.file == file)&&(identical(other.readOnlineUrl, readOnlineUrl) || other.readOnlineUrl == readOnlineUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,summary,type,size,updated,language,file,readOnlineUrl);

@override
String toString() {
  return 'Publication(title: $title, summary: $summary, type: $type, size: $size, updated: $updated, language: $language, file: $file, readOnlineUrl: $readOnlineUrl)';
}


}

/// @nodoc
abstract mixin class _$PublicationCopyWith<$Res> implements $PublicationCopyWith<$Res> {
  factory _$PublicationCopyWith(_Publication value, $Res Function(_Publication) _then) = __$PublicationCopyWithImpl;
@override @useResult
$Res call({
 String title, String? summary, String? type, String? size, String? updated, String? language, String? file, String? readOnlineUrl
});




}
/// @nodoc
class __$PublicationCopyWithImpl<$Res>
    implements _$PublicationCopyWith<$Res> {
  __$PublicationCopyWithImpl(this._self, this._then);

  final _Publication _self;
  final $Res Function(_Publication) _then;

/// Create a copy of Publication
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? summary = freezed,Object? type = freezed,Object? size = freezed,Object? updated = freezed,Object? language = freezed,Object? file = freezed,Object? readOnlineUrl = freezed,}) {
  return _then(_Publication(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as String?,updated: freezed == updated ? _self.updated : updated // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,file: freezed == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String?,readOnlineUrl: freezed == readOnlineUrl ? _self.readOnlineUrl : readOnlineUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
