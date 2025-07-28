// lib/screens/activity.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';
import '../widgets/event_card.dart';
import '../widgets/nav_bar.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  Position? _userPosition;
  List<Event> _nearbyEvents = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNearbyEvents();
  }

  Future<void> _fetchNearbyEvents() async {
    try {
      final pos = await _handleLocationPermission();
      if (pos == null) return; // user denied or cancelled

      setState(() => _userPosition = pos);

      final eventsSnapshot = await FirebaseFirestore.instance.collection('events').get();
      final allEvents = eventsSnapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();

      const maxDistanceMeters = 100.0;

      final nearby = allEvents.where((event) {
        if (event.lat == null || event.lng == null) return false;

        final dist = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          event.lat!,
          event.lng!,
        );

        return dist <= maxDistanceMeters;
      }).toList();

      setState(() {
        _nearbyEvents = nearby;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
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
        _showDialog("Location permission is required to show nearby events.");
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

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<Position> _getUserLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
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
              onPressed: () {
                Geolocator.openAppSettings();
                Navigator.of(context).pop();
              },
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Navbar(),
          const SizedBox(height: 20),
          const Text(
            'Nearby Events',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text('Error: $_error'))
                : _nearbyEvents.isEmpty
                ? const Center(child: Text('No nearby events found.'))
                : ListView(
              padding: const EdgeInsets.all(16),
              children:
              _nearbyEvents.map((e) => EventCard(event: e)).toList(),
            ),
          ),
        ],
      ),
    );
  }}