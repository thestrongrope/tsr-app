import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../models/notification_history.dart';
import '../../../core/utils/api_datetime.dart';
import '../../../core/utils/user_message.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Notification History Screen
/// Shows the history of all sent notifications with statistics and details
class NotificationHistoryScreen extends ConsumerStatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  ConsumerState<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState
    extends ConsumerState<NotificationHistoryScreen> {
  List<NotificationHistory> _notifications = [];
  bool _isLoading = false;
  String? _error;
  int _offset = 0;
  final int _limit = 20;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchNotificationHistory();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchNotificationHistory({bool loadMore = false}) async {
    if (_isLoading || (!loadMore && _notifications.isNotEmpty)) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = ApiClient();
      final response = await apiClient.get<Map<String, dynamic>>(
        '/notifications/history',
        queryParameters: {'limit': _limit, 'offset': loadMore ? _offset : 0},
      );

      final historyResponse = NotificationHistoryResponse.fromJson(response);

      setState(() {
        if (loadMore) {
          _notifications.addAll(historyResponse.notifications);
        } else {
          _notifications = historyResponse.notifications;
        }
        _offset = loadMore ? _offset + _limit : _limit;
        _hasMore = historyResponse.notifications.length == _limit;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load notification history: ${userMessage(e)}';
        _isLoading = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      if (_hasMore && !_isLoading) {
        _fetchNotificationHistory(loadMore: true);
      }
    }
  }

  Future<void> _refreshHistory() async {
    setState(() {
      _notifications.clear();
      _offset = 0;
      _hasMore = true;
    });
    await _fetchNotificationHistory();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.subtleGreenGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Notification History'),
          elevation: 0,
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshHistory,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_error != null && _notifications.isEmpty) {
      return _buildErrorState(theme);
    }

    if (_isLoading && _notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notifications.isEmpty) {
      return _buildEmptyState(theme);
    }

    return RefreshIndicator(
      onRefresh: _refreshHistory,
      child: ListView.builder(
        controller: _scrollController,
        padding: withTabBarInset(
          context,
          const EdgeInsets.all(AppTheme.screenPadding),
        ),
        itemCount: _notifications.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _notifications.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacingLG),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final notification = _notifications[index];
          return NotificationHistoryCard(notification: notification);
        },
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing3XL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
            const SizedBox(height: AppTheme.spacingLG),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.errorRed,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingLG),
            OutlinedButton.icon(
              onPressed: _refreshHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing3XL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingXL),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none,
                size: 48,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: AppTheme.sectionSpacing),
            Text(
              'No notifications sent yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              'Sent notifications will appear here',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.mediumText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One sent notification as a card; tapping it opens its details. Shared by the
/// history list and the dashboard's recent activity.
class NotificationHistoryCard extends StatelessWidget {
  final NotificationHistory notification;

  const NotificationHistoryCard({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final successRate = notification.deviceCount > 0
        ? (notification.successCount / notification.deviceCount * 100)
        : 0.0;
    final isSuccess = notification.failureCount == 0;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        onTap: () => _showDetailsBottomSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLG),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Icon
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingSM),
                    decoration: BoxDecoration(
                      color: isSuccess
                          ? AppTheme.successGreen.withValues(alpha: 0.1)
                          : AppTheme.warningOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                    child: Icon(
                      isSuccess ? Icons.check_circle : Icons.warning,
                      color: isSuccess
                          ? AppTheme.successGreen
                          : AppTheme.warningOrange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  // Title and Target
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkText,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        _buildTargetBadge(theme),
                      ],
                    ),
                  ),
                  // Time
                  Text(
                    _formatTimeAgo(notification.sentAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.lightText,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spacingMD),

              // Body Preview
              Text(
                notification.body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.mediumText,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: AppTheme.spacingLG),

              // Stats Row
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      theme,
                      Icons.devices,
                      '${notification.deviceCount}',
                      'Devices',
                      AppTheme.primaryGreen,
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: AppTheme.dividerColor,
                    ),
                    _buildStatItem(
                      theme,
                      Icons.check_circle_outline,
                      '${notification.successCount}',
                      'Success',
                      AppTheme.successGreen,
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: AppTheme.dividerColor,
                    ),
                    _buildStatItem(
                      theme,
                      Icons.error_outline,
                      '${notification.failureCount}',
                      'Failed',
                      AppTheme.errorRed,
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: AppTheme.dividerColor,
                    ),
                    _buildStatItem(
                      theme,
                      Icons.percent,
                      '${successRate.toStringAsFixed(0)}%',
                      'Rate',
                      AppTheme.accentGold,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingMD),

              // Footer
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: AppTheme.lightText,
                  ),
                  const SizedBox(width: AppTheme.spacingXS),
                  Expanded(
                    child: Text(
                      notification.senderName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.lightText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'Tap to view details',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingXS),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: AppTheme.primaryGreen,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Who it went to: the audience in words, the classes, levels or teacher by
  /// name, how many people have it in their inbox, and where it opens.
  Widget _buildAudience(ThemeData theme) {
    final summary = notification.audienceSummary.isNotEmpty
        ? notification.audienceSummary
        : notification.targetAudienceCriteria.type;
    final link = notification.actionLink;
    final count = notification.recipientCount;

    return Container(
      key: const Key('notification-audience'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.darkText,
            ),
          ),
          for (final item in notification.audienceItems)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spacingXS),
              child: Text(
                item,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.mediumText,
                ),
              ),
            ),
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            count == 1
                ? '1 person has it in their inbox'
                : '$count people have it in their inbox',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.mediumText,
            ),
          ),
          if (link != null && link.isNotEmpty)
            Text(
              'Opens $link',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.mediumText,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTargetBadge(ThemeData theme) {
    final targetType = notification.targetAudienceCriteria.type;
    final targetValue = notification.targetAudienceCriteria.value;

    String label;
    IconData icon;

    switch (targetType) {
      case 'ALL_USERS':
        label = 'All Users';
        icon = Icons.group;
        break;
      case 'CLASS_LEVEL':
        final count = targetValue?.length ?? 0;
        label = count > 1 ? '$count Classes' : 'Class Level';
        icon = Icons.school;
        break;
      case 'GENDER':
        label = targetValue?.first == '1' ? 'Male' : 'Female';
        icon = Icons.people;
        break;
      case 'TEACHERS':
        label = 'Teachers';
        icon = Icons.person;
        break;
      default:
        label = targetType;
        icon = Icons.info;
    }
    // The server's own wording is more specific than the type; an older server
    // does not send it.
    if (notification.audienceSummary.isNotEmpty) {
      label = notification.audienceSummary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSM,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusXS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.primaryGreen),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.primaryGreen,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    ThemeData theme,
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.darkText,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppTheme.lightText,
          ),
        ),
      ],
    );
  }

  String _formatTimeAgo(String isoString) {
    try {
      final dateTime = parseApiLocalDateTime(isoString);
      if (dateTime == null) return '';
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d';
      } else {
        return DateFormat('MMM d').format(dateTime);
      }
    } catch (e) {
      return '';
    }
  }

  void _showDetailsBottomSheet(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusLG),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spacingMD,
                ),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: withTabBarInset(
                    context,
                    const EdgeInsets.all(AppTheme.screenPadding),
                  ),
                  children: [
                    // Title
                    Text(
                      notification.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    _buildTargetBadge(theme),
                    const SizedBox(height: AppTheme.sectionSpacing),

                    // Message Section
                    _buildSectionHeader(theme, 'MESSAGE'),
                    const SizedBox(height: AppTheme.spacingMD),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingLG),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                      child: Text(
                        notification.body,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.darkText,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.sectionSpacing),

                    // Statistics Section
                    _buildSectionHeader(theme, 'STATISTICS'),
                    const SizedBox(height: AppTheme.spacingMD),
                    _buildDetailedStats(theme),
                    const SizedBox(height: AppTheme.sectionSpacing),

                    // Audience Section
                    _buildSectionHeader(theme, 'SENT TO'),
                    const SizedBox(height: AppTheme.spacingMD),
                    _buildAudience(theme),
                    const SizedBox(height: AppTheme.sectionSpacing),

                    // Sender Section
                    _buildSectionHeader(theme, 'SENT BY'),
                    const SizedBox(height: AppTheme.spacingMD),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingLG),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppTheme.spacingMD),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withValues(
                                alpha: 0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingMD),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notification.senderName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.darkText,
                                  ),
                                ),
                                Text(
                                  notification.senderEmail,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.mediumText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.sectionSpacing),

                    // Timestamp Section
                    _buildSectionHeader(theme, 'SENT AT'),
                    const SizedBox(height: AppTheme.spacingMD),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingLG),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, color: AppTheme.primaryGreen),
                          const SizedBox(width: AppTheme.spacingMD),
                          Text(
                            _formatFullDateTime(notification.sentAt),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.darkText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing3XL),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryGreen,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildDetailedStats(ThemeData theme) {
    final successRate = notification.deviceCount > 0
        ? (notification.successCount / notification.deviceCount * 100)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDetailStatTile(
                  theme,
                  'Total Devices',
                  '${notification.deviceCount}',
                  Icons.devices,
                  AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: _buildDetailStatTile(
                  theme,
                  'Success Rate',
                  '${successRate.toStringAsFixed(1)}%',
                  Icons.percent,
                  AppTheme.accentGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          Row(
            children: [
              Expanded(
                child: _buildDetailStatTile(
                  theme,
                  'Successful',
                  '${notification.successCount}',
                  Icons.check_circle,
                  AppTheme.successGreen,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: _buildDetailStatTile(
                  theme,
                  'Failed',
                  '${notification.failureCount}',
                  Icons.error,
                  AppTheme.errorRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailStatTile(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppTheme.spacingSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.mediumText,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatFullDateTime(String isoString) {
    final dateTime = parseApiLocalDateTime(isoString);
    if (dateTime == null) return isoString;
    return DateFormat('MMMM d, y • h:mm a').format(dateTime);
  }
}
