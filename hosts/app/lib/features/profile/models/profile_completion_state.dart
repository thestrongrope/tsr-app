import 'package:freezed_annotation/freezed_annotation.dart';
import '../models/profile_form_data.dart';

part 'profile_completion_state.freezed.dart';

enum ProfileCompletionStatus { initial, loading, success, error }

@freezed
sealed class ProfileCompletionState with _$ProfileCompletionState {
  const factory ProfileCompletionState({
    @Default(ProfileCompletionStatus.initial) ProfileCompletionStatus status,
    @Default(ProfileFormData()) ProfileFormData formData,
    String? error,
    @Default(0) int currentStep,
  }) = _ProfileCompletionState;
}
