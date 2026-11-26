import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../models/user_notification.dart';
import '../providers/notification_target.dart';
import '../providers/user_notifications_provider.dart';
import '../../../core/widgets/content_width_cap.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Screen to display in-app notifications for the user
class UserNotificationsScreen extends ConsumerStatefulWidget {
  const UserNotificationsScreen({super.key});

  @override
  ConsumerState<UserNotificationsScreen> createState() =>
      _UserNotificationsScreenState();
}

class _UserNotificationsScreenState
    extends ConsumerState<UserNotificationsScreen> {
  static const _failed = 'Could not be marked as read';

  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Unread'];

  @override
  void initState() {
    super.initState();
    // Fetch notifications on screen load
    Future.microtask(() {
      ref.read(userNotificationsProvider.notifier).fetchNotifications();
    });
  }

  List<UserNotification> _filterNotifications(
    List<UserNotification> notifications,
  ) {
    switch (_selectedFilter) {
      case 'Unread':
        return notifications.where((n) => !n.isRead).toList();
      case 'All':
      default:
        return notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userNotificationsProvider);
    final filteredNotifications = _filterNotifications(state.notifications);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (state.notifications.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.done_all_rounded,
                color: AppTheme.primaryGreen,
              ),
              tooltip: 'Mark all as read',
              onPressed: _markAllAsRead,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            height: 50,
            margin: const EdgeInsets.only(bottom: 10),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = filter == _selectedFilter;
                return ChoiceChip(
                  label: Text(
                    filter,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[600],
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    }
                  },
                  selectedColor: AppTheme.primaryGreen,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? AppTheme.primaryGreen
                          : Colors.grey[300]!,
                    ),
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),
        ),
      ),
      body: ContentWidthCap(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref
                .read(userNotificationsProvider.notifier)
                .fetchNotifications(refresh: true);
          },
          child: state.isLoading && state.notifications.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : state.error != null && state.notifications.isEmpty
              ? _buildErrorState(context, state.error!)
              : filteredNotifications.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding: withTabBarInset(
                    context,
                    const EdgeInsets.symmetric(vertical: 8),
                  ),
                  itemCount:
                      (state.isSavedCopy ? 1 : 0) +
                      filteredNotifications.length +
                      (state.hasMore && _selectedFilter == 'All' ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (state.isSavedCopy) {
                      if (index == 0) return const _SavedCopyNotice();
                      index -= 1;
                    }
                    if (index == filteredNotifications.length) {
                      return state.isLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: TextButton(
                                  onPressed: () => ref
                                      .read(userNotificationsProvider.notifier)
                                      .fetchNotifications(),
                                  child: const Text('Load More'),
                                ),
                              ),
                            );
                    }

                    final isLastItem =
                        index == filteredNotifications.length - 1;

                    return Column(
                      children: [
                        _NotificationTile(
                          notification: filteredNotifications[index],
                          onTap: () async {
                            final notification = filteredNotifications[index];
                            if (!notification.isRead) {
                              _markAsRead(notification.id);
                            }
                            _openNotification(notification);
                          },
                        ),
                        if (!isLastItem)
                          Divider(
                            height: 1,
                            thickness: 1,
                            indent: 80,
                            endIndent: 16,
                            color: Colors.grey[200],
                          ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _markAsRead(int id) async {
    final messenger = ScaffoldMessenger.of(context);
    final done = await ref
        .read(userNotificationsProvider.notifier)
        .markAsRead(id);
    if (!done) messenger.showSnackBar(const SnackBar(content: Text(_failed)));
  }

  Future<void> _markAllAsRead() async {
    final messenger = ScaffoldMessenger.of(context);
    final done = await ref
        .read(userNotificationsProvider.notifier)
        .markAllAsRead();
    if (!done) messenger.showSnackBar(const SnackBar(content: Text(_failed)));
  }

  /// Opens what the notification was about: the same mapping, chooser and
  /// access check as a tapped push (#800, #925). With no target, or one the
  /// member cannot open, the full text is shown, with the reason when there is
  /// one.
  Future<void> _openNotification(UserNotification notification) {
    return openNotificationTarget(
      context,
      check: ref.read(notificationTargetCheckerProvider),
      destination: historyDestination(notification),
      title: notification.title,
      body: notification.body,
      sentAt: notification.sentAt,
      classNames: {for (final c in notification.classes) c.id: c.name},
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.lightGreen.withAlpha(100),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 48,
              color: AppTheme.primaryGreen.withAlpha(180),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.darkText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.mediumText),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.mediumText),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              ref
                  .read(userNotificationsProvider.notifier)
                  .fetchNotifications(refresh: true);
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _NotificationStyle {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  const _NotificationStyle({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });

  factory _NotificationStyle.fromNotification(UserNotification notification) {
    final title = notification.title.toLowerCase();

    // Determine style based on title keywords
    if (title.contains('rejected') ||
        title.contains('error') ||
        title.contains('failed')) {
      return const _NotificationStyle(
        icon: Icons.notifications_off_outlined,
        backgroundColor: Color(0xFFE8F5F2), // Light Cyan/Greenish
        iconColor: AppTheme.primaryGreen,
      );
    } else if (title.contains('update') || title.contains('system')) {
      return const _NotificationStyle(
        icon: Icons.campaign_outlined,
        backgroundColor: Color(0xFFEEEEFF), // Light Blue
        iconColor: Color(0xFF5B5EFC),
      );
    } else if (title.contains('lecture') ||
        title.contains('class') ||
        title.contains('new')) {
      return const _NotificationStyle(
        icon: Icons.school_outlined,
        backgroundColor: Color(0xFFFFF4E5), // Light Orange
        iconColor: Color(0xFFFF9800),
      );
    } else if (title.contains('mention') ||
        title.contains('like') ||
        title.contains('comment')) {
      return const _NotificationStyle(
        icon: Icons.favorite_border,
        backgroundColor: Color(0xFFFFEBEE), // Light Pink
        iconColor: Color(0xFFE91E63),
      );
    } else if (title.contains('event') || title.contains('calendar')) {
      return const _NotificationStyle(
        icon: Icons.calendar_today_outlined,
        backgroundColor: Color(0xFFE3F2FD), // Light Blue
        iconColor: Color(0xFF2196F3),
      );
    }

    // Default Style
    return const _NotificationStyle(
      icon: Icons.notifications_outlined,
      backgroundColor: AppTheme.lightGreen,
      iconColor: AppTheme.primaryGreen,
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final UserNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(dateTime);
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _NotificationStyle.fromNotification(notification);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: notification.isRead
            ? Colors.transparent
            : const Color(0xFFF5F9FA),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: style.backgroundColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(style.icon, color: style.iconColor, size: 24),
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: notification.isRead
                                ? FontWeight.w400
                                : FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimeAgo(notification.sentAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Unread Dot
            if (!notification.isRead) ...[
              const SizedBox(width: 8),
              Container(
                key: const Key('unread-dot'),
                margin: const EdgeInsets.only(top: 6),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryGreen,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tells the member the list is the copy saved on this device.
class _SavedCopyNotice extends StatelessWidget {
  const _SavedCopyNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Text(
        'Showing saved notifications. Pull to refresh when you are back online.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
      ),
    );
  }
}
