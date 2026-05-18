// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/foundation.dart';

// // Handles background messages (must be top-level function, not inside a class)
// @pragma('vm:entry-point')
// Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   // App is in background or terminated — FCM handles display automatically
//   debugPrint('[FCM] Background message received: ${message.messageId}');
// }

// class NotificationService {
//   static final NotificationService _instance = NotificationService._internal();
//   factory NotificationService() => _instance;
//   NotificationService._internal();

//   final FirebaseMessaging _fcm = FirebaseMessaging.instance;

//   /// Call this once from main.dart before runApp()
//   static Future<void> initBackgroundHandler() async {
//     FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
//   }

//   /// Call this after the user logs in
//   // Future<void> initialize() async {
//   //   await _requestPermission();
//   //   await _setupForegroundOptions();
//   //   await saveTokenToFirestore();
//   //   _listenForTokenRefresh();
//   // }

//   /// Call this after the user logs in
//   Future<void> initialize() async {
//     print('🚀 [FCM] Start initialize()...');
    
//     print('🚀 [FCM] Requesting permission...');
//     await _requestPermission();
//     print('🚀 [FCM] Permission step done.');
    
//     print('🚀 [FCM] Setting up foreground options...');
//     await _setupForegroundOptions();
//     print('🚀 [FCM] Foreground options done.');
    
//     print('🚀 [FCM] Calling saveTokenToFirestore()...');
//     await saveTokenToFirestore();
//     print('🚀 [FCM] initialize() completely finished!');
//   }

//   // ── Permission ────────────────────────────────────────────────────────────

//   Future<void> _requestPermission() async {
//     final settings = await _fcm.requestPermission(
//       alert: true,
//       badge: true,
//       sound: true,
//     );
//     debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');
//   }

//   // ── Foreground display options (iOS only) ─────────────────────────────────

//   Future<void> _setupForegroundOptions() async {
//     // Show notification banner even when app is open (iOS)
//     await _fcm.setForegroundNotificationPresentationOptions(
//       alert: true,
//       badge: true,
//       sound: true,
//     );
//   }

//   // ── Token Management ──────────────────────────────────────────────────────

//   /// Saves the FCM token to Firestore so Cloud Functions can send to this device
//   Future<void> saveTokenToFirestore() async {
//     final user = FirebaseAuth.instance.currentUser;
//     print(' ✅ ✅ ✅ ✅ ✅ ✅[FCM] Current user: ${user?.uid}'); 
//     if (user == null) return;

//     final token = await _fcm.getToken();
//     if (token == null) return;

//     await FirebaseFirestore.instance
//         .collection('fcmTokens')
//         .doc(user.uid)
//         .set({
//       'token': token,
//       'userId': user.uid,
//       'updatedAt': FieldValue.serverTimestamp(),
//       'platform': defaultTargetPlatform.name,
//     }, SetOptions(merge: true));

//     debugPrint('[FCM] Token saved to Firestore');
//   }

//   /// Listen for token refreshes (FCM can rotate tokens)
//   void _listenForTokenRefresh() {
//     _fcm.onTokenRefresh.listen((newToken) async {
//       debugPrint('[FCM] Token refreshed, updating Firestore...');
//       await saveTokenToFirestore();
//     });
//   }

//   /// Call this when the user logs out to remove their token
//   Future<void> deleteToken() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return;

//     await _fcm.deleteToken();
//     await FirebaseFirestore.instance
//         .collection('fcmTokens')
//         .doc(user.uid)
//         .delete();

//     debugPrint('[FCM] Token deleted from Firestore');
//   }
// }

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  /// Call this once from main.dart before runApp()
  static Future<void> initBackgroundHandler() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  /// Call this after the user logs in
  Future<void> initialize() async {
    print('🚀 [FCM] Start initialize()...');
    
    print('🚀 [FCM] Requesting permission...');
    await _requestPermission();
    print('🚀 [FCM] Permission step done.');
    
    print('🚀 [FCM] Setting up foreground options...');
    await _setupForegroundOptions();
    print('🚀 [FCM] Foreground options done.');
    
    // Listen for incoming messages while the app is active in foreground
    _configureForegroundListening();
    
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

  // ── Foreground display options (iOS only) ─────────────────────────────────

  Future<void> _setupForegroundOptions() async {
    // Show notification banner even when app is open (iOS)
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // ── Foreground Listening Handler ──────────────────────────────────────────

  /// Handles stream listening for active foreground notifications
  void _configureForegroundListening() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] Active foreground message caught: ${message.notification?.title}');
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