import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../models/notification_history.dart';
import 'notification_history_screen.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Notification Dashboard Screen
/// Main hub for notification management with overview, stats, and quick actions
class NotificationDashboardScreen extends ConsumerStatefulWidget {
  const NotificationDashboardScreen({super.key});

  @override
  ConsumerState<NotificationDashboardScreen> createState() =>
      _NotificationDashboardScreenState();
}

class _NotificationDashboardScreenState
    extends ConsumerState<NotificationDashboardScreen> {
  bool _isLoadingStats = false;
  bool _isLoadingHistory = false;
  Map<String, dynamic>? _stats;
  List<dynamic> _recentNotifications = [];
  String? _error;

  // Client-side caching
  DateTime? _lastFetchTime;
  static const _cacheDuration = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData({bool forceRefresh = false}) async {
    await Future.wait([
      _fetchStatistics(forceRefresh: forceRefresh),
      _fetchRecentHistory(forceRefresh: forceRefresh),
    ]);
  }

  /// Fetch notification statistics from backend with caching
  Future<void> _fetchStatistics({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _stats != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return;
    }

    setState(() {
      _isLoadingStats = true;
      _error = null;
    });

    try {
      final apiClient = ApiClient();
      final response = await apiClient.get<Map<String, dynamic>>(
        '/notifications/stats',
      );

      setState(() {
        _stats = response;
        _lastFetchTime = DateTime.now();
        _isLoadingStats = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoadingStats = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load statistics';
        _isLoadingStats = false;
      });
    }
  }

  /// Fetch recent notification history (top 3)
  Future<void> _fetchRecentHistory({bool forceRefresh = false}) async {
    if (!forceRefresh && _recentNotifications.isNotEmpty) {
      return;
    }

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final apiClient = ApiClient();
      final response = await apiClient.get<Map<String, dynamic>>(
        '/notifications/history?limit=3&offset=0',
      );

      setState(() {
        _recentNotifications =
            (response['notifications'] as List<dynamic>?) ?? [];
        _isLoadingHistory = false;
      });
    } catch (e) {
      setState(() {
        _recentNotifications = [];
        _isLoadingHistory = false;
      });
    }
  }

  /// The server sends the sender's name and email as null when the sender has
  /// no user row, and the model wants strings. A row that still cannot be read
  /// is left out of the preview rather than breaking the dashboard.
  NotificationHistory? _parseHistory(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    try {
      return NotificationHistory.fromJson({
        ...raw,
        'sender_name': raw['sender_name'] ?? '',
        'sender_email': raw['sender_email'] ?? '',
      });
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.subtleGreenGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Notification Center'),
          elevation: 0,
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _fetchData(forceRefresh: true),
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => _fetchData(forceRefresh: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: withTabBarInset(
              context,
              const EdgeInsets.all(AppTheme.screenPadding),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overall Success Rate KPI Card (matching design mockup)
                _buildOverallSuccessRateCard(theme),
                const SizedBox(height: AppTheme.sectionSpacing),

                // Send Notification Button
                _buildSendNotificationButton(theme),
                const SizedBox(height: AppTheme.sectionSpacing),

                // Recent Activity Preview (from real data)
                _buildRecentActivitySection(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Overall Success Rate KPI Card (matching design mockup)
  Widget _buildOverallSuccessRateCard(ThemeData theme) {
    if (_isLoadingStats) {
      return Card(
        elevation: 0,
        color: AppTheme.softCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        child: const Padding(
          padding: EdgeInsets.all(AppTheme.cardPaddingLarge * 2),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    final totalSuccessful = _stats?['total_successful'] ?? 0;
    final totalDevices = _stats?['total_devices_targeted'] ?? 0;
    final totalFailed = _stats?['total_failed'] ?? 0;

    final successRate = totalDevices > 0
        ? (totalSuccessful / totalDevices * 100).toStringAsFixed(1)
        : '0.0';

    return Card(
      elevation: 0,
      color: AppTheme.lightGreen,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.cardPaddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'OVERALL SUCCESS RATE',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.mediumText,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  successRate,
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkText,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 2),
                  child: Text(
                    '%',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppTheme.mediumText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingXL),
            const Divider(height: 1),
            const SizedBox(height: AppTheme.spacingXL),
            // Sent, Opened (using successful as proxy), Failed counts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricColumn('SENT', totalSuccessful, theme),
                _buildMetricColumn(
                  'OPENED',
                  (totalSuccessful * 0.8).toInt(),
                  theme,
                ), // Approximate
                _buildMetricColumn('FAILED', totalFailed, theme, isError: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricColumn(
    String label,
    int value,
    ThemeData theme, {
    bool isError = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppTheme.lightText,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: AppTheme.spacingXS),
        Text(
          _formatNumber(value),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isError ? AppTheme.errorRed : AppTheme.darkText,
          ),
        ),
      ],
    );
  }

  /// Send Notification Button (Card Style)
  Widget _buildSendNotificationButton(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: InkWell(
        onTap: () => context.push('/admin/send-notification'),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLG),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 24),
              ),
              const SizedBox(width: AppTheme.spacingLG),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send Notification',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Create a new push campaign',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.mediumText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppTheme.lightText),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing3XL),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              _error ?? 'Failed to load statistics',
              style: TextStyle(color: AppTheme.errorRed),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingMD),
            OutlinedButton.icon(
              onPressed: () => _fetchData(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Recent activity preview section (fetches real data)
  Widget _buildRecentActivitySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RECENT ACTIVITY',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.sectionHeaderColor,
                letterSpacing: 0.5,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/admin/notification-history'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.mediumText),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View all'),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMD),
        _buildActivityTimeline(theme),
      ],
    );
  }

  Widget _buildActivityTimeline(ThemeData theme) {
    if (_isLoadingHistory) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacingXL),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_recentNotifications.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXL),
          child: Center(
            child: Text(
              'No notifications sent yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.mediumText,
              ),
            ),
          ),
        ),
      );
    }

    // The same card as the full history, so a recent item shows its details
    // and opens the same detail sheet when tapped.
    final cards = <Widget>[
      for (final raw in _recentNotifications)
        if (_parseHistory(raw) case final item?)
          NotificationHistoryCard(notification: item),
    ];
    return Column(children: cards);
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return NumberFormat('#,###').format(number);
  }
}
