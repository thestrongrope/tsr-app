// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'quiz.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Quiz {

 int get id; String get code; String get name; String? get topic; int get classId; DateTime? get publishedAt; int get questionCount; bool get attempted; int? get score; int? get total; double? get percent;
/// Create a copy of Quiz
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuizCopyWith<Quiz> get copyWith => _$QuizCopyWithImpl<Quiz>(this as Quiz, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Quiz&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.topic, topic) || other.topic == topic)&&(identical(other.classId, classId) || other.classId == classId)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt)&&(identical(other.questionCount, questionCount) || other.questionCount == questionCount)&&(identical(other.attempted, attempted) || other.attempted == attempted)&&(identical(other.score, score) || other.score == score)&&(identical(other.total, total) || other.total == total)&&(identical(other.percent, percent) || other.percent == percent));
}


@override
int get hashCode => Object.hash(runtimeType,id,code,name,topic,classId,publishedAt,questionCount,attempted,score,total,percent);

@override
String toString() {
  return 'Quiz(id: $id, code: $code, name: $name, topic: $topic, classId: $classId, publishedAt: $publishedAt, questionCount: $questionCount, attempted: $attempted, score: $score, total: $total, percent: $percent)';
}


}

/// @nodoc
abstract mixin class $QuizCopyWith<$Res>  {
  factory $QuizCopyWith(Quiz value, $Res Function(Quiz) _then) = _$QuizCopyWithImpl;
@useResult
$Res call({
 int id, String code, String name, String? topic, int classId, DateTime? publishedAt, int questionCount, bool attempted, int? score, int? total, double? percent
});




}
/// @nodoc
class _$QuizCopyWithImpl<$Res>
    implements $QuizCopyWith<$Res> {
  _$QuizCopyWithImpl(this._self, this._then);

  final Quiz _self;
  final $Res Function(Quiz) _then;

/// Create a copy of Quiz
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? code = null,Object? name = null,Object? topic = freezed,Object? classId = null,Object? publishedAt = freezed,Object? questionCount = null,Object? attempted = null,Object? score = freezed,Object? total = freezed,Object? percent = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,topic: freezed == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String?,classId: null == classId ? _self.classId : classId // ignore: cast_nullable_to_non_nullable
as int,publishedAt: freezed == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,questionCount: null == questionCount ? _self.questionCount : questionCount // ignore: cast_nullable_to_non_nullable
as int,attempted: null == attempted ? _self.attempted : attempted // ignore: cast_nullable_to_non_nullable
as bool,score: freezed == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int?,total: freezed == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int?,percent: freezed == percent ? _self.percent : percent // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [Quiz].
extension QuizPatterns on Quiz {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Quiz value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Quiz() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Quiz value)  $default,){
final _that = this;
switch (_that) {
case _Quiz():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Quiz value)?  $default,){
final _that = this;
switch (_that) {
case _Quiz() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String code,  String name,  String? topic,  int classId,  DateTime? publishedAt,  int questionCount,  bool attempted,  int? score,  int? total,  double? percent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Quiz() when $default != null:
return $default(_that.id,_that.code,_that.name,_that.topic,_that.classId,_that.publishedAt,_that.questionCount,_that.attempted,_that.score,_that.total,_that.percent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String code,  String name,  String? topic,  int classId,  DateTime? publishedAt,  int questionCount,  bool attempted,  int? score,  int? total,  double? percent)  $default,) {final _that = this;
switch (_that) {
case _Quiz():
return $default(_that.id,_that.code,_that.name,_that.topic,_that.classId,_that.publishedAt,_that.questionCount,_that.attempted,_that.score,_that.total,_that.percent);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String code,  String name,  String? topic,  int classId,  DateTime? publishedAt,  int questionCount,  bool attempted,  int? score,  int? total,  double? percent)?  $default,) {final _that = this;
switch (_that) {
case _Quiz() when $default != null:
return $default(_that.id,_that.code,_that.name,_that.topic,_that.classId,_that.publishedAt,_that.questionCount,_that.attempted,_that.score,_that.total,_that.percent);case _:
  return null;

}
}

}

/// @nodoc


class _Quiz extends Quiz {
  const _Quiz({required this.id, required this.code, required this.name, this.topic, required this.classId, this.publishedAt, this.questionCount = 0, this.attempted = false, this.score, this.total, this.percent}): super._();
  

@override final  int id;
@override final  String code;
@override final  String name;
@override final  String? topic;
@override final  int classId;
@override final  DateTime? publishedAt;
@override@JsonKey() final  int questionCount;
@override@JsonKey() final  bool attempted;
@override final  int? score;
@override final  int? total;
@override final  double? percent;

/// Create a copy of Quiz
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuizCopyWith<_Quiz> get copyWith => __$QuizCopyWithImpl<_Quiz>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Quiz&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.topic, topic) || other.topic == topic)&&(identical(other.classId, classId) || other.classId == classId)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt)&&(identical(other.questionCount, questionCount) || other.questionCount == questionCount)&&(identical(other.attempted, attempted) || other.attempted == attempted)&&(identical(other.score, score) || other.score == score)&&(identical(other.total, total) || other.total == total)&&(identical(other.percent, percent) || other.percent == percent));
}


@override
int get hashCode => Object.hash(runtimeType,id,code,name,topic,classId,publishedAt,questionCount,attempted,score,total,percent);

@override
String toString() {
  return 'Quiz(id: $id, code: $code, name: $name, topic: $topic, classId: $classId, publishedAt: $publishedAt, questionCount: $questionCount, attempted: $attempted, score: $score, total: $total, percent: $percent)';
}


}

/// @nodoc
abstract mixin class _$QuizCopyWith<$Res> implements $QuizCopyWith<$Res> {
  factory _$QuizCopyWith(_Quiz value, $Res Function(_Quiz) _then) = __$QuizCopyWithImpl;
@override @useResult
$Res call({
 int id, String code, String name, String? topic, int classId, DateTime? publishedAt, int questionCount, bool attempted, int? score, int? total, double? percent
});




}
/// @nodoc
class __$QuizCopyWithImpl<$Res>
    implements _$QuizCopyWith<$Res> {
  __$QuizCopyWithImpl(this._self, this._then);

  final _Quiz _self;
  final $Res Function(_Quiz) _then;

/// Create a copy of Quiz
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? code = null,Object? name = null,Object? topic = freezed,Object? classId = null,Object? publishedAt = freezed,Object? questionCount = null,Object? attempted = null,Object? score = freezed,Object? total = freezed,Object? percent = freezed,}) {
  return _then(_Quiz(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,topic: freezed == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String?,classId: null == classId ? _self.classId : classId // ignore: cast_nullable_to_non_nullable
as int,publishedAt: freezed == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,questionCount: null == questionCount ? _self.questionCount : questionCount // ignore: cast_nullable_to_non_nullable
as int,attempted: null == attempted ? _self.attempted : attempted // ignore: cast_nullable_to_non_nullable
as bool,score: freezed == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int?,total: freezed == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int?,percent: freezed == percent ? _self.percent : percent // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

/// @nodoc
mixin _$QuizQuestion {

 int get id; String get text; List<String> get options; bool get isArabic;
/// Create a copy of QuizQuestion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuizQuestionCopyWith<QuizQuestion> get copyWith => _$QuizQuestionCopyWithImpl<QuizQuestion>(this as QuizQuestion, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuizQuestion&&(identical(other.id, id) || other.id == id)&&(identical(other.text, text) || other.text == text)&&const DeepCollectionEquality().equals(other.options, options)&&(identical(other.isArabic, isArabic) || other.isArabic == isArabic));
}


@override
int get hashCode => Object.hash(runtimeType,id,text,const DeepCollectionEquality().hash(options),isArabic);

@override
String toString() {
  return 'QuizQuestion(id: $id, text: $text, options: $options, isArabic: $isArabic)';
}


}

/// @nodoc
abstract mixin class $QuizQuestionCopyWith<$Res>  {
  factory $QuizQuestionCopyWith(QuizQuestion value, $Res Function(QuizQuestion) _then) = _$QuizQuestionCopyWithImpl;
@useResult
$Res call({
 int id, String text, List<String> options, bool isArabic
});




}
/// @nodoc
class _$QuizQuestionCopyWithImpl<$Res>
    implements $QuizQuestionCopyWith<$Res> {
  _$QuizQuestionCopyWithImpl(this._self, this._then);

  final QuizQuestion _self;
  final $Res Function(QuizQuestion) _then;

/// Create a copy of QuizQuestion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? text = null,Object? options = null,Object? isArabic = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<String>,isArabic: null == isArabic ? _self.isArabic : isArabic // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [QuizQuestion].
extension QuizQuestionPatterns on QuizQuestion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QuizQuestion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QuizQuestion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QuizQuestion value)  $default,){
final _that = this;
switch (_that) {
case _QuizQuestion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QuizQuestion value)?  $default,){
final _that = this;
switch (_that) {
case _QuizQuestion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String text,  List<String> options,  bool isArabic)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QuizQuestion() when $default != null:
return $default(_that.id,_that.text,_that.options,_that.isArabic);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String text,  List<String> options,  bool isArabic)  $default,) {final _that = this;
switch (_that) {
case _QuizQuestion():
return $default(_that.id,_that.text,_that.options,_that.isArabic);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String text,  List<String> options,  bool isArabic)?  $default,) {final _that = this;
switch (_that) {
case _QuizQuestion() when $default != null:
return $default(_that.id,_that.text,_that.options,_that.isArabic);case _:
  return null;

}
}

}

/// @nodoc


class _QuizQuestion implements QuizQuestion {
  const _QuizQuestion({required this.id, required this.text, required final  List<String> options, this.isArabic = false}): _options = options;
  

@override final  int id;
@override final  String text;
 final  List<String> _options;
@override List<String> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}

@override@JsonKey() final  bool isArabic;

/// Create a copy of QuizQuestion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuizQuestionCopyWith<_QuizQuestion> get copyWith => __$QuizQuestionCopyWithImpl<_QuizQuestion>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QuizQuestion&&(identical(other.id, id) || other.id == id)&&(identical(other.text, text) || other.text == text)&&const DeepCollectionEquality().equals(other._options, _options)&&(identical(other.isArabic, isArabic) || other.isArabic == isArabic));
}


@override
int get hashCode => Object.hash(runtimeType,id,text,const DeepCollectionEquality().hash(_options),isArabic);

@override
String toString() {
  return 'QuizQuestion(id: $id, text: $text, options: $options, isArabic: $isArabic)';
}


}

/// @nodoc
abstract mixin class _$QuizQuestionCopyWith<$Res> implements $QuizQuestionCopyWith<$Res> {
  factory _$QuizQuestionCopyWith(_QuizQuestion value, $Res Function(_QuizQuestion) _then) = __$QuizQuestionCopyWithImpl;
@override @useResult
$Res call({
 int id, String text, List<String> options, bool isArabic
});




}
/// @nodoc
class __$QuizQuestionCopyWithImpl<$Res>
    implements _$QuizQuestionCopyWith<$Res> {
  __$QuizQuestionCopyWithImpl(this._self, this._then);

  final _QuizQuestion _self;
  final $Res Function(_QuizQuestion) _then;

/// Create a copy of QuizQuestion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? text = null,Object? options = null,Object? isArabic = null,}) {
  return _then(_QuizQuestion(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<String>,isArabic: null == isArabic ? _self.isArabic : isArabic // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$QuizListResponse {

 int get total; int get page; int get pageSize; bool get hasNext; List<Quiz> get items;
/// Create a copy of QuizListResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuizListResponseCopyWith<QuizListResponse> get copyWith => _$QuizListResponseCopyWithImpl<QuizListResponse>(this as QuizListResponse, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuizListResponse&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize)&&(identical(other.hasNext, hasNext) || other.hasNext == hasNext)&&const DeepCollectionEquality().equals(other.items, items));
}


@override
int get hashCode => Object.hash(runtimeType,total,page,pageSize,hasNext,const DeepCollectionEquality().hash(items));

@override
String toString() {
  return 'QuizListResponse(total: $total, page: $page, pageSize: $pageSize, hasNext: $hasNext, items: $items)';
}


}

/// @nodoc
abstract mixin class $QuizListResponseCopyWith<$Res>  {
  factory $QuizListResponseCopyWith(QuizListResponse value, $Res Function(QuizListResponse) _then) = _$QuizListResponseCopyWithImpl;
@useResult
$Res call({
 int total, int page, int pageSize, bool hasNext, List<Quiz> items
});




}
/// @nodoc
class _$QuizListResponseCopyWithImpl<$Res>
    implements $QuizListResponseCopyWith<$Res> {
  _$QuizListResponseCopyWithImpl(this._self, this._then);

  final QuizListResponse _self;
  final $Res Function(QuizListResponse) _then;

/// Create a copy of QuizListResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? total = null,Object? page = null,Object? pageSize = null,Object? hasNext = null,Object? items = null,}) {
  return _then(_self.copyWith(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,hasNext: null == hasNext ? _self.hasNext : hasNext // ignore: cast_nullable_to_non_nullable
as bool,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<Quiz>,
  ));
}

}


/// Adds pattern-matching-related methods to [QuizListResponse].
extension QuizListResponsePatterns on QuizListResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QuizListResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QuizListResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QuizListResponse value)  $default,){
final _that = this;
switch (_that) {
case _QuizListResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QuizListResponse value)?  $default,){
final _that = this;
switch (_that) {
case _QuizListResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int total,  int page,  int pageSize,  bool hasNext,  List<Quiz> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QuizListResponse() when $default != null:
return $default(_that.total,_that.page,_that.pageSize,_that.hasNext,_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int total,  int page,  int pageSize,  bool hasNext,  List<Quiz> items)  $default,) {final _that = this;
switch (_that) {
case _QuizListResponse():
return $default(_that.total,_that.page,_that.pageSize,_that.hasNext,_that.items);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int total,  int page,  int pageSize,  bool hasNext,  List<Quiz> items)?  $default,) {final _that = this;
switch (_that) {
case _QuizListResponse() when $default != null:
return $default(_that.total,_that.page,_that.pageSize,_that.hasNext,_that.items);case _:
  return null;

}
}

}

/// @nodoc


class _QuizListResponse implements QuizListResponse {
  const _QuizListResponse({required this.total, required this.page, required this.pageSize, required this.hasNext, required final  List<Quiz> items}): _items = items;
  

@override final  int total;
@override final  int page;
@override final  int pageSize;
@override final  bool hasNext;
 final  List<Quiz> _items;
@override List<Quiz> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of QuizListResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuizListResponseCopyWith<_QuizListResponse> get copyWith => __$QuizListResponseCopyWithImpl<_QuizListResponse>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QuizListResponse&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize)&&(identical(other.hasNext, hasNext) || other.hasNext == hasNext)&&const DeepCollectionEquality().equals(other._items, _items));
}


@override
int get hashCode => Object.hash(runtimeType,total,page,pageSize,hasNext,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'QuizListResponse(total: $total, page: $page, pageSize: $pageSize, hasNext: $hasNext, items: $items)';
}


}

/// @nodoc
abstract mixin class _$QuizListResponseCopyWith<$Res> implements $QuizListResponseCopyWith<$Res> {
  factory _$QuizListResponseCopyWith(_QuizListResponse value, $Res Function(_QuizListResponse) _then) = __$QuizListResponseCopyWithImpl;
@override @useResult
$Res call({
 int total, int page, int pageSize, bool hasNext, List<Quiz> items
});




}
/// @nodoc
class __$QuizListResponseCopyWithImpl<$Res>
    implements _$QuizListResponseCopyWith<$Res> {
  __$QuizListResponseCopyWithImpl(this._self, this._then);

  final _QuizListResponse _self;
  final $Res Function(_QuizListResponse) _then;

/// Create a copy of QuizListResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? total = null,Object? page = null,Object? pageSize = null,Object? hasNext = null,Object? items = null,}) {
  return _then(_QuizListResponse(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,hasNext: null == hasNext ? _self.hasNext : hasNext // ignore: cast_nullable_to_non_nullable
as bool,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<Quiz>,
  ));
}


}

/// @nodoc
mixin _$QuizQuestionsResponse {

 int get total; int get page; int get pageSize; List<QuizQuestion> get items;
/// Create a copy of QuizQuestionsResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuizQuestionsResponseCopyWith<QuizQuestionsResponse> get copyWith => _$QuizQuestionsResponseCopyWithImpl<QuizQuestionsResponse>(this as QuizQuestionsResponse, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuizQuestionsResponse&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize)&&const DeepCollectionEquality().equals(other.items, items));
}


@override
int get hashCode => Object.hash(runtimeType,total,page,pageSize,const DeepCollectionEquality().hash(items));

@override
String toString() {
  return 'QuizQuestionsResponse(total: $total, page: $page, pageSize: $pageSize, items: $items)';
}


}

/// @nodoc
abstract mixin class $QuizQuestionsResponseCopyWith<$Res>  {
  factory $QuizQuestionsResponseCopyWith(QuizQuestionsResponse value, $Res Function(QuizQuestionsResponse) _then) = _$QuizQuestionsResponseCopyWithImpl;
@useResult
$Res call({
 int total, int page, int pageSize, List<QuizQuestion> items
});




}
/// @nodoc
class _$QuizQuestionsResponseCopyWithImpl<$Res>
    implements $QuizQuestionsResponseCopyWith<$Res> {
  _$QuizQuestionsResponseCopyWithImpl(this._self, this._then);

  final QuizQuestionsResponse _self;
  final $Res Function(QuizQuestionsResponse) _then;

/// Create a copy of QuizQuestionsResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? total = null,Object? page = null,Object? pageSize = null,Object? items = null,}) {
  return _then(_self.copyWith(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<QuizQuestion>,
  ));
}

}


/// Adds pattern-matching-related methods to [QuizQuestionsResponse].
extension QuizQuestionsResponsePatterns on QuizQuestionsResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QuizQuestionsResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QuizQuestionsResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QuizQuestionsResponse value)  $default,){
final _that = this;
switch (_that) {
case _QuizQuestionsResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QuizQuestionsResponse value)?  $default,){
final _that = this;
switch (_that) {
case _QuizQuestionsResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int total,  int page,  int pageSize,  List<QuizQuestion> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QuizQuestionsResponse() when $default != null:
return $default(_that.total,_that.page,_that.pageSize,_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int total,  int page,  int pageSize,  List<QuizQuestion> items)  $default,) {final _that = this;
switch (_that) {
case _QuizQuestionsResponse():
return $default(_that.total,_that.page,_that.pageSize,_that.items);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int total,  int page,  int pageSize,  List<QuizQuestion> items)?  $default,) {final _that = this;
switch (_that) {
case _QuizQuestionsResponse() when $default != null:
return $default(_that.total,_that.page,_that.pageSize,_that.items);case _:
  return null;

}
}

}

/// @nodoc


class _QuizQuestionsResponse implements QuizQuestionsResponse {
  const _QuizQuestionsResponse({required this.total, required this.page, required this.pageSize, required final  List<QuizQuestion> items}): _items = items;
  

@override final  int total;
@override final  int page;
@override final  int pageSize;
 final  List<QuizQuestion> _items;
@override List<QuizQuestion> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of QuizQuestionsResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuizQuestionsResponseCopyWith<_QuizQuestionsResponse> get copyWith => __$QuizQuestionsResponseCopyWithImpl<_QuizQuestionsResponse>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QuizQuestionsResponse&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize)&&const DeepCollectionEquality().equals(other._items, _items));
}


@override
int get hashCode => Object.hash(runtimeType,total,page,pageSize,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'QuizQuestionsResponse(total: $total, page: $page, pageSize: $pageSize, items: $items)';
}


}

/// @nodoc
abstract mixin class _$QuizQuestionsResponseCopyWith<$Res> implements $QuizQuestionsResponseCopyWith<$Res> {
  factory _$QuizQuestionsResponseCopyWith(_QuizQuestionsResponse value, $Res Function(_QuizQuestionsResponse) _then) = __$QuizQuestionsResponseCopyWithImpl;
@override @useResult
$Res call({
 int total, int page, int pageSize, List<QuizQuestion> items
});




}
/// @nodoc
class __$QuizQuestionsResponseCopyWithImpl<$Res>
    implements _$QuizQuestionsResponseCopyWith<$Res> {
  __$QuizQuestionsResponseCopyWithImpl(this._self, this._then);

  final _QuizQuestionsResponse _self;
  final $Res Function(_QuizQuestionsResponse) _then;

/// Create a copy of QuizQuestionsResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? total = null,Object? page = null,Object? pageSize = null,Object? items = null,}) {
  return _then(_QuizQuestionsResponse(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<QuizQuestion>,
  ));
}


}

/// @nodoc
mixin _$QuizSubmitResponse {

 int get total; int get answered; int get correct; double get percent; List<QuizResponseResult> get responses;
/// Create a copy of QuizSubmitResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuizSubmitResponseCopyWith<QuizSubmitResponse> get copyWith => _$QuizSubmitResponseCopyWithImpl<QuizSubmitResponse>(this as QuizSubmitResponse, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuizSubmitResponse&&(identical(other.total, total) || other.total == total)&&(identical(other.answered, answered) || other.answered == answered)&&(identical(other.correct, correct) || other.correct == correct)&&(identical(other.percent, percent) || other.percent == percent)&&const DeepCollectionEquality().equals(other.responses, responses));
}


@override
int get hashCode => Object.hash(runtimeType,total,answered,correct,percent,const DeepCollectionEquality().hash(responses));

@override
String toString() {
  return 'QuizSubmitResponse(total: $total, answered: $answered, correct: $correct, percent: $percent, responses: $responses)';
}


}

/// @nodoc
abstract mixin class $QuizSubmitResponseCopyWith<$Res>  {
  factory $QuizSubmitResponseCopyWith(QuizSubmitResponse value, $Res Function(QuizSubmitResponse) _then) = _$QuizSubmitResponseCopyWithImpl;
@useResult
$Res call({
 int total, int answered, int correct, double percent, List<QuizResponseResult> responses
});




}
/// @nodoc
class _$QuizSubmitResponseCopyWithImpl<$Res>
    implements $QuizSubmitResponseCopyWith<$Res> {
  _$QuizSubmitResponseCopyWithImpl(this._self, this._then);

  final QuizSubmitResponse _self;
  final $Res Function(QuizSubmitResponse) _then;

/// Create a copy of QuizSubmitResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? total = null,Object? answered = null,Object? correct = null,Object? percent = null,Object? responses = null,}) {
  return _then(_self.copyWith(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,answered: null == answered ? _self.answered : answered // ignore: cast_nullable_to_non_nullable
as int,correct: null == correct ? _self.correct : correct // ignore: cast_nullable_to_non_nullable
as int,percent: null == percent ? _self.percent : percent // ignore: cast_nullable_to_non_nullable
as double,responses: null == responses ? _self.responses : responses // ignore: cast_nullable_to_non_nullable
as List<QuizResponseResult>,
  ));
}

}


/// Adds pattern-matching-related methods to [QuizSubmitResponse].
extension QuizSubmitResponsePatterns on QuizSubmitResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QuizSubmitResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QuizSubmitResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QuizSubmitResponse value)  $default,){
final _that = this;
switch (_that) {
case _QuizSubmitResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QuizSubmitResponse value)?  $default,){
final _that = this;
switch (_that) {
case _QuizSubmitResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int total,  int answered,  int correct,  double percent,  List<QuizResponseResult> responses)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QuizSubmitResponse() when $default != null:
return $default(_that.total,_that.answered,_that.correct,_that.percent,_that.responses);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int total,  int answered,  int correct,  double percent,  List<QuizResponseResult> responses)  $default,) {final _that = this;
switch (_that) {
case _QuizSubmitResponse():
return $default(_that.total,_that.answered,_that.correct,_that.percent,_that.responses);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int total,  int answered,  int correct,  double percent,  List<QuizResponseResult> responses)?  $default,) {final _that = this;
switch (_that) {
case _QuizSubmitResponse() when $default != null:
return $default(_that.total,_that.answered,_that.correct,_that.percent,_that.responses);case _:
  return null;

}
}

}

/// @nodoc


class _QuizSubmitResponse extends QuizSubmitResponse {
  const _QuizSubmitResponse({required this.total, required this.answered, required this.correct, required this.percent, required final  List<QuizResponseResult> responses}): _responses = responses,super._();
  

@override final  int total;
@override final  int answered;
@override final  int correct;
@override final  double percent;
 final  List<QuizResponseResult> _responses;
@override List<QuizResponseResult> get responses {
  if (_responses is EqualUnmodifiableListView) return _responses;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_responses);
}


/// Create a copy of QuizSubmitResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuizSubmitResponseCopyWith<_QuizSubmitResponse> get copyWith => __$QuizSubmitResponseCopyWithImpl<_QuizSubmitResponse>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QuizSubmitResponse&&(identical(other.total, total) || other.total == total)&&(identical(other.answered, answered) || other.answered == answered)&&(identical(other.correct, correct) || other.correct == correct)&&(identical(other.percent, percent) || other.percent == percent)&&const DeepCollectionEquality().equals(other._responses, _responses));
}


@override
int get hashCode => Object.hash(runtimeType,total,answered,correct,percent,const DeepCollectionEquality().hash(_responses));

@override
String toString() {
  return 'QuizSubmitResponse(total: $total, answered: $answered, correct: $correct, percent: $percent, responses: $responses)';
}


}

/// @nodoc
abstract mixin class _$QuizSubmitResponseCopyWith<$Res> implements $QuizSubmitResponseCopyWith<$Res> {
  factory _$QuizSubmitResponseCopyWith(_QuizSubmitResponse value, $Res Function(_QuizSubmitResponse) _then) = __$QuizSubmitResponseCopyWithImpl;
@override @useResult
$Res call({
 int total, int answered, int correct, double percent, List<QuizResponseResult> responses
});




}
/// @nodoc
class __$QuizSubmitResponseCopyWithImpl<$Res>
    implements _$QuizSubmitResponseCopyWith<$Res> {
  __$QuizSubmitResponseCopyWithImpl(this._self, this._then);

  final _QuizSubmitResponse _self;
  final $Res Function(_QuizSubmitResponse) _then;

/// Create a copy of QuizSubmitResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? total = null,Object? answered = null,Object? correct = null,Object? percent = null,Object? responses = null,}) {
  return _then(_QuizSubmitResponse(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,answered: null == answered ? _self.answered : answered // ignore: cast_nullable_to_non_nullable
as int,correct: null == correct ? _self.correct : correct // ignore: cast_nullable_to_non_nullable
as int,percent: null == percent ? _self.percent : percent // ignore: cast_nullable_to_non_nullable
as double,responses: null == responses ? _self._responses : responses // ignore: cast_nullable_to_non_nullable
as List<QuizResponseResult>,
  ));
}


}


/// @nodoc
mixin _$QuizResponseResult {

 int get questionId; int get selected; int get isCorrect; String? get questionText; String? get selectedText; String? get correctText;
/// Create a copy of QuizResponseResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuizResponseResultCopyWith<QuizResponseResult> get copyWith => _$QuizResponseResultCopyWithImpl<QuizResponseResult>(this as QuizResponseResult, _$identity);

  /// Serializes this QuizResponseResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuizResponseResult&&(identical(other.questionId, questionId) || other.questionId == questionId)&&(identical(other.selected, selected) || other.selected == selected)&&(identical(other.isCorrect, isCorrect) || other.isCorrect == isCorrect)&&(identical(other.questionText, questionText) || other.questionText == questionText)&&(identical(other.selectedText, selectedText) || other.selectedText == selectedText)&&(identical(other.correctText, correctText) || other.correctText == correctText));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,questionId,selected,isCorrect,questionText,selectedText,correctText);

@override
String toString() {
  return 'QuizResponseResult(questionId: $questionId, selected: $selected, isCorrect: $isCorrect, questionText: $questionText, selectedText: $selectedText, correctText: $correctText)';
}


}

/// @nodoc
abstract mixin class $QuizResponseResultCopyWith<$Res>  {
  factory $QuizResponseResultCopyWith(QuizResponseResult value, $Res Function(QuizResponseResult) _then) = _$QuizResponseResultCopyWithImpl;
@useResult
$Res call({
 int questionId, int selected, int isCorrect, String? questionText, String? selectedText, String? correctText
});




}
/// @nodoc
class _$QuizResponseResultCopyWithImpl<$Res>
    implements $QuizResponseResultCopyWith<$Res> {
  _$QuizResponseResultCopyWithImpl(this._self, this._then);

  final QuizResponseResult _self;
  final $Res Function(QuizResponseResult) _then;

/// Create a copy of QuizResponseResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? questionId = null,Object? selected = null,Object? isCorrect = null,Object? questionText = freezed,Object? selectedText = freezed,Object? correctText = freezed,}) {
  return _then(_self.copyWith(
questionId: null == questionId ? _self.questionId : questionId // ignore: cast_nullable_to_non_nullable
as int,selected: null == selected ? _self.selected : selected // ignore: cast_nullable_to_non_nullable
as int,isCorrect: null == isCorrect ? _self.isCorrect : isCorrect // ignore: cast_nullable_to_non_nullable
as int,questionText: freezed == questionText ? _self.questionText : questionText // ignore: cast_nullable_to_non_nullable
as String?,selectedText: freezed == selectedText ? _self.selectedText : selectedText // ignore: cast_nullable_to_non_nullable
as String?,correctText: freezed == correctText ? _self.correctText : correctText // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [QuizResponseResult].
extension QuizResponseResultPatterns on QuizResponseResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QuizResponseResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QuizResponseResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QuizResponseResult value)  $default,){
final _that = this;
switch (_that) {
case _QuizResponseResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QuizResponseResult value)?  $default,){
final _that = this;
switch (_that) {
case _QuizResponseResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int questionId,  int selected,  int isCorrect,  String? questionText,  String? selectedText,  String? correctText)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QuizResponseResult() when $default != null:
return $default(_that.questionId,_that.selected,_that.isCorrect,_that.questionText,_that.selectedText,_that.correctText);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int questionId,  int selected,  int isCorrect,  String? questionText,  String? selectedText,  String? correctText)  $default,) {final _that = this;
switch (_that) {
case _QuizResponseResult():
return $default(_that.questionId,_that.selected,_that.isCorrect,_that.questionText,_that.selectedText,_that.correctText);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int questionId,  int selected,  int isCorrect,  String? questionText,  String? selectedText,  String? correctText)?  $default,) {final _that = this;
switch (_that) {
case _QuizResponseResult() when $default != null:
return $default(_that.questionId,_that.selected,_that.isCorrect,_that.questionText,_that.selectedText,_that.correctText);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _QuizResponseResult implements QuizResponseResult {
  const _QuizResponseResult({required this.questionId, required this.selected, required this.isCorrect, this.questionText, this.selectedText, this.correctText});
  factory _QuizResponseResult.fromJson(Map<String, dynamic> json) => _$QuizResponseResultFromJson(json);

@override final  int questionId;
@override final  int selected;
@override final  int isCorrect;
@override final  String? questionText;
@override final  String? selectedText;
@override final  String? correctText;

/// Create a copy of QuizResponseResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuizResponseResultCopyWith<_QuizResponseResult> get copyWith => __$QuizResponseResultCopyWithImpl<_QuizResponseResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QuizResponseResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QuizResponseResult&&(identical(other.questionId, questionId) || other.questionId == questionId)&&(identical(other.selected, selected) || other.selected == selected)&&(identical(other.isCorrect, isCorrect) || other.isCorrect == isCorrect)&&(identical(other.questionText, questionText) || other.questionText == questionText)&&(identical(other.selectedText, selectedText) || other.selectedText == selectedText)&&(identical(other.correctText, correctText) || other.correctText == correctText));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,questionId,selected,isCorrect,questionText,selectedText,correctText);

@override
String toString() {
  return 'QuizResponseResult(questionId: $questionId, selected: $selected, isCorrect: $isCorrect, questionText: $questionText, selectedText: $selectedText, correctText: $correctText)';
}


}

/// @nodoc
abstract mixin class _$QuizResponseResultCopyWith<$Res> implements $QuizResponseResultCopyWith<$Res> {
  factory _$QuizResponseResultCopyWith(_QuizResponseResult value, $Res Function(_QuizResponseResult) _then) = __$QuizResponseResultCopyWithImpl;
@override @useResult
$Res call({
 int questionId, int selected, int isCorrect, String? questionText, String? selectedText, String? correctText
});




}
/// @nodoc
class __$QuizResponseResultCopyWithImpl<$Res>
    implements _$QuizResponseResultCopyWith<$Res> {
  __$QuizResponseResultCopyWithImpl(this._self, this._then);

  final _QuizResponseResult _self;
  final $Res Function(_QuizResponseResult) _then;

/// Create a copy of QuizResponseResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? questionId = null,Object? selected = null,Object? isCorrect = null,Object? questionText = freezed,Object? selectedText = freezed,Object? correctText = freezed,}) {
  return _then(_QuizResponseResult(
questionId: null == questionId ? _self.questionId : questionId // ignore: cast_nullable_to_non_nullable
as int,selected: null == selected ? _self.selected : selected // ignore: cast_nullable_to_non_nullable
as int,isCorrect: null == isCorrect ? _self.isCorrect : isCorrect // ignore: cast_nullable_to_non_nullable
as int,questionText: freezed == questionText ? _self.questionText : questionText // ignore: cast_nullable_to_non_nullable
as String?,selectedText: freezed == selectedText ? _self.selectedText : selectedText // ignore: cast_nullable_to_non_nullable
as String?,correctText: freezed == correctText ? _self.correctText : correctText // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$QuizScoreHistory {

 int get quizId; String get quizName; String? get topic; int get score; int get total; double get percent;
/// Create a copy of QuizScoreHistory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuizScoreHistoryCopyWith<QuizScoreHistory> get copyWith => _$QuizScoreHistoryCopyWithImpl<QuizScoreHistory>(this as QuizScoreHistory, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuizScoreHistory&&(identical(other.quizId, quizId) || other.quizId == quizId)&&(identical(other.quizName, quizName) || other.quizName == quizName)&&(identical(other.topic, topic) || other.topic == topic)&&(identical(other.score, score) || other.score == score)&&(identical(other.total, total) || other.total == total)&&(identical(other.percent, percent) || other.percent == percent));
}


@override
int get hashCode => Object.hash(runtimeType,quizId,quizName,topic,score,total,percent);

@override
String toString() {
  return 'QuizScoreHistory(quizId: $quizId, quizName: $quizName, topic: $topic, score: $score, total: $total, percent: $percent)';
}


}

/// @nodoc
abstract mixin class $QuizScoreHistoryCopyWith<$Res>  {
  factory $QuizScoreHistoryCopyWith(QuizScoreHistory value, $Res Function(QuizScoreHistory) _then) = _$QuizScoreHistoryCopyWithImpl;
@useResult
$Res call({
 int quizId, String quizName, String? topic, int score, int total, double percent
});




}
/// @nodoc
class _$QuizScoreHistoryCopyWithImpl<$Res>
    implements $QuizScoreHistoryCopyWith<$Res> {
  _$QuizScoreHistoryCopyWithImpl(this._self, this._then);

  final QuizScoreHistory _self;
  final $Res Function(QuizScoreHistory) _then;

/// Create a copy of QuizScoreHistory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? quizId = null,Object? quizName = null,Object? topic = freezed,Object? score = null,Object? total = null,Object? percent = null,}) {
  return _then(_self.copyWith(
quizId: null == quizId ? _self.quizId : quizId // ignore: cast_nullable_to_non_nullable
as int,quizName: null == quizName ? _self.quizName : quizName // ignore: cast_nullable_to_non_nullable
as String,topic: freezed == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String?,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,percent: null == percent ? _self.percent : percent // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [QuizScoreHistory].
extension QuizScoreHistoryPatterns on QuizScoreHistory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QuizScoreHistory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QuizScoreHistory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QuizScoreHistory value)  $default,){
final _that = this;
switch (_that) {
case _QuizScoreHistory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QuizScoreHistory value)?  $default,){
final _that = this;
switch (_that) {
case _QuizScoreHistory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int quizId,  String quizName,  String? topic,  int score,  int total,  double percent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QuizScoreHistory() when $default != null:
return $default(_that.quizId,_that.quizName,_that.topic,_that.score,_that.total,_that.percent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int quizId,  String quizName,  String? topic,  int score,  int total,  double percent)  $default,) {final _that = this;
switch (_that) {
case _QuizScoreHistory():
return $default(_that.quizId,_that.quizName,_that.topic,_that.score,_that.total,_that.percent);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int quizId,  String quizName,  String? topic,  int score,  int total,  double percent)?  $default,) {final _that = this;
switch (_that) {
case _QuizScoreHistory() when $default != null:
return $default(_that.quizId,_that.quizName,_that.topic,_that.score,_that.total,_that.percent);case _:
  return null;

}
}

}

/// @nodoc


class _QuizScoreHistory extends QuizScoreHistory {
  const _QuizScoreHistory({required this.quizId, required this.quizName, this.topic, required this.score, required this.total, required this.percent}): super._();
  

@override final  int quizId;
@override final  String quizName;
@override final  String? topic;
@override final  int score;
@override final  int total;
@override final  double percent;

/// Create a copy of QuizScoreHistory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuizScoreHistoryCopyWith<_QuizScoreHistory> get copyWith => __$QuizScoreHistoryCopyWithImpl<_QuizScoreHistory>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QuizScoreHistory&&(identical(other.quizId, quizId) || other.quizId == quizId)&&(identical(other.quizName, quizName) || other.quizName == quizName)&&(identical(other.topic, topic) || other.topic == topic)&&(identical(other.score, score) || other.score == score)&&(identical(other.total, total) || other.total == total)&&(identical(other.percent, percent) || other.percent == percent));
}


@override
int get hashCode => Object.hash(runtimeType,quizId,quizName,topic,score,total,percent);

@override
String toString() {
  return 'QuizScoreHistory(quizId: $quizId, quizName: $quizName, topic: $topic, score: $score, total: $total, percent: $percent)';
}


}

/// @nodoc
abstract mixin class _$QuizScoreHistoryCopyWith<$Res> implements $QuizScoreHistoryCopyWith<$Res> {
  factory _$QuizScoreHistoryCopyWith(_QuizScoreHistory value, $Res Function(_QuizScoreHistory) _then) = __$QuizScoreHistoryCopyWithImpl;
@override @useResult
$Res call({
 int quizId, String quizName, String? topic, int score, int total, double percent
});




}
/// @nodoc
class __$QuizScoreHistoryCopyWithImpl<$Res>
    implements _$QuizScoreHistoryCopyWith<$Res> {
  __$QuizScoreHistoryCopyWithImpl(this._self, this._then);

  final _QuizScoreHistory _self;
  final $Res Function(_QuizScoreHistory) _then;

/// Create a copy of QuizScoreHistory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? quizId = null,Object? quizName = null,Object? topic = freezed,Object? score = null,Object? total = null,Object? percent = null,}) {
  return _then(_QuizScoreHistory(
quizId: null == quizId ? _self.quizId : quizId // ignore: cast_nullable_to_non_nullable
as int,quizName: null == quizName ? _self.quizName : quizName // ignore: cast_nullable_to_non_nullable
as String,topic: freezed == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String?,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,percent: null == percent ? _self.percent : percent // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
