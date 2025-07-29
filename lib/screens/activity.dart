import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event.dart';
import '../widgets/event_card.dart';
import '../widgets/nav_bar.dart';
import 'dart:async'; // For Timer
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';


class ActivityScreen extends StatefulWidget {
  final List<Event> events;

  const ActivityScreen({super.key, required this.events});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late GoogleMapController _mapController;
  Set<Circle> _popularityCircles = {};
  bool _loading = true;
  bool _showHeatmap = true;
  Position? _userPosition;
  String? _error;
  Event? _selectedEvent;
  LatLng? _selectedEventPosition;
  Event? _nearbyEvent;
  final Map<String, DateTime> _lastNotified = {};
  bool _notificationsBlocked = false;





  Future<void> _initActivity() async {
    final pos = await _handleLocationPermission();
    if (pos == null) return;

    setState(() => _userPosition = pos);
    setState(() => _loading = false); // after getting location

     _logUserLocation(pos);


    if (!_notificationsBlocked) {
      debugPrint('[NOTIF] Proximity trigger check ran');
      // ✅ CALL IT ONCE IMMEDIATELY
      await _checkProximityToEvent();

      // ✅ THEN CONTINUE WITH THE TIMER
      Timer.periodic(const Duration(seconds: 30), (_) => _checkProximityToEvent());
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initNotifications();
      await _initActivity();
    });

    _subscribeToClusterUpdates();
  }



  Future<void> _sendFeedbackNotification(Event event) async {
    debugPrint('[NOTIF] Trying to send');
    final plugin = FlutterLocalNotificationsPlugin();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'busyness_feedback',
        'Event Feedback',
        icon: '@mipmap/ic_launcher',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    try {
      await plugin.show(
        0,
        'Are you at ${event.title}?',
        'Tap to give quick feedback!',
        details,
      );
      debugPrint("✅ Feedback notification sent for ${event.title}");
    } catch (e) {
      debugPrint("❌ Failed to send feedback notification: $e");
    }


  }

  Future<void> _checkProximityToEvent() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      debugPrint("📍 User position: ${pos.latitude}, ${pos.longitude}");
      final now = DateTime.now();
      Text('Nearby event: ${_nearbyEvent?.title ?? "None"}');




      for (final event in widget.events) {
        debugPrint("Checking event: ${event.title}, lat=${event.lat}, lng=${event.lng}");
        if (event.lat != null && event.lng != null) {
          final distance = Geolocator.distanceBetween(
            pos.latitude,
            pos.longitude,
            event.lat!,
            event.lng!,
          );

          final lastTime = _lastNotified[event.id];
          final recentlyNotified = lastTime != null &&
              now.difference(lastTime).inMinutes < 30;

          if (distance <= 100 ) { //&& !recentlyNotified
            debugPrint("✅ Close to ${event.title} (${distance.toStringAsFixed(1)}m)");
            _nearbyEvent = event;
            _lastNotified[event.id] = now;
            debugPrint('[NOTIF] Proximity trigger ran');
            if (mounted) {
              _askUserForFeedback(event);
            }
            await _sendFeedbackNotification(event);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Notification sent for ${event.title}')),
            );
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking proximity: $e');
    }
  }




  Future<void> _initNotifications() async {
    final plugin = FlutterLocalNotificationsPlugin();

    // ✅ Check Android version and request notification permission
    if (Theme.of(context).platform == TargetPlatform.android) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        final status = await Permission.notification.request();
        _notificationsBlocked = !status.isGranted;
        if (_notificationsBlocked) {
          debugPrint("Notifications are blocked.");
          return;
        }
      }
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'), // fallback to the default launcher icon
      iOS: DarwinInitializationSettings(),
    );


    await plugin.initialize(settings, onDidReceiveNotificationResponse: (res) {
    });

    await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
      const AndroidNotificationChannel(
        'busyness_feedback',
        'Event Feedback',
        description: 'Notifications asking for event feedback',
        importance: Importance.high,
      ),
    );
    debugPrint("[NOTIF] Init complete: blocked = $_notificationsBlocked");

    if (_nearbyEvent != null) {
      _askUserForFeedback(_nearbyEvent!);
    }
  }

  void _askUserForFeedback(Event event) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('At ${event.title}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How busy is it?'),
            ...['Quiet', 'Moderate', 'Busy'].map((level) {
              return ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop(); // ✅ Closes immediately

                  final pos = await Geolocator.getCurrentPosition();

                  const maxDistance = 60.0;
                  final mergedRef = FirebaseFirestore.instance.collection('merged_clusters');
                  final snapshot = await mergedRef.get();

                  String? clusterId;
                  double minDistance = double.infinity;

                  for (var doc in snapshot.docs) {
                    final data = doc.data();
                    final double lat = data['lat'];
                    final double lng = data['lng'];

                    final distance = Geolocator.distanceBetween(
                      pos.latitude, pos.longitude, lat, lng,
                    );

                    if (distance < minDistance && distance <= maxDistance) {
                      minDistance = distance;
                      clusterId = doc.id;
                    }
                  }

                  // 🌱 Create new cluster if none found
                  if (clusterId == null) {
                    final newDoc = await mergedRef.add({
                      'lat': pos.latitude,
                      'lng': pos.longitude,
                      'level': level, // initial level based on feedback
                      'createdFrom': 'app',
                      'updated': Timestamp.now(),
                    });
                    clusterId = newDoc.id;
                    debugPrint("🆕 New cluster created: $clusterId");
                  }

                  await FirebaseFirestore.instance.collection('event_feedback').add({
                    'eventId': event.id,
                    'timestamp': Timestamp.now(),
                    'busyness': level,
                    'userId': FirebaseAuth.instance.currentUser?.uid,
                    'clusterId': clusterId,
                  });

                  debugPrint("✅ Feedback submitted for $clusterId ($level)");
                },
                child: Text(level),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }



  void _sendTestNotification() async {
    debugPrint("Trying to send test notification...");

    if (_notificationsBlocked) {
      debugPrint("Blocked: Notification permission not granted.");
      return;
    }

    final plugin = FlutterLocalNotificationsPlugin();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'busyness_feedback',
        'Event Feedback',
        icon: '@mipmap/ic_launcher',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );


    try {
      await plugin.show(
        999,
        'Test Notification',
        'This is a test notification to verify your setup.',
        details,
      );


      debugPrint("✅ Test notification sent.");
    } catch (e) {
      debugPrint("❌ Failed to send test notification: $e");
    }
  }





  Future<void> _initMap() async {
    try {
      final pos = await _handleLocationPermission();
      if (pos == null) return;

      setState(() => _userPosition = pos);
      await _logUserLocation(pos);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _logUserLocation(Position pos) async {
    await FirebaseFirestore.instance.collection('location_logs').add({
      'userId': FirebaseAuth.instance.currentUser?.uid,
      'timestamp': Timestamp.now(),
      'lat': pos.latitude,
      'lng': pos.longitude,
    });
  }

  void _handleLongPress(LatLng tappedPoint) {
    const double maxDistance = 60; // Match cluster radius
    Circle? nearest;
    double minDistance = double.infinity;

    for (final circle in _popularityCircles) {
      final distance = Geolocator.distanceBetween(
        tappedPoint.latitude,
        tappedPoint.longitude,
        circle.center.latitude,
        circle.center.longitude,
      );

      if (distance < minDistance && distance <= maxDistance) {
        minDistance = distance;
        nearest = circle;
      }
    }

    if (nearest != null) {
      final clusterId = nearest.circleId.value;
      final match = FirebaseFirestore.instance
          .collection('popularity_clusters')
          .doc(clusterId)
          .get();

      match.then((doc) {
        if (doc.exists) {
          final count = doc['count'];
          final level = doc['level'];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cluster: $count pings ($level)')),
          );
        }
      });
    }
  }


  Future<Position?> _handleLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showDialog("Location services are disabled. Please enable them in your device settings.");
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showDialog("Location permission is required to show the map.");
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showDialog(
        "Location permission is permanently denied. Please open app settings to enable it.",
        showSettings: true,
      );
      return null;
    }

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
  }

  void _showDialog(String message, {bool showSettings = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Location Required'),
        content: Text(message),
        actions: [
          if (showSettings)
            TextButton(
              onPressed: () => Geolocator.openAppSettings(),
              child: const Text('Open Settings'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _subscribeToClusterUpdates() {
    FirebaseFirestore.instance
        .collection('merged_clusters')
        .snapshots()
        .listen((snapshot) {
      final Set<Circle> circles = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final lat = data['lat'] as double;
        final lng = data['lng'] as double;
        final level = data['level'] as String;

        Color color;
        switch (level) {
          case 'Quiet':
            color = Colors.green.withAlpha(77);
            break;
          case 'Moderate':
            color = Colors.orange.withAlpha(120);
            break;
          case 'Busy':
            color = Colors.red.withAlpha(140);
            break;
          default:
            color = Colors.white.withAlpha(0); // fallback
        }

        circles.add(Circle(
          circleId: CircleId(doc.id),
          center: LatLng(lat, lng),
          radius: 60,
          fillColor: color,
          strokeColor: Colors.transparent,
        ));
      }

      setState(() {
        _popularityCircles = {
          ..._popularityCircles,
          ...circles, // overlays matching IDs will fade smoothly
        };
      });

    });
  }



  Widget _buildLegend() {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white70,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: const [
            _LegendItem(color: Colors.green, label: 'Quiet'),
            _LegendItem(color: Colors.orange, label: 'Moderate'),
            _LegendItem(color: Colors.red, label: 'Busy'),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationBanner() {
    if (!_notificationsBlocked) return const SizedBox.shrink();

    return Positioned(
      top: 70,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: const [
            Icon(Icons.warning, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Notifications are blocked. Enable them in system settings.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Navbar(),
          Expanded(
            child: _loading || _userPosition == null
                ? const Center(child: CircularProgressIndicator())
                : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      _userPosition!.latitude,
                      _userPosition!.longitude,
                    ),
                    zoom: 14,
                  ),
                  markers: {},
                  circles: _showHeatmap ? _popularityCircles : {},
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _mapController.animateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: LatLng(
                            _userPosition!.latitude,
                            _userPosition!.longitude,
                          ),
                          zoom: 15,
                        ),
                      ),
                    );
                  },
                  onCameraMoveStarted: () {
                    setState(() {
                      _selectedEvent = null;
                      _selectedEventPosition = null;
                    });
                  },
                  onTap: (_) {
                    setState(() {
                      _selectedEvent = null;
                      _selectedEventPosition = null;
                    });
                  },
                  onLongPress: _handleLongPress,
                ),
                if (_selectedEvent != null)
                  Positioned(
                    left: MediaQuery.of(context).size.width / 2 - 150,
                    bottom: 120,
                    child: SizedBox(
                      width: 300,
                      child: Stack(
                        children: [
                          EventCard(event: _selectedEvent!),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _selectedEvent = null;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                _buildLegend(),
                _buildNotificationBanner(),
                Positioned(
                  bottom: 80,
                  right: 16,
                  child: FloatingActionButton.extended(
                    onPressed: _sendTestNotification,
                    label: const Text('Test Notification'),
                    icon: const Icon(Icons.notifications),
                    backgroundColor: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 14, height: 14, color: color),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
