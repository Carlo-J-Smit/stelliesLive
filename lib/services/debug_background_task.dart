import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart'; // for flutterLocalNotificationsPlugin

Future<void> runBackgroundTaskDebug() async {
  print('*** Running background task DEBUG mode');

  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    print('Location service enabled: $serviceEnabled');
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    print('Location permission: $permission');
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print('Location permission not granted, skipping task.');
      return;
    }

    Position pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
    );
    print('Current position: lat=${pos.latitude}, lng=${pos.longitude}');

    final prefs = await SharedPreferences.getInstance();
    final notify = prefs.getBool('notifyProximity') ?? true;
    print('Proximity notifications enabled: $notify');

    if (notify) {
      final eventsSnapshot = await FirebaseFirestore.instance.collection('events').get();
      print('Found ${eventsSnapshot.docs.length} events to check.');
      for (var doc in eventsSnapshot.docs) {
        final data = doc.data();
        final location = data['location'] as Map<String, dynamic>?;
        if (location != null) {
          final lat = (location['lat'] as num?)?.toDouble();
          final lng = (location['lng'] as num?)?.toDouble();

          final id = doc.id;

          if (lat != null && lng != null) {
            final eventDistance =
            Geolocator.distanceBetween(pos.latitude, pos.longitude, lat, lng);
            print('Distance to event ${data['title']}: $eventDistance meters');

            if (eventDistance <= 200) { // <-- 200 meters instead of 50
              print('Preparing to show notification for ${data['title']}');

              try {
                await flutterLocalNotificationsPlugin.show(
                  id.hashCode,
                  'Near ${data['title']}',
                  'Tap to give feedback or check the event.',
                  const NotificationDetails(
                    android: AndroidNotificationDetails(
                      'event_proximity',
                      'Nearby Events',
                      importance: Importance.high,
                      priority: Priority.high,
                      icon: '@mipmap/ic_launcher',
                    ),
                    iOS: DarwinNotificationDetails(),
                  ),
                );
                print('Notification successfully shown for ${data['title']}');
              } catch (e) {
                print('Error showing notification: $e');
              }

            }
          }
        }
      }
    }
  } catch (e, st) {
    print('Error running background task DEBUG: $e');
    print(st);
  }
}
