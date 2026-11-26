import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../core/models/user.dart';
import '../../account_deletion/models/deletion_request.dart';

part 'auth_state.freezed.dart';

/// Authentication states
enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  guest, // Anonymous browsing - can view public content only
  error,
}

@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState({
    @Default(AuthStatus.initial) AuthStatus status,
    User? user,
    String? error,

    /// Whether a live account deletion request is restricting this session.
    ///
    /// Deliberately a separate axis from [AuthStatus]: the member is genuinely
    /// authenticated while a request is pending, so adding a status value here
    /// would force every `status == authenticated` check in the app to be
    /// re-examined.
    @Default(DeletionStatus.none) DeletionStatus deletionStatus,

    /// True when account deletion could not remove everything stored on this
    /// device, so the deleted screen says so.
    @Default(false) bool deletionLeftDataOnDevice,
  }) = _AuthState;
}
