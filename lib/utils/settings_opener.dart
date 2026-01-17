import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

enum AppSettingType { location, notifications }

Future<bool> openRelevantSettings(AppSettingType type) async {
  if (kIsWeb) {
    // Web cannot open OS settings
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
