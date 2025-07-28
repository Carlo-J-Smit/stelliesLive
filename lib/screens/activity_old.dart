// lib/screens/activity.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';
import '../widgets/event_card.dart';
import '../widgets/nav_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/event_map_screen.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;


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
        //print('Lat: ${pos.latitude}, Lng: ${pos.longitude}, Accuracy: ${pos.accuracy}m');
        final dist = Geolocator.distanceBetween(

          pos.latitude,
          pos.longitude,
          event.lat!,
          event.lng!,
        );
        event.distance = dist;
        if (dist <= 20) {
          _askUserForFeedback(event);
        }

        return dist <= maxDistanceMeters;
      }).toList();

      setState(() {
        _nearbyEvents = nearby;
        _loading = false;
      });

      await FirebaseFirestore.instance.collection('location_logs').add({
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'timestamp': Timestamp.now(),
        'lat': pos.latitude,
        'lng': pos.longitude,
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

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
  }

  Future<Position> _getUserLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
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
              onPressed: () {
                if (!kIsWeb && Platform.isAndroid) {
                  Geolocator.openAppSettings();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings not available on web.')),
                  );
                }
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

          ElevatedButton.icon(
            icon: const Icon(Icons.map),
            label: const Text("Show Map"),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => EventMapScreen(events: _nearbyEvents),
              ));
            },
          ),
        ],
      ),
    );
  }}