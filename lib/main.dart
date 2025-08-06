import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:stellieslive/constants/colors.dart';
import 'package:stellieslive/screens/admin_page.dart';
import 'services/firestore_service.dart';
import 'models/event.dart';
import 'widgets/event_card.dart';
import 'firebase_options.dart';
import 'screens/events_screen.dart';
import 'screens/admin_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../screens/about_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async'; // This gives you runZonedGuarded
import 'package:flutter/foundation.dart' show kIsWeb;

Future<void> _requestNotificationPermission() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

void log(String message) => print(message);

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      //ads

      if (!kIsWeb) {
        MobileAds.instance.initialize();
      }

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      log('🔥 Dart main started');

      // Enable Firestore caching (good!)
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // ✅ Initialize Firebase Performance
      FirebasePerformance performance = FirebasePerformance.instance;

      //Notifications
      //await NotificationService.init();

      // // Step 1: Create Android Notification Channel
      //   await _requestNotificationPermission();
      //
      //   const AndroidNotificationChannel channel = AndroidNotificationChannel(
      //     'high_importance_channel', // id
      //     'High Importance Notifications', // title
      //     description: 'This channel is used for important notifications.', // description
      //     importance: Importance.high,
      //   );
      //
      // // Step 2: Initialize the plugin
      //   const AndroidInitializationSettings initializationSettingsAndroid =
      //   AndroidInitializationSettings('ic_stat_notifications');
      //
      //   const InitializationSettings initializationSettings = InitializationSettings(
      //     android: initializationSettingsAndroid,
      //     iOS: DarwinInitializationSettings(),
      //   );
      //
      //   await flutterLocalNotificationsPlugin.initialize(
      //     initializationSettings,
      //     onDidReceiveNotificationResponse: (NotificationResponse response) {
      //       debugPrint('User tapped notification: ${response.payload}');
      //     },
      //   );
      //
      // // Step 3: Register the channel with Android
      //   await flutterLocalNotificationsPlugin
      //       .resolvePlatformSpecificImplementation<
      //       AndroidFlutterLocalNotificationsPlugin>()
      //       ?.createNotificationChannel(channel);

      runApp(const MyApp());
    },
    (error, stack) {
      print('Uncaught error: $error');
      print('Stack trace: $stack');
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StelliesLive',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryRed),
        useMaterial3: true,
      ),
      home: const EventsScreen(),
      routes: {
        '/admin': (context) => AdminPage(),
        '/about': (context) => const AboutScreen(),
      },
    );
  }
}

// class EventsScreen extends StatefulWidget {
//   const EventsScreen({super.key});
//
//   @override
//   State<EventsScreen> createState() => _EventsScreenState();
// }
//
// class _EventsScreenState extends State<EventsScreen> {
//   final FirestoreService _firestoreService = FirestoreService();
//   late Future<List<Event>> _eventsFuture;
//
//   @override
//   void initState() {
//     super.initState();
//     _eventsFuture = _firestoreService.getEvents();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Events')),
//       body: FutureBuilder<List<Event>>(
//         future: _eventsFuture,
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           } else if (snapshot.hasError) {
//             return Center(child: Text('Error: ${snapshot.error}'));
//           } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//             return const Center(child: Text('No events available.'));
//           }
//
//           final events = snapshot.data!;
//           return ListView.builder(
//             itemCount: events.length,
//             itemBuilder: (context, index) => EventCard(event: events[index]),
//           );
//         },
//       ),
//     );
//   }
// }
