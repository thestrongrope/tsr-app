import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/notifications/providers/notification_target.dart'
    show NotificationTapSource;
import 'reminder_telemetry.dart';

/// Top-level function to handle background messages
/// Must be a top-level function (not a class method) for iOS/Android background handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Release builds log nothing: title, body and data are member content.
  if (kReleaseMode) return;
  debugPrint('📩 Background message received: ${message.messageId}');
  debugPrint('📩 Title: ${message.notification?.title}');
  debugPrint('📩 Body: ${message.notification?.body}');
  debugPrint('📩 Data: ${message.data}');
}

/// A notification the member tapped: what it carried and its text, so the app
/// can open its target or, failing that, show what it said.
class NotificationTap {
  const NotificationTap({
    required this.data,
    required this.title,
    required this.body,
  });

  final Map<String, dynamic> data;
  final String title;
  final String body;
}

/// Payload keys a local notification uses to carry its own text.
const notificationPayloadTitleKey = 'notification_title';
const notificationPayloadBodyKey = 'notification_body';

/// Notification Service
/// Handles Firebase Cloud Messaging (FCM) for push notifications
class NotificationService implements NotificationTapSource {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Exposed so [ScheduledNotificationService] can share the same plugin
  /// instance (avoids double-initialization of local notifications).
  FlutterLocalNotificationsPlugin get localNotificationsPlugin =>
      _localNotifications;

  /// Query the OS each time; app preferences cannot tell whether alerts are blocked.
  Future<bool> areNotificationsEnabled() async {
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  // Notification taps. The stream is broadcast and drops events nobody listens
  // to, so a tap that arrives first (a cold start) is kept for the first
  // listener.
  final _notificationTapController =
      StreamController<NotificationTap>.broadcast();
  NotificationTap? _pendingTap;

  @override
  Stream<NotificationTap> get taps => _notificationTapController.stream;

  @override
  NotificationTap? takePendingTap() {
    final tap = _pendingTap;
    _pendingTap = null;
    return tap;
  }

  void _emitTap(NotificationTap tap) {
    if (_notificationTapController.hasListener) {
      _notificationTapController.add(tap);
    } else {
      _pendingTap = tap;
    }
  }

  // Store the latest FCM token
  String? _currentToken;
  String? get currentToken => _currentToken;

  bool _isInitialized = false;
  bool _permissionRequested = false;

  /// Initialize the notification service.
  ///
  /// Startup calls this with [requestPermission] `false`: it sets up the local
  /// notifications plugin and the Android channel (which
  /// [ScheduledNotificationService] needs) without showing the OS prompt. The
  /// prompt is one-shot on iOS, so asking before the explainer screen has made
  /// the case for it means a decline there can never be recovered and the
  /// device never registers for push.
  ///
  /// The explainer screen calls this with the default `true` once the user has
  /// opted in.
  Future<void> initialize({bool requestPermission = true}) async {
    if (_isInitialized && (_permissionRequested || !requestPermission)) {
      debugPrint('🔔 NotificationService already initialized');
      return;
    }

    try {
      debugPrint('🔔 Initializing NotificationService...');

      if (!_isInitialized) {
        await _initializeLocalPlugin();
        _isInitialized = true;
      }

      if (!requestPermission) {
        debugPrint('🔔 Local plugin ready; OS prompt deferred to opt-in');
        return;
      }
      _permissionRequested = true;

      // Request notification permissions (iOS)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ User granted notification permissions');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        debugPrint('⚠️ User granted provisional notification permissions');
      } else {
        debugPrint(
          '❌ User declined or has not accepted notification permissions',
        );
        return;
      }

      // Get FCM token
      await _getFCMToken();

      // Listen to token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM Token refreshed: ${newToken.substring(0, 20)}...');
        _currentToken = newToken;
        // TODO: Update token on backend when it refreshes
      });

      // Setup message handlers
      _setupMessageHandlers();

      debugPrint('✅ NotificationService initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing NotificationService: $e');
    }
  }

  /// Set up the local notifications plugin and the Android channel. Shows no
  /// OS permission prompt: the Darwin settings below all request nothing.
  Future<void> _initializeLocalPlugin() async {
    // Initialize local notifications plugin
    const androidSettings = AndroidInitializationSettings(
      '@drawable/ic_notification',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // A local reminder tapped while the app was closed launches it without
    // calling the handler above.
    final launch = await _localNotifications.getNotificationAppLaunchDetails();
    final launchResponse = launch?.notificationResponse;
    if (launch?.didNotificationLaunchApp == true && launchResponse != null) {
      _onNotificationTap(launchResponse);
    }

    // Create Android notification channel
    const channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// Get FCM token for this device
  Future<String?> _getFCMToken() async {
    try {
      _currentToken = await _messaging.getToken();
      if (_currentToken != null) {
        debugPrint('📱 FCM Token: ${_currentToken!.substring(0, 20)}...');
      } else {
        debugPrint('⚠️ Failed to get FCM token');
      }
      return _currentToken;
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Get the current FCM token
  /// Returns cached token or fetches a new one if not available
  Future<String?> getToken() async {
    return _currentToken ?? await _getFCMToken();
  }

  /// Setup handlers for different message states
  void _setupMessageHandlers() {
    // Handle foreground messages (when app is open and in use)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a terminated state by tapping a notification
    _checkInitialMessage();
  }

  /// Handle messages received while app is in foreground
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📨 Foreground message received');
    if (!kReleaseMode) {
      debugPrint('📨 Title: ${message.notification?.title}');
      debugPrint('📨 Body: ${message.notification?.body}');
      debugPrint('📨 Data: ${message.data}');
    }

    // Show local notification when app is in foreground
    _showLocalNotification(message);
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: jsonEncode({
        ...message.data,
        notificationPayloadTitleKey: notification.title ?? '',
        notificationPayloadBodyKey: notification.body ?? '',
      }),
    );
  }

  /// Handle notification tap from local notifications: a push shown while the
  /// app was open, or a scheduled class reminder.
  void _onNotificationTap(NotificationResponse response) {
    if (!kReleaseMode) {
      debugPrint('👆 Local notification tapped: ${response.payload}');
    }
    final payload = response.payload;
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'];
      if (type is String) ReminderTelemetry.logOpened(type);
      _emitTap(
        NotificationTap(
          data: data,
          title: data[notificationPayloadTitleKey] as String? ?? '',
          body: data[notificationPayloadBodyKey] as String? ?? '',
        ),
      );
    } catch (e) {
      debugPrint('❌ Error parsing local notification payload: $e');
    }
  }

  /// Handle a push tapped from the background or a closed app.
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 Notification tapped');
    if (!kReleaseMode) debugPrint('👆 Data: ${message.data}');

    final type = message.data['type'];
    if (type is String && ReminderTelemetry.isReminderType(type)) {
      ReminderTelemetry.logOpened(type);
    }
    _emitTap(
      NotificationTap(
        data: message.data,
        title: message.notification?.title ?? '',
        body: message.notification?.body ?? '',
      ),
    );
  }

  /// Check if app was opened from terminated state via notification tap
  Future<void> _checkInitialMessage() async {
    try {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('🚀 App opened from terminated state via notification');
        if (!kReleaseMode) debugPrint('🚀 Data: ${initialMessage.data}');
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      debugPrint('❌ Error checking initial message: $e');
    }
  }

  /// Subscribe to a topic (for group notifications)
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topic $topic: $e');
    }
  }

  /// Delete FCM token (call this on logout)
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      _currentToken = null;
      debugPrint('✅ FCM token deleted');
    } catch (e) {
      debugPrint('❌ Error deleting FCM token: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _notificationTapController.close();
  }
}
