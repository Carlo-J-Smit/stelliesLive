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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:stellieslive/services/messaging_service.dart';
import 'firebase_options.dart'; // If you have generated firebase options

Future<void> _requestNotificationPermission() async {
  //
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

      //await MessagingService().init();


      const useEmulator = true; // <-- toggle ON/OFF

      final emulatorHost = kIsWeb ? 'localhost' : '10.0.2.2';
      //final emulatorHost = '192.168.68.104'; //over network

      if (useEmulator) {
        FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
        FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
        FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);
      }

      log('🔥 Dart main started');

      // Enable Firestore caching (good!)
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // ✅ Initialize Firebase Performance
      FirebasePerformance performance = FirebasePerformance.instance;

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
