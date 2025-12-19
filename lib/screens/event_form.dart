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

import '../constants/colors.dart';
import '../models/event.dart';
import '../widgets/event_card.dart';
import '../providers/event_provider.dart';
class EventFormPage extends StatefulWidget {
  final Event? event;
  final EventProvider provider; // <-- pass provider

  const EventFormPage({
    super.key,
    this.event,
    required this.provider,
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Pick Location"),
      content: SizedBox(
        width: 400,
        height: 400,
        child: GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(0, 0),
            zoom: 1,
          ),
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
        ),
      ),
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
}

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
    if (isEdit) _populateFromEvent(widget.event!);
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
        toolbarHeight: 90, // Taller to accommodate big buttons
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
                    label: const Text('Delete', style: TextStyle(fontSize: 18, color: AppColors.darkInteract)),
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
                    style: const TextStyle(fontSize: 18, color: AppColors.darkInteract),
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

      body: SingleChildScrollView(
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
                          _section(title: "Description", child: _description()),
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
                    _section(title: "Basic Information", child: _basicInfo()),
                    _section(title: "Description", child: _description()),
                    _section(title: "Pricing & Tags", child: _pricingAndTags()),
                    _section(title: "Date & Recurrence", child: _dateSection()),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, // <-- stretch
      children: [
        Text(
          _locationLat != null
              ? 'Lat: $_locationLat, Lng: $_locationLng'
              : 'No location selected',
        ),
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
      _locationLat = picked.latitude;
      _locationLng = picked.longitude;
      try {
        final placemarks = await placemarkFromCoordinates(
          picked.latitude,
          picked.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          _locationAddress =
              '${place.name}, ${place.locality}, ${place.administrativeArea}';
        }
      } catch (_) {
        _locationAddress = null;
      }
      setState(() {});
    }
  }

  Future<void> _submitEvent() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      if (!_isRecurring && _selectedDateTime == null) {
        throw Exception('Please select a date & time');
      }
      if (_isRecurring && _selectedDayOfWeek == null) {
        throw Exception('Please select a day of week');
      }

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
        'busynessLevel': 'Quiet',
        'likes': 0,
        'dislikes': 0,
      };

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          final screenWidth = MediaQuery.of(context).size.width;
          final maxCardWidth = min(screenWidth * 0.95, 800).toDouble();

          return AlertDialog(
            backgroundColor: AppColors.white, // Change dialog background color
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20), // Rounded corners
            ),
            insetPadding: const EdgeInsets.all(16), // Controls padding from screen edges
            title: const Text(
              'Preview Event',
              style: TextStyle(color: AppColors.primaryRed), // Change title text color
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: min(maxCardWidth, 800),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1 ,vertical: 1 ), // Padding inside dialog
                  child: SizedBox(
                    width: max(screenWidth , maxCardWidth), // make EventCard wider
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


      if (_pickedImage != null || _pickedBytes != null) {
        await _uploadEventImage(eventRef.id, _titleController.text.trim());
        await eventRef.update({'imageUrl': _imageUrl});
      }

      if (_pickedIcon != null || _pickedIconBytes != null) {
        await _uploadEventIcon(eventRef.id, _titleController.text.trim());
        await eventRef.update({'iconUrl': _iconUrl});
      }

      if (isEdit) {
        await eventRef.update(data);
        widget.provider.updateEvent(widget.event!.id, data); // <-- update provider
      } else {
        final newDoc = await FirebaseFirestore.instance
            .collection('events')
            .add(data);
        widget.provider.addEvent(Event.fromMap(newDoc.id, data)); // <-- add to provider
      }


      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isSubmitting = false);
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
