import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class MessagingService {
  static final MessagingService _instance = MessagingService._internal();
  factory MessagingService() => _instance;
  MessagingService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Call this in main.dart after Firebase.initializeApp()
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb) {
      // Skip web entirely
     debugPrint('[FCM] Web detected — skipping notifications');
      return;
    }

    // Local notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _local.initialize(initSettings);

    // iOS permissions
    if (Platform.isIOS) {
      await _fcm.requestPermission(alert: true, badge: true, sound: true);
    }

    // Foreground messages
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // Background messages
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Save FCM token
    await _saveDeviceToken();
    _fcm.onTokenRefresh.listen(_saveDeviceToken);
  }

  /// Store FCM token in Firestore
  Future<void> _saveDeviceToken([String? newToken]) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = newToken ?? await _fcm.getToken();
    if (token == null) return;

    String platform = Platform.isIOS ? 'ios' : 'android';

    await _db.collection('devices').doc(token).set({
      'userId': user.uid,
      'fcmToken': token,
      'platform': platform,
      'lastSeen': FieldValue.serverTimestamp(),
      'enabled': true,
    }, SetOptions(merge: true));
  }

  /// Subscribe to a topic
  Future<void> subscribeTopic(String topic) async => _fcm.subscribeToTopic(topic);

  /// Unsubscribe from a topic
  Future<void> unsubscribeTopic(String topic) async => _fcm.unsubscribeFromTopic(topic);

  /// Show local notification for foreground messages
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'General Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);
    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
    );
  }
}

/// Background message handler (must be top-level)
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Log or handle silent updates here
}
