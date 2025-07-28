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



  @override
  void initState() {
    super.initState();
    _initMap();
    _initNotifications();
    Timer.periodic(const Duration(seconds: 180), (_) => _checkProximityToEvent());

  }

  Future<void> _sendFeedbackNotification(Event event) async {
    final plugin = FlutterLocalNotificationsPlugin();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'busyness_feedback',
        'Event Feedback',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await plugin.show(
      0,
      'Are you at ${event.title}?',
      'Tap to give quick feedback!',
      details,
    );
  }

  Future<void> _checkProximityToEvent() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      final now = DateTime.now();

      for (final event in widget.events) {
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

          if (distance <= 20 && !recentlyNotified) {
            _nearbyEvent = event;
            _lastNotified[event.id] = now;
            await _sendFeedbackNotification(event);
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
        if (!status.isGranted) {
          debugPrint("Notification permission not granted.");
          return;
        }
      }
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await plugin.initialize(settings, onDidReceiveNotificationResponse: (res) {
      if (_nearbyEvent != null) {
        _askUserForFeedback(_nearbyEvent!);
      }
    });
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
            for (final level in ['Quiet', 'Moderate', 'Busy'])
              ElevatedButton(
                onPressed: () {
                  FirebaseFirestore.instance.collection('event_feedback').add({
                    'eventId': event.id,
                    'timestamp': Timestamp.now(),
                    'busyness': level,
                    'userId': FirebaseAuth.instance.currentUser?.uid,
                  });
                  Navigator.of(context).pop();
                },
                child: Text(level),
              ),
          ],
        ),
      ),
    );
  }



  Future<void> _initMap() async {
    try {
      final pos = await _handleLocationPermission();
      if (pos == null) return;

      setState(() => _userPosition = pos);
      await _logUserLocation(pos);
      await _loadPopularityCircles();
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

  Future<void> _loadPopularityCircles() async {
    final snapshot = await FirebaseFirestore.instance.collection('location_logs').get();

    final logs = snapshot.docs
        .map((doc) => doc.data())
        .where((data) =>
    data.containsKey('lat') &&
        data.containsKey('lng') &&
        data.containsKey('timestamp'))
        .toList();

    final now = Timestamp.now();
    final recentLogs = logs.where((data) {
      final timestamp = data['timestamp'] as Timestamp;
      return now.seconds - timestamp.seconds <= 30 * 60;
    }).toList();

    final Set<Circle> circles = {};
    int idCounter = 0;

    for (var center in recentLogs) {
      final double lat = center['lat'];
      final double lng = center['lng'];
      final centerPoint = LatLng(lat, lng);

      int nearbyCount = recentLogs.where((entry) {
        final d = Geolocator.distanceBetween(
          lat,
          lng,
          entry['lat'],
          entry['lng'],
        );
        return d <= 50;
      }).length;

      int level = (nearbyCount / 30).round().clamp(1, 3);

      Color color;
      switch (level) {
        case 1:
          color = Colors.green.withOpacity(0.3);
          break;
        case 2:
          color = Colors.orange.withOpacity(0.4);
          break;
        case 3:
        default:
          color = Colors.red.withOpacity(0.5);
          break;
      }

      circles.add(Circle(
        circleId: CircleId('circle_${idCounter++}'),
        center: centerPoint,
        radius: 60,
        fillColor: color,
        strokeColor: Colors.transparent,
      ));
    }

    setState(() {
      _popularityCircles = circles;
      _loading = false;
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
