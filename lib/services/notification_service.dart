import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data; 

// Handles background messages (must be top-level function, not inside a class)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // App is in background or terminated — FCM handles display automatically
  debugPrint('[FCM] Background message received: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final _localPlugin = FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  OverlayEntry? _fcmToastEntry;

  /// Local exam reminders (used by [ExamNotificationScheduler]).
  static Future<void> init() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localPlugin.initialize(
      settings: const InitializationSettings(android: android),
    );

    await _localPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> scheduleExamReminder({
    required int id,
    required String courseName,
    required DateTime examDate,
  }) async {
    final reminderDate = examDate.subtract(const Duration(days: 1));
    final now = DateTime.now();
    if (reminderDate.isBefore(now)) return;

    final scheduledTime = tz.TZDateTime(
      tz.local,
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      8,
      16,
    );

    await _localPlugin.zonedSchedule(
      id: id,
      title: '⏰ Exam Reminder',
      body:
          'Your $courseName exam is tomorrow. Review your notes and get some rest! 📚',
      scheduledDate: scheduledTime,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'exam_reminders',
          'Exam Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> cancelAll() async => _localPlugin.cancelAll();

  /// Call this once from main.dart before runApp()
  static Future<void> initBackgroundHandler() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  /// Call this after the user logs in
  Future<void> initialize(BuildContext context) async {
    print('🚀 [FCM] Start initialize()...');
    
    print('🚀 [FCM] Requesting permission...');
    await _requestPermission();
    print('🚀 [FCM] Permission step done.');
    
    print('🚀 [FCM] Setting up foreground options...');
    await _setupForegroundOptions();
    print('🚀 [FCM] Foreground options done.');
    
    // Listen for incoming messages while the app is active in foreground
    _configureForegroundListening(context);
    
    print('🚀 [FCM] Calling saveTokenToFirestore()...');
    await saveTokenToFirestore();
    print('🚀 [FCM] initialize() completely finished!');
  }

  // ── Permission ────────────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');
  }

  // ── Foreground display options ────────────────────────────────────────────

  Future<void> _setupForegroundOptions() async {
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: false, 
      badge: true,
      sound: true,
    );
  }

  // ── Foreground Listening Handler ──────────────────────────────────────────

  /// Handles stream listening for active foreground notifications
  void _configureForegroundListening(BuildContext context) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] Active foreground message caught: ${message.notification?.title}');
      
      final title = message.notification?.title ?? 'Notification';
      final body = message.notification?.body ?? '';
      
      if (!Navigator.of(context).mounted) return;

      _fcmToastEntry?.remove();
      _fcmToastEntry = OverlayEntry(
        builder: (ctx) => Positioned(
          top: 24,
          right: 24,
          child: _ToastNotification(
            notificationTitle: title,
            notificationBody: body,
            onDismiss: () {
              _fcmToastEntry?.remove();
              _fcmToastEntry = null;
            },
          ),
        ),
      );

      Overlay.of(context).insert(_fcmToastEntry!);
    });
  }

  // ── Token Management ──────────────────────────────────────────────────────

  /// Saves the FCM token to Firestore so Cloud Functions can send to this device
  Future<void> saveTokenToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    print(' ✅ ✅ ✅ ✅ ✅ ✅[FCM] Current user: ${user?.uid}'); 
    if (user == null) return;

    final token = await _fcm.getToken();
    if (token == null) return;

    await FirebaseFirestore.instance
        .collection('fcmTokens')
        .doc(user.uid)
        .set({
      'token': token,
      'userId': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'platform': defaultTargetPlatform.name,
    }, SetOptions(merge: true));

    debugPrint('[FCM] Token saved to Firestore');
  }

  /// Listen for token refreshes (FCM can rotate tokens)
  void _listenForTokenRefresh() {
    _fcm.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] Token refreshed, updating Firestore...');
      await saveTokenToFirestore();
    });
  }

  /// Call this when the user logs out to remove their token
  Future<void> deleteToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _fcm.deleteToken();
    await FirebaseFirestore.instance
        .collection('fcmTokens')
        .doc(user.uid)
        .delete();

    debugPrint('[FCM] Token deleted from Firestore');
  }
}

class _ToastNotification extends StatefulWidget {
  final String notificationTitle;
  final String notificationBody;
  final VoidCallback onDismiss;

  const _ToastNotification({
    required this.notificationTitle,
    required this.notificationBody,
    required this.onDismiss,
  });

  @override
  State<_ToastNotification> createState() => _ToastNotificationState();
}

class _ToastNotificationState extends State<_ToastNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) _controller.reverse().then((_) => widget.onDismiss());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _opacity,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEDE9FA), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                      color: Color(0xFFEDE9FA), shape: BoxShape.circle),
                  child: const Icon(Icons.notifications_active_rounded,
                      color: Color(0xFF423066), size: 20),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.notificationTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.notificationBody,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _controller.reverse().then((_) => widget.onDismiss()),
                  child: Icon(Icons.close, size: 16, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}