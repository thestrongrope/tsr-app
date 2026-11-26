// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'article.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Article {

 int get id; DateTime get date; String get title;// plain text title
 String get content;// full html content
 String get excerpt;// html excerpt
 String get link; int get author; int get featuredMedia; List<int> get categories; List<int> get tags; String? get featuredImageUrl;
/// Create a copy of Article
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ArticleCopyWith<Article> get copyWith => _$ArticleCopyWithImpl<Article>(this as Article, _$identity);

  /// Serializes this Article to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Article&&(identical(other.id, id) || other.id == id)&&(identical(other.date, date) || other.date == date)&&(identical(other.title, title) || other.title == title)&&(identical(other.content, content) || other.content == content)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt)&&(identical(other.link, link) || other.link == link)&&(identical(other.author, author) || other.author == author)&&(identical(other.featuredMedia, featuredMedia) || other.featuredMedia == featuredMedia)&&const DeepCollectionEquality().equals(other.categories, categories)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.featuredImageUrl, featuredImageUrl) || other.featuredImageUrl == featuredImageUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,date,title,content,excerpt,link,author,featuredMedia,const DeepCollectionEquality().hash(categories),const DeepCollectionEquality().hash(tags),featuredImageUrl);

@override
String toString() {
  return 'Article(id: $id, date: $date, title: $title, content: $content, excerpt: $excerpt, link: $link, author: $author, featuredMedia: $featuredMedia, categories: $categories, tags: $tags, featuredImageUrl: $featuredImageUrl)';
}


}

/// @nodoc
abstract mixin class $ArticleCopyWith<$Res>  {
  factory $ArticleCopyWith(Article value, $Res Function(Article) _then) = _$ArticleCopyWithImpl;
@useResult
$Res call({
 int id, DateTime date, String title, String content, String excerpt, String link, int author, int featuredMedia, List<int> categories, List<int> tags, String? featuredImageUrl
});




}
/// @nodoc
class _$ArticleCopyWithImpl<$Res>
    implements $ArticleCopyWith<$Res> {
  _$ArticleCopyWithImpl(this._self, this._then);

  final Article _self;
  final $Res Function(Article) _then;

/// Create a copy of Article
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? date = null,Object? title = null,Object? content = null,Object? excerpt = null,Object? link = null,Object? author = null,Object? featuredMedia = null,Object? categories = null,Object? tags = null,Object? featuredImageUrl = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,excerpt: null == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String,link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as int,featuredMedia: null == featuredMedia ? _self.featuredMedia : featuredMedia // ignore: cast_nullable_to_non_nullable
as int,categories: null == categories ? _self.categories : categories // ignore: cast_nullable_to_non_nullable
as List<int>,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<int>,featuredImageUrl: freezed == featuredImageUrl ? _self.featuredImageUrl : featuredImageUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Article].
extension ArticlePatterns on Article {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Article value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Article() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Article value)  $default,){
final _that = this;
switch (_that) {
case _Article():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Article value)?  $default,){
final _that = this;
switch (_that) {
case _Article() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  DateTime date,  String title,  String content,  String excerpt,  String link,  int author,  int featuredMedia,  List<int> categories,  List<int> tags,  String? featuredImageUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Article() when $default != null:
return $default(_that.id,_that.date,_that.title,_that.content,_that.excerpt,_that.link,_that.author,_that.featuredMedia,_that.categories,_that.tags,_that.featuredImageUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  DateTime date,  String title,  String content,  String excerpt,  String link,  int author,  int featuredMedia,  List<int> categories,  List<int> tags,  String? featuredImageUrl)  $default,) {final _that = this;
switch (_that) {
case _Article():
return $default(_that.id,_that.date,_that.title,_that.content,_that.excerpt,_that.link,_that.author,_that.featuredMedia,_that.categories,_that.tags,_that.featuredImageUrl);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  DateTime date,  String title,  String content,  String excerpt,  String link,  int author,  int featuredMedia,  List<int> categories,  List<int> tags,  String? featuredImageUrl)?  $default,) {final _that = this;
switch (_that) {
case _Article() when $default != null:
return $default(_that.id,_that.date,_that.title,_that.content,_that.excerpt,_that.link,_that.author,_that.featuredMedia,_that.categories,_that.tags,_that.featuredImageUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Article implements Article {
  const _Article({required this.id, required this.date, required this.title, required this.content, required this.excerpt, required this.link, required this.author, required this.featuredMedia, required final  List<int> categories, required final  List<int> tags, this.featuredImageUrl}): _categories = categories,_tags = tags;
  factory _Article.fromJson(Map<String, dynamic> json) => _$ArticleFromJson(json);

@override final  int id;
@override final  DateTime date;
@override final  String title;
// plain text title
@override final  String content;
// full html content
@override final  String excerpt;
// html excerpt
@override final  String link;
@override final  int author;
@override final  int featuredMedia;
 final  List<int> _categories;
@override List<int> get categories {
  if (_categories is EqualUnmodifiableListView) return _categories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_categories);
}

 final  List<int> _tags;
@override List<int> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

@override final  String? featuredImageUrl;

/// Create a copy of Article
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ArticleCopyWith<_Article> get copyWith => __$ArticleCopyWithImpl<_Article>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ArticleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Article&&(identical(other.id, id) || other.id == id)&&(identical(other.date, date) || other.date == date)&&(identical(other.title, title) || other.title == title)&&(identical(other.content, content) || other.content == content)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt)&&(identical(other.link, link) || other.link == link)&&(identical(other.author, author) || other.author == author)&&(identical(other.featuredMedia, featuredMedia) || other.featuredMedia == featuredMedia)&&const DeepCollectionEquality().equals(other._categories, _categories)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.featuredImageUrl, featuredImageUrl) || other.featuredImageUrl == featuredImageUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,date,title,content,excerpt,link,author,featuredMedia,const DeepCollectionEquality().hash(_categories),const DeepCollectionEquality().hash(_tags),featuredImageUrl);

@override
String toString() {
  return 'Article(id: $id, date: $date, title: $title, content: $content, excerpt: $excerpt, link: $link, author: $author, featuredMedia: $featuredMedia, categories: $categories, tags: $tags, featuredImageUrl: $featuredImageUrl)';
}


}

/// @nodoc
abstract mixin class _$ArticleCopyWith<$Res> implements $ArticleCopyWith<$Res> {
  factory _$ArticleCopyWith(_Article value, $Res Function(_Article) _then) = __$ArticleCopyWithImpl;
@override @useResult
$Res call({
 int id, DateTime date, String title, String content, String excerpt, String link, int author, int featuredMedia, List<int> categories, List<int> tags, String? featuredImageUrl
});




}
/// @nodoc
class __$ArticleCopyWithImpl<$Res>
    implements _$ArticleCopyWith<$Res> {
  __$ArticleCopyWithImpl(this._self, this._then);

  final _Article _self;
  final $Res Function(_Article) _then;

/// Create a copy of Article
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? date = null,Object? title = null,Object? content = null,Object? excerpt = null,Object? link = null,Object? author = null,Object? featuredMedia = null,Object? categories = null,Object? tags = null,Object? featuredImageUrl = freezed,}) {
  return _then(_Article(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,excerpt: null == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String,link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as int,featuredMedia: null == featuredMedia ? _self.featuredMedia : featuredMedia // ignore: cast_nullable_to_non_nullable
as int,categories: null == categories ? _self._categories : categories // ignore: cast_nullable_to_non_nullable
as List<int>,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<int>,featuredImageUrl: freezed == featuredImageUrl ? _self.featuredImageUrl : featuredImageUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
