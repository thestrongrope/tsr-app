import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/saved_copy.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/user_notification.dart';

/// State for user notifications
class UserNotificationsState {
  final List<UserNotification> notifications;
  final bool isLoading;
  final String? error;
  final int unreadCount;
  final bool hasMore;
  final int currentOffset;

  /// True while the list shown is the copy saved on this device because the
  /// server could not be reached.
  final bool isSavedCopy;

  const UserNotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
    this.unreadCount = 0,
    this.hasMore = true,
    this.currentOffset = 0,
    this.isSavedCopy = false,
  });

  UserNotificationsState copyWith({
    List<UserNotification>? notifications,
    bool? isLoading,
    String? error,
    int? unreadCount,
    bool? hasMore,
    int? currentOffset,
    bool? isSavedCopy,
  }) {
    return UserNotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      unreadCount: unreadCount ?? this.unreadCount,
      hasMore: hasMore ?? this.hasMore,
      currentOffset: currentOffset ?? this.currentOffset,
      isSavedCopy: isSavedCopy ?? this.isSavedCopy,
    );
  }
}

/// Provider for user notifications
class UserNotificationsNotifier extends Notifier<UserNotificationsState> {
  final ApiClient _apiClient = ApiClient();
  static const int _pageSize = 20;
  static const String savedInboxPrefix = 'notifications_inbox_';

  /// The clock the saved copy's age is measured by; tests move it.
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  /// One page of the inbox from the server. A seam for tests: [ApiClient] is a
  /// singleton with a private constructor and cannot be subclassed.
  @visibleForTesting
  Future<Map<String, dynamic>> fetchPage(int offset) async {
    final response = await _apiClient.get(
      '/user/notifications',
      queryParameters: {'limit': _pageSize, 'offset': offset},
    );
    return response as Map<String, dynamic>;
  }

  /// Where the signed-in member's first page is saved, or null for a guest
  /// (token 0 is shared by every guest, so nothing is saved for one).
  String? get _savedInboxKey {
    final token = _signedInToken;
    return token == null ? null : '$savedInboxPrefix$token';
  }

  int? get _signedInToken {
    final token = ref.read(currentUserProvider)?.token ?? 0;
    return token > 0 ? token : null;
  }

  SavedCopies get _savedCopies => SavedCopies(
    Hive.box(AppConstants.cacheBoxKey),
    owner: () => _signedInToken,
    clock: clock,
  );

  Future<void> _saveFirstPage(Map<String, dynamic> response) async {
    final key = _savedInboxKey;
    if (key == null) return;
    try {
      await _savedCopies.save(key, jsonEncode(response));
    } catch (e) {
      debugPrint('Error saving notifications: $e');
    }
  }

  /// The saved first page, or null when there is none, it has expired or it
  /// cannot be read.
  ({List<UserNotification> notifications, int unreadCount})?
  _readSavedFirstPage() {
    final key = _savedInboxKey;
    if (key == null) return null;
    try {
      final saved = _savedCopies.read(key);
      if (saved is! String) return null;
      final page = jsonDecode(saved) as Map<String, dynamic>;
      final notifications = (page['notifications'] as List<dynamic>? ?? [])
          .map(
            (json) => UserNotification.fromJson(json as Map<String, dynamic>),
          )
          .toList();
      return (
        notifications: notifications,
        unreadCount: page['unread_count'] as int? ?? 0,
      );
    } catch (e) {
      debugPrint('Error reading saved notifications: $e');
      return null;
    }
  }

  @override
  UserNotificationsState build() {
    Future.microtask(() => fetchUnreadCount());
    return const UserNotificationsState();
  }

  /// Quickly fetch only the unread count from backend
  Future<void> fetchUnreadCount() async {
    try {
      final response = await _apiClient.get('/user/notifications/unread-count');
      final unread = response['unread_count'] as int? ?? 0;
      state = state.copyWith(unreadCount: unread);
    } catch (e) {
      debugPrint('Error fetching unread notification count: $e');
    }
  }

  /// Fetch notifications from backend
  Future<void> fetchNotifications({bool refresh = false}) async {
    if (state.isLoading) return;

    final offset = refresh ? 0 : state.currentOffset;

    state = state.copyWith(
      isLoading: true,
      error: null,
      currentOffset: offset,
      notifications: refresh ? [] : state.notifications,
    );

    try {
      final response = await fetchPage(offset);
      if (offset == 0) await _saveFirstPage(response);

      final List<dynamic> notificationsJson = response['notifications'] ?? [];
      final notifications = notificationsJson
          .map(
            (json) => UserNotification.fromJson(json as Map<String, dynamic>),
          )
          .toList();

      final total = response['total'] as int? ?? 0;
      final unreadCount = response['unread_count'] as int? ?? 0;
      final hasMore = offset + notifications.length < total;

      state = state.copyWith(
        notifications: refresh
            ? notifications
            : [...state.notifications, ...notifications],
        isLoading: false,
        unreadCount: unreadCount,
        hasMore: hasMore,
        currentOffset: offset + notifications.length,
        isSavedCopy: false,
      );
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      final saved = offset == 0 && isUnreachable(e)
          ? _readSavedFirstPage()
          : null;
      if (saved != null) {
        _showSavedFirstPage(saved);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: e.toString(),
          isSavedCopy: false,
        );
      }
    }
  }

  /// Shows the saved first page. Nothing beyond it is saved, so there is no
  /// "Load More" until a fetch succeeds.
  void _showSavedFirstPage(
    ({List<UserNotification> notifications, int unreadCount}) saved,
  ) {
    state = state.copyWith(
      notifications: saved.notifications,
      isLoading: false,
      unreadCount: saved.unreadCount,
      hasMore: false,
      currentOffset: saved.notifications.length,
      isSavedCopy: true,
    );
  }

  /// Mark a notification as read. Returns false, leaving it unread, when the
  /// server could not be told.
  Future<bool> markAsRead(int notificationId) async {
    try {
      await _apiClient.post('/user/notifications/$notificationId/read');

      // Update local state
      final updatedNotifications = state.notifications.map((n) {
        if (n.id == notificationId) {
          return n.copyWith(isRead: true, readAt: DateTime.now());
        }
        return n;
      }).toList();

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: (state.unreadCount - 1).clamp(0, double.maxFinite.toInt()),
      );
      return true;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read. Returns false, leaving them unread, when
  /// the server could not be told.
  Future<bool> markAllAsRead() async {
    try {
      await _apiClient.post('/user/notifications/read-all');

      // Update local state
      final updatedNotifications = state.notifications.map((n) {
        return n.copyWith(isRead: true, readAt: DateTime.now());
      }).toList();

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: 0,
      );
      return true;
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Get the count of unread notifications
  int get unreadCount => state.unreadCount;
}

/// Provider instance
final userNotificationsProvider =
    NotifierProvider<UserNotificationsNotifier, UserNotificationsState>(
      UserNotificationsNotifier.new,
    );

/// Provider for unread notification count (for badge display)
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(userNotificationsProvider).unreadCount;
});
