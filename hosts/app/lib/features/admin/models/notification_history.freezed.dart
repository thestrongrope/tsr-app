// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_history.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NotificationHistory {

@JsonKey(name: 'notification_id') int get notificationId; String get title; String get body;@JsonKey(name: 'target_audience_criteria') TargetAudienceCriteria get targetAudienceCriteria;@JsonKey(name: 'device_count') int get deviceCount;@JsonKey(name: 'success_count') int get successCount;@JsonKey(name: 'failure_count') int get failureCount;@JsonKey(name: 'sent_at') String get sentAt;@JsonKey(name: 'sender_name') String get senderName;@JsonKey(name: 'sender_email') String get senderEmail;/// Where the notification opens in the app, when it has a link.
@JsonKey(name: 'action_link') String? get actionLink;/// Who it went to, in words ("Students of a class"), then the classes,
/// levels or teacher by name. Empty when an older server does not send it.
@JsonKey(name: 'audience_summary') String get audienceSummary;@JsonKey(name: 'audience_items') List<String> get audienceItems;/// How many people have it in their inbox.
@JsonKey(name: 'recipient_count') int get recipientCount;
/// Create a copy of NotificationHistory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationHistoryCopyWith<NotificationHistory> get copyWith => _$NotificationHistoryCopyWithImpl<NotificationHistory>(this as NotificationHistory, _$identity);

  /// Serializes this NotificationHistory to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationHistory&&(identical(other.notificationId, notificationId) || other.notificationId == notificationId)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.targetAudienceCriteria, targetAudienceCriteria) || other.targetAudienceCriteria == targetAudienceCriteria)&&(identical(other.deviceCount, deviceCount) || other.deviceCount == deviceCount)&&(identical(other.successCount, successCount) || other.successCount == successCount)&&(identical(other.failureCount, failureCount) || other.failureCount == failureCount)&&(identical(other.sentAt, sentAt) || other.sentAt == sentAt)&&(identical(other.senderName, senderName) || other.senderName == senderName)&&(identical(other.senderEmail, senderEmail) || other.senderEmail == senderEmail)&&(identical(other.actionLink, actionLink) || other.actionLink == actionLink)&&(identical(other.audienceSummary, audienceSummary) || other.audienceSummary == audienceSummary)&&const DeepCollectionEquality().equals(other.audienceItems, audienceItems)&&(identical(other.recipientCount, recipientCount) || other.recipientCount == recipientCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,notificationId,title,body,targetAudienceCriteria,deviceCount,successCount,failureCount,sentAt,senderName,senderEmail,actionLink,audienceSummary,const DeepCollectionEquality().hash(audienceItems),recipientCount);

@override
String toString() {
  return 'NotificationHistory(notificationId: $notificationId, title: $title, body: $body, targetAudienceCriteria: $targetAudienceCriteria, deviceCount: $deviceCount, successCount: $successCount, failureCount: $failureCount, sentAt: $sentAt, senderName: $senderName, senderEmail: $senderEmail, actionLink: $actionLink, audienceSummary: $audienceSummary, audienceItems: $audienceItems, recipientCount: $recipientCount)';
}


}

/// @nodoc
abstract mixin class $NotificationHistoryCopyWith<$Res>  {
  factory $NotificationHistoryCopyWith(NotificationHistory value, $Res Function(NotificationHistory) _then) = _$NotificationHistoryCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'notification_id') int notificationId, String title, String body,@JsonKey(name: 'target_audience_criteria') TargetAudienceCriteria targetAudienceCriteria,@JsonKey(name: 'device_count') int deviceCount,@JsonKey(name: 'success_count') int successCount,@JsonKey(name: 'failure_count') int failureCount,@JsonKey(name: 'sent_at') String sentAt,@JsonKey(name: 'sender_name') String senderName,@JsonKey(name: 'sender_email') String senderEmail,@JsonKey(name: 'action_link') String? actionLink,@JsonKey(name: 'audience_summary') String audienceSummary,@JsonKey(name: 'audience_items') List<String> audienceItems,@JsonKey(name: 'recipient_count') int recipientCount
});


$TargetAudienceCriteriaCopyWith<$Res> get targetAudienceCriteria;

}
/// @nodoc
class _$NotificationHistoryCopyWithImpl<$Res>
    implements $NotificationHistoryCopyWith<$Res> {
  _$NotificationHistoryCopyWithImpl(this._self, this._then);

  final NotificationHistory _self;
  final $Res Function(NotificationHistory) _then;

/// Create a copy of NotificationHistory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? notificationId = null,Object? title = null,Object? body = null,Object? targetAudienceCriteria = null,Object? deviceCount = null,Object? successCount = null,Object? failureCount = null,Object? sentAt = null,Object? senderName = null,Object? senderEmail = null,Object? actionLink = freezed,Object? audienceSummary = null,Object? audienceItems = null,Object? recipientCount = null,}) {
  return _then(_self.copyWith(
notificationId: null == notificationId ? _self.notificationId : notificationId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,targetAudienceCriteria: null == targetAudienceCriteria ? _self.targetAudienceCriteria : targetAudienceCriteria // ignore: cast_nullable_to_non_nullable
as TargetAudienceCriteria,deviceCount: null == deviceCount ? _self.deviceCount : deviceCount // ignore: cast_nullable_to_non_nullable
as int,successCount: null == successCount ? _self.successCount : successCount // ignore: cast_nullable_to_non_nullable
as int,failureCount: null == failureCount ? _self.failureCount : failureCount // ignore: cast_nullable_to_non_nullable
as int,sentAt: null == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as String,senderName: null == senderName ? _self.senderName : senderName // ignore: cast_nullable_to_non_nullable
as String,senderEmail: null == senderEmail ? _self.senderEmail : senderEmail // ignore: cast_nullable_to_non_nullable
as String,actionLink: freezed == actionLink ? _self.actionLink : actionLink // ignore: cast_nullable_to_non_nullable
as String?,audienceSummary: null == audienceSummary ? _self.audienceSummary : audienceSummary // ignore: cast_nullable_to_non_nullable
as String,audienceItems: null == audienceItems ? _self.audienceItems : audienceItems // ignore: cast_nullable_to_non_nullable
as List<String>,recipientCount: null == recipientCount ? _self.recipientCount : recipientCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of NotificationHistory
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TargetAudienceCriteriaCopyWith<$Res> get targetAudienceCriteria {
  
  return $TargetAudienceCriteriaCopyWith<$Res>(_self.targetAudienceCriteria, (value) {
    return _then(_self.copyWith(targetAudienceCriteria: value));
  });
}
}


/// Adds pattern-matching-related methods to [NotificationHistory].
extension NotificationHistoryPatterns on NotificationHistory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationHistory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationHistory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationHistory value)  $default,){
final _that = this;
switch (_that) {
case _NotificationHistory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationHistory value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationHistory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'notification_id')  int notificationId,  String title,  String body, @JsonKey(name: 'target_audience_criteria')  TargetAudienceCriteria targetAudienceCriteria, @JsonKey(name: 'device_count')  int deviceCount, @JsonKey(name: 'success_count')  int successCount, @JsonKey(name: 'failure_count')  int failureCount, @JsonKey(name: 'sent_at')  String sentAt, @JsonKey(name: 'sender_name')  String senderName, @JsonKey(name: 'sender_email')  String senderEmail, @JsonKey(name: 'action_link')  String? actionLink, @JsonKey(name: 'audience_summary')  String audienceSummary, @JsonKey(name: 'audience_items')  List<String> audienceItems, @JsonKey(name: 'recipient_count')  int recipientCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationHistory() when $default != null:
return $default(_that.notificationId,_that.title,_that.body,_that.targetAudienceCriteria,_that.deviceCount,_that.successCount,_that.failureCount,_that.sentAt,_that.senderName,_that.senderEmail,_that.actionLink,_that.audienceSummary,_that.audienceItems,_that.recipientCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'notification_id')  int notificationId,  String title,  String body, @JsonKey(name: 'target_audience_criteria')  TargetAudienceCriteria targetAudienceCriteria, @JsonKey(name: 'device_count')  int deviceCount, @JsonKey(name: 'success_count')  int successCount, @JsonKey(name: 'failure_count')  int failureCount, @JsonKey(name: 'sent_at')  String sentAt, @JsonKey(name: 'sender_name')  String senderName, @JsonKey(name: 'sender_email')  String senderEmail, @JsonKey(name: 'action_link')  String? actionLink, @JsonKey(name: 'audience_summary')  String audienceSummary, @JsonKey(name: 'audience_items')  List<String> audienceItems, @JsonKey(name: 'recipient_count')  int recipientCount)  $default,) {final _that = this;
switch (_that) {
case _NotificationHistory():
return $default(_that.notificationId,_that.title,_that.body,_that.targetAudienceCriteria,_that.deviceCount,_that.successCount,_that.failureCount,_that.sentAt,_that.senderName,_that.senderEmail,_that.actionLink,_that.audienceSummary,_that.audienceItems,_that.recipientCount);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'notification_id')  int notificationId,  String title,  String body, @JsonKey(name: 'target_audience_criteria')  TargetAudienceCriteria targetAudienceCriteria, @JsonKey(name: 'device_count')  int deviceCount, @JsonKey(name: 'success_count')  int successCount, @JsonKey(name: 'failure_count')  int failureCount, @JsonKey(name: 'sent_at')  String sentAt, @JsonKey(name: 'sender_name')  String senderName, @JsonKey(name: 'sender_email')  String senderEmail, @JsonKey(name: 'action_link')  String? actionLink, @JsonKey(name: 'audience_summary')  String audienceSummary, @JsonKey(name: 'audience_items')  List<String> audienceItems, @JsonKey(name: 'recipient_count')  int recipientCount)?  $default,) {final _that = this;
switch (_that) {
case _NotificationHistory() when $default != null:
return $default(_that.notificationId,_that.title,_that.body,_that.targetAudienceCriteria,_that.deviceCount,_that.successCount,_that.failureCount,_that.sentAt,_that.senderName,_that.senderEmail,_that.actionLink,_that.audienceSummary,_that.audienceItems,_that.recipientCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NotificationHistory implements NotificationHistory {
  const _NotificationHistory({@JsonKey(name: 'notification_id') required this.notificationId, required this.title, required this.body, @JsonKey(name: 'target_audience_criteria') required this.targetAudienceCriteria, @JsonKey(name: 'device_count') required this.deviceCount, @JsonKey(name: 'success_count') required this.successCount, @JsonKey(name: 'failure_count') required this.failureCount, @JsonKey(name: 'sent_at') required this.sentAt, @JsonKey(name: 'sender_name') required this.senderName, @JsonKey(name: 'sender_email') required this.senderEmail, @JsonKey(name: 'action_link') this.actionLink, @JsonKey(name: 'audience_summary') this.audienceSummary = '', @JsonKey(name: 'audience_items') final  List<String> audienceItems = const [], @JsonKey(name: 'recipient_count') this.recipientCount = 0}): _audienceItems = audienceItems;
  factory _NotificationHistory.fromJson(Map<String, dynamic> json) => _$NotificationHistoryFromJson(json);

@override@JsonKey(name: 'notification_id') final  int notificationId;
@override final  String title;
@override final  String body;
@override@JsonKey(name: 'target_audience_criteria') final  TargetAudienceCriteria targetAudienceCriteria;
@override@JsonKey(name: 'device_count') final  int deviceCount;
@override@JsonKey(name: 'success_count') final  int successCount;
@override@JsonKey(name: 'failure_count') final  int failureCount;
@override@JsonKey(name: 'sent_at') final  String sentAt;
@override@JsonKey(name: 'sender_name') final  String senderName;
@override@JsonKey(name: 'sender_email') final  String senderEmail;
/// Where the notification opens in the app, when it has a link.
@override@JsonKey(name: 'action_link') final  String? actionLink;
/// Who it went to, in words ("Students of a class"), then the classes,
/// levels or teacher by name. Empty when an older server does not send it.
@override@JsonKey(name: 'audience_summary') final  String audienceSummary;
 final  List<String> _audienceItems;
@override@JsonKey(name: 'audience_items') List<String> get audienceItems {
  if (_audienceItems is EqualUnmodifiableListView) return _audienceItems;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_audienceItems);
}

/// How many people have it in their inbox.
@override@JsonKey(name: 'recipient_count') final  int recipientCount;

/// Create a copy of NotificationHistory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationHistoryCopyWith<_NotificationHistory> get copyWith => __$NotificationHistoryCopyWithImpl<_NotificationHistory>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationHistoryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationHistory&&(identical(other.notificationId, notificationId) || other.notificationId == notificationId)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.targetAudienceCriteria, targetAudienceCriteria) || other.targetAudienceCriteria == targetAudienceCriteria)&&(identical(other.deviceCount, deviceCount) || other.deviceCount == deviceCount)&&(identical(other.successCount, successCount) || other.successCount == successCount)&&(identical(other.failureCount, failureCount) || other.failureCount == failureCount)&&(identical(other.sentAt, sentAt) || other.sentAt == sentAt)&&(identical(other.senderName, senderName) || other.senderName == senderName)&&(identical(other.senderEmail, senderEmail) || other.senderEmail == senderEmail)&&(identical(other.actionLink, actionLink) || other.actionLink == actionLink)&&(identical(other.audienceSummary, audienceSummary) || other.audienceSummary == audienceSummary)&&const DeepCollectionEquality().equals(other._audienceItems, _audienceItems)&&(identical(other.recipientCount, recipientCount) || other.recipientCount == recipientCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,notificationId,title,body,targetAudienceCriteria,deviceCount,successCount,failureCount,sentAt,senderName,senderEmail,actionLink,audienceSummary,const DeepCollectionEquality().hash(_audienceItems),recipientCount);

@override
String toString() {
  return 'NotificationHistory(notificationId: $notificationId, title: $title, body: $body, targetAudienceCriteria: $targetAudienceCriteria, deviceCount: $deviceCount, successCount: $successCount, failureCount: $failureCount, sentAt: $sentAt, senderName: $senderName, senderEmail: $senderEmail, actionLink: $actionLink, audienceSummary: $audienceSummary, audienceItems: $audienceItems, recipientCount: $recipientCount)';
}


}

/// @nodoc
abstract mixin class _$NotificationHistoryCopyWith<$Res> implements $NotificationHistoryCopyWith<$Res> {
  factory _$NotificationHistoryCopyWith(_NotificationHistory value, $Res Function(_NotificationHistory) _then) = __$NotificationHistoryCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'notification_id') int notificationId, String title, String body,@JsonKey(name: 'target_audience_criteria') TargetAudienceCriteria targetAudienceCriteria,@JsonKey(name: 'device_count') int deviceCount,@JsonKey(name: 'success_count') int successCount,@JsonKey(name: 'failure_count') int failureCount,@JsonKey(name: 'sent_at') String sentAt,@JsonKey(name: 'sender_name') String senderName,@JsonKey(name: 'sender_email') String senderEmail,@JsonKey(name: 'action_link') String? actionLink,@JsonKey(name: 'audience_summary') String audienceSummary,@JsonKey(name: 'audience_items') List<String> audienceItems,@JsonKey(name: 'recipient_count') int recipientCount
});


@override $TargetAudienceCriteriaCopyWith<$Res> get targetAudienceCriteria;

}
/// @nodoc
class __$NotificationHistoryCopyWithImpl<$Res>
    implements _$NotificationHistoryCopyWith<$Res> {
  __$NotificationHistoryCopyWithImpl(this._self, this._then);

  final _NotificationHistory _self;
  final $Res Function(_NotificationHistory) _then;

/// Create a copy of NotificationHistory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? notificationId = null,Object? title = null,Object? body = null,Object? targetAudienceCriteria = null,Object? deviceCount = null,Object? successCount = null,Object? failureCount = null,Object? sentAt = null,Object? senderName = null,Object? senderEmail = null,Object? actionLink = freezed,Object? audienceSummary = null,Object? audienceItems = null,Object? recipientCount = null,}) {
  return _then(_NotificationHistory(
notificationId: null == notificationId ? _self.notificationId : notificationId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,targetAudienceCriteria: null == targetAudienceCriteria ? _self.targetAudienceCriteria : targetAudienceCriteria // ignore: cast_nullable_to_non_nullable
as TargetAudienceCriteria,deviceCount: null == deviceCount ? _self.deviceCount : deviceCount // ignore: cast_nullable_to_non_nullable
as int,successCount: null == successCount ? _self.successCount : successCount // ignore: cast_nullable_to_non_nullable
as int,failureCount: null == failureCount ? _self.failureCount : failureCount // ignore: cast_nullable_to_non_nullable
as int,sentAt: null == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as String,senderName: null == senderName ? _self.senderName : senderName // ignore: cast_nullable_to_non_nullable
as String,senderEmail: null == senderEmail ? _self.senderEmail : senderEmail // ignore: cast_nullable_to_non_nullable
as String,actionLink: freezed == actionLink ? _self.actionLink : actionLink // ignore: cast_nullable_to_non_nullable
as String?,audienceSummary: null == audienceSummary ? _self.audienceSummary : audienceSummary // ignore: cast_nullable_to_non_nullable
as String,audienceItems: null == audienceItems ? _self._audienceItems : audienceItems // ignore: cast_nullable_to_non_nullable
as List<String>,recipientCount: null == recipientCount ? _self.recipientCount : recipientCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of NotificationHistory
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TargetAudienceCriteriaCopyWith<$Res> get targetAudienceCriteria {
  
  return $TargetAudienceCriteriaCopyWith<$Res>(_self.targetAudienceCriteria, (value) {
    return _then(_self.copyWith(targetAudienceCriteria: value));
  });
}
}


/// @nodoc
mixin _$TargetAudienceCriteria {

 String get type; List<String>? get value;
/// Create a copy of TargetAudienceCriteria
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TargetAudienceCriteriaCopyWith<TargetAudienceCriteria> get copyWith => _$TargetAudienceCriteriaCopyWithImpl<TargetAudienceCriteria>(this as TargetAudienceCriteria, _$identity);

  /// Serializes this TargetAudienceCriteria to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TargetAudienceCriteria&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.value, value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,const DeepCollectionEquality().hash(value));

@override
String toString() {
  return 'TargetAudienceCriteria(type: $type, value: $value)';
}


}

/// @nodoc
abstract mixin class $TargetAudienceCriteriaCopyWith<$Res>  {
  factory $TargetAudienceCriteriaCopyWith(TargetAudienceCriteria value, $Res Function(TargetAudienceCriteria) _then) = _$TargetAudienceCriteriaCopyWithImpl;
@useResult
$Res call({
 String type, List<String>? value
});




}
/// @nodoc
class _$TargetAudienceCriteriaCopyWithImpl<$Res>
    implements $TargetAudienceCriteriaCopyWith<$Res> {
  _$TargetAudienceCriteriaCopyWithImpl(this._self, this._then);

  final TargetAudienceCriteria _self;
  final $Res Function(TargetAudienceCriteria) _then;

/// Create a copy of TargetAudienceCriteria
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? value = freezed,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}

}


/// Adds pattern-matching-related methods to [TargetAudienceCriteria].
extension TargetAudienceCriteriaPatterns on TargetAudienceCriteria {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TargetAudienceCriteria value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TargetAudienceCriteria() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TargetAudienceCriteria value)  $default,){
final _that = this;
switch (_that) {
case _TargetAudienceCriteria():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TargetAudienceCriteria value)?  $default,){
final _that = this;
switch (_that) {
case _TargetAudienceCriteria() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  List<String>? value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TargetAudienceCriteria() when $default != null:
return $default(_that.type,_that.value);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  List<String>? value)  $default,) {final _that = this;
switch (_that) {
case _TargetAudienceCriteria():
return $default(_that.type,_that.value);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  List<String>? value)?  $default,) {final _that = this;
switch (_that) {
case _TargetAudienceCriteria() when $default != null:
return $default(_that.type,_that.value);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TargetAudienceCriteria implements TargetAudienceCriteria {
  const _TargetAudienceCriteria({required this.type, final  List<String>? value}): _value = value;
  factory _TargetAudienceCriteria.fromJson(Map<String, dynamic> json) => _$TargetAudienceCriteriaFromJson(json);

@override final  String type;
 final  List<String>? _value;
@override List<String>? get value {
  final value = _value;
  if (value == null) return null;
  if (_value is EqualUnmodifiableListView) return _value;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of TargetAudienceCriteria
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TargetAudienceCriteriaCopyWith<_TargetAudienceCriteria> get copyWith => __$TargetAudienceCriteriaCopyWithImpl<_TargetAudienceCriteria>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TargetAudienceCriteriaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TargetAudienceCriteria&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other._value, _value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,const DeepCollectionEquality().hash(_value));

@override
String toString() {
  return 'TargetAudienceCriteria(type: $type, value: $value)';
}


}

/// @nodoc
abstract mixin class _$TargetAudienceCriteriaCopyWith<$Res> implements $TargetAudienceCriteriaCopyWith<$Res> {
  factory _$TargetAudienceCriteriaCopyWith(_TargetAudienceCriteria value, $Res Function(_TargetAudienceCriteria) _then) = __$TargetAudienceCriteriaCopyWithImpl;
@override @useResult
$Res call({
 String type, List<String>? value
});




}
/// @nodoc
class __$TargetAudienceCriteriaCopyWithImpl<$Res>
    implements _$TargetAudienceCriteriaCopyWith<$Res> {
  __$TargetAudienceCriteriaCopyWithImpl(this._self, this._then);

  final _TargetAudienceCriteria _self;
  final $Res Function(_TargetAudienceCriteria) _then;

/// Create a copy of TargetAudienceCriteria
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? value = freezed,}) {
  return _then(_TargetAudienceCriteria(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self._value : value // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}


}


/// @nodoc
mixin _$NotificationHistoryResponse {

 List<NotificationHistory> get notifications; int get limit; int get offset; int get count;
/// Create a copy of NotificationHistoryResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationHistoryResponseCopyWith<NotificationHistoryResponse> get copyWith => _$NotificationHistoryResponseCopyWithImpl<NotificationHistoryResponse>(this as NotificationHistoryResponse, _$identity);

  /// Serializes this NotificationHistoryResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationHistoryResponse&&const DeepCollectionEquality().equals(other.notifications, notifications)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.offset, offset) || other.offset == offset)&&(identical(other.count, count) || other.count == count));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(notifications),limit,offset,count);

@override
String toString() {
  return 'NotificationHistoryResponse(notifications: $notifications, limit: $limit, offset: $offset, count: $count)';
}


}

/// @nodoc
abstract mixin class $NotificationHistoryResponseCopyWith<$Res>  {
  factory $NotificationHistoryResponseCopyWith(NotificationHistoryResponse value, $Res Function(NotificationHistoryResponse) _then) = _$NotificationHistoryResponseCopyWithImpl;
@useResult
$Res call({
 List<NotificationHistory> notifications, int limit, int offset, int count
});




}
/// @nodoc
class _$NotificationHistoryResponseCopyWithImpl<$Res>
    implements $NotificationHistoryResponseCopyWith<$Res> {
  _$NotificationHistoryResponseCopyWithImpl(this._self, this._then);

  final NotificationHistoryResponse _self;
  final $Res Function(NotificationHistoryResponse) _then;

/// Create a copy of NotificationHistoryResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? notifications = null,Object? limit = null,Object? offset = null,Object? count = null,}) {
  return _then(_self.copyWith(
notifications: null == notifications ? _self.notifications : notifications // ignore: cast_nullable_to_non_nullable
as List<NotificationHistory>,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,offset: null == offset ? _self.offset : offset // ignore: cast_nullable_to_non_nullable
as int,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationHistoryResponse].
extension NotificationHistoryResponsePatterns on NotificationHistoryResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationHistoryResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationHistoryResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationHistoryResponse value)  $default,){
final _that = this;
switch (_that) {
case _NotificationHistoryResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationHistoryResponse value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationHistoryResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<NotificationHistory> notifications,  int limit,  int offset,  int count)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationHistoryResponse() when $default != null:
return $default(_that.notifications,_that.limit,_that.offset,_that.count);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<NotificationHistory> notifications,  int limit,  int offset,  int count)  $default,) {final _that = this;
switch (_that) {
case _NotificationHistoryResponse():
return $default(_that.notifications,_that.limit,_that.offset,_that.count);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<NotificationHistory> notifications,  int limit,  int offset,  int count)?  $default,) {final _that = this;
switch (_that) {
case _NotificationHistoryResponse() when $default != null:
return $default(_that.notifications,_that.limit,_that.offset,_that.count);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NotificationHistoryResponse implements NotificationHistoryResponse {
  const _NotificationHistoryResponse({required final  List<NotificationHistory> notifications, required this.limit, required this.offset, required this.count}): _notifications = notifications;
  factory _NotificationHistoryResponse.fromJson(Map<String, dynamic> json) => _$NotificationHistoryResponseFromJson(json);

 final  List<NotificationHistory> _notifications;
@override List<NotificationHistory> get notifications {
  if (_notifications is EqualUnmodifiableListView) return _notifications;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_notifications);
}

@override final  int limit;
@override final  int offset;
@override final  int count;

/// Create a copy of NotificationHistoryResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationHistoryResponseCopyWith<_NotificationHistoryResponse> get copyWith => __$NotificationHistoryResponseCopyWithImpl<_NotificationHistoryResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationHistoryResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationHistoryResponse&&const DeepCollectionEquality().equals(other._notifications, _notifications)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.offset, offset) || other.offset == offset)&&(identical(other.count, count) || other.count == count));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_notifications),limit,offset,count);

@override
String toString() {
  return 'NotificationHistoryResponse(notifications: $notifications, limit: $limit, offset: $offset, count: $count)';
}


}

/// @nodoc
abstract mixin class _$NotificationHistoryResponseCopyWith<$Res> implements $NotificationHistoryResponseCopyWith<$Res> {
  factory _$NotificationHistoryResponseCopyWith(_NotificationHistoryResponse value, $Res Function(_NotificationHistoryResponse) _then) = __$NotificationHistoryResponseCopyWithImpl;
@override @useResult
$Res call({
 List<NotificationHistory> notifications, int limit, int offset, int count
});




}
/// @nodoc
class __$NotificationHistoryResponseCopyWithImpl<$Res>
    implements _$NotificationHistoryResponseCopyWith<$Res> {
  __$NotificationHistoryResponseCopyWithImpl(this._self, this._then);

  final _NotificationHistoryResponse _self;
  final $Res Function(_NotificationHistoryResponse) _then;

/// Create a copy of NotificationHistoryResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? notifications = null,Object? limit = null,Object? offset = null,Object? count = null,}) {
  return _then(_NotificationHistoryResponse(
notifications: null == notifications ? _self._notifications : notifications // ignore: cast_nullable_to_non_nullable
as List<NotificationHistory>,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,offset: null == offset ? _self.offset : offset // ignore: cast_nullable_to_non_nullable
as int,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
