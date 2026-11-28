import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/models.dart';
import '../repositories/grand_quiz_repository.dart';

// ============ Repository Provider ============

final grandQuizRepositoryProvider = Provider<GrandQuizRepository>((ref) {
  return GrandQuizRepository();
});

// ============ State Class ============

class GrandQuizState {
  final bool isLoading;
  final QuizInfo? quizInfo;
  final String? error;
  final DateTime? lastFetch;

  const GrandQuizState({
    this.isLoading = false,
    this.quizInfo,
    this.error,
    this.lastFetch,
  });

  GrandQuizState copyWith({
    bool? isLoading,
    QuizInfo? quizInfo,
    String? error,
    DateTime? lastFetch,
    bool clearQuizInfo = false,
    bool clearError = false,
  }) {
    return GrandQuizState(
      isLoading: isLoading ?? this.isLoading,
      quizInfo: clearQuizInfo ? null : (quizInfo ?? this.quizInfo),
      error: clearError ? null : (error ?? this.error),
      lastFetch: lastFetch ?? this.lastFetch,
    );
  }

  /// Check if quiz info is available and active
  bool get hasActiveQuiz => quizInfo != null && quizInfo!.isActive;

  /// Check if the quiz is visible (has data and not offline)
  bool get shouldShowBanner => quizInfo?.shouldDisplayBanner ?? false;

  /// Check if data is stale (older than the quiz info cache duration, 60 seconds)
  bool get isStale {
    if (lastFetch == null) return true;
    return DateTime.now().difference(lastFetch!) >
        AppConstants.quizInfoCacheDuration;
  }
}

// ============ State Notifier ============

class GrandQuizNotifier extends StateNotifier<GrandQuizState> {
  final GrandQuizRepository _repository;
  final Ref _ref;

  GrandQuizNotifier(this._repository, this._ref)
    : super(const GrandQuizState());

  /// Load quiz info from API
  Future<void> loadQuizInfo({bool forceRefresh = false}) async {
    // Don't reload if already loading
    if (state.isLoading) return;

    // Skip if data is fresh and not forcing refresh
    if (!forceRefresh && !state.isStale && state.quizInfo != null) {
      debugPrint('📦 Quiz info is fresh, skipping fetch');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Get current user for dual auth (if available)
      final currentUser = _ref.read(currentUserProvider);

      final response = await _repository.getQuizInfo(
        currentUser: currentUser,
        forceRefresh: forceRefresh,
      );

      if (response.success && response.data != null) {
        state = state.copyWith(
          isLoading: false,
          quizInfo: response.data,
          lastFetch: DateTime.now(),
          clearError: true,
        );
        debugPrint('✅ Quiz info loaded: ${response.data!.name}');
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? 'Failed to load quiz info',
          clearQuizInfo: true,
        );
        debugPrint('⚠️ Quiz info load failed: ${response.error}');
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
      );
      debugPrint('🔴 Quiz info load error: $e');
    }
  }

  /// Refresh quiz info (force refresh)
  Future<void> refresh() async {
    await loadQuizInfo(forceRefresh: true);
  }

  /// Silent refresh (doesn't show loading state)
  Future<void> silentRefresh() async {
    try {
      final currentUser = _ref.read(currentUserProvider);
      final response = await _repository.getQuizInfo(
        currentUser: currentUser,
        forceRefresh: true,
      );

      if (response.success && response.data != null) {
        state = state.copyWith(
          quizInfo: response.data,
          lastFetch: DateTime.now(),
          clearError: true,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Silent refresh failed: $e');
    }
  }

  /// Clear cached data
  Future<void> clearCache() async {
    await _repository.clearCache();
    state = const GrandQuizState();
  }
}

// ============ Provider ============

final grandQuizProvider =
    StateNotifierProvider<GrandQuizNotifier, GrandQuizState>((ref) {
      final repository = ref.watch(grandQuizRepositoryProvider);
      return GrandQuizNotifier(repository, ref);
    });

// ============ Convenience Providers ============

/// Provider for just the quiz info (null if not loaded or offline)
final quizInfoProvider = Provider<QuizInfo?>((ref) {
  final state = ref.watch(grandQuizProvider);
  return state.shouldShowBanner ? state.quizInfo : null;
});

/// Provider to check if banner should be shown
final shouldShowQuizBannerProvider = Provider<bool>((ref) {
  final state = ref.watch(grandQuizProvider);
  return state.shouldShowBanner;
});

/// Provider for quiz loading state
final isQuizLoadingProvider = Provider<bool>((ref) {
  return ref.watch(grandQuizProvider).isLoading;
});
