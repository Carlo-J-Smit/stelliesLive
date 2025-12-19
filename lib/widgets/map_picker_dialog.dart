import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

/// Call this to open the map picker dialog
Future<LatLng?> showMapPickerDialog(BuildContext context) {
  return showDialog<LatLng>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _MapPickerDialog(),
  );
}

class _MapPickerDialog extends StatefulWidget {
  const _MapPickerDialog({Key? key}) : super(key: key);

  @override
  State<_MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<_MapPickerDialog> {
  LatLng? _pickedLocation;

  @override
  Widget build(BuildContext context) {
    debugPrint('BUILD: MapPickerDialog');

    return FutureBuilder<Position>(
      future: Geolocator.getCurrentPosition(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const AlertDialog(
            content: SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final position = snapshot.data!;
        final initialPosition = LatLng(
          position.latitude,
          position.longitude,
        );

        return AlertDialog(
          title: const Text("Pick Location"),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialPosition,
                zoom: 14,
              ),
              onTap: (pos) {
                setState(() => _pickedLocation = pos);
              },
              markers: _pickedLocation != null
                  ? {
                Marker(
                  markerId: const MarkerId('picked'),
                  position: _pickedLocation!,
                ),
              }
                  : {},
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: _pickedLocation == null
                  ? null
                  : () => Navigator.pop(context, _pickedLocation),
              child: const Text("Select"),
            ),
          ],
        );
      },
    );
  }
}
