import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firestore_service.dart';

const _channelId = 'claude_notify_foreground';
const _channelName = 'Claude Notify';

/// Top-level background message handler (must be top-level function).
/// Shows notification via flutter_local_notifications so we control the icon.
/// Background handler — with notification+data messages, Android already shows
/// the notification automatically in background. This handler is a no-op to
/// avoid duplicate notifications. It must still be registered.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No-op: Android system already displayed the notification using the
  // icon/color/channel set in the FCM android.notification payload.
}

class FcmService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirestoreService _firestore;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  final Set<String> _processedMessageIds = {};

  FcmService(this._firestore);

  Future<void> init(String uid) async {
    // Guard against multiple calls (authStateChanges fires repeatedly)
    if (_initialized) return;
    _initialized = true;

    // Request permissions (iOS)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // iOS: disable system foreground presentation — we handle it ourselves
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );

    // Set up local notifications (used for foreground sound + banner)
    const android = AndroidInitializationSettings('ic_notification');
    const ios = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Android: create high-importance channel so sound plays
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            importance: Importance.high,
            playSound: true,
          ),
        );

    // Save FCM token (do NOT delete+recreate — that's counterproductive)
    final token = await _fcm.getToken();
    if (token != null) {
      await _firestore.saveFcmToken(uid, token);
    }

    // Refresh token handler
    _fcm.onTokenRefresh.listen((newToken) {
      _firestore.saveFcmToken(uid, newToken);
    });
  }

  /// Show a local notification with sound.
  Future<void> showLocalNotification(RemoteMessage msg) async {
    // Deduplicate by messageId
    if (msg.messageId != null && !_processedMessageIds.add(msg.messageId!)) {
      return;
    }
    if (_processedMessageIds.length > 500) _processedMessageIds.clear();

    // Discard messages older than 5 minutes
    final sentAt = int.tryParse(msg.data['sentAt'] ?? '');
    if (sentAt != null && DateTime.now().millisecondsSinceEpoch - sentAt > 300000) return;

    final title = msg.data['title'] ?? msg.notification?.title ?? '';
    final body  = msg.data['body']  ?? msg.notification?.body  ?? '';
    if (title.isEmpty && body.isEmpty) return;

    await _localNotifications.show(
      msg.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          icon: 'ic_notification',
          color: const Color(0xFF3F51B5),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
        ),
      ),
    );
  }

  /// Returns the initial notification if the app was launched via a tap.
  Future<RemoteMessage?> getInitialMessage() => _fcm.getInitialMessage();

  /// Stream of notifications received while app is in foreground.
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  /// Stream of notification taps when app is in background (not terminated).
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;
}
