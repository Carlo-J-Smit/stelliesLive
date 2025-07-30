import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
    InitializationSettings(android: androidSettings);

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request permissions (especially for iOS, but good practice)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle messages in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle taps on notifications (cold-start or background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      _flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', // must match with created channel ID
            'Important Notifications',
            channelDescription: 'This channel is used for important notifications.',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
          ),
        ),
      );
    }
  }

  static void _handleNotificationTap(RemoteMessage message) {
    debugPrint("User tapped notification: ${message.data}");
    // TODO: Handle navigation or action based on message data
  }

  static void _onNotificationTap(NotificationResponse response) {
    debugPrint("Local notification tapped: ${response.payload}");
    // TODO: Handle navigation based on payload (if used)
  }

  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    debugPrint("Background message received: ${message.messageId}");
    // You can handle background logic here if needed
  }

  static Future<void> showTestNotification() async {
    await _flutterLocalNotificationsPlugin.show(
      0,
      "Test Notification",
      "This is a test local notification",
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'Important Notifications',
          channelDescription: 'This channel is used for important notifications.',
          importance: Importance.high,
        ),
      ),
    );
  }
}
