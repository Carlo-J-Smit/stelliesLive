import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/colors.dart';
import '../models/event.dart';
import '../widgets/event_card.dart';
import '../providers/event_provider.dart';

enum MapStatus { loading, ready, error }

class EventFormPage extends StatefulWidget {
  final Event? event;
  final EventProvider provider; // <-- pass provider
  final String businessName;

  const EventFormPage({
    super.key,
    this.event,
    required this.provider,
    required this.businessName,
  });

  @override
  State<EventFormPage> createState() => _EventFormPageState();
}

class _MapPickerDialog extends StatefulWidget {
  @override
  State<_MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<_MapPickerDialog> {
  LatLng? _pickedLocation;
  LatLng _center = const LatLng(0, 0);

  GoogleMapController? _mapController;
  String? _errorMessage;

  MapStatus _status = MapStatus.loading;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      // 1️⃣ Check service
      if (!await Geolocator.isLocationServiceEnabled()) {
        _fail("Location services are disabled.");
        return;
      }

      // 2️⃣ Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _fail("Location permission denied.");
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _fail(
          "Location permission permanently denied.\nOpen settings to enable it.",
        );
        await Geolocator.openAppSettings();
        return;
      }

      // 3️⃣ Get position WITH TIMEOUT
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 8));

      _center = LatLng(position.latitude, position.longitude);
      _status = MapStatus.ready;
    } catch (e) {
      _fail(
        "Unable to determine location.\nCheck internet or Location Permission.",
      );
    }

    if (mounted) setState(() {});
  }

  void _fail(String message) {
    _errorMessage = message;
    _status = MapStatus.error;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Pick Location"),
      content: SizedBox(width: 400, height: 400, child: _buildContent()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed:
              _pickedLocation != null
                  ? () => Navigator.pop(context, _pickedLocation)
                  : null,
          child: const Text("Select"),
        ),
      ],
    );
  }

  Widget _buildContent() {
    switch (_status) {
      case MapStatus.loading:
        return const Center(child: CircularProgressIndicator());

      case MapStatus.error:
        return _errorUI();

      case MapStatus.ready:
        return GoogleMap(
          initialCameraPosition: CameraPosition(target: _center, zoom: 15),
          onMapCreated: (controller) {
            _mapController = controller;
          },
          onTap: (latLng) => setState(() => _pickedLocation = latLng),
          markers:
              _pickedLocation != null
                  ? {
                    Marker(
                      markerId: const MarkerId('picked'),
                      position: _pickedLocation!,
                    ),
                  }
                  : {},
        );
    }
  }

  Widget _errorUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.location_off, size: 48, color: Colors.red),
        const SizedBox(height: 12),
        Text(
          _errorMessage ?? "Map unavailable",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _status = MapStatus.loading;
              _errorMessage = null;
            });
            _initLocation();
          },
          child: const Text("Retry"),
        ),
      ],
    );
  }
}

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: const Text("Pick Location"),
//       content: SizedBox(
//         width: 400,
//         height: 400,
//         child:
//             _loading
//                 ? const Center(child: CircularProgressIndicator())
//                 : Column(
//                   children: [
//                     Expanded(
//                       child: GoogleMap(
//                         initialCameraPosition: CameraPosition(
//                           target: _currentLocation!,
//                           zoom: 15,
//                         ),
//                         onMapCreated: (controller) {
//                           _mapController = controller;
//                           // Animate to current location if it's already set
//                           if (_currentLocation != null) {
//                             _mapController!.animateCamera(
//                               CameraUpdate.newCameraPosition(
//                                 CameraPosition(
//                                   target: _currentLocation!,
//                                   zoom: 15,
//                                 ),
//                               ),
//                             );
//                           }
//                         },
//                         onTap:
//                             (latLng) =>
//                                 setState(() => _pickedLocation = latLng),
//                         markers:
//                             _pickedLocation != null
//                                 ? {
//                                   Marker(
//                                     markerId: const MarkerId('picked'),
//                                     position: _pickedLocation!,
//                                   ),
//                                 }
//                                 : {},
//                       ),
//                     ),
//                     if (_errorMessage != null)
//                       Padding(
//                         padding: const EdgeInsets.only(top: 8.0),
//                         child: Text(
//                           _errorMessage!,
//                           style: const TextStyle(color: Colors.red),
//                           textAlign: TextAlign.center,
//                         ),
//                       ),
//                   ],
//                 ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(context),
//           child: const Text("Cancel"),
//         ),
//         ElevatedButton(
//           onPressed:
//               _pickedLocation != null
//                   ? () => Navigator.pop(context, _pickedLocation)
//                   : null,
//           child: const Text("Select"),
//         ),
//       ],
//     );
//   }
// }

class _EventFormPageState extends State<EventFormPage> {
  // ---------------- MODE ----------------
  bool get isEdit => widget.event != null;

  // ---------------- CONTROLLERS ----------------
  final _titleController = TextEditingController();
  final _venueController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  // ---------------- EVENT STATE ----------------
  DateTime? _selectedDateTime;
  bool _isRecurring = false;
  String? _selectedDayOfWeek;
  String? _selectedTag;
  double _uploadProgress = 0.0; // 0.0 → 1.0
  String _uploadMessage = '';

  // ---------------- LOCATION ----------------
  String? _locationAddress;
  double? _locationLat;
  double? _locationLng;

  // ---------------- MEDIA ----------------
  XFile? _pickedImage;
  Uint8List? _pickedBytes;
  String? _imageUrl;

  XFile? _pickedIcon;
  Uint8List? _pickedIconBytes;
  String? _iconUrl;

  // ---------------- UI ----------------
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _populateFromEvent(widget.event!);
    } else {
      // Only auto-load business address when creating a new event
      _loadBusinessHomeAddress();
    }
  }

  void _populateFromEvent(Event e) {
    _titleController.text = e.title ?? '';
    _venueController.text = e.venue ?? '';
    _categoryController.text = e.category ?? '';
    _descriptionController.text = e.description ?? '';
    _priceController.text = (e.price ?? 0).toStringAsFixed(2);

    _selectedTag = e.tag;
    _isRecurring = e.recurring ?? false;
    _selectedDayOfWeek = e.dayOfWeek;
    _selectedDateTime = e.dateTime;

    _imageUrl = e.imageUrl;
    _iconUrl = e.iconUrl;

    _locationLat = e.lat;
    _locationLng = e.lng;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Event' : 'Create Event',
          style: TextStyle(fontSize: 24),
        ),

        centerTitle: false,
        toolbarHeight: 90,
        // Taller to accommodate big buttons
        backgroundColor: AppColors.textLight,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                if (isEdit)
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _deleteEvent,
                    icon: const Icon(Icons.delete, size: 28),
                    label: const Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.darkInteract,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      //backgroundColor: AppColors.textLight,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitEvent,
                  icon: const Icon(Icons.save, size: 28),
                  label: Text(
                    isEdit ? 'Save' : 'Create',
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.darkInteract,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    //backgroundColor: AppColors.textLight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                isWide
                    ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _section(
                                title: "Basic Information",
                                child: _basicInfo(),
                              ),
                              _section(
                                title: "Description",
                                child: _description(),
                              ),
                              _section(
                                title: "Pricing & Tags",
                                child: _pricingAndTags(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            children: [
                              _section(
                                title: "Date & Recurrence",
                                child: _dateSection(),
                              ),
                              _section(
                                title: "Location",
                                child: _locationSection(),
                              ),
                              _section(title: "Media", child: _mediaSection()),
                            ],
                          ),
                        ),
                      ],
                    )
                    : Column(
                      children: [
                        _section(
                          title: "Basic Information",
                          child: _basicInfo(),
                        ),
                        _section(title: "Description", child: _description()),
                        _section(
                          title: "Pricing & Tags",
                          child: _pricingAndTags(),
                        ),
                        _section(
                          title: "Date & Recurrence",
                          child: _dateSection(),
                        ),
                        _section(title: "Location", child: _locationSection()),
                        _section(title: "Media", child: _mediaSection()),
                      ],
                    ),
                const SizedBox(height: 10),
                _actionButtons(), // <-- Buttons moved here
                const SizedBox(height: 32),
              ],
            ),
          ),
          if (_isSubmitting)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  width: 300,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Uploading data...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Spinning wheel
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),

                      // Linear progress bar
                      LinearProgressIndicator(
                        value: _uploadProgress, // 0.0 → 1.0
                      ),
                      const SizedBox(height: 12),

                      // Status message
                      Text(
                        _uploadMessage,
                        // "Uploading image..." / "Uploading icon..."
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _submitEvent,
          icon: const Icon(Icons.save, size: 28),
          label: Text(
            isEdit ? 'Save' : 'Create',
            style: const TextStyle(fontSize: 18, color: AppColors.darkInteract),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.textLight,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _basicInfo() {
    return Column(
      children: [
        TextField(
          controller: _titleController,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        TextField(
          controller: _venueController,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'Venue'),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value:
              _categoryController.text.isNotEmpty
                  ? _categoryController.text
                  : null,
          items:
              const [
                'Live Music',
                'Games',
                'Karaoke',
                'Market',
                'Sport',
                'Other',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => _categoryController.text = v ?? '',
          decoration: const InputDecoration(labelText: 'Category'),
        ),
      ],
    );
  }

  Widget _description() {
    return TextField(
      controller: _descriptionController,
      maxLines: null,
      decoration: const InputDecoration(
        labelText: 'Description',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _pricingAndTags() {
    return Column(
      children: [
        TextFormField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          decoration: const InputDecoration(
            labelText: 'Price',
            prefixText: 'R ',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedTag,
          items:
              const [
                '18+',
                'VIP',
                'Sold Out',
                'Outdoor',
                'Limited Seats',
              ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (v) => setState(() => _selectedTag = v),
          decoration: const InputDecoration(labelText: 'Event Tag (optional)'),
        ),
      ],
    );
  }

  Widget _dateSection() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text("Recurring Weekly"),
          value: _isRecurring,
          onChanged:
              (v) => setState(() {
                _isRecurring = v;
                if (v) _selectedDateTime = null;
              }),
        ),
        if (_isRecurring)
          DropdownButtonFormField<String>(
            value: _selectedDayOfWeek,
            items:
                const [
                      'monday',
                      'tuesday',
                      'wednesday',
                      'thursday',
                      'friday',
                      'saturday',
                      'sunday',
                    ]
                    .map(
                      (d) => DropdownMenuItem(
                        value: d,
                        child: Text(d.toUpperCase()),
                      ),
                    )
                    .toList(),
            onChanged: (v) => setState(() => _selectedDayOfWeek = v),
            decoration: const InputDecoration(labelText: 'Day'),
          ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _pickDateTime,
          child: Text(
            _selectedDateTime == null
                ? 'Pick Date & Time'
                : DateFormat.yMd().add_jm().format(_selectedDateTime!),
          ),
        ),
      ],
    );
  }

  Widget _locationSection() {
    String locationText;
    if (_locationLat != null && _locationLng != null) {
      if (_locationAddress != null && _locationAddress!.isNotEmpty) {
        locationText = _locationAddress!;
      } else {
        locationText =
            'Lat: ${_locationLat!.toStringAsFixed(5)}, '
            'Lng: ${_locationLng!.toStringAsFixed(5)}';
      }
    } else {
      locationText = 'No location selected';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(locationText),
        const SizedBox(height: 10),
        TextButton.icon(
          icon: const Icon(Icons.location_on),
          label: const Text("Pick Location"),
          onPressed: _openLocationPicker,
        ),
      ],
    );
  }

  Widget _mediaSection() {
    return Column(
      children: [
        _mediaButton(
          label: "Upload Event Image",
          onTap: pickImage,
          preview: _buildImagePreview(),
        ),
        const SizedBox(height: 16),
        _mediaButton(
          label: "Upload Icon",
          onTap: pickIcon,
          preview: _buildIconPreview(),
        ),
      ],
    );
  }

  Widget _mediaButton({
    required String label,
    required VoidCallback onTap,
    Widget? preview,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey),
        ),
        child: Row(
          children: [
            const Icon(Icons.upload, color: AppColors.primaryRed),
            const SizedBox(width: 8),
            Text(label),
            const Spacer(),
            if (preview != null)
              SizedBox(width: 60, height: 60, child: preview),
          ],
        ),
      ),
    );
  }

  Widget? _buildImagePreview() {
    if (_pickedImage != null) {
      return kIsWeb
          ? Image.memory(_pickedBytes!, fit: BoxFit.cover)
          : Image.file(File(_pickedImage!.path), fit: BoxFit.cover);
    }
    if (_imageUrl != null) return Image.network(_imageUrl!, fit: BoxFit.cover);
    return null;
  }

  Widget? _buildIconPreview() {
    if (_pickedIcon != null) {
      return kIsWeb
          ? Image.memory(_pickedIconBytes!, fit: BoxFit.cover)
          : Image.file(File(_pickedIcon!.path), fit: BoxFit.cover);
    }
    if (_iconUrl != null) return Image.network(_iconUrl!, fit: BoxFit.cover);
    return null;
  }

  // ============================================================
  // LOGIC
  // ============================================================

  Future<void> pickImage() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (img == null) return;
    _pickedImage = img;
    if (kIsWeb) _pickedBytes = await img.readAsBytes();
    setState(() {});
  }

  Future<void> pickIcon() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (img == null) return;
    _pickedIcon = img;
    if (kIsWeb) _pickedIconBytes = await img.readAsBytes();
    setState(() {});
  }

  Future<void> _loadBusinessHomeAddress() async {
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('businesses')
              .doc(widget.businessName) // or businessId if you have one
              .get();

      if (!snap.exists) return;

      final data = snap.data()!;
      final location = data['location'];

      if (location == null) return;

      setState(() {
        _locationLat = (location['lat'] as num?)?.toDouble();
        _locationLng = (location['lng'] as num?)?.toDouble();
        _locationAddress = location['address'] as String?;
      });
    } catch (e) {
      debugPrint('Failed to load business location: $e');
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      initialDate: now,
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    _selectedDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {});
  }

  Future<void> _openLocationPicker() async {
    final LatLng? picked = await showDialog(
      context: context,
      builder: (context) => _MapPickerDialog(),
    );

    if (picked != null) {
      // Always store coordinates
      _locationLat = picked.latitude;
      _locationLng = picked.longitude;

      try {
        // Attempt to get address
        final placemarks = await placemarkFromCoordinates(
          picked.latitude,
          picked.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          // Compose a human-readable address
          _locationAddress =
              '${place.name ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}'
                  .replaceAll(RegExp(r'(, )+$'), ''); // remove trailing commas
        } else {
          _locationAddress = null;
        }
      } catch (e) {
        // Failed to get address (no internet, etc.)
        _locationAddress = null;
      }

      setState(() {}); // Refresh UI
    }
  }

  Future<void> _submitEvent() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
      _uploadProgress = 0.0;
      _uploadMessage = 'Preparing data...';
    });

    try {
      // --- Validations ---
      if (_titleController.text.trim().isEmpty)
        throw Exception('Title required');
      if (_venueController.text.trim().isEmpty)
        throw Exception('Venue required');
      if (_categoryController.text.trim().isEmpty)
        throw Exception('Category required');
      if (!_isRecurring && _selectedDateTime == null)
        throw Exception('Select date & time');
      if (_isRecurring && _selectedDayOfWeek == null)
        throw Exception('Select day of week');
      if (_priceController.text.trim().isEmpty) throw Exception('Enter price');
      if (_locationLat == null || _locationLng == null)
        throw Exception('Select location');

      final previewData = {
        'title': _titleController.text.trim(),
        'venue': _venueController.text.trim(),
        'category': _categoryController.text.trim(),
        'description': _descriptionController.text.trim(),
        'titleLower': _titleController.text.trim().toLowerCase(),
        'recurring': _isRecurring,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'dayOfWeek': _selectedDayOfWeek,
        'dateTime':
            _selectedDateTime != null
                ? Timestamp.fromDate(_selectedDateTime!)
                : null,
        'location':
            _locationLat != null && _locationLng != null
                ? {
                  'lat': _locationLat,
                  'lng': _locationLng,
                  'address': _locationAddress ?? '',
                }
                : null,
        'tag': _selectedTag,
        'imageUrl': _imageUrl ?? '',
        'iconUrl': _iconUrl ?? '',
        'busynessLevel':
            isEdit ? widget.event!.busynessLevel ?? 'Quiet' : 'Quiet',
        'likes': isEdit ? widget.event!.likes ?? 0 : 0,
        'dislikes': isEdit ? widget.event!.dislikes ?? 0 : 0,
        'business': widget.businessName,
      };

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          final screenWidth = MediaQuery.of(context).size.width;
          final maxCardWidth = min(screenWidth * 0.95, 800).toDouble();

          return AlertDialog(
            backgroundColor: AppColors.white,
            // Change dialog background color
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20), // Rounded corners
            ),
            insetPadding: const EdgeInsets.all(16),
            // Controls padding from screen edges
            title: const Text(
              'Preview Event',
              style: TextStyle(
                color: AppColors.primaryRed,
              ), // Change title text color
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: min(maxCardWidth, 800)),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 1,
                    vertical: 1,
                  ), // Padding inside dialog
                  child: SizedBox(
                    width: max(screenWidth, maxCardWidth),
                    // make EventCard wider
                    child: EventCard(
                      event: Event.fromMap('preview', previewData),
                      pickedBytes: _pickedBytes,
                      pickedFile: _pickedImage,
                    ),
                  ),
                ),
              ),
            ),
            //actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), // padding for buttons
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;

      final data =
          Map<String, dynamic>.from(previewData)
            ..remove('imageUrl')
            ..remove('iconUrl');
      DocumentReference eventRef;

      if (isEdit) {
        eventRef = FirebaseFirestore.instance
            .collection('events')
            .doc(widget.event!.id);
        await eventRef.update(data);
      } else {
        eventRef = await FirebaseFirestore.instance
            .collection('events')
            .add(data);
      }

      // --- UPLOAD IMAGE ---
      if (_pickedImage != null || _pickedBytes != null) {
        await _uploadFileWithProgress(
          fileId: eventRef.id,
          title: _titleController.text.trim(),
          isIcon: false,
        );
        await eventRef.update({'imageUrl': _imageUrl});
      }

      // --- UPLOAD ICON ---
      if (_pickedIcon != null || _pickedIconBytes != null) {
        await _uploadFileWithProgress(
          fileId: eventRef.id,
          title: _titleController.text.trim(),
          isIcon: true,
        );
        await eventRef.update({'iconUrl': _iconUrl});
      }

      // After uploading images/icons and Firestore update
      // --- UPDATE PROVIDER ---
      if (isEdit) {
        widget.provider.updateEvent(widget.event!.id, data);
      } else {
        widget.provider.addEvent(Event.fromMap(eventRef.id, data));
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Event updated successfully!'
                : 'Event created successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _uploadFileWithProgress({
    required String fileId,
    required String title,
    required bool isIcon,
  }) async {
    final safeTitle = title
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    final ref = FirebaseStorage.instance.ref().child(
      isIcon
          ? 'event_icon/$fileId/$safeTitle.png'
          : 'event_pics/$fileId/$safeTitle.png',
    );

    UploadTask uploadTask;

    if (kIsWeb) {
      final bytes = isIcon ? _pickedIconBytes! : _pickedBytes!;
      uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/png'),
      );
    } else {
      final file = File(isIcon ? _pickedIcon!.path : _pickedImage!.path);
      uploadTask = ref.putFile(file);
    }

    setState(() {
      _uploadMessage = isIcon ? 'Uploading icon...' : 'Uploading image...';
    });

    uploadTask.snapshotEvents.listen((taskSnapshot) {
      setState(() {
        _uploadProgress =
            taskSnapshot.bytesTransferred / taskSnapshot.totalBytes;
      });
    });

    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    if (isIcon) {
      _iconUrl = downloadUrl;
    } else {
      _imageUrl = downloadUrl;
    }
  }

  Future<void> _uploadEventImage(String eventId, String title) async {
    final safeTitle = title
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final ref = FirebaseStorage.instance.ref().child(
      'event_pics/$eventId/$safeTitle.png',
    );

    if (kIsWeb) {
      await ref.putData(
        _pickedBytes!,
        SettableMetadata(contentType: 'image/png'),
      );
    } else {
      await ref.putFile(File(_pickedImage!.path));
    }
    _imageUrl = await ref.getDownloadURL();
  }

  Future<void> _uploadEventIcon(String eventId, String title) async {
    final safeTitle = title
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final ref = FirebaseStorage.instance.ref().child(
      'event_icon/$eventId/$safeTitle.png',
    );

    if (kIsWeb) {
      await ref.putData(
        _pickedIconBytes!,
        SettableMetadata(contentType: 'image/png'),
      );
    } else {
      await ref.putFile(File(_pickedIcon!.path));
    }
    _iconUrl = await ref.getDownloadURL();
  }

  void _showError(String message) {
    final snackBar = SnackBar(
      content: Text(message, style: const TextStyle(fontSize: 18)),
      backgroundColor: AppColors.primaryRed,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 50, 16, 0),
      // top margin = 50
      padding: const EdgeInsets.all(20),
      // increase padding
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 4),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> _deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Event'),
            content: Text('Delete "${widget.event!.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      // Delete Firestore document
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event!.id)
          .delete();

      widget.provider.removeEvent(widget.event!.id); // <-- remove from provider

      // Optionally: delete images from Firebase Storage
      if (_imageUrl != null) {
        try {
          await FirebaseStorage.instance.refFromURL(_imageUrl!).delete();
        } catch (_) {}
      }
      if (_iconUrl != null) {
        try {
          await FirebaseStorage.instance.refFromURL(_iconUrl!).delete();
        } catch (_) {}
      }

      Navigator.pop(context);
    }
  }
}
