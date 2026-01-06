import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifyProximity = true;
  bool _locationGranted = false;

  List<Map<String, String>> _businesses = []; // [{id: docId, name: name}]
  Map<String, bool> _businessNotifications = {};

  String _searchQuery = '';
  bool _loadingBusinesses = true;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _loadGlobalPreference();
    _fetchBusinesses();
  }

  /// Load global proximity notification preference
  Future<void> _loadGlobalPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifyProximity = prefs.getBool('notifyProximity') ?? true;
    });
  }

  /// Fetch businesses from Firestore
  Future<void> _fetchBusinesses() async {
    try {
      final snapshot =
      await FirebaseFirestore.instance.collection('businesses').get();

      List<Map<String, String>> businessList = snapshot.docs
          .map((doc) => {
        'id': doc.id,
        'name': doc.data()['name'] as String? ?? 'Unnamed',
      })
          .toList();

      // Load local preferences for each business
      final prefs = await SharedPreferences.getInstance();
      Map<String, bool> notifications = {};
      for (var b in businessList) {
        notifications[b['id']!] = prefs.getBool('notify_${b['id']}') ?? true;
      }

      setState(() {
        _businesses = businessList;
        _businessNotifications = notifications;
        _loadingBusinesses = false;
      });
    } catch (e) {
      debugPrint('Error fetching businesses: $e');
      setState(() => _loadingBusinesses = false);
    }
  }

  /// Check location permission
  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _locationGranted = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    setState(() => _locationGranted = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse);
  }

  /// Request location permission
  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.requestPermission();
    await _checkLocationPermission();

    if (permission == LocationPermission.deniedForever && mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Location Permanently Denied'),
          content: const Text(
              'To enable location services, go to app settings.'),
          actions: [
            TextButton(
              onPressed: () {
                Geolocator.openAppSettings();
                Navigator.pop(context);
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
  }

  /// Toggle global proximity notifications
  void _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifyProximity', value);
    setState(() => _notifyProximity = value);
  }

  /// Toggle business notification preference
  void _toggleBusinessNotification(String businessId, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notify_$businessId', value);
    setState(() => _businessNotifications[businessId] = value);
  }

  @override
  Widget build(BuildContext context) {
    final filteredBusinesses = _businesses
        .where((b) => b['name']!
        .toLowerCase()
        .contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            /// Location Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Location Settings",
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_locationGranted
                          ? 'Location Access Granted'
                          : 'Location Access Denied'),
                      subtitle: const Text(
                          'Used for background event proximity detection'),
                      trailing: ElevatedButton(
                        onPressed: _requestLocationPermission,
                        child: Text(_locationGranted ? 'Change' : 'Enable'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            /// Global Notification Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Notifications",
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Notify when near events'),
                      subtitle: const Text(
                          'Receive notifications when you are within 50m of an event'),
                      value: _notifyProximity,
                      onChanged: _toggleNotifications,
                    ),
                  ],
                ),
              ),
            ),

            /// Business Notifications Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Business Notifications",
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: "Search businesses...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                    const SizedBox(height: 12),
                    _loadingBusinesses
                        ? const Center(child: CircularProgressIndicator())
                        : filteredBusinesses.isEmpty
                        ? const Text("No businesses found")
                        : Column(
                      children: filteredBusinesses.map((b) {
                        final id = b['id']!;
                        final name = b['name']!;
                        return SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(name),
                          value: _businessNotifications[id] ?? true,
                          onChanged: (val) =>
                              _toggleBusinessNotification(id, val),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
