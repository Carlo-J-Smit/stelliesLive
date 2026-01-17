import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/settings_opener.dart';

final List<String> _notificationTypes = [
  'Update',
  'Promotion',
  'Reminder',
  'Cancellation',
];



class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifyProximity = true;
  bool _locationGranted = false;
  SharedPreferences? _prefs;
  Map<String, Map<String, bool>> _businessTypeNotifications = {};
// structure: { businessId: { type: true/false } }


  List<Map<String, String>> _businesses = []; // List of {id: docId, name: name}
  // Map<String, bool> _businessNotifications = {};

  String _searchQuery = '';
  bool _loadingBusinesses = true;

  @override
  void initState() {
    super.initState();
    _initSettings();
  }

  Future<void> _initSettings() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadGlobalPreference();  // global proximity toggle
    await _fetchBusinesses();       // load businesses + restore local prefs

    // --- FIRST INSTALL: subscribe to all if never done before ---
    bool isFirstInstall = !(_prefs!.containsKey('app_installed'));
    if (isFirstInstall) {
      for (final b in _businesses) {
        final id = b['id']!;
        for (final type in _notificationTypes) {
          final topic = _topicFor(id, type);
          if (!kIsWeb) await FirebaseMessaging.instance.subscribeToTopic(topic);
          await _prefs!.setBool('notify_${id}_${type.toLowerCase()}', true);
        }
      }
      await _prefs!.setBool('app_installed', true);
    }

    await _restoreSubscriptions();  // only after businesses are loaded
    await _checkLocationPermission();
  }


  /// Load global proximity notification preference
  Future<void> _loadGlobalPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifyProximity = prefs.getBool('notifyProximity') ?? true;
    });
  }

  String _topicFor(String businessId, String type) {
    return 'business_${businessId}_${type.toLowerCase()}';
  }

  _loadPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {});
  }


  Future<void> _restoreSubscriptions() async {
    if (_prefs == null) return;
    if (_businesses.isEmpty) return;

    for (final b in _businesses) {
      final id = b['id']!;
      for (final type in _notificationTypes) {
        final key = 'notify_${id}_${type.toLowerCase()}';
        final enabled = _prefs!.getBool(key) ?? true; // only subscribe if true
        final topic = _topicFor(id, type);

        if (enabled) {
          if (!kIsWeb) await FirebaseMessaging.instance.subscribeToTopic(topic);
        } else {
          if (!kIsWeb) await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
        }
      }
    }
  }



  Future<void> _toggleBusinessTypeNotification(String businessId, String type, bool value) async {
    final topic = _topicFor(businessId, type);

    try {
      if (!kIsWeb) {
        if (value) {
          await FirebaseMessaging.instance.subscribeToTopic(topic);
        } else {
          await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
        }
      }

      await _prefs?.setBool('notify_${businessId}_${type.toLowerCase()}', value);

      // Update local state immediately
      setState(() {
        _businessTypeNotifications[businessId]![type] = value;
      });
    } catch (e) {
      debugPrint('Failed toggling $topic: $e');
    }
  }



  /// Fetch businesses from Firestore
  Future<void> _fetchBusinesses() async {
    try {
      final snapshot =
      await FirebaseFirestore.instance.collection('businesses').get();

      // Convert each doc to {id, name}
      List<Map<String, String>> businessList = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] as String? ?? 'Unnamed',
        };
      }).toList();

      for (var b in businessList) {
        final id = b['id']!;
        _businessTypeNotifications[id] = {};
        for (var type in _notificationTypes) {
          // Only default to true if key doesn't exist
          _businessTypeNotifications[id]![type] =
          _prefs?.containsKey('notify_${id}_${type.toLowerCase()}') == true
              ? _prefs!.getBool('notify_${id}_${type.toLowerCase()}')!
              : true;
        }
      }



      debugPrint('Fetched businesses: $businessList');


      // // Load local notification preferences
      // final prefs = await SharedPreferences.getInstance();
      // Map<String, bool> notifications = {};
      // for (var b in businessList) {
      //   final id = b['id']!;
      //   notifications[id] = prefs.getBool('notify_$id') ?? true;
      // }

      setState(() {
        _businesses = businessList;
        // _businessNotifications = notifications;
        _loadingBusinesses = false;
      });

      await _syncBusinessTopics();
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
    setState(() => _locationGranted =
        permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse);
  }

  /// Request location permission
  Future<void> _requestLocationPermission() async {
    if (kIsWeb) {
      _showWebHelpDialog(
        title: 'Enable Location',
        message:
        'Please enable location permissions in your browser settings.\n\n'
            'Chrome: Settings → Privacy & Security → Site Settings → Location',
      );
      return;
    }

    final permission = await Geolocator.requestPermission();
    await _checkLocationPermission();

    if (permission == LocationPermission.deniedForever && mounted) {
      await openRelevantSettings(context, AppSettingType.location);
    }
  }

  void _showWebHelpDialog({
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }



  /// Toggle global proximity notifications
  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifyProximity', value);

    setState(() => _notifyProximity = value);

    for (final b in _businesses) {
      final id = b['id']!;

      for (final type in _notificationTypes) {
        final enabled =
            prefs.getBool('notify_${id}_$type') ?? true;

        final topic = _topicFor(id, type);

        if (value && enabled) {
          if (!kIsWeb) {
            await FirebaseMessaging.instance.subscribeToTopic(topic);
          }

        } else {
          if (!kIsWeb) {
            await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
          }
        }
      }
    }
  }



  // /// Toggle individual business notifications
  // Future<void> _toggleBusinessNotification(
  //     String businessId,
  //     bool value,
  //     ) async {
  //   final prefs = await SharedPreferences.getInstance();
  //
  //   final topic = 'business_$businessId';
  //
  //   try {
  //     if (value) {
  //       // ✅ User ENABLED notifications
  //       await FirebaseMessaging.instance.subscribeToTopic(topic);
  //       debugPrint('Subscribed to $topic');
  //     } else {
  //       // ❌ User DISABLED notifications
  //       await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
  //       debugPrint('Unsubscribed from $topic');
  //     }
  //
  //     // Persist locally
  //     await prefs.setBool('notify_$businessId', value);
  //
  //     setState(() {
  //       _businessNotifications[businessId] = value;
  //     });
  //   } catch (e) {
  //     debugPrint('Topic toggle failed: $e');
  //   }
  // }

  Future<void> _syncBusinessTopics() async {
    final prefs = await SharedPreferences.getInstance();

    for (final b in _businesses) {
      final id = b['id']!;

      for (final type in _notificationTypes) {
        final enabled =
            prefs.getBool('notify_${id}_$type') ?? true;

        final topic = _topicFor(id, type);

        if (_notifyProximity && enabled) {
          if (!kIsWeb) {
            await FirebaseMessaging.instance.subscribeToTopic(topic);
          }
        } else {
          if (!kIsWeb) {
            await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
          }
        }
      }
    }
  }




  @override
  Widget build(BuildContext context) {
    // Filter businesses based on search
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
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
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
                        child: Text(_locationGranted ? 'Enabled' : 'Enable'),
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
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
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

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('System Notification Settings'),
                      subtitle: const Text('Manage notification permissions'),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          if (kIsWeb) {
                            _showWebHelpDialog(
                              title: 'Enable Notifications',
                              message:
                              'Please enable notifications in your browser settings.\n\n'
                                  'Chrome: Settings → Privacy & Security → Notifications',
                            );
                          } else {
                            await openRelevantSettings(context, AppSettingType.notifications);
                          }
                        },
                        child: const Text('Open'),
                      ),
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
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
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
                    // _loadingBusinesses
                    //     ? const Center(child: CircularProgressIndicator())
                    //     : filteredBusinesses.isEmpty
                    //     ? const Text("No businesses found")
                    //     : Column(
                    //   children: filteredBusinesses.map((b) {
                    //     final id = b['id']!;
                    //     final name = b['name']!;
                    //     return SwitchListTile(
                    //       contentPadding: EdgeInsets.zero,
                    //       title: Text(name),
                    //       value: _businessNotifications[id] ?? true,
                    //       onChanged: (val) =>
                    //           _toggleBusinessNotification(id, val),
                    //     );
                    //   }).toList(),
                    // ),
                    _loadingBusinesses
                        ? const Center(child: CircularProgressIndicator())
                        : filteredBusinesses.isEmpty
                        ? const Text("No businesses found")
                        : Column(
                      children: filteredBusinesses.map((b) {
                        final id = b['id']!;
                        final name = b['name']!;

                        return ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          children: _notificationTypes.map((type) {
                            final enabled = _businessTypeNotifications[id]![type]!;

                            return SwitchListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.only(left: 16, right: 8),
                              title: Text(type),
                              value: enabled,
                              onChanged: (val) async {
                                await _toggleBusinessTypeNotification(id, type, val);
                                setState(() {
                                  _businessTypeNotifications[id]![type] = val;
                                });
                              },
                            );
                          }).toList(),

                        );


                        // return Column(
                        //   crossAxisAlignment: CrossAxisAlignment.start,
                        //   children: [
                        //     /// Business name
                        //     Text(
                        //       name,
                        //       style: const TextStyle(
                        //         fontSize: 16,
                        //         fontWeight: FontWeight.bold,
                        //       ),
                        //     ),
                        //
                        //     const SizedBox(height: 6),
                        //
                        //     /// Per-type notification switches
                        //     // ..._notificationTypes.map((type) {
                        //     //   return FutureBuilder<SharedPreferences>(
                        //     //     future: SharedPreferences.getInstance(),
                        //     //     builder: (context, snapshot) {
                        //     //       if (!snapshot.hasData) {
                        //     //         return const SizedBox();
                        //     //       }
                        //     //
                        //     //       final prefs = snapshot.data!;
                        //     //       final enabled =
                        //     //           prefs.getBool('notify_${id}_$type') ?? true;
                        //     //
                        //     //       return SwitchListTile(
                        //     //         dense: true,
                        //     //         contentPadding: EdgeInsets.zero,
                        //     //         title: Text(type),
                        //     //         value: enabled,
                        //     //         onChanged: (val) =>
                        //     //             _toggleBusinessTypeNotification(id, type, val),
                        //     //       );
                        //     //     },
                        //     //   );
                        //     // }),
                        //
                        //     ..._notificationTypes.map((type) {
                        //       if (_prefs == null) return const SizedBox();
                        //
                        //       final enabled =
                        //           _prefs!.getBool('notify_${id}_$type') ?? true;
                        //
                        //       return SwitchListTile(
                        //         dense: true,
                        //         contentPadding: EdgeInsets.zero,
                        //         title: Text(type),
                        //         value: enabled,
                        //         onChanged: (val) =>
                        //             _toggleBusinessTypeNotification(id, type, val),
                        //       );
                        //     }),
                        //
                        //
                        //     const Divider(height: 24),
                        //   ],
                        //);
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
