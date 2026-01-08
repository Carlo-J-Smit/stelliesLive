import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/web_location_pinger.dart'
  if (dart.library.io) 'services/location_pinger_stub.dart';




import 'firebase_options.dart';
import 'screens/events_screen.dart';
import 'screens/admin_page.dart';
import 'screens/about_screen.dart';
import 'screens/SettingsScreen.dart';
import 'constants/colors.dart';
import 'providers/event_provider.dart';
import 'services/firestore_service.dart';
import 'models/event.dart';
import 'widgets/event_card.dart';


const String locationTask = "pingUserLocation";
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

/// Background callback for WorkManager
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    debugPrint('*** callbackDispatcher triggered for task: $task');

    if (task != locationTask) return Future.value(true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location service disabled.');
        return Future.value(true);
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('Location permission not granted.');
        return Future.value(true);
      }

      // Get device location
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      debugPrint('Current position: lat=${pos.latitude}, lng=${pos.longitude}');

      // Log location — no auth required
      await FirebaseFirestore.instance.collection('location_logs').add({
        'timestamp': Timestamp.now(),
        'lat': pos.latitude,
        'lng': pos.longitude,
      });
      debugPrint('Location logged successfully.');

    } catch (e, stack) {
      debugPrint('Background location error: $e');
      debugPrint('Stack trace: $stack');
    }

    debugPrint('*** callbackDispatcher finished for task: $task');
    return Future.value(true);
  });
}



Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Ads
    if (!kIsWeb) {
      MobileAds.instance.initialize();
    }

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Enable Firestore caching
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Initialize Firebase Performance
    FirebasePerformance performance = FirebasePerformance.instance;

    // Firebase emulators (toggle ON/OFF)
    const useEmulator = false;
    final emulatorHost = kIsWeb ? 'localhost' : '10.0.2.2';
    //final emulatorHost = '192.168.68.104';

    if (useEmulator) {
      FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
      FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
      FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);
    }

    // Disable debugPrint in release
    if (kReleaseMode) {
      debugPrint = (String? message, {int? wrapWidth}) {};
    }

    // WorkManager init
    if (!kIsWeb) {
      Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

      // Trigger first ping immediately
      Workmanager().registerOneOffTask(
        "initial_location_ping",
        locationTask,
        initialDelay: Duration(seconds: 15), // trigger almost immediately
      );

      // Then schedule periodic background task every 30 minutes
      Workmanager().registerPeriodicTask(
        "periodic_location_ping",
        locationTask,
        frequency: const Duration(minutes: 30),
        initialDelay: Duration(minutes: 30), // first periodic run after 30 mins
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
    }

    // Initialize notifications
    await initNotifications();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => EventProvider()),
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('Uncaught error: $error');
    debugPrint('Stack trace: $stack');
  });
}

/// Initialize Flutter Local Notifications (foreground + background support)
@pragma('vm:entry-point')
Future<void> initNotifications() async {
  const AndroidInitializationSettings androidSettings =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iOSSettings = DarwinInitializationSettings(
    requestSoundPermission: true,
    requestBadgePermission: true,
    requestAlertPermission: true,
  );

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: androidSettings, iOS: iOSSettings),
  );

  // Create Android notification channel (required for foreground notifications)
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
    const AndroidNotificationChannel(
      'event_proximity', // id
      'Nearby Events', // name
      description: 'Notifications for nearby events',
      importance: Importance.high,
    ),
  );
}

/// Request and handle location permission
@pragma('vm:entry-point')
Future<bool> ensureLocationPermission() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return false;

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return false;
  }

  if (permission == LocationPermission.deniedForever) return false;

  return true;
}

/// Main app
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _notifyProximity = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    if (kIsWeb) {
      WebLocationPinger.start();
    }


    // Request permissions AFTER first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _requestPermissionsOnLaunch();
      await _subscribeToBusinessTopic();
    });

    _setupFCMListeners();
  }

  void _setupFCMListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      if (notification == null) return;

      await flutterLocalNotificationsPlugin.show(
        message.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'event_proximity',
            'Nearby Events',
            channelDescription: 'Notifications for events and updates',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification opened: ${message.data}');
      // Optional: navigate to event screen using eventId
    });
  }


  Future<void> _subscribeToBusinessTopic() async {
    // You already know the business name in your app
    if (kIsWeb) return;
    const businessName = 'stellieslive'; // or load dynamically if needed

    await FirebaseMessaging.instance.subscribeToTopic(
      'business_$businessName',
    );

    debugPrint('Subscribed to business_$businessName');
  }

  Future<void> subscribeToEvent(Event event) async {
    if (event.id == null) return;
    if (kIsWeb) return;
    await FirebaseMessaging.instance.subscribeToTopic(
      'event_${event.id}',
    );

    debugPrint('Subscribed to event_${event.id}');
  }


  Future<void> _requestPermissionsOnLaunch() async {
    // --- Location permission ---
    bool locationGranted = await ensureLocationPermission();
    if (!locationGranted && mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Location Required'),
          content: const Text(
              'Enable location to allow background event notifications.'),
          actions: [
            TextButton(
              onPressed: () async {
                await Geolocator.openAppSettings();
                Navigator.pop(context);
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }

    // --- Notification permission ---
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied && mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Notifications Required'),
          content: const Text('Enable notifications to receive event alerts.'),
          actions: [
            TextButton(
              onPressed: () async {
                await openAppSettings();
                Navigator.pop(context);
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }

    debugPrint(
        'Permissions on launch — Location: $locationGranted, Notifications: ${settings.authorizationStatus}');
  }

  @pragma('vm:entry-point')
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifyProximity = prefs.getBool('notifyProximity') ?? true;
    });
  }

  @pragma('vm:entry-point')
  Future<void> _checkLocationPermission() async {
    bool granted = await ensureLocationPermission();
    if (!granted && mounted) {
      debugPrint('Notification permission granted & mounted');
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Location Required'),
          content: const Text('Enable location to allow background pings.'),
          actions: [
            TextButton(
              onPressed: () async {
                await Geolocator.openAppSettings();
                Navigator.pop(context);
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    } else {
      debugPrint('Notification permission denied');
    }
  }

  @pragma('vm:entry-point')
  void _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifyProximity', value);
    setState(() {
      _notifyProximity = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'StelliesLive',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryRed),
        useMaterial3: true,
      ),
      home: EventsScreen(),
      routes: {
        '/admin': (context) => AdminPage(),
        '/about': (context) => const AboutScreen(),
        '/settings': (context) => const SettingsScreen(), // <- new
      },

    );
  }
}
