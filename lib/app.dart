import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/fcm_service.dart';
import 'theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/session_detail_screen.dart';
import 'screens/permission_request_screen.dart';
import 'screens/question_reply_screen.dart';

class ClaudeNotifyApp extends StatefulWidget {
  const ClaudeNotifyApp({super.key});

  @override
  State<ClaudeNotifyApp> createState() => _ClaudeNotifyAppState();
}

class _ClaudeNotifyAppState extends State<ClaudeNotifyApp> {
  late final AuthService _auth;
  late final FirestoreService _firestore;
  late final FcmService _fcm;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _auth = AuthService();
    _firestore = FirestoreService();
    _fcm = FcmService(_firestore);

    // Init FCM when user signs in
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) _fcm.init(user.uid);
    });

    _router = GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        final loggedIn = FirebaseAuth.instance.currentUser != null;
        final onLogin = state.matchedLocation == '/login';
        if (!loggedIn && !onLogin) return '/login';
        if (loggedIn && onLogin) return '/';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (ctx, state) => LoginScreen(auth: _auth),
        ),
        GoRoute(
          path: '/',
          builder: (ctx, state) =>
              HomeScreen(firestore: _firestore, auth: _auth),
        ),
        GoRoute(
          path: '/session/:sessionId',
          builder: (ctx, state) => SessionDetailScreen(
            sessionId: state.pathParameters['sessionId']!,
            firestore: _firestore,
          ),
        ),
        GoRoute(
          path: '/permission/:sessionId',
          builder: (ctx, state) {
            final sessionId = state.pathParameters['sessionId']!;
            final eventId = state.uri.queryParameters['eventId'] ?? '';
            return PermissionRequestScreen(
              sessionId: sessionId,
              eventId: eventId,
              firestore: _firestore,
            );
          },
        ),
        GoRoute(
          path: '/question/:sessionId',
          builder: (ctx, state) {
            final sessionId = state.pathParameters['sessionId']!;
            final eventId = state.uri.queryParameters['eventId'] ?? '';
            return QuestionReplyScreen(
              sessionId: sessionId,
              eventId: eventId,
              firestore: _firestore,
            );
          },
        ),
      ],
    );

    // Handle FCM messages while app is open (foreground)
    _fcm.onMessage.listen(_handleForegroundMessage);

    // Handle FCM notification taps (app in background, user taps banner)
    _fcm.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle initial notification tap (app launched from notification)
    _fcm.getInitialMessage().then((msg) {
      if (msg != null) _handleNotificationTap(msg);
    });
  }

  void _handleForegroundMessage(RemoteMessage msg) {
    // Show a real OS notification with sound even while app is open
    _fcm.showLocalNotification(msg);
  }

  void _handleNotificationTap(RemoteMessage msg) {
    final data = msg.data;
    final screen = data['screen'] as String?;
    final sessionId = data['sessionId'] as String?;
    final eventId = data['eventId'] as String?;
    if (sessionId == null) return;

    switch (screen) {
      case 'permission':
        _router.go('/permission/$sessionId?eventId=${eventId ?? ""}');
        break;
      case 'question':
        _router.go('/question/$sessionId?eventId=${eventId ?? ""}');
        break;
      default:
        _router.go('/session/$sessionId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Claude Notify',
      theme: appTheme(),
      routerConfig: _router,
    );
  }
}
