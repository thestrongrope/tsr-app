// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tsr_article.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TsrArticle {

 int get id; String get slug;// Same encoding as the video title, and rendered raw at
// all_articles_screen.dart:824. `content` is deliberately untouched below:
// it is HTML by design and decoding it would corrupt the markup.
@JsonKey(fromJson: decodeHtmlEntities) String get title; String get content;// HTML content (only in detail view)
 String get excerpt; String? get publishedDate; String? get modifiedDate; List<String> get categories;// Changed from category to categories (array)
 List<String> get tags; String? get author; String? get language; int get readingTime; bool get featured;
/// Create a copy of TsrArticle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TsrArticleCopyWith<TsrArticle> get copyWith => _$TsrArticleCopyWithImpl<TsrArticle>(this as TsrArticle, _$identity);

  /// Serializes this TsrArticle to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TsrArticle&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.title, title) || other.title == title)&&(identical(other.content, content) || other.content == content)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt)&&(identical(other.publishedDate, publishedDate) || other.publishedDate == publishedDate)&&(identical(other.modifiedDate, modifiedDate) || other.modifiedDate == modifiedDate)&&const DeepCollectionEquality().equals(other.categories, categories)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.author, author) || other.author == author)&&(identical(other.language, language) || other.language == language)&&(identical(other.readingTime, readingTime) || other.readingTime == readingTime)&&(identical(other.featured, featured) || other.featured == featured));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,slug,title,content,excerpt,publishedDate,modifiedDate,const DeepCollectionEquality().hash(categories),const DeepCollectionEquality().hash(tags),author,language,readingTime,featured);

@override
String toString() {
  return 'TsrArticle(id: $id, slug: $slug, title: $title, content: $content, excerpt: $excerpt, publishedDate: $publishedDate, modifiedDate: $modifiedDate, categories: $categories, tags: $tags, author: $author, language: $language, readingTime: $readingTime, featured: $featured)';
}


}

/// @nodoc
abstract mixin class $TsrArticleCopyWith<$Res>  {
  factory $TsrArticleCopyWith(TsrArticle value, $Res Function(TsrArticle) _then) = _$TsrArticleCopyWithImpl;
@useResult
$Res call({
 int id, String slug,@JsonKey(fromJson: decodeHtmlEntities) String title, String content, String excerpt, String? publishedDate, String? modifiedDate, List<String> categories, List<String> tags, String? author, String? language, int readingTime, bool featured
});




}
/// @nodoc
class _$TsrArticleCopyWithImpl<$Res>
    implements $TsrArticleCopyWith<$Res> {
  _$TsrArticleCopyWithImpl(this._self, this._then);

  final TsrArticle _self;
  final $Res Function(TsrArticle) _then;

/// Create a copy of TsrArticle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? slug = null,Object? title = null,Object? content = null,Object? excerpt = null,Object? publishedDate = freezed,Object? modifiedDate = freezed,Object? categories = null,Object? tags = null,Object? author = freezed,Object? language = freezed,Object? readingTime = null,Object? featured = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,excerpt: null == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String,publishedDate: freezed == publishedDate ? _self.publishedDate : publishedDate // ignore: cast_nullable_to_non_nullable
as String?,modifiedDate: freezed == modifiedDate ? _self.modifiedDate : modifiedDate // ignore: cast_nullable_to_non_nullable
as String?,categories: null == categories ? _self.categories : categories // ignore: cast_nullable_to_non_nullable
as List<String>,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,readingTime: null == readingTime ? _self.readingTime : readingTime // ignore: cast_nullable_to_non_nullable
as int,featured: null == featured ? _self.featured : featured // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TsrArticle].
extension TsrArticlePatterns on TsrArticle {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TsrArticle value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TsrArticle() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TsrArticle value)  $default,){
final _that = this;
switch (_that) {
case _TsrArticle():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TsrArticle value)?  $default,){
final _that = this;
switch (_that) {
case _TsrArticle() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String slug, @JsonKey(fromJson: decodeHtmlEntities)  String title,  String content,  String excerpt,  String? publishedDate,  String? modifiedDate,  List<String> categories,  List<String> tags,  String? author,  String? language,  int readingTime,  bool featured)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TsrArticle() when $default != null:
return $default(_that.id,_that.slug,_that.title,_that.content,_that.excerpt,_that.publishedDate,_that.modifiedDate,_that.categories,_that.tags,_that.author,_that.language,_that.readingTime,_that.featured);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String slug, @JsonKey(fromJson: decodeHtmlEntities)  String title,  String content,  String excerpt,  String? publishedDate,  String? modifiedDate,  List<String> categories,  List<String> tags,  String? author,  String? language,  int readingTime,  bool featured)  $default,) {final _that = this;
switch (_that) {
case _TsrArticle():
return $default(_that.id,_that.slug,_that.title,_that.content,_that.excerpt,_that.publishedDate,_that.modifiedDate,_that.categories,_that.tags,_that.author,_that.language,_that.readingTime,_that.featured);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String slug, @JsonKey(fromJson: decodeHtmlEntities)  String title,  String content,  String excerpt,  String? publishedDate,  String? modifiedDate,  List<String> categories,  List<String> tags,  String? author,  String? language,  int readingTime,  bool featured)?  $default,) {final _that = this;
switch (_that) {
case _TsrArticle() when $default != null:
return $default(_that.id,_that.slug,_that.title,_that.content,_that.excerpt,_that.publishedDate,_that.modifiedDate,_that.categories,_that.tags,_that.author,_that.language,_that.readingTime,_that.featured);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TsrArticle implements TsrArticle {
  const _TsrArticle({this.id = 0, required this.slug, @JsonKey(fromJson: decodeHtmlEntities) required this.title, this.content = '', this.excerpt = '', this.publishedDate, this.modifiedDate, final  List<String> categories = const [], final  List<String> tags = const [], this.author, this.language, this.readingTime = 1, this.featured = false}): _categories = categories,_tags = tags;
  factory _TsrArticle.fromJson(Map<String, dynamic> json) => _$TsrArticleFromJson(json);

@override@JsonKey() final  int id;
@override final  String slug;
// Same encoding as the video title, and rendered raw at
// all_articles_screen.dart:824. `content` is deliberately untouched below:
// it is HTML by design and decoding it would corrupt the markup.
@override@JsonKey(fromJson: decodeHtmlEntities) final  String title;
@override@JsonKey() final  String content;
// HTML content (only in detail view)
@override@JsonKey() final  String excerpt;
@override final  String? publishedDate;
@override final  String? modifiedDate;
 final  List<String> _categories;
@override@JsonKey() List<String> get categories {
  if (_categories is EqualUnmodifiableListView) return _categories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_categories);
}

// Changed from category to categories (array)
 final  List<String> _tags;
// Changed from category to categories (array)
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

@override final  String? author;
@override final  String? language;
@override@JsonKey() final  int readingTime;
@override@JsonKey() final  bool featured;

/// Create a copy of TsrArticle
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TsrArticleCopyWith<_TsrArticle> get copyWith => __$TsrArticleCopyWithImpl<_TsrArticle>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TsrArticleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TsrArticle&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.title, title) || other.title == title)&&(identical(other.content, content) || other.content == content)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt)&&(identical(other.publishedDate, publishedDate) || other.publishedDate == publishedDate)&&(identical(other.modifiedDate, modifiedDate) || other.modifiedDate == modifiedDate)&&const DeepCollectionEquality().equals(other._categories, _categories)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.author, author) || other.author == author)&&(identical(other.language, language) || other.language == language)&&(identical(other.readingTime, readingTime) || other.readingTime == readingTime)&&(identical(other.featured, featured) || other.featured == featured));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,slug,title,content,excerpt,publishedDate,modifiedDate,const DeepCollectionEquality().hash(_categories),const DeepCollectionEquality().hash(_tags),author,language,readingTime,featured);

@override
String toString() {
  return 'TsrArticle(id: $id, slug: $slug, title: $title, content: $content, excerpt: $excerpt, publishedDate: $publishedDate, modifiedDate: $modifiedDate, categories: $categories, tags: $tags, author: $author, language: $language, readingTime: $readingTime, featured: $featured)';
}


}

/// @nodoc
abstract mixin class _$TsrArticleCopyWith<$Res> implements $TsrArticleCopyWith<$Res> {
  factory _$TsrArticleCopyWith(_TsrArticle value, $Res Function(_TsrArticle) _then) = __$TsrArticleCopyWithImpl;
@override @useResult
$Res call({
 int id, String slug,@JsonKey(fromJson: decodeHtmlEntities) String title, String content, String excerpt, String? publishedDate, String? modifiedDate, List<String> categories, List<String> tags, String? author, String? language, int readingTime, bool featured
});




}
/// @nodoc
class __$TsrArticleCopyWithImpl<$Res>
    implements _$TsrArticleCopyWith<$Res> {
  __$TsrArticleCopyWithImpl(this._self, this._then);

  final _TsrArticle _self;
  final $Res Function(_TsrArticle) _then;

/// Create a copy of TsrArticle
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? slug = null,Object? title = null,Object? content = null,Object? excerpt = null,Object? publishedDate = freezed,Object? modifiedDate = freezed,Object? categories = null,Object? tags = null,Object? author = freezed,Object? language = freezed,Object? readingTime = null,Object? featured = null,}) {
  return _then(_TsrArticle(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,excerpt: null == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String,publishedDate: freezed == publishedDate ? _self.publishedDate : publishedDate // ignore: cast_nullable_to_non_nullable
as String?,modifiedDate: freezed == modifiedDate ? _self.modifiedDate : modifiedDate // ignore: cast_nullable_to_non_nullable
as String?,categories: null == categories ? _self._categories : categories // ignore: cast_nullable_to_non_nullable
as List<String>,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,readingTime: null == readingTime ? _self.readingTime : readingTime // ignore: cast_nullable_to_non_nullable
as int,featured: null == featured ? _self.featured : featured // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$TsrCategory {

 String get slug; String get title; String? get description; int get articleCount; List<TsrCategory> get subcategories;
/// Create a copy of TsrCategory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TsrCategoryCopyWith<TsrCategory> get copyWith => _$TsrCategoryCopyWithImpl<TsrCategory>(this as TsrCategory, _$identity);

  /// Serializes this TsrCategory to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TsrCategory&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.articleCount, articleCount) || other.articleCount == articleCount)&&const DeepCollectionEquality().equals(other.subcategories, subcategories));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,slug,title,description,articleCount,const DeepCollectionEquality().hash(subcategories));

@override
String toString() {
  return 'TsrCategory(slug: $slug, title: $title, description: $description, articleCount: $articleCount, subcategories: $subcategories)';
}


}

/// @nodoc
abstract mixin class $TsrCategoryCopyWith<$Res>  {
  factory $TsrCategoryCopyWith(TsrCategory value, $Res Function(TsrCategory) _then) = _$TsrCategoryCopyWithImpl;
@useResult
$Res call({
 String slug, String title, String? description, int articleCount, List<TsrCategory> subcategories
});




}
/// @nodoc
class _$TsrCategoryCopyWithImpl<$Res>
    implements $TsrCategoryCopyWith<$Res> {
  _$TsrCategoryCopyWithImpl(this._self, this._then);

  final TsrCategory _self;
  final $Res Function(TsrCategory) _then;

/// Create a copy of TsrCategory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? slug = null,Object? title = null,Object? description = freezed,Object? articleCount = null,Object? subcategories = null,}) {
  return _then(_self.copyWith(
slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,articleCount: null == articleCount ? _self.articleCount : articleCount // ignore: cast_nullable_to_non_nullable
as int,subcategories: null == subcategories ? _self.subcategories : subcategories // ignore: cast_nullable_to_non_nullable
as List<TsrCategory>,
  ));
}

}


/// Adds pattern-matching-related methods to [TsrCategory].
extension TsrCategoryPatterns on TsrCategory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TsrCategory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TsrCategory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TsrCategory value)  $default,){
final _that = this;
switch (_that) {
case _TsrCategory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TsrCategory value)?  $default,){
final _that = this;
switch (_that) {
case _TsrCategory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String slug,  String title,  String? description,  int articleCount,  List<TsrCategory> subcategories)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TsrCategory() when $default != null:
return $default(_that.slug,_that.title,_that.description,_that.articleCount,_that.subcategories);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String slug,  String title,  String? description,  int articleCount,  List<TsrCategory> subcategories)  $default,) {final _that = this;
switch (_that) {
case _TsrCategory():
return $default(_that.slug,_that.title,_that.description,_that.articleCount,_that.subcategories);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String slug,  String title,  String? description,  int articleCount,  List<TsrCategory> subcategories)?  $default,) {final _that = this;
switch (_that) {
case _TsrCategory() when $default != null:
return $default(_that.slug,_that.title,_that.description,_that.articleCount,_that.subcategories);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TsrCategory implements TsrCategory {
  const _TsrCategory({required this.slug, required this.title, this.description, this.articleCount = 0, final  List<TsrCategory> subcategories = const []}): _subcategories = subcategories;
  factory _TsrCategory.fromJson(Map<String, dynamic> json) => _$TsrCategoryFromJson(json);

@override final  String slug;
@override final  String title;
@override final  String? description;
@override@JsonKey() final  int articleCount;
 final  List<TsrCategory> _subcategories;
@override@JsonKey() List<TsrCategory> get subcategories {
  if (_subcategories is EqualUnmodifiableListView) return _subcategories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_subcategories);
}


/// Create a copy of TsrCategory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TsrCategoryCopyWith<_TsrCategory> get copyWith => __$TsrCategoryCopyWithImpl<_TsrCategory>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TsrCategoryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TsrCategory&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.articleCount, articleCount) || other.articleCount == articleCount)&&const DeepCollectionEquality().equals(other._subcategories, _subcategories));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,slug,title,description,articleCount,const DeepCollectionEquality().hash(_subcategories));

@override
String toString() {
  return 'TsrCategory(slug: $slug, title: $title, description: $description, articleCount: $articleCount, subcategories: $subcategories)';
}


}

/// @nodoc
abstract mixin class _$TsrCategoryCopyWith<$Res> implements $TsrCategoryCopyWith<$Res> {
  factory _$TsrCategoryCopyWith(_TsrCategory value, $Res Function(_TsrCategory) _then) = __$TsrCategoryCopyWithImpl;
@override @useResult
$Res call({
 String slug, String title, String? description, int articleCount, List<TsrCategory> subcategories
});




}
/// @nodoc
class __$TsrCategoryCopyWithImpl<$Res>
    implements _$TsrCategoryCopyWith<$Res> {
  __$TsrCategoryCopyWithImpl(this._self, this._then);

  final _TsrCategory _self;
  final $Res Function(_TsrCategory) _then;

/// Create a copy of TsrCategory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? slug = null,Object? title = null,Object? description = freezed,Object? articleCount = null,Object? subcategories = null,}) {
  return _then(_TsrCategory(
slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,articleCount: null == articleCount ? _self.articleCount : articleCount // ignore: cast_nullable_to_non_nullable
as int,subcategories: null == subcategories ? _self._subcategories : subcategories // ignore: cast_nullable_to_non_nullable
as List<TsrCategory>,
  ));
}


}


/// @nodoc
mixin _$TsrTag {

 String get name; String get slug; int get articleCount;
/// Create a copy of TsrTag
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TsrTagCopyWith<TsrTag> get copyWith => _$TsrTagCopyWithImpl<TsrTag>(this as TsrTag, _$identity);

  /// Serializes this TsrTag to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TsrTag&&(identical(other.name, name) || other.name == name)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.articleCount, articleCount) || other.articleCount == articleCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,slug,articleCount);

@override
String toString() {
  return 'TsrTag(name: $name, slug: $slug, articleCount: $articleCount)';
}


}

/// @nodoc
abstract mixin class $TsrTagCopyWith<$Res>  {
  factory $TsrTagCopyWith(TsrTag value, $Res Function(TsrTag) _then) = _$TsrTagCopyWithImpl;
@useResult
$Res call({
 String name, String slug, int articleCount
});




}
/// @nodoc
class _$TsrTagCopyWithImpl<$Res>
    implements $TsrTagCopyWith<$Res> {
  _$TsrTagCopyWithImpl(this._self, this._then);

  final TsrTag _self;
  final $Res Function(TsrTag) _then;

/// Create a copy of TsrTag
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? slug = null,Object? articleCount = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,articleCount: null == articleCount ? _self.articleCount : articleCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TsrTag].
extension TsrTagPatterns on TsrTag {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TsrTag value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TsrTag() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TsrTag value)  $default,){
final _that = this;
switch (_that) {
case _TsrTag():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TsrTag value)?  $default,){
final _that = this;
switch (_that) {
case _TsrTag() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String slug,  int articleCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TsrTag() when $default != null:
return $default(_that.name,_that.slug,_that.articleCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String slug,  int articleCount)  $default,) {final _that = this;
switch (_that) {
case _TsrTag():
return $default(_that.name,_that.slug,_that.articleCount);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String slug,  int articleCount)?  $default,) {final _that = this;
switch (_that) {
case _TsrTag() when $default != null:
return $default(_that.name,_that.slug,_that.articleCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TsrTag implements TsrTag {
  const _TsrTag({required this.name, required this.slug, this.articleCount = 0});
  factory _TsrTag.fromJson(Map<String, dynamic> json) => _$TsrTagFromJson(json);

@override final  String name;
@override final  String slug;
@override@JsonKey() final  int articleCount;

/// Create a copy of TsrTag
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TsrTagCopyWith<_TsrTag> get copyWith => __$TsrTagCopyWithImpl<_TsrTag>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TsrTagToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TsrTag&&(identical(other.name, name) || other.name == name)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.articleCount, articleCount) || other.articleCount == articleCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,slug,articleCount);

@override
String toString() {
  return 'TsrTag(name: $name, slug: $slug, articleCount: $articleCount)';
}


}

/// @nodoc
abstract mixin class _$TsrTagCopyWith<$Res> implements $TsrTagCopyWith<$Res> {
  factory _$TsrTagCopyWith(_TsrTag value, $Res Function(_TsrTag) _then) = __$TsrTagCopyWithImpl;
@override @useResult
$Res call({
 String name, String slug, int articleCount
});




}
/// @nodoc
class __$TsrTagCopyWithImpl<$Res>
    implements _$TsrTagCopyWith<$Res> {
  __$TsrTagCopyWithImpl(this._self, this._then);

  final _TsrTag _self;
  final $Res Function(_TsrTag) _then;

/// Create a copy of TsrTag
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? slug = null,Object? articleCount = null,}) {
  return _then(_TsrTag(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,articleCount: null == articleCount ? _self.articleCount : articleCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$TsrYouTubeVideo {

 String get id; String get videoId;// Decoded at the boundary rather than at each render site, so that search
// in AllVideosScreen matches what the user can actually see. The API hands
// WordPress's stored encoding straight through.
@JsonKey(fromJson: decodeHtmlEntities) String get title; String get youtubeLink; String? get publishedDate; String? get publishedDateFormatted; int? get views; String? get intro; String? get description; TsrThumbnail? get thumbnail;
/// Create a copy of TsrYouTubeVideo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TsrYouTubeVideoCopyWith<TsrYouTubeVideo> get copyWith => _$TsrYouTubeVideoCopyWithImpl<TsrYouTubeVideo>(this as TsrYouTubeVideo, _$identity);

  /// Serializes this TsrYouTubeVideo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TsrYouTubeVideo&&(identical(other.id, id) || other.id == id)&&(identical(other.videoId, videoId) || other.videoId == videoId)&&(identical(other.title, title) || other.title == title)&&(identical(other.youtubeLink, youtubeLink) || other.youtubeLink == youtubeLink)&&(identical(other.publishedDate, publishedDate) || other.publishedDate == publishedDate)&&(identical(other.publishedDateFormatted, publishedDateFormatted) || other.publishedDateFormatted == publishedDateFormatted)&&(identical(other.views, views) || other.views == views)&&(identical(other.intro, intro) || other.intro == intro)&&(identical(other.description, description) || other.description == description)&&(identical(other.thumbnail, thumbnail) || other.thumbnail == thumbnail));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,videoId,title,youtubeLink,publishedDate,publishedDateFormatted,views,intro,description,thumbnail);

@override
String toString() {
  return 'TsrYouTubeVideo(id: $id, videoId: $videoId, title: $title, youtubeLink: $youtubeLink, publishedDate: $publishedDate, publishedDateFormatted: $publishedDateFormatted, views: $views, intro: $intro, description: $description, thumbnail: $thumbnail)';
}


}

/// @nodoc
abstract mixin class $TsrYouTubeVideoCopyWith<$Res>  {
  factory $TsrYouTubeVideoCopyWith(TsrYouTubeVideo value, $Res Function(TsrYouTubeVideo) _then) = _$TsrYouTubeVideoCopyWithImpl;
@useResult
$Res call({
 String id, String videoId,@JsonKey(fromJson: decodeHtmlEntities) String title, String youtubeLink, String? publishedDate, String? publishedDateFormatted, int? views, String? intro, String? description, TsrThumbnail? thumbnail
});


$TsrThumbnailCopyWith<$Res>? get thumbnail;

}
/// @nodoc
class _$TsrYouTubeVideoCopyWithImpl<$Res>
    implements $TsrYouTubeVideoCopyWith<$Res> {
  _$TsrYouTubeVideoCopyWithImpl(this._self, this._then);

  final TsrYouTubeVideo _self;
  final $Res Function(TsrYouTubeVideo) _then;

/// Create a copy of TsrYouTubeVideo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? videoId = null,Object? title = null,Object? youtubeLink = null,Object? publishedDate = freezed,Object? publishedDateFormatted = freezed,Object? views = freezed,Object? intro = freezed,Object? description = freezed,Object? thumbnail = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,videoId: null == videoId ? _self.videoId : videoId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,youtubeLink: null == youtubeLink ? _self.youtubeLink : youtubeLink // ignore: cast_nullable_to_non_nullable
as String,publishedDate: freezed == publishedDate ? _self.publishedDate : publishedDate // ignore: cast_nullable_to_non_nullable
as String?,publishedDateFormatted: freezed == publishedDateFormatted ? _self.publishedDateFormatted : publishedDateFormatted // ignore: cast_nullable_to_non_nullable
as String?,views: freezed == views ? _self.views : views // ignore: cast_nullable_to_non_nullable
as int?,intro: freezed == intro ? _self.intro : intro // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,thumbnail: freezed == thumbnail ? _self.thumbnail : thumbnail // ignore: cast_nullable_to_non_nullable
as TsrThumbnail?,
  ));
}
/// Create a copy of TsrYouTubeVideo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TsrThumbnailCopyWith<$Res>? get thumbnail {
    if (_self.thumbnail == null) {
    return null;
  }

  return $TsrThumbnailCopyWith<$Res>(_self.thumbnail!, (value) {
    return _then(_self.copyWith(thumbnail: value));
  });
}
}


/// Adds pattern-matching-related methods to [TsrYouTubeVideo].
extension TsrYouTubeVideoPatterns on TsrYouTubeVideo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TsrYouTubeVideo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TsrYouTubeVideo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TsrYouTubeVideo value)  $default,){
final _that = this;
switch (_that) {
case _TsrYouTubeVideo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TsrYouTubeVideo value)?  $default,){
final _that = this;
switch (_that) {
case _TsrYouTubeVideo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String videoId, @JsonKey(fromJson: decodeHtmlEntities)  String title,  String youtubeLink,  String? publishedDate,  String? publishedDateFormatted,  int? views,  String? intro,  String? description,  TsrThumbnail? thumbnail)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TsrYouTubeVideo() when $default != null:
return $default(_that.id,_that.videoId,_that.title,_that.youtubeLink,_that.publishedDate,_that.publishedDateFormatted,_that.views,_that.intro,_that.description,_that.thumbnail);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String videoId, @JsonKey(fromJson: decodeHtmlEntities)  String title,  String youtubeLink,  String? publishedDate,  String? publishedDateFormatted,  int? views,  String? intro,  String? description,  TsrThumbnail? thumbnail)  $default,) {final _that = this;
switch (_that) {
case _TsrYouTubeVideo():
return $default(_that.id,_that.videoId,_that.title,_that.youtubeLink,_that.publishedDate,_that.publishedDateFormatted,_that.views,_that.intro,_that.description,_that.thumbnail);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String videoId, @JsonKey(fromJson: decodeHtmlEntities)  String title,  String youtubeLink,  String? publishedDate,  String? publishedDateFormatted,  int? views,  String? intro,  String? description,  TsrThumbnail? thumbnail)?  $default,) {final _that = this;
switch (_that) {
case _TsrYouTubeVideo() when $default != null:
return $default(_that.id,_that.videoId,_that.title,_that.youtubeLink,_that.publishedDate,_that.publishedDateFormatted,_that.views,_that.intro,_that.description,_that.thumbnail);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TsrYouTubeVideo implements TsrYouTubeVideo {
  const _TsrYouTubeVideo({required this.id, required this.videoId, @JsonKey(fromJson: decodeHtmlEntities) required this.title, required this.youtubeLink, this.publishedDate, this.publishedDateFormatted, this.views, this.intro, this.description, this.thumbnail});
  factory _TsrYouTubeVideo.fromJson(Map<String, dynamic> json) => _$TsrYouTubeVideoFromJson(json);

@override final  String id;
@override final  String videoId;
// Decoded at the boundary rather than at each render site, so that search
// in AllVideosScreen matches what the user can actually see. The API hands
// WordPress's stored encoding straight through.
@override@JsonKey(fromJson: decodeHtmlEntities) final  String title;
@override final  String youtubeLink;
@override final  String? publishedDate;
@override final  String? publishedDateFormatted;
@override final  int? views;
@override final  String? intro;
@override final  String? description;
@override final  TsrThumbnail? thumbnail;

/// Create a copy of TsrYouTubeVideo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TsrYouTubeVideoCopyWith<_TsrYouTubeVideo> get copyWith => __$TsrYouTubeVideoCopyWithImpl<_TsrYouTubeVideo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TsrYouTubeVideoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TsrYouTubeVideo&&(identical(other.id, id) || other.id == id)&&(identical(other.videoId, videoId) || other.videoId == videoId)&&(identical(other.title, title) || other.title == title)&&(identical(other.youtubeLink, youtubeLink) || other.youtubeLink == youtubeLink)&&(identical(other.publishedDate, publishedDate) || other.publishedDate == publishedDate)&&(identical(other.publishedDateFormatted, publishedDateFormatted) || other.publishedDateFormatted == publishedDateFormatted)&&(identical(other.views, views) || other.views == views)&&(identical(other.intro, intro) || other.intro == intro)&&(identical(other.description, description) || other.description == description)&&(identical(other.thumbnail, thumbnail) || other.thumbnail == thumbnail));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,videoId,title,youtubeLink,publishedDate,publishedDateFormatted,views,intro,description,thumbnail);

@override
String toString() {
  return 'TsrYouTubeVideo(id: $id, videoId: $videoId, title: $title, youtubeLink: $youtubeLink, publishedDate: $publishedDate, publishedDateFormatted: $publishedDateFormatted, views: $views, intro: $intro, description: $description, thumbnail: $thumbnail)';
}


}

/// @nodoc
abstract mixin class _$TsrYouTubeVideoCopyWith<$Res> implements $TsrYouTubeVideoCopyWith<$Res> {
  factory _$TsrYouTubeVideoCopyWith(_TsrYouTubeVideo value, $Res Function(_TsrYouTubeVideo) _then) = __$TsrYouTubeVideoCopyWithImpl;
@override @useResult
$Res call({
 String id, String videoId,@JsonKey(fromJson: decodeHtmlEntities) String title, String youtubeLink, String? publishedDate, String? publishedDateFormatted, int? views, String? intro, String? description, TsrThumbnail? thumbnail
});


@override $TsrThumbnailCopyWith<$Res>? get thumbnail;

}
/// @nodoc
class __$TsrYouTubeVideoCopyWithImpl<$Res>
    implements _$TsrYouTubeVideoCopyWith<$Res> {
  __$TsrYouTubeVideoCopyWithImpl(this._self, this._then);

  final _TsrYouTubeVideo _self;
  final $Res Function(_TsrYouTubeVideo) _then;

/// Create a copy of TsrYouTubeVideo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? videoId = null,Object? title = null,Object? youtubeLink = null,Object? publishedDate = freezed,Object? publishedDateFormatted = freezed,Object? views = freezed,Object? intro = freezed,Object? description = freezed,Object? thumbnail = freezed,}) {
  return _then(_TsrYouTubeVideo(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,videoId: null == videoId ? _self.videoId : videoId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,youtubeLink: null == youtubeLink ? _self.youtubeLink : youtubeLink // ignore: cast_nullable_to_non_nullable
as String,publishedDate: freezed == publishedDate ? _self.publishedDate : publishedDate // ignore: cast_nullable_to_non_nullable
as String?,publishedDateFormatted: freezed == publishedDateFormatted ? _self.publishedDateFormatted : publishedDateFormatted // ignore: cast_nullable_to_non_nullable
as String?,views: freezed == views ? _self.views : views // ignore: cast_nullable_to_non_nullable
as int?,intro: freezed == intro ? _self.intro : intro // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,thumbnail: freezed == thumbnail ? _self.thumbnail : thumbnail // ignore: cast_nullable_to_non_nullable
as TsrThumbnail?,
  ));
}

/// Create a copy of TsrYouTubeVideo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TsrThumbnailCopyWith<$Res>? get thumbnail {
    if (_self.thumbnail == null) {
    return null;
  }

  return $TsrThumbnailCopyWith<$Res>(_self.thumbnail!, (value) {
    return _then(_self.copyWith(thumbnail: value));
  });
}
}


/// @nodoc
mixin _$TsrThumbnail {

 String get url; int? get width; int? get height;
/// Create a copy of TsrThumbnail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TsrThumbnailCopyWith<TsrThumbnail> get copyWith => _$TsrThumbnailCopyWithImpl<TsrThumbnail>(this as TsrThumbnail, _$identity);

  /// Serializes this TsrThumbnail to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TsrThumbnail&&(identical(other.url, url) || other.url == url)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,url,width,height);

@override
String toString() {
  return 'TsrThumbnail(url: $url, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class $TsrThumbnailCopyWith<$Res>  {
  factory $TsrThumbnailCopyWith(TsrThumbnail value, $Res Function(TsrThumbnail) _then) = _$TsrThumbnailCopyWithImpl;
@useResult
$Res call({
 String url, int? width, int? height
});




}
/// @nodoc
class _$TsrThumbnailCopyWithImpl<$Res>
    implements $TsrThumbnailCopyWith<$Res> {
  _$TsrThumbnailCopyWithImpl(this._self, this._then);

  final TsrThumbnail _self;
  final $Res Function(TsrThumbnail) _then;

/// Create a copy of TsrThumbnail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? url = null,Object? width = freezed,Object? height = freezed,}) {
  return _then(_self.copyWith(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [TsrThumbnail].
extension TsrThumbnailPatterns on TsrThumbnail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TsrThumbnail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TsrThumbnail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TsrThumbnail value)  $default,){
final _that = this;
switch (_that) {
case _TsrThumbnail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TsrThumbnail value)?  $default,){
final _that = this;
switch (_that) {
case _TsrThumbnail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String url,  int? width,  int? height)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TsrThumbnail() when $default != null:
return $default(_that.url,_that.width,_that.height);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String url,  int? width,  int? height)  $default,) {final _that = this;
switch (_that) {
case _TsrThumbnail():
return $default(_that.url,_that.width,_that.height);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String url,  int? width,  int? height)?  $default,) {final _that = this;
switch (_that) {
case _TsrThumbnail() when $default != null:
return $default(_that.url,_that.width,_that.height);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TsrThumbnail implements TsrThumbnail {
  const _TsrThumbnail({required this.url, this.width, this.height});
  factory _TsrThumbnail.fromJson(Map<String, dynamic> json) => _$TsrThumbnailFromJson(json);

@override final  String url;
@override final  int? width;
@override final  int? height;

/// Create a copy of TsrThumbnail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TsrThumbnailCopyWith<_TsrThumbnail> get copyWith => __$TsrThumbnailCopyWithImpl<_TsrThumbnail>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TsrThumbnailToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TsrThumbnail&&(identical(other.url, url) || other.url == url)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,url,width,height);

@override
String toString() {
  return 'TsrThumbnail(url: $url, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class _$TsrThumbnailCopyWith<$Res> implements $TsrThumbnailCopyWith<$Res> {
  factory _$TsrThumbnailCopyWith(_TsrThumbnail value, $Res Function(_TsrThumbnail) _then) = __$TsrThumbnailCopyWithImpl;
@override @useResult
$Res call({
 String url, int? width, int? height
});




}
/// @nodoc
class __$TsrThumbnailCopyWithImpl<$Res>
    implements _$TsrThumbnailCopyWith<$Res> {
  __$TsrThumbnailCopyWithImpl(this._self, this._then);

  final _TsrThumbnail _self;
  final $Res Function(_TsrThumbnail) _then;

/// Create a copy of TsrThumbnail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? url = null,Object? width = freezed,Object? height = freezed,}) {
  return _then(_TsrThumbnail(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$TsrYouTubeMeta {

 int? get total; String? get channelId; String? get channelName; String? get channelUrl; String? get lastUpdated; bool get cacheHit;
/// Create a copy of TsrYouTubeMeta
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TsrYouTubeMetaCopyWith<TsrYouTubeMeta> get copyWith => _$TsrYouTubeMetaCopyWithImpl<TsrYouTubeMeta>(this as TsrYouTubeMeta, _$identity);

  /// Serializes this TsrYouTubeMeta to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TsrYouTubeMeta&&(identical(other.total, total) || other.total == total)&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.channelName, channelName) || other.channelName == channelName)&&(identical(other.channelUrl, channelUrl) || other.channelUrl == channelUrl)&&(identical(other.lastUpdated, lastUpdated) || other.lastUpdated == lastUpdated)&&(identical(other.cacheHit, cacheHit) || other.cacheHit == cacheHit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,total,channelId,channelName,channelUrl,lastUpdated,cacheHit);

@override
String toString() {
  return 'TsrYouTubeMeta(total: $total, channelId: $channelId, channelName: $channelName, channelUrl: $channelUrl, lastUpdated: $lastUpdated, cacheHit: $cacheHit)';
}


}

/// @nodoc
abstract mixin class $TsrYouTubeMetaCopyWith<$Res>  {
  factory $TsrYouTubeMetaCopyWith(TsrYouTubeMeta value, $Res Function(TsrYouTubeMeta) _then) = _$TsrYouTubeMetaCopyWithImpl;
@useResult
$Res call({
 int? total, String? channelId, String? channelName, String? channelUrl, String? lastUpdated, bool cacheHit
});




}
/// @nodoc
class _$TsrYouTubeMetaCopyWithImpl<$Res>
    implements $TsrYouTubeMetaCopyWith<$Res> {
  _$TsrYouTubeMetaCopyWithImpl(this._self, this._then);

  final TsrYouTubeMeta _self;
  final $Res Function(TsrYouTubeMeta) _then;

/// Create a copy of TsrYouTubeMeta
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? total = freezed,Object? channelId = freezed,Object? channelName = freezed,Object? channelUrl = freezed,Object? lastUpdated = freezed,Object? cacheHit = null,}) {
  return _then(_self.copyWith(
total: freezed == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int?,channelId: freezed == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String?,channelName: freezed == channelName ? _self.channelName : channelName // ignore: cast_nullable_to_non_nullable
as String?,channelUrl: freezed == channelUrl ? _self.channelUrl : channelUrl // ignore: cast_nullable_to_non_nullable
as String?,lastUpdated: freezed == lastUpdated ? _self.lastUpdated : lastUpdated // ignore: cast_nullable_to_non_nullable
as String?,cacheHit: null == cacheHit ? _self.cacheHit : cacheHit // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TsrYouTubeMeta].
extension TsrYouTubeMetaPatterns on TsrYouTubeMeta {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TsrYouTubeMeta value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TsrYouTubeMeta() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TsrYouTubeMeta value)  $default,){
final _that = this;
switch (_that) {
case _TsrYouTubeMeta():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TsrYouTubeMeta value)?  $default,){
final _that = this;
switch (_that) {
case _TsrYouTubeMeta() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? total,  String? channelId,  String? channelName,  String? channelUrl,  String? lastUpdated,  bool cacheHit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TsrYouTubeMeta() when $default != null:
return $default(_that.total,_that.channelId,_that.channelName,_that.channelUrl,_that.lastUpdated,_that.cacheHit);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? total,  String? channelId,  String? channelName,  String? channelUrl,  String? lastUpdated,  bool cacheHit)  $default,) {final _that = this;
switch (_that) {
case _TsrYouTubeMeta():
return $default(_that.total,_that.channelId,_that.channelName,_that.channelUrl,_that.lastUpdated,_that.cacheHit);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? total,  String? channelId,  String? channelName,  String? channelUrl,  String? lastUpdated,  bool cacheHit)?  $default,) {final _that = this;
switch (_that) {
case _TsrYouTubeMeta() when $default != null:
return $default(_that.total,_that.channelId,_that.channelName,_that.channelUrl,_that.lastUpdated,_that.cacheHit);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TsrYouTubeMeta implements TsrYouTubeMeta {
  const _TsrYouTubeMeta({this.total, this.channelId, this.channelName, this.channelUrl, this.lastUpdated, this.cacheHit = false});
  factory _TsrYouTubeMeta.fromJson(Map<String, dynamic> json) => _$TsrYouTubeMetaFromJson(json);

@override final  int? total;
@override final  String? channelId;
@override final  String? channelName;
@override final  String? channelUrl;
@override final  String? lastUpdated;
@override@JsonKey() final  bool cacheHit;

/// Create a copy of TsrYouTubeMeta
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TsrYouTubeMetaCopyWith<_TsrYouTubeMeta> get copyWith => __$TsrYouTubeMetaCopyWithImpl<_TsrYouTubeMeta>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TsrYouTubeMetaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TsrYouTubeMeta&&(identical(other.total, total) || other.total == total)&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.channelName, channelName) || other.channelName == channelName)&&(identical(other.channelUrl, channelUrl) || other.channelUrl == channelUrl)&&(identical(other.lastUpdated, lastUpdated) || other.lastUpdated == lastUpdated)&&(identical(other.cacheHit, cacheHit) || other.cacheHit == cacheHit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,total,channelId,channelName,channelUrl,lastUpdated,cacheHit);

@override
String toString() {
  return 'TsrYouTubeMeta(total: $total, channelId: $channelId, channelName: $channelName, channelUrl: $channelUrl, lastUpdated: $lastUpdated, cacheHit: $cacheHit)';
}


}

/// @nodoc
abstract mixin class _$TsrYouTubeMetaCopyWith<$Res> implements $TsrYouTubeMetaCopyWith<$Res> {
  factory _$TsrYouTubeMetaCopyWith(_TsrYouTubeMeta value, $Res Function(_TsrYouTubeMeta) _then) = __$TsrYouTubeMetaCopyWithImpl;
@override @useResult
$Res call({
 int? total, String? channelId, String? channelName, String? channelUrl, String? lastUpdated, bool cacheHit
});




}
/// @nodoc
class __$TsrYouTubeMetaCopyWithImpl<$Res>
    implements _$TsrYouTubeMetaCopyWith<$Res> {
  __$TsrYouTubeMetaCopyWithImpl(this._self, this._then);

  final _TsrYouTubeMeta _self;
  final $Res Function(_TsrYouTubeMeta) _then;

/// Create a copy of TsrYouTubeMeta
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? total = freezed,Object? channelId = freezed,Object? channelName = freezed,Object? channelUrl = freezed,Object? lastUpdated = freezed,Object? cacheHit = null,}) {
  return _then(_TsrYouTubeMeta(
total: freezed == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int?,channelId: freezed == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String?,channelName: freezed == channelName ? _self.channelName : channelName // ignore: cast_nullable_to_non_nullable
as String?,channelUrl: freezed == channelUrl ? _self.channelUrl : channelUrl // ignore: cast_nullable_to_non_nullable
as String?,lastUpdated: freezed == lastUpdated ? _self.lastUpdated : lastUpdated // ignore: cast_nullable_to_non_nullable
as String?,cacheHit: null == cacheHit ? _self.cacheHit : cacheHit // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$TsrApiResponse<T> {

 bool get success; T? get data; TsrPagination? get pagination; TsrApiError? get error;
/// Create a copy of TsrApiResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TsrApiResponseCopyWith<T, TsrApiResponse<T>> get copyWith => _$TsrApiResponseCopyWithImpl<T, TsrApiResponse<T>>(this as TsrApiResponse<T>, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TsrApiResponse<T>&&(identical(other.success, success) || other.success == success)&&const DeepCollectionEquality().equals(other.data, data)&&(identical(other.pagination, pagination) || other.pagination == pagination)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,success,const DeepCollectionEquality().hash(data),pagination,error);

@override
String toString() {
  return 'TsrApiResponse<$T>(success: $success, data: $data, pagination: $pagination, error: $error)';
}


}

/// @nodoc
abstract mixin class $TsrApiResponseCopyWith<T,$Res>  {
  factory $TsrApiResponseCopyWith(TsrApiResponse<T> value, $Res Function(TsrApiResponse<T>) _then) = _$TsrApiResponseCopyWithImpl;
@useResult
$Res call({
 bool success, T? data, TsrPagination? pagination, TsrApiError? error
});


$TsrPaginationCopyWith<$Res>? get pagination;$TsrApiErrorCopyWith<$Res>? get error;

}
/// @nodoc
class _$TsrApiResponseCopyWithImpl<T,$Res>
    implements $TsrApiResponseCopyWith<T, $Res> {
  _$TsrApiResponseCopyWithImpl(this._self, this._then);

  final TsrApiResponse<T> _self;
  final $Res Function(TsrApiResponse<T>) _then;

/// Create a copy of TsrApiResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? success = null,Object? data = freezed,Object? pagination = freezed,Object? error = freezed,}) {
  return _then(_self.copyWith(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as T?,pagination: freezed == pagination ? _self.pagination : pagination // ignore: cast_nullable_to_non_nullable
as TsrPagination?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as TsrApiError?,
  ));
}
/// Create a copy of TsrApiResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TsrPaginationCopyWith<$Res>? get pagination {
    if (_self.pagination == null) {
    return null;
  }

  return $TsrPaginationCopyWith<$Res>(_self.pagination!, (value) {
    return _then(_self.copyWith(pagination: value));
  });
}/// Create a copy of TsrApiResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TsrApiErrorCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $TsrApiErrorCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}


/// Adds pattern-matching-related methods to [TsrApiResponse].
extension TsrApiResponsePatterns<T> on TsrApiResponse<T> {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TsrApiResponse<T> value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TsrApiResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TsrApiResponse<T> value)  $default,){
final _that = this;
switch (_that) {
case _TsrApiResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TsrApiResponse<T> value)?  $default,){
final _that = this;
switch (_that) {
case _TsrApiResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool success,  T? data,  TsrPagination? pagination,  TsrApiError? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TsrApiResponse() when $default != null:
return $default(_that.success,_that.data,_that.pagination,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool success,  T? data,  TsrPagination? pagination,  TsrApiError? error)  $default,) {final _that = this;
switch (_that) {
case _TsrApiResponse():
return $default(_that.success,_that.data,_that.pagination,_that.error);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool success,  T? data,  TsrPagination? pagination,  TsrApiError? error)?  $default,) {final _that = this;
switch (_that) {
case _TsrApiResponse() when $default != null:
return $default(_that.success,_that.data,_that.pagination,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _TsrApiResponse<T> implements TsrApiResponse<T> {
  const _TsrApiResponse({required this.success, this.data, this.pagination, this.error});
  

@override final  bool success;
@override final  T? data;
@override final  TsrPagination? pagination;
@override final  TsrApiError? error;

/// Create a copy of TsrApiResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TsrApiResponseCopyWith<T, _TsrApiResponse<T>> get copyWith => __$TsrApiResponseCopyWithImpl<T, _TsrApiResponse<T>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TsrApiResponse<T>&&(identical(other.success, success) || other.success == success)&&const DeepCollectionEquality().equals(other.data, data)&&(identical(other.pagination, pagination) || other.pagination == pagination)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,success,const DeepCollectionEquality().hash(data),pagination,error);

@override
String toString() {
  return 'TsrApiResponse<$T>(success: $success, data: $data, pagination: $pagination, error: $error)';
}


}

/// @nodoc
abstract mixin class _$TsrApiResponseCopyWith<T,$Res> implements $TsrApiResponseCopyWith<T, $Res> {
  factory _$TsrApiResponseCopyWith(_TsrApiResponse<T> value, $Res Function(_TsrApiResponse<T>) _then) = __$TsrApiResponseCopyWithImpl;
@override @useResult
$Res call({
 bool success, T? data, TsrPagination? pagination, TsrApiError? error
});


@override $TsrPaginationCopyWith<$Res>? get pagination;@override $TsrApiErrorCopyWith<$Res>? get error;

}
/// @nodoc
class __$TsrApiResponseCopyWithImpl<T,$Res>
    implements _$TsrApiResponseCopyWith<T, $Res> {
  __$TsrApiResponseCopyWithImpl(this._self, this._then);

  final _TsrApiResponse<T> _self;
  final $Res Function(_TsrApiResponse<T>) _then;

/// Create a copy of TsrApiResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? success = null,Object? data = freezed,Object? pagination = freezed,Object? error = freezed,}) {
  return _then(_TsrApiResponse<T>(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as T?,pagination: freezed == pagination ? _self.pagination : pagination // ignore: cast_nullable_to_non_nullable
as TsrPagination?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as TsrApiError?,
  ));
}

/// Create a copy of TsrApiResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TsrPaginationCopyWith<$Res>? get pagination {
    if (_self.pagination == null) {
    return null;
  }

  return $TsrPaginationCopyWith<$Res>(_self.pagination!, (value) {
    return _then(_self.copyWith(pagination: value));
  });
}/// Create a copy of TsrApiResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TsrApiErrorCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $TsrApiErrorCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}


/// @nodoc
mixin _$TsrPagination {

 int get total; int get limit; int get offset; bool get hasMore;
/// Create a copy of TsrPagination
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TsrPaginationCopyWith<TsrPagination> get copyWith => _$TsrPaginationCopyWithImpl<TsrPagination>(this as TsrPagination, _$identity);

  /// Serializes this TsrPagination to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TsrPagination&&(identical(other.total, total) || other.total == total)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.offset, offset) || other.offset == offset)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,total,limit,offset,hasMore);

@override
String toString() {
  return 'TsrPagination(total: $total, limit: $limit, offset: $offset, hasMore: $hasMore)';
}


}

/// @nodoc
abstract mixin class $TsrPaginationCopyWith<$Res>  {
  factory $TsrPaginationCopyWith(TsrPagination value, $Res Function(TsrPagination) _then) = _$TsrPaginationCopyWithImpl;
@useResult
$Res call({
 int total, int limit, int offset, bool hasMore
});




}
/// @nodoc
class _$TsrPaginationCopyWithImpl<$Res>
    implements $TsrPaginationCopyWith<$Res> {
  _$TsrPaginationCopyWithImpl(this._self, this._then);

  final TsrPagination _self;
  final $Res Function(TsrPagination) _then;

/// Create a copy of TsrPagination
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? total = null,Object? limit = null,Object? offset = null,Object? hasMore = null,}) {
  return _then(_self.copyWith(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,offset: null == offset ? _self.offset : offset // ignore: cast_nullable_to_non_nullable
as int,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TsrPagination].
extension TsrPaginationPatterns on TsrPagination {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TsrPagination value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TsrPagination() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TsrPagination value)  $default,){
final _that = this;
switch (_that) {
case _TsrPagination():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TsrPagination value)?  $default,){
final _that = this;
switch (_that) {
case _TsrPagination() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int total,  int limit,  int offset,  bool hasMore)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TsrPagination() when $default != null:
return $default(_that.total,_that.limit,_that.offset,_that.hasMore);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int total,  int limit,  int offset,  bool hasMore)  $default,) {final _that = this;
switch (_that) {
case _TsrPagination():
return $default(_that.total,_that.limit,_that.offset,_that.hasMore);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int total,  int limit,  int offset,  bool hasMore)?  $default,) {final _that = this;
switch (_that) {
case _TsrPagination() when $default != null:
return $default(_that.total,_that.limit,_that.offset,_that.hasMore);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TsrPagination implements TsrPagination {
  const _TsrPagination({this.total = 0, this.limit = 20, this.offset = 0, this.hasMore = false});
  factory _TsrPagination.fromJson(Map<String, dynamic> json) => _$TsrPaginationFromJson(json);

@override@JsonKey() final  int total;
@override@JsonKey() final  int limit;
@override@JsonKey() final  int offset;
@override@JsonKey() final  bool hasMore;

/// Create a copy of TsrPagination
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TsrPaginationCopyWith<_TsrPagination> get copyWith => __$TsrPaginationCopyWithImpl<_TsrPagination>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TsrPaginationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TsrPagination&&(identical(other.total, total) || other.total == total)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.offset, offset) || other.offset == offset)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,total,limit,offset,hasMore);

@override
String toString() {
  return 'TsrPagination(total: $total, limit: $limit, offset: $offset, hasMore: $hasMore)';
}


}

/// @nodoc
abstract mixin class _$TsrPaginationCopyWith<$Res> implements $TsrPaginationCopyWith<$Res> {
  factory _$TsrPaginationCopyWith(_TsrPagination value, $Res Function(_TsrPagination) _then) = __$TsrPaginationCopyWithImpl;
@override @useResult
$Res call({
 int total, int limit, int offset, bool hasMore
});




}
/// @nodoc
class __$TsrPaginationCopyWithImpl<$Res>
    implements _$TsrPaginationCopyWith<$Res> {
  __$TsrPaginationCopyWithImpl(this._self, this._then);

  final _TsrPagination _self;
  final $Res Function(_TsrPagination) _then;

/// Create a copy of TsrPagination
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? total = null,Object? limit = null,Object? offset = null,Object? hasMore = null,}) {
  return _then(_TsrPagination(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,offset: null == offset ? _self.offset : offset // ignore: cast_nullable_to_non_nullable
as int,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$TsrApiError {

 String? get code; String? get message;
/// Create a copy of TsrApiError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TsrApiErrorCopyWith<TsrApiError> get copyWith => _$TsrApiErrorCopyWithImpl<TsrApiError>(this as TsrApiError, _$identity);

  /// Serializes this TsrApiError to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TsrApiError&&(identical(other.code, code) || other.code == code)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,message);

@override
String toString() {
  return 'TsrApiError(code: $code, message: $message)';
}


}

/// @nodoc
abstract mixin class $TsrApiErrorCopyWith<$Res>  {
  factory $TsrApiErrorCopyWith(TsrApiError value, $Res Function(TsrApiError) _then) = _$TsrApiErrorCopyWithImpl;
@useResult
$Res call({
 String? code, String? message
});




}
/// @nodoc
class _$TsrApiErrorCopyWithImpl<$Res>
    implements $TsrApiErrorCopyWith<$Res> {
  _$TsrApiErrorCopyWithImpl(this._self, this._then);

  final TsrApiError _self;
  final $Res Function(TsrApiError) _then;

/// Create a copy of TsrApiError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = freezed,Object? message = freezed,}) {
  return _then(_self.copyWith(
code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TsrApiError].
extension TsrApiErrorPatterns on TsrApiError {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TsrApiError value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TsrApiError() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TsrApiError value)  $default,){
final _that = this;
switch (_that) {
case _TsrApiError():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TsrApiError value)?  $default,){
final _that = this;
switch (_that) {
case _TsrApiError() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? code,  String? message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TsrApiError() when $default != null:
return $default(_that.code,_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? code,  String? message)  $default,) {final _that = this;
switch (_that) {
case _TsrApiError():
return $default(_that.code,_that.message);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? code,  String? message)?  $default,) {final _that = this;
switch (_that) {
case _TsrApiError() when $default != null:
return $default(_that.code,_that.message);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TsrApiError implements TsrApiError {
  const _TsrApiError({this.code, this.message});
  factory _TsrApiError.fromJson(Map<String, dynamic> json) => _$TsrApiErrorFromJson(json);

@override final  String? code;
@override final  String? message;

/// Create a copy of TsrApiError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TsrApiErrorCopyWith<_TsrApiError> get copyWith => __$TsrApiErrorCopyWithImpl<_TsrApiError>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TsrApiErrorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TsrApiError&&(identical(other.code, code) || other.code == code)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,message);

@override
String toString() {
  return 'TsrApiError(code: $code, message: $message)';
}


}

/// @nodoc
abstract mixin class _$TsrApiErrorCopyWith<$Res> implements $TsrApiErrorCopyWith<$Res> {
  factory _$TsrApiErrorCopyWith(_TsrApiError value, $Res Function(_TsrApiError) _then) = __$TsrApiErrorCopyWithImpl;
@override @useResult
$Res call({
 String? code, String? message
});




}
/// @nodoc
class __$TsrApiErrorCopyWithImpl<$Res>
    implements _$TsrApiErrorCopyWith<$Res> {
  __$TsrApiErrorCopyWithImpl(this._self, this._then);

  final _TsrApiError _self;
  final $Res Function(_TsrApiError) _then;

/// Create a copy of TsrApiError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = freezed,Object? message = freezed,}) {
  return _then(_TsrApiError(
code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$TsrSearchResult {

 List<TsrArticle> get results; String get query; int get total;
/// Create a copy of TsrSearchResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TsrSearchResultCopyWith<TsrSearchResult> get copyWith => _$TsrSearchResultCopyWithImpl<TsrSearchResult>(this as TsrSearchResult, _$identity);

  /// Serializes this TsrSearchResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TsrSearchResult&&const DeepCollectionEquality().equals(other.results, results)&&(identical(other.query, query) || other.query == query)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(results),query,total);

@override
String toString() {
  return 'TsrSearchResult(results: $results, query: $query, total: $total)';
}


}

/// @nodoc
abstract mixin class $TsrSearchResultCopyWith<$Res>  {
  factory $TsrSearchResultCopyWith(TsrSearchResult value, $Res Function(TsrSearchResult) _then) = _$TsrSearchResultCopyWithImpl;
@useResult
$Res call({
 List<TsrArticle> results, String query, int total
});




}
/// @nodoc
class _$TsrSearchResultCopyWithImpl<$Res>
    implements $TsrSearchResultCopyWith<$Res> {
  _$TsrSearchResultCopyWithImpl(this._self, this._then);

  final TsrSearchResult _self;
  final $Res Function(TsrSearchResult) _then;

/// Create a copy of TsrSearchResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? results = null,Object? query = null,Object? total = null,}) {
  return _then(_self.copyWith(
results: null == results ? _self.results : results // ignore: cast_nullable_to_non_nullable
as List<TsrArticle>,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TsrSearchResult].
extension TsrSearchResultPatterns on TsrSearchResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TsrSearchResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TsrSearchResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TsrSearchResult value)  $default,){
final _that = this;
switch (_that) {
case _TsrSearchResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TsrSearchResult value)?  $default,){
final _that = this;
switch (_that) {
case _TsrSearchResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<TsrArticle> results,  String query,  int total)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TsrSearchResult() when $default != null:
return $default(_that.results,_that.query,_that.total);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<TsrArticle> results,  String query,  int total)  $default,) {final _that = this;
switch (_that) {
case _TsrSearchResult():
return $default(_that.results,_that.query,_that.total);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<TsrArticle> results,  String query,  int total)?  $default,) {final _that = this;
switch (_that) {
case _TsrSearchResult() when $default != null:
return $default(_that.results,_that.query,_that.total);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TsrSearchResult implements TsrSearchResult {
  const _TsrSearchResult({required final  List<TsrArticle> results, required this.query, this.total = 0}): _results = results;
  factory _TsrSearchResult.fromJson(Map<String, dynamic> json) => _$TsrSearchResultFromJson(json);

 final  List<TsrArticle> _results;
@override List<TsrArticle> get results {
  if (_results is EqualUnmodifiableListView) return _results;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_results);
}

@override final  String query;
@override@JsonKey() final  int total;

/// Create a copy of TsrSearchResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TsrSearchResultCopyWith<_TsrSearchResult> get copyWith => __$TsrSearchResultCopyWithImpl<_TsrSearchResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TsrSearchResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TsrSearchResult&&const DeepCollectionEquality().equals(other._results, _results)&&(identical(other.query, query) || other.query == query)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_results),query,total);

@override
String toString() {
  return 'TsrSearchResult(results: $results, query: $query, total: $total)';
}


}

/// @nodoc
abstract mixin class _$TsrSearchResultCopyWith<$Res> implements $TsrSearchResultCopyWith<$Res> {
  factory _$TsrSearchResultCopyWith(_TsrSearchResult value, $Res Function(_TsrSearchResult) _then) = __$TsrSearchResultCopyWithImpl;
@override @useResult
$Res call({
 List<TsrArticle> results, String query, int total
});




}
/// @nodoc
class __$TsrSearchResultCopyWithImpl<$Res>
    implements _$TsrSearchResultCopyWith<$Res> {
  __$TsrSearchResultCopyWithImpl(this._self, this._then);

  final _TsrSearchResult _self;
  final $Res Function(_TsrSearchResult) _then;

/// Create a copy of TsrSearchResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? results = null,Object? query = null,Object? total = null,}) {
  return _then(_TsrSearchResult(
results: null == results ? _self._results : results // ignore: cast_nullable_to_non_nullable
as List<TsrArticle>,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
