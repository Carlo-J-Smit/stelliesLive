import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/event.dart';

class EventMapScreen extends StatefulWidget {
  final List<Event> events;

  const EventMapScreen({super.key, required this.events});

  @override
  State<EventMapScreen> createState() => _EventMapScreenState();
}

class _EventMapScreenState extends State<EventMapScreen> {
  late GoogleMapController _mapController;
  Set<Marker> _eventMarkers = {};
  Set<Circle> _popularityCircles = {};
  bool _loading = true;
  bool _showHeatmap = true;

  @override
  void initState() {
    super.initState();
    _loadEventMarkers();
    _loadPopularityCircles();
  }

  void _loadEventMarkers() {
    final markers = widget.events
        .where((e) => e.lat != null && e.lng != null)
        .map((e) => Marker(
      markerId: MarkerId(e.id),
      position: LatLng(e.lat!, e.lng!),
      infoWindow: InfoWindow(title: e.title),
    ))
        .toSet();

    setState(() {
      _eventMarkers = markers;
    });
  }

  String _clusterKey(double lat, double lng) {
    // Approx 0.00045 deg ~ 50m
    int latBucket = (lat / 0.00045).round();
    int lngBucket = (lng / 0.00045).round();
    return '$latBucket|$lngBucket';
  }


  Future<void> _loadPopularityCircles() async {
    final snapshot = await FirebaseFirestore.instance.collection('location_logs').get();

    final logs = snapshot.docs
        .map((doc) => doc.data())
        .where((data) =>
    data.containsKey('lat') &&
        data.containsKey('lng') &&
        data.containsKey('timestamp') &&
        data.containsKey('accuracy') &&
        data['accuracy'] <= 25) // Only high accuracy
        .toList();

    final now = Timestamp.now();
    final recentLogs = logs.where((data) {
      final timestamp = data['timestamp'] as Timestamp;
      return now.seconds - timestamp.seconds <= 30 * 60; // last 30 minutes
    }).toList();

    final Set<Circle> circles = {};
    int idCounter = 0;

    for (var center in recentLogs) {
      final double lat = center['lat'];
      final double lng = center['lng'];
      final centerPoint = LatLng(lat, lng);

      // Count how many logs are within 50m of this point
      int nearbyCount = recentLogs.where((entry) {
        final d = Geolocator.distanceBetween(
          lat,
          lng,
          entry['lat'],
          entry['lng'],
        );
        return d <= 50;
      }).length;

      // Handle user popularity report (0 = no data)
      int reportScore = center['popularity'] ?? 0;

      // Combine scores with weights
      double popularityScore = 0;
      if (reportScore > 0) {
        popularityScore += reportScore * 2;
      }

      if (nearbyCount < 50) {
        popularityScore += 1;
      } else if (nearbyCount <= 200) {
        popularityScore += 2;
      } else {
        popularityScore += 3;
      }

      // Final level
      int level = popularityScore.round().clamp(1, 3); // 1 = quiet, 3 = busy

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
      bottom: 16,
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
      appBar: AppBar(
        title: const Text('Event Map'),
        actions: [
          IconButton(
            icon: Icon(
              _showHeatmap ? Icons.visibility : Icons.visibility_off,
            ),
            tooltip: 'Toggle Heatmap',
            onPressed: () {
              setState(() {
                _showHeatmap = !_showHeatmap;
              });
            },
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(-33.9346, 18.8612),
              zoom: 14,
            ),
            markers: _eventMarkers,
            circles: _showHeatmap ? _popularityCircles : {},
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),
          _buildLegend(),
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
