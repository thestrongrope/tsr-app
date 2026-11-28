// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_notification.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserNotification {

 int get id; String get title; String get body; String? get actionLink;@JsonKey(fromJson: _localTime) DateTime get sentAt; bool get isRead;@JsonKey(fromJson: _localTimeOrNull) DateTime? get readAt;/// The classes a reminder covers (#831); empty for any other notification.
 List<NotificationClass> get classes;
/// Create a copy of UserNotification
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserNotificationCopyWith<UserNotification> get copyWith => _$UserNotificationCopyWithImpl<UserNotification>(this as UserNotification, _$identity);

  /// Serializes this UserNotification to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserNotification&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.actionLink, actionLink) || other.actionLink == actionLink)&&(identical(other.sentAt, sentAt) || other.sentAt == sentAt)&&(identical(other.isRead, isRead) || other.isRead == isRead)&&(identical(other.readAt, readAt) || other.readAt == readAt)&&const DeepCollectionEquality().equals(other.classes, classes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,body,actionLink,sentAt,isRead,readAt,const DeepCollectionEquality().hash(classes));

@override
String toString() {
  return 'UserNotification(id: $id, title: $title, body: $body, actionLink: $actionLink, sentAt: $sentAt, isRead: $isRead, readAt: $readAt, classes: $classes)';
}


}

/// @nodoc
abstract mixin class $UserNotificationCopyWith<$Res>  {
  factory $UserNotificationCopyWith(UserNotification value, $Res Function(UserNotification) _then) = _$UserNotificationCopyWithImpl;
@useResult
$Res call({
 int id, String title, String body, String? actionLink,@JsonKey(fromJson: _localTime) DateTime sentAt, bool isRead,@JsonKey(fromJson: _localTimeOrNull) DateTime? readAt, List<NotificationClass> classes
});




}
/// @nodoc
class _$UserNotificationCopyWithImpl<$Res>
    implements $UserNotificationCopyWith<$Res> {
  _$UserNotificationCopyWithImpl(this._self, this._then);

  final UserNotification _self;
  final $Res Function(UserNotification) _then;

/// Create a copy of UserNotification
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? body = null,Object? actionLink = freezed,Object? sentAt = null,Object? isRead = null,Object? readAt = freezed,Object? classes = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,actionLink: freezed == actionLink ? _self.actionLink : actionLink // ignore: cast_nullable_to_non_nullable
as String?,sentAt: null == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as DateTime,isRead: null == isRead ? _self.isRead : isRead // ignore: cast_nullable_to_non_nullable
as bool,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as DateTime?,classes: null == classes ? _self.classes : classes // ignore: cast_nullable_to_non_nullable
as List<NotificationClass>,
  ));
}

}


/// Adds pattern-matching-related methods to [UserNotification].
extension UserNotificationPatterns on UserNotification {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserNotification value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserNotification() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserNotification value)  $default,){
final _that = this;
switch (_that) {
case _UserNotification():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserNotification value)?  $default,){
final _that = this;
switch (_that) {
case _UserNotification() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String title,  String body,  String? actionLink, @JsonKey(fromJson: _localTime)  DateTime sentAt,  bool isRead, @JsonKey(fromJson: _localTimeOrNull)  DateTime? readAt,  List<NotificationClass> classes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserNotification() when $default != null:
return $default(_that.id,_that.title,_that.body,_that.actionLink,_that.sentAt,_that.isRead,_that.readAt,_that.classes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String title,  String body,  String? actionLink, @JsonKey(fromJson: _localTime)  DateTime sentAt,  bool isRead, @JsonKey(fromJson: _localTimeOrNull)  DateTime? readAt,  List<NotificationClass> classes)  $default,) {final _that = this;
switch (_that) {
case _UserNotification():
return $default(_that.id,_that.title,_that.body,_that.actionLink,_that.sentAt,_that.isRead,_that.readAt,_that.classes);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String title,  String body,  String? actionLink, @JsonKey(fromJson: _localTime)  DateTime sentAt,  bool isRead, @JsonKey(fromJson: _localTimeOrNull)  DateTime? readAt,  List<NotificationClass> classes)?  $default,) {final _that = this;
switch (_that) {
case _UserNotification() when $default != null:
return $default(_that.id,_that.title,_that.body,_that.actionLink,_that.sentAt,_that.isRead,_that.readAt,_that.classes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserNotification implements UserNotification {
  const _UserNotification({required this.id, required this.title, required this.body, this.actionLink, @JsonKey(fromJson: _localTime) required this.sentAt, this.isRead = false, @JsonKey(fromJson: _localTimeOrNull) this.readAt, final  List<NotificationClass> classes = const []}): _classes = classes;
  factory _UserNotification.fromJson(Map<String, dynamic> json) => _$UserNotificationFromJson(json);

@override final  int id;
@override final  String title;
@override final  String body;
@override final  String? actionLink;
@override@JsonKey(fromJson: _localTime) final  DateTime sentAt;
@override@JsonKey() final  bool isRead;
@override@JsonKey(fromJson: _localTimeOrNull) final  DateTime? readAt;
/// The classes a reminder covers (#831); empty for any other notification.
 final  List<NotificationClass> _classes;
/// The classes a reminder covers (#831); empty for any other notification.
@override@JsonKey() List<NotificationClass> get classes {
  if (_classes is EqualUnmodifiableListView) return _classes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_classes);
}


/// Create a copy of UserNotification
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserNotificationCopyWith<_UserNotification> get copyWith => __$UserNotificationCopyWithImpl<_UserNotification>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserNotificationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserNotification&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.actionLink, actionLink) || other.actionLink == actionLink)&&(identical(other.sentAt, sentAt) || other.sentAt == sentAt)&&(identical(other.isRead, isRead) || other.isRead == isRead)&&(identical(other.readAt, readAt) || other.readAt == readAt)&&const DeepCollectionEquality().equals(other._classes, _classes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,body,actionLink,sentAt,isRead,readAt,const DeepCollectionEquality().hash(_classes));

@override
String toString() {
  return 'UserNotification(id: $id, title: $title, body: $body, actionLink: $actionLink, sentAt: $sentAt, isRead: $isRead, readAt: $readAt, classes: $classes)';
}


}

/// @nodoc
abstract mixin class _$UserNotificationCopyWith<$Res> implements $UserNotificationCopyWith<$Res> {
  factory _$UserNotificationCopyWith(_UserNotification value, $Res Function(_UserNotification) _then) = __$UserNotificationCopyWithImpl;
@override @useResult
$Res call({
 int id, String title, String body, String? actionLink,@JsonKey(fromJson: _localTime) DateTime sentAt, bool isRead,@JsonKey(fromJson: _localTimeOrNull) DateTime? readAt, List<NotificationClass> classes
});




}
/// @nodoc
class __$UserNotificationCopyWithImpl<$Res>
    implements _$UserNotificationCopyWith<$Res> {
  __$UserNotificationCopyWithImpl(this._self, this._then);

  final _UserNotification _self;
  final $Res Function(_UserNotification) _then;

/// Create a copy of UserNotification
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? body = null,Object? actionLink = freezed,Object? sentAt = null,Object? isRead = null,Object? readAt = freezed,Object? classes = null,}) {
  return _then(_UserNotification(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,actionLink: freezed == actionLink ? _self.actionLink : actionLink // ignore: cast_nullable_to_non_nullable
as String?,sentAt: null == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as DateTime,isRead: null == isRead ? _self.isRead : isRead // ignore: cast_nullable_to_non_nullable
as bool,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as DateTime?,classes: null == classes ? _self._classes : classes // ignore: cast_nullable_to_non_nullable
as List<NotificationClass>,
  ));
}


}


/// @nodoc
mixin _$NotificationClass {

 int get id; String get name;
/// Create a copy of NotificationClass
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationClassCopyWith<NotificationClass> get copyWith => _$NotificationClassCopyWithImpl<NotificationClass>(this as NotificationClass, _$identity);

  /// Serializes this NotificationClass to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationClass&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name);

@override
String toString() {
  return 'NotificationClass(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class $NotificationClassCopyWith<$Res>  {
  factory $NotificationClassCopyWith(NotificationClass value, $Res Function(NotificationClass) _then) = _$NotificationClassCopyWithImpl;
@useResult
$Res call({
 int id, String name
});




}
/// @nodoc
class _$NotificationClassCopyWithImpl<$Res>
    implements $NotificationClassCopyWith<$Res> {
  _$NotificationClassCopyWithImpl(this._self, this._then);

  final NotificationClass _self;
  final $Res Function(NotificationClass) _then;

/// Create a copy of NotificationClass
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationClass].
extension NotificationClassPatterns on NotificationClass {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationClass value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationClass() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationClass value)  $default,){
final _that = this;
switch (_that) {
case _NotificationClass():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationClass value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationClass() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationClass() when $default != null:
return $default(_that.id,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name)  $default,) {final _that = this;
switch (_that) {
case _NotificationClass():
return $default(_that.id,_that.name);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name)?  $default,) {final _that = this;
switch (_that) {
case _NotificationClass() when $default != null:
return $default(_that.id,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NotificationClass implements NotificationClass {
  const _NotificationClass({required this.id, required this.name});
  factory _NotificationClass.fromJson(Map<String, dynamic> json) => _$NotificationClassFromJson(json);

@override final  int id;
@override final  String name;

/// Create a copy of NotificationClass
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationClassCopyWith<_NotificationClass> get copyWith => __$NotificationClassCopyWithImpl<_NotificationClass>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationClassToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationClass&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name);

@override
String toString() {
  return 'NotificationClass(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class _$NotificationClassCopyWith<$Res> implements $NotificationClassCopyWith<$Res> {
  factory _$NotificationClassCopyWith(_NotificationClass value, $Res Function(_NotificationClass) _then) = __$NotificationClassCopyWithImpl;
@override @useResult
$Res call({
 int id, String name
});




}
/// @nodoc
class __$NotificationClassCopyWithImpl<$Res>
    implements _$NotificationClassCopyWith<$Res> {
  __$NotificationClassCopyWithImpl(this._self, this._then);

  final _NotificationClass _self;
  final $Res Function(_NotificationClass) _then;

/// Create a copy of NotificationClass
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,}) {
  return _then(_NotificationClass(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$UserNotificationsResponse {

 List<UserNotification> get notifications; int get total; int get unreadCount; int get limit; int get offset;
/// Create a copy of UserNotificationsResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserNotificationsResponseCopyWith<UserNotificationsResponse> get copyWith => _$UserNotificationsResponseCopyWithImpl<UserNotificationsResponse>(this as UserNotificationsResponse, _$identity);

  /// Serializes this UserNotificationsResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserNotificationsResponse&&const DeepCollectionEquality().equals(other.notifications, notifications)&&(identical(other.total, total) || other.total == total)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.offset, offset) || other.offset == offset));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(notifications),total,unreadCount,limit,offset);

@override
String toString() {
  return 'UserNotificationsResponse(notifications: $notifications, total: $total, unreadCount: $unreadCount, limit: $limit, offset: $offset)';
}


}

/// @nodoc
abstract mixin class $UserNotificationsResponseCopyWith<$Res>  {
  factory $UserNotificationsResponseCopyWith(UserNotificationsResponse value, $Res Function(UserNotificationsResponse) _then) = _$UserNotificationsResponseCopyWithImpl;
@useResult
$Res call({
 List<UserNotification> notifications, int total, int unreadCount, int limit, int offset
});




}
/// @nodoc
class _$UserNotificationsResponseCopyWithImpl<$Res>
    implements $UserNotificationsResponseCopyWith<$Res> {
  _$UserNotificationsResponseCopyWithImpl(this._self, this._then);

  final UserNotificationsResponse _self;
  final $Res Function(UserNotificationsResponse) _then;

/// Create a copy of UserNotificationsResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? notifications = null,Object? total = null,Object? unreadCount = null,Object? limit = null,Object? offset = null,}) {
  return _then(_self.copyWith(
notifications: null == notifications ? _self.notifications : notifications // ignore: cast_nullable_to_non_nullable
as List<UserNotification>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,offset: null == offset ? _self.offset : offset // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UserNotificationsResponse].
extension UserNotificationsResponsePatterns on UserNotificationsResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserNotificationsResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserNotificationsResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserNotificationsResponse value)  $default,){
final _that = this;
switch (_that) {
case _UserNotificationsResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserNotificationsResponse value)?  $default,){
final _that = this;
switch (_that) {
case _UserNotificationsResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<UserNotification> notifications,  int total,  int unreadCount,  int limit,  int offset)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserNotificationsResponse() when $default != null:
return $default(_that.notifications,_that.total,_that.unreadCount,_that.limit,_that.offset);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<UserNotification> notifications,  int total,  int unreadCount,  int limit,  int offset)  $default,) {final _that = this;
switch (_that) {
case _UserNotificationsResponse():
return $default(_that.notifications,_that.total,_that.unreadCount,_that.limit,_that.offset);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<UserNotification> notifications,  int total,  int unreadCount,  int limit,  int offset)?  $default,) {final _that = this;
switch (_that) {
case _UserNotificationsResponse() when $default != null:
return $default(_that.notifications,_that.total,_that.unreadCount,_that.limit,_that.offset);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserNotificationsResponse implements UserNotificationsResponse {
  const _UserNotificationsResponse({required final  List<UserNotification> notifications, required this.total, required this.unreadCount, required this.limit, required this.offset}): _notifications = notifications;
  factory _UserNotificationsResponse.fromJson(Map<String, dynamic> json) => _$UserNotificationsResponseFromJson(json);

 final  List<UserNotification> _notifications;
@override List<UserNotification> get notifications {
  if (_notifications is EqualUnmodifiableListView) return _notifications;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_notifications);
}

@override final  int total;
@override final  int unreadCount;
@override final  int limit;
@override final  int offset;

/// Create a copy of UserNotificationsResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserNotificationsResponseCopyWith<_UserNotificationsResponse> get copyWith => __$UserNotificationsResponseCopyWithImpl<_UserNotificationsResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserNotificationsResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserNotificationsResponse&&const DeepCollectionEquality().equals(other._notifications, _notifications)&&(identical(other.total, total) || other.total == total)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.offset, offset) || other.offset == offset));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_notifications),total,unreadCount,limit,offset);

@override
String toString() {
  return 'UserNotificationsResponse(notifications: $notifications, total: $total, unreadCount: $unreadCount, limit: $limit, offset: $offset)';
}


}

/// @nodoc
abstract mixin class _$UserNotificationsResponseCopyWith<$Res> implements $UserNotificationsResponseCopyWith<$Res> {
  factory _$UserNotificationsResponseCopyWith(_UserNotificationsResponse value, $Res Function(_UserNotificationsResponse) _then) = __$UserNotificationsResponseCopyWithImpl;
@override @useResult
$Res call({
 List<UserNotification> notifications, int total, int unreadCount, int limit, int offset
});




}
/// @nodoc
class __$UserNotificationsResponseCopyWithImpl<$Res>
    implements _$UserNotificationsResponseCopyWith<$Res> {
  __$UserNotificationsResponseCopyWithImpl(this._self, this._then);

  final _UserNotificationsResponse _self;
  final $Res Function(_UserNotificationsResponse) _then;

/// Create a copy of UserNotificationsResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? notifications = null,Object? total = null,Object? unreadCount = null,Object? limit = null,Object? offset = null,}) {
  return _then(_UserNotificationsResponse(
notifications: null == notifications ? _self._notifications : notifications // ignore: cast_nullable_to_non_nullable
as List<UserNotification>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,offset: null == offset ? _self.offset : offset // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
