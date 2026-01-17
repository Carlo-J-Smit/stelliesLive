import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stellieslive/constants/colors.dart';
import '../models/event.dart';
import '../widgets/event_card.dart';
import '../widgets/nav_bar.dart';
import 'dart:async'; // For Timer
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import '../widgets/native_ad_banner.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import '../widgets/event_markers.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'dart:math'; // for min/max
import '../widgets/aggregated_event_icon.dart';




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
  Set<Marker> _eventMarkers = {};
  DateTime _lastReload = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<String, BitmapDescriptor> _markerIconCache = {};



  Future<void> _initActivity() async {
    final pos = await _handleLocationPermission();
    if (pos == null) return;

    setState(() => _userPosition = pos);
    setState(() => _loading = false); // after getting location

    // _logUserLocation(pos);

    await _checkProximityToEvent();

  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      _updateEventMarkers();
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

    // _subscribeToClusterUpdates();
  }

  Future<Marker> createEventMarker(Event event) async {
    final icon = await getEventMarkerIcon(event);

    return Marker(
      markerId: MarkerId(event.id),
      position: LatLng(event.lat!, event.lng!),
      onTap: () {
        // Show the EventCard dialog
       debugPrint(event.busynessLevel);
        _showEventDialog(event);

        // Optional: move camera to marker
        _mapController.animateCamera(
          CameraUpdate.newLatLng(LatLng(event.lat!, event.lng!)),
        );

      },

      icon: icon,
      infoWindow: InfoWindow.noText, // no default popup
    );
  }

  Future<Set<Marker>> loadEventMarkers(List<Event> events) async {
    Set<Marker> markers = {};
    for (var event in events) {
      final marker = await createEventMarker(event);
      markers.add(marker);
    }
    return markers;
  }


  Future<void> _loadCustomMarker(Event event) async {
    try {
      debugPrint("⏳ Loading custom marker for event ${event.id}");
      final icon = await getEventMarkerIcon(event);

      setState(() {
        _eventMarkers.removeWhere((m) => m.markerId.value == event.id);
        _eventMarkers.add(
          Marker(
            markerId: MarkerId(event.id),
            position: LatLng(event.lat!, event.lng!),
            icon: icon,
            infoWindow: InfoWindow.noText,
            onTap: () => _showEventDialog(event),
          ),
        );
      });

      debugPrint("✅ Custom marker applied for event ${event.id}");
    } catch (e) {
      debugPrint("❌ Failed to load custom icon for ${event.id}: $e");
    }
  }

  double _currentZoom = 15; // default zoom

  void _onCameraMove(CameraPosition position) {
    _currentZoom = position.zoom;
    // Optionally, throttle updates to avoid constant rebuilds
    _updateEventMarkers();
  }



  // Inside _ActivityScreenState

  Future<void> _updateEventMarkers() async {
    try {
      if (DateTime.now().difference(_lastReload).inSeconds < 5) return;
      _lastReload = DateTime.now();
      final now = DateTime.now();

      final snapshot = await FirebaseFirestore.instance.collection('events').get();
      final List<Event> freshEvents = snapshot.docs.map((doc) {
        return Event.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).where((event) => _isEventHappeningToday(event, now)).toList();

      widget.events..clear()..addAll(freshEvents);

      // Determine clustering precision based on zoom
      int precisionInt;
      debugPrint("current zoom level: $_currentZoom");
      if (_currentZoom <= 12) {
        precisionInt = 2; // ~100m
      } else if (_currentZoom <= 15) {
        precisionInt = 3; // ~50m
      } else {
        precisionInt = 4; // ~10m (high zoom)
      }

      // Group events by approximate lat/lng based on precision
      Map<String, List<Event>> groupedEvents = {};
      for (var event in freshEvents) {
        String key =
            "${event.lat!.toStringAsFixed(precisionInt)}_${event.lng!.toStringAsFixed(precisionInt)}";
        groupedEvents.putIfAbsent(key, () => []).add(event);
      }

      Set<Marker> newMarkers = {};
      for (var key in groupedEvents.keys) {
        final cluster = groupedEvents[key]!;
        final firstEvent = cluster.first;

        if (cluster.length == 1) {
          // Single Event Marker
          newMarkers.add(Marker(
            markerId: MarkerId(firstEvent.id),
            position: LatLng(firstEvent.lat!, firstEvent.lng!),
            icon: BitmapDescriptor.defaultMarker, // Will be updated by custom loader
            onTap: () => _showEventDialog(firstEvent),
          ));
          _loadCustomMarker(firstEvent); // Async load custom icon
        } else {
          // Aggregated Marker (cluster)
          final clusterIcon = await createAggregatedMarkerIcon(
            count: cluster.length,
            isDarkMode: _isDarkMap,
            size: 50, // higher resolution for map clarity
          );

          newMarkers.add(Marker(
            markerId: MarkerId("cluster_$key"),
            position: LatLng(firstEvent.lat!, firstEvent.lng!),
            icon: clusterIcon,
            onTap: () => _showAggregatedEventsPopup(cluster),
          ));
        }
      }

      setState(() {
        _eventMarkers = newMarkers;
      });
    } catch (e) {
      debugPrint("❌ Failed to reload events: $e");
    }
  }

  void _showAggregatedEventsPopup(List<Event> events) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: AppColors.darkInteract.withOpacity(0.5), // Subtle background dim
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: _isDarkMap ? AppColors.eventCardBackground : AppColors.eventCardBackground,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkInteract.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  decoration: BoxDecoration(
                    color: _isDarkMap ? AppColors.eventCardBackground : AppColors.eventCardBackground,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Text(
                    "${events.length} Events at this Location",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMap ? AppColors.primaryRed : AppColors.primaryRed,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Event list
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final e = events[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _showEventDialog(e);
                        },
                        child: Material(
                          color: _isDarkMap ? AppColors.eventCardBackground : AppColors.eventCardBackground,
                          borderRadius: BorderRadius.circular(16),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: AbsorbPointer(
                              absorbing: true,
                              child: EventCard(event: e),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Close button
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isDarkMap ? AppColors.primaryRed : AppColors.primaryRed,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Close",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isDarkMap ? AppColors.textLight : AppColors.textLight,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }




  Future<BitmapDescriptor> getEventMarkerIcon(Event event) async {
    // Return cached icon if available
    if (_markerIconCache.containsKey(event.id)) {
      debugPrint("🔍 Using cached marker icon for ${event.id}");
      return _markerIconCache[event.id]!;
    }


    try {
      final safeTitle = event.title
          .trim()
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
          .replaceAll(RegExp(r'_+'), '_');

      final String path = 'event_icon/${event.id}/$safeTitle.png';
      final Reference ref = FirebaseStorage.instance.ref().child(path);

      debugPrint("🔍 Fetching icon from Firebase Storage: $path");

      final Uint8List? data = await ref.getData();
      if (data == null) {
        debugPrint("⚠️ No data for ${event.id}, using default marker");
        return BitmapDescriptor.defaultMarker;
      }

      // Decode image
      final codec = await ui.instantiateImageCodec(data);
      final frame = await codec.getNextFrame();
      ui.Image originalImage = frame.image;

      // BASE SIZE
      double baseSize = 80;
      double scaleFactor = switch (event.busynessLevel) {
        'Quiet' => 1.0,
        'Moderate' => 1.25,
        'Busy' => 1.5,
        _ => 1.0
      };

      final int finalSize = (baseSize * scaleFactor).clamp(5, 150).toInt();
      final radius = finalSize / 2;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      // ------- GLOW COLOR -------
      Color glowColor = switch (event.busynessLevel) {
        'Quiet' => Colors.transparent,
        'Moderate' => Colors.yellow.withOpacity(0.6),
        'Busy' => Colors.red.withOpacity(0.7),
        _ => Colors.transparent
      };


      // ------- CATEGORY BORDER (CUSTOMIZE HERE) -------
      Color categoryColor = Colors.blue; // MAKE OPTIONAL
      switch (event.busynessLevel) {
        case 'Quiet':
          categoryColor = Colors.green;
          break;
        case 'Moderate':
          categoryColor = Colors.orange;
          break;
        case 'Busy':
          categoryColor = Colors.red;
          break;
        default:
          categoryColor =  Colors.black; // fallback if no match
      }
      final Paint ringPaint = Paint()
        ..color = categoryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = finalSize * 0.08
        ..isAntiAlias = true;

      canvas.drawCircle(Offset(radius, radius), radius * 0.8, ringPaint);

      // ------- INNER CIRCLE CLIP -------
      final double innerRadius = radius * 0.72;

      final Path clipPath = Path()
        ..addOval(Rect.fromCircle(center: Offset(radius, radius), radius: innerRadius));

      canvas.clipPath(clipPath);

      final Rect src = Rect.fromLTWH(
        0,
        0,
        originalImage.width.toDouble(),
        originalImage.height.toDouble(),
      );

      final double imgSide = innerRadius * 2;

      final Rect dst = Rect.fromLTWH(
        radius - innerRadius,
        radius - innerRadius,
        imgSide,
        imgSide,
      );

      final Paint imgPaint = Paint()..isAntiAlias = true;
      canvas.drawImageRect(originalImage, src, dst, imgPaint);

      // Convert to final image
      final ui.Image finalImage =
      await recorder.endRecording().toImage(finalSize, finalSize);

      final ByteData? byteData =
      await finalImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return BitmapDescriptor.defaultMarker;

      final icon = BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());

      // Cache it
      _markerIconCache[event.id] = icon;

      return icon;
    } catch (e) {
      debugPrint("❌ Error processing marker icon: $e");
    }

    return BitmapDescriptor.defaultMarker;
  }







  void _showEventDialog(Event event) async {
    await showDialog(
      context: context,
      builder: (_) => EventFeedbackDialog(event: event, isDarkMode: _isDarkMap),
    );

    // Reload events from Firebase after the dialog is closed
    await _updateEventMarkers();
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isEventHappeningToday(Event event, DateTime now) {
    // Exact date event
    if (event.dateTime != null) {
      if (_isSameDay(event.dateTime!, now)) {
        return true;
      }
    }

    // Recurring event (by weekday)
    // Assumes event.recurringDays = ['Monday', 'Wednesday', ...]
    if (event.dayOfWeek != null && event.dayOfWeek!.isNotEmpty) {
      final todayName = [
        'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
      ][now.weekday - 1];

      return event.dayOfWeek == todayName;
    }


    return false;
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
              //_askUserForFeedback(event);
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
      //_askUserForFeedback(_nearbyEvent!);
    }
  }

  // void _askUserForFeedback(Event event) {
  //   final isDark = _isDarkMap;
  //
  //   showDialog(
  //     context: context,
  //     builder:
  //         (_) => AlertDialog(
  //           backgroundColor:
  //               isDark
  //                   ? const Color(0xCC1E1E1E) // 80% opacity black
  //                   : Colors.white.withOpacity(0.90), // 95% opacity white
  //
  //           title: Text(
  //             'At ${event.title}?',
  //             style: TextStyle(
  //               color: isDark ? Colors.white : Colors.black,
  //               fontWeight: FontWeight.bold,
  //             ),
  //           ),
  //           content: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             crossAxisAlignment: CrossAxisAlignment.stretch,
  //             children: [
  //               Text(
  //                 'How busy is it?',
  //                 style: TextStyle(
  //                   color: isDark ? Colors.white70 : Colors.black87,
  //                   fontSize: 16,
  //                 ),
  //               ),
  //               const SizedBox(height: 10),
  //               ...['Quiet', 'Moderate', 'Busy'].map((level) {
  //                 Color bgColor;
  //                 switch (level) {
  //                   case 'Quiet':
  //                     bgColor = Colors.green;
  //                     break;
  //                   case 'Moderate':
  //                     bgColor = Colors.orange;
  //                     break;
  //                   case 'Busy':
  //                     bgColor = Colors.red;
  //                     break;
  //                   default:
  //                     bgColor = Colors.grey;
  //                 }
  //
  //                 return Padding(
  //                   padding: const EdgeInsets.only(top: 6),
  //                   child: ElevatedButton(
  //                     style: ElevatedButton.styleFrom(
  //                       backgroundColor: bgColor,
  //                       foregroundColor: Colors.white,
  //                     ),
  //                     onPressed: () async {
  //                       Navigator.of(context).pop(); // Close dialog immediately
  //
  //                       final pos = await Geolocator.getCurrentPosition();
  //
  //                       const maxDistance = 60.0;
  //                       final mergedRef = FirebaseFirestore.instance.collection(
  //                         'merged_clusters',
  //                       );
  //                       final snapshot = await mergedRef.get();
  //
  //                       String? clusterId;
  //                       double minDistance = double.infinity;
  //
  //                       for (var doc in snapshot.docs) {
  //                         final data = doc.data();
  //                         final double lat = data['lat'];
  //                         final double lng = data['lng'];
  //
  //                         final distance = Geolocator.distanceBetween(
  //                           pos.latitude,
  //                           pos.longitude,
  //                           lat,
  //                           lng,
  //                         );
  //
  //                         if (distance < minDistance &&
  //                             distance <= maxDistance) {
  //                           minDistance = distance;
  //                           clusterId = doc.id;
  //                         }
  //                       }
  //
  //                       if (clusterId == null) {
  //                         final newDoc = await mergedRef.add({
  //                           'lat': pos.latitude,
  //                           'lng': pos.longitude,
  //                           'level': level,
  //                           'createdFrom': 'app',
  //                           'updated': Timestamp.now(),
  //                         });
  //                         clusterId = newDoc.id;
  //                         debugPrint("🆕 New cluster created: $clusterId");
  //                       }
  //
  //                       try {
  //                         await FirebaseFirestore.instance
  //                             .collection('event_feedback')
  //                             .add({
  //                               'eventId': event.id,
  //                               'timestamp': Timestamp.now(),
  //                               'busyness': level,
  //                               'userId':
  //                                   FirebaseAuth.instance.currentUser?.uid,
  //                               'clusterId': clusterId,
  //                             });
  //                         debugPrint(
  //                           "✅ Feedback submitted for $clusterId ($level)",
  //                         );
  //                       } catch (e) {
  //                         debugPrint("❌ Firestore write failed: $e");
  //                       }
  //                     },
  //                     child: Text(level),
  //                   ),
  //                 );
  //               }),
  //             ],
  //           ),
  //         ),
  //   );
  // }

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
      // await _logUserLocation(pos);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  // Future<void> _logUserLocation(Position pos) async {
  //   await FirebaseFirestore.instance.collection('location_logs').add({
  //     'userId': FirebaseAuth.instance.currentUser?.uid,
  //     'timestamp': Timestamp.now(),
  //     'lat': pos.latitude,
  //     'lng': pos.longitude,
  //   });
  // }

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
        _updateEventMarkers();
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
          crossAxisAlignment: CrossAxisAlignment.start, // align items to the left
          children: [
            _LegendItem(color: Colors.green, label: 'Quiet', isDark: isDark),
            _LegendItem(
              color: Colors.orange,
              label: 'Moderate',
              isDark: isDark,
            ),
            _LegendItem(color: Colors.red, label: 'Busy', isDark: isDark),
            _LegendItem(color: Colors.black, label: 'No Information', isDark: isDark),
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
    debugPrint('BUILD: Activity Screen 1');
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
                            zoom: _currentZoom,
                          ),
                          markers: _eventMarkers,
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
                          onCameraMove: _onCameraMove,
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

                          bottom: _bottomMapPadding + 135,
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
                          bottom: _bottomMapPadding+20,
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
                          top: 120,
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

                        // // Sticky Ad Banner at the bottom
                        // if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
                        //   Positioned(
                        //     left: 0,
                        //     right: 0,
                        //     bottom: 0,
                        //     child: SafeArea(
                        //       top: false,
                        //       child: NativeAdBanner(
                        //         onVisibilityChanged: (visible) {
                        //           final safeBottom = MediaQuery.of(context).padding.bottom;
                        //           setState(() {
                        //             _bottomMapPadding = visible ? (safeBottom) : safeBottom;
                        //           });
                        //         },
                        //       ),
                        //     ),
                        //   ),

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
    debugPrint('BUILD: Activity Screen 2');
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
    debugPrint('BUILD: Activity Screen 3');
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
