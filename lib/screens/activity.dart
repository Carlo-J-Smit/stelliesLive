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
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/native_ad_banner.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;


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
  String? _mapStyle;
  bool _isDarkMap = false;
  bool _mapReady = false;
  String? _darkStyle;
  double _bottomMapPadding = 0;

  Future<void> _initActivity() async {
    final pos = await _handleLocationPermission();
    if (pos == null) return;

    setState(() => _userPosition = pos);
    setState(() => _loading = false); // after getting location

    _logUserLocation(pos);

    await _checkProximityToEvent();

  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMap = prefs.getBool('isDarkMap') ?? false;

      // If dark, preload map style
      _darkStyle = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/map_style.json').catchError((e) {
        debugPrint("❌ Could not load dark style: $e");
        return null;
      });

      _mapStyle = _isDarkMap ? _darkStyle : null;
      _mapReady = true;
      setState(() {});

      //await _initNotifications();
      await _initActivity();
    });

    _subscribeToClusterUpdates();
  }

  Future<void> _sendFeedbackNotification(Event event) async {
    return;
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
        debugPrint(
          "Checking event: ${event.title}, lat=${event.lat}, lng=${event.lng}",
        );
        if (event.lat != null && event.lng != null) {
          final distance = Geolocator.distanceBetween(
            pos.latitude,
            pos.longitude,
            event.lat!,
            event.lng!,
          );

          final lastTime = _lastNotified[event.id];
          final recentlyNotified =
              lastTime != null && now.difference(lastTime).inMinutes < 30;

          if (distance <= 100) {
            //&& !recentlyNotified
            debugPrint(
              "✅ Close to ${event.title} (${distance.toStringAsFixed(1)}m)",
            );
            _nearbyEvent = event;
            _lastNotified[event.id] = now;
            debugPrint('[NOTIF] Proximity trigger ran');
            if (mounted) {
              _askUserForFeedback(event);
            }
            await _sendFeedbackNotification(event);
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(content: Text('Notification sent for ${event.title}')),
            // );
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
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      // fallback to the default launcher icon
      iOS: DarwinInitializationSettings(),
    );

    await plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (res) {},
    );

    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
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
    final isDark = _isDarkMap;

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor:
                isDark
                    ? const Color(0xCC1E1E1E) // 80% opacity black
                    : Colors.white.withOpacity(0.90), // 95% opacity white

            title: Text(
              'At ${event.title}?',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'How busy is it?',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                ...['Quiet', 'Moderate', 'Busy'].map((level) {
                  Color bgColor;
                  switch (level) {
                    case 'Quiet':
                      bgColor = Colors.green;
                      break;
                    case 'Moderate':
                      bgColor = Colors.orange;
                      break;
                    case 'Busy':
                      bgColor = Colors.red;
                      break;
                    default:
                      bgColor = Colors.grey;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: bgColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        Navigator.of(context).pop(); // Close dialog immediately

                        final pos = await Geolocator.getCurrentPosition();

                        const maxDistance = 60.0;
                        final mergedRef = FirebaseFirestore.instance.collection(
                          'merged_clusters',
                        );
                        final snapshot = await mergedRef.get();

                        String? clusterId;
                        double minDistance = double.infinity;

                        for (var doc in snapshot.docs) {
                          final data = doc.data();
                          final double lat = data['lat'];
                          final double lng = data['lng'];

                          final distance = Geolocator.distanceBetween(
                            pos.latitude,
                            pos.longitude,
                            lat,
                            lng,
                          );

                          if (distance < minDistance &&
                              distance <= maxDistance) {
                            minDistance = distance;
                            clusterId = doc.id;
                          }
                        }

                        if (clusterId == null) {
                          final newDoc = await mergedRef.add({
                            'lat': pos.latitude,
                            'lng': pos.longitude,
                            'level': level,
                            'createdFrom': 'app',
                            'updated': Timestamp.now(),
                          });
                          clusterId = newDoc.id;
                          debugPrint("🆕 New cluster created: $clusterId");
                        }

                        try {
                          await FirebaseFirestore.instance
                              .collection('event_feedback')
                              .add({
                                'eventId': event.id,
                                'timestamp': Timestamp.now(),
                                'busyness': level,
                                'userId':
                                    FirebaseAuth.instance.currentUser?.uid,
                                'clusterId': clusterId,
                              });
                          debugPrint(
                            "✅ Feedback submitted for $clusterId ($level)",
                          );
                        } catch (e) {
                          debugPrint("❌ Firestore write failed: $e");
                        }
                      },
                      child: Text(level),
                    ),
                  );
                }),
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
      final match =
          FirebaseFirestore.instance
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
      _showDialog(
        "Location services are disabled. Please enable them in your device settings.",
      );
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

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
  }

  void _showDialog(String message, {bool showSettings = false}) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
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
    FirebaseFirestore.instance.collection('merged_clusters').snapshots().listen(
      (snapshot) {
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

          circles.add(
            Circle(
              circleId: CircleId(doc.id),
              center: LatLng(lat, lng),
              radius: 60,
              fillColor: color,
              strokeColor: Colors.transparent,
            ),
          );
        }

        setState(() {
          _popularityCircles = {
            ..._popularityCircles,
            ...circles, // overlays matching IDs will fade smoothly
          };
        });
      },
    );
  }

  Widget _buildLegend() {
    final isDark = _isDarkMap;

    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          //color: isDark ? Colors.black.withOpacity(0.7) : Colors.white70,
          color: Colors.white70,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            //color: isDark ? Colors.white24 : Colors.black12,
            color: Colors.black12,
          ),
        ),
        child: Column(
          children: [
            _LegendItem(color: Colors.green, label: 'Quiet', isDark: isDark),
            _LegendItem(
              color: Colors.orange,
              label: 'Moderate',
              isDark: isDark,
            ),
            _LegendItem(color: Colors.red, label: 'Busy', isDark: isDark),
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

  void _applyMapStyle() {
    if (_mapController == null) return;

    final style = _isDarkMap ? _darkStyle : null;

    _mapController.setMapStyle(style);
    debugPrint('[MAP] Applied style: ${_isDarkMap ? "Dark" : "Default"}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Navbar(),
          Expanded(
            child:
                _loading || _userPosition == null || !_mapReady
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
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                          mapToolbarEnabled: false,
                          padding: EdgeInsets.only(bottom: _bottomMapPadding),
                          onMapCreated: (controller) {
                            _mapController = controller;
                            _applyMapStyle();
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

                        // Custom My Location Button (bottom-right, below zoom)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 2000),

                          bottom: _bottomMapPadding + 120,
                          //_bottomMapPadding + 165, // base + padding from ad
                          right: 12,
                          child: _MapCircleButton(
                            icon: Icons.my_location,
                            onPressed: () async {
                              final pos = await Geolocator.getCurrentPosition();
                              _mapController.animateCamera(
                                CameraUpdate.newLatLng(
                                  LatLng(pos.latitude, pos.longitude),
                                ),
                              );
                            },
                          ),
                        ),

                        // Custom Zoom Controls (bottom-right)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 2000),
                          bottom: _bottomMapPadding,
                          //bottom: _bottomMapPadding + 50,
                          right: 12,
                          child: Column(
                            children: [
                              _MapCircleButton(
                                icon: Icons.add,
                                onPressed:
                                    () => _mapController.animateCamera(
                                      CameraUpdate.zoomIn(),
                                    ),
                              ),
                              const SizedBox(height: 10),
                              _MapCircleButton(
                                icon: Icons.remove,
                                onPressed:
                                    () => _mapController.animateCamera(
                                      CameraUpdate.zoomOut(),
                                    ),
                              ),
                            ],
                          ),
                        ),

                        Positioned(
                          top: 100,
                          right: 12,
                          child: Opacity(
                            opacity: 0.7,
                            child: FloatingActionButton.small(
                              heroTag: 'toggleMapTheme',
                              onPressed: () async {
                                final prefs =
                                    await SharedPreferences.getInstance();

                                setState(() {
                                  _isDarkMap = !_isDarkMap;
                                  _mapStyle = _isDarkMap ? _darkStyle : null;
                                });

                                prefs.setBool('isDarkMap', _isDarkMap);

                                _applyMapStyle();
                              },
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                transitionBuilder: (child, animation) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  );
                                },
                                child: Icon(
                                  _isDarkMap
                                      ? Icons.light_mode
                                      : Icons.dark_mode,
                                  key: ValueKey(_isDarkMap),
                                ),
                              ),
                            ),
                          ),
                        ),

                        _buildLegend(),

                        // Sticky Ad Banner at the bottom
                        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: SafeArea(
                              top: false,
                              child: NativeAdBanner(
                                onVisibilityChanged: (visible) {
                                  final safeBottom = MediaQuery.of(context).padding.bottom;
                                  setState(() {
                                    _bottomMapPadding = visible ? (safeBottom) : safeBottom;
                                  });
                                },
                              ),
                            ),
                          ),

                        // _buildNotificationBanner(),
                        // Positioned(
                        //   bottom: 80,
                        //   right: 16,
                        //   child: FloatingActionButton.extended(
                        //     onPressed: _sendTestNotification,
                        //     label: const Text('Test Notification'),
                        //     icon: const Icon(Icons.notifications),
                        //     backgroundColor: Colors.blue,
                        //   ),
                        // ),
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
  final bool isDark;

  const _LegendItem({
    required this.color,
    required this.label,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 14, height: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            //color: isDark ? Colors.white70 : Colors.black87,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MapCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _MapCircleButton({
    Key? key,
    required this.icon,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.9, // Adjust to your desired transparency
      child: Material(
        color: Colors.white.withOpacity(0.8), // Semi-transparent white
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // Slight rounding
        ),
        elevation: 3,
        child: IconButton(
          icon: Icon(icon),
          onPressed: onPressed,
          color: Colors.black,
          splashRadius: 24,
          iconSize: 20,
        ),
      ),
    );
  }
}
