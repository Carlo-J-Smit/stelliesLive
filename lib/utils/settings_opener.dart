import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../screens/events_screen.dart';

enum AppSettingType { location, notifications }

Future<bool> openRelevantSettings(BuildContext context, AppSettingType type) async {
  if (kIsWeb) {
    // Show a message to guide the user on web
    String settingName = type == AppSettingType.location ? "location" : "notifications";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Enable $settingName"),
        content: Text(
            "Please enable $settingName permissions in your browser settings to use this feature."
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const EventsScreen()),
              );
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
    return false;
  }

  try {
    switch (type) {
      case AppSettingType.location:
        return await Geolocator.openAppSettings();
      case AppSettingType.notifications:
        return await openAppSettings();
    }
  } catch (_) {
    return false;
  }
}
