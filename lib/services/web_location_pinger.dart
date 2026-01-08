// services/web_location_pinger.dart
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WebLocationPinger {
  static Timer? _timer;

  static void start() {
    if (!kIsWeb) return;

    _pingLocation();

    _timer = Timer.periodic(
      const Duration(minutes: 30),
          (_) => _pingLocation(),
    );

    html.document.onVisibilityChange.listen((_) {
      if (html.document.visibilityState == 'visible') {
        _pingLocation();
      }
    });
  }

  static void stop() {
    _timer?.cancel();
  }

  static Future<void> _pingLocation() async {
    final geo = html.window.navigator.geolocation;
    if (geo == null) return;

    try {
      // Only enableHighAccuracy is supported on Flutter Web
      final pos = await geo.getCurrentPosition(enableHighAccuracy: false);

      final coords = pos.coords;
      if (coords == null) return;

      final lat = double.parse(coords.latitude!.toStringAsFixed(3));
      final lng = double.parse(coords.longitude!.toStringAsFixed(3));

      await FirebaseFirestore.instance.collection('location_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'lat': lat,
        'lng': lng,
      });
    } catch (e) {
      debugPrint('Web location error: $e');
    }
  }
}
