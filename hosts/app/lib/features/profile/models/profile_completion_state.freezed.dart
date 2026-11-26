// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_completion_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProfileCompletionState {

 ProfileCompletionStatus get status; ProfileFormData get formData; String? get error; int get currentStep;
/// Create a copy of ProfileCompletionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileCompletionStateCopyWith<ProfileCompletionState> get copyWith => _$ProfileCompletionStateCopyWithImpl<ProfileCompletionState>(this as ProfileCompletionState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileCompletionState&&(identical(other.status, status) || other.status == status)&&(identical(other.formData, formData) || other.formData == formData)&&(identical(other.error, error) || other.error == error)&&(identical(other.currentStep, currentStep) || other.currentStep == currentStep));
}


@override
int get hashCode => Object.hash(runtimeType,status,formData,error,currentStep);

@override
String toString() {
  return 'ProfileCompletionState(status: $status, formData: $formData, error: $error, currentStep: $currentStep)';
}


}

/// @nodoc
abstract mixin class $ProfileCompletionStateCopyWith<$Res>  {
  factory $ProfileCompletionStateCopyWith(ProfileCompletionState value, $Res Function(ProfileCompletionState) _then) = _$ProfileCompletionStateCopyWithImpl;
@useResult
$Res call({
 ProfileCompletionStatus status, ProfileFormData formData, String? error, int currentStep
});


$ProfileFormDataCopyWith<$Res> get formData;

}
/// @nodoc
class _$ProfileCompletionStateCopyWithImpl<$Res>
    implements $ProfileCompletionStateCopyWith<$Res> {
  _$ProfileCompletionStateCopyWithImpl(this._self, this._then);

  final ProfileCompletionState _self;
  final $Res Function(ProfileCompletionState) _then;

/// Create a copy of ProfileCompletionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? formData = null,Object? error = freezed,Object? currentStep = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ProfileCompletionStatus,formData: null == formData ? _self.formData : formData // ignore: cast_nullable_to_non_nullable
as ProfileFormData,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,currentStep: null == currentStep ? _self.currentStep : currentStep // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of ProfileCompletionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfileFormDataCopyWith<$Res> get formData {
  
  return $ProfileFormDataCopyWith<$Res>(_self.formData, (value) {
    return _then(_self.copyWith(formData: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProfileCompletionState].
extension ProfileCompletionStatePatterns on ProfileCompletionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileCompletionState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileCompletionState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileCompletionState value)  $default,){
final _that = this;
switch (_that) {
case _ProfileCompletionState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileCompletionState value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileCompletionState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ProfileCompletionStatus status,  ProfileFormData formData,  String? error,  int currentStep)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileCompletionState() when $default != null:
return $default(_that.status,_that.formData,_that.error,_that.currentStep);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ProfileCompletionStatus status,  ProfileFormData formData,  String? error,  int currentStep)  $default,) {final _that = this;
switch (_that) {
case _ProfileCompletionState():
return $default(_that.status,_that.formData,_that.error,_that.currentStep);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ProfileCompletionStatus status,  ProfileFormData formData,  String? error,  int currentStep)?  $default,) {final _that = this;
switch (_that) {
case _ProfileCompletionState() when $default != null:
return $default(_that.status,_that.formData,_that.error,_that.currentStep);case _:
  return null;

}
}

}

/// @nodoc


class _ProfileCompletionState implements ProfileCompletionState {
  const _ProfileCompletionState({this.status = ProfileCompletionStatus.initial, this.formData = const ProfileFormData(), this.error, this.currentStep = 0});
  

@override@JsonKey() final  ProfileCompletionStatus status;
@override@JsonKey() final  ProfileFormData formData;
@override final  String? error;
@override@JsonKey() final  int currentStep;

/// Create a copy of ProfileCompletionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileCompletionStateCopyWith<_ProfileCompletionState> get copyWith => __$ProfileCompletionStateCopyWithImpl<_ProfileCompletionState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileCompletionState&&(identical(other.status, status) || other.status == status)&&(identical(other.formData, formData) || other.formData == formData)&&(identical(other.error, error) || other.error == error)&&(identical(other.currentStep, currentStep) || other.currentStep == currentStep));
}


@override
int get hashCode => Object.hash(runtimeType,status,formData,error,currentStep);

@override
String toString() {
  return 'ProfileCompletionState(status: $status, formData: $formData, error: $error, currentStep: $currentStep)';
}


}

/// @nodoc
abstract mixin class _$ProfileCompletionStateCopyWith<$Res> implements $ProfileCompletionStateCopyWith<$Res> {
  factory _$ProfileCompletionStateCopyWith(_ProfileCompletionState value, $Res Function(_ProfileCompletionState) _then) = __$ProfileCompletionStateCopyWithImpl;
@override @useResult
$Res call({
 ProfileCompletionStatus status, ProfileFormData formData, String? error, int currentStep
});


@override $ProfileFormDataCopyWith<$Res> get formData;

}
/// @nodoc
class __$ProfileCompletionStateCopyWithImpl<$Res>
    implements _$ProfileCompletionStateCopyWith<$Res> {
  __$ProfileCompletionStateCopyWithImpl(this._self, this._then);

  final _ProfileCompletionState _self;
  final $Res Function(_ProfileCompletionState) _then;

/// Create a copy of ProfileCompletionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? formData = null,Object? error = freezed,Object? currentStep = null,}) {
  return _then(_ProfileCompletionState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ProfileCompletionStatus,formData: null == formData ? _self.formData : formData // ignore: cast_nullable_to_non_nullable
as ProfileFormData,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,currentStep: null == currentStep ? _self.currentStep : currentStep // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of ProfileCompletionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfileFormDataCopyWith<$Res> get formData {
  
  return $ProfileFormDataCopyWith<$Res>(_self.formData, (value) {
    return _then(_self.copyWith(formData: value));
  });
}
}

// dart format on
