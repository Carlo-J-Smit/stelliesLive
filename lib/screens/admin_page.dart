import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';


class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _venueController = TextEditingController();
  final _categoryController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _selectedDateTime;
  bool _isRecurring = false;
  String? _selectedDayOfWeek;

  bool _isSubmitting = false;
  String? _error;
  String? _locationAddress;
  double? _locationLat;
  double? _locationLng;

  List<DocumentSnapshot> _searchResults = [];
  DocumentSnapshot? _selectedEvent;

  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  final User? user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: Text("Login required."));
    if (user!.email != 'admin@gmail.com')
      return const Center(child: Text("Admin access only."));

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔍 Search
              TextField(
                controller: _searchController,
                onChanged: (value) {
                  _searchEvents();
                },
                decoration: const InputDecoration(
                  labelText: 'Search for Event',
                ),
              ),

              const SizedBox(height: 16),
              ..._searchResults.map(
                (doc) => ListTile(
                  title: Text(doc['title']),
                  subtitle: Text(doc['venue']),
                  onTap: () => _loadEvent(doc),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteEvent(doc),
                  ),
                ),
              ),
              if (_hasMore && !_isLoadingMore)
                TextButton(
                  onPressed: _loadMoreResults,
                  child: const Text('Load More'),
                ),
              const Divider(height: 32),

              const Text(
                "Edit or Create Event",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: _venueController,
                decoration: const InputDecoration(labelText: 'Venue'),
              ),
              TextField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: _imageUrlController,
                decoration: const InputDecoration(labelText: 'Image URL'),
              ),

              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text("Recurring Weekly"),
                value: _isRecurring,
                onChanged: (val) {
                  setState(() {
                    _isRecurring = val;
                    _selectedDateTime = null;
                  });
                },
              ),
              if (_isRecurring) ...[
                DropdownButtonFormField<String>(
                  value: _selectedDayOfWeek,
                  items:
                      [
                            'Monday',
                            'Tuesday',
                            'Wednesday',
                            'Thursday',
                            'Friday',
                            'Saturday',
                            'Sunday',
                          ]
                          .map(
                            (day) => DropdownMenuItem(
                              value:
                                  day.toLowerCase(), // match saved value format
                              child: Text(day),
                            ),
                          )
                          .toList(),
                  onChanged: (val) {
                    setState(() => _selectedDayOfWeek = val);
                  },
                  decoration: const InputDecoration(labelText: 'Day of Week'),
                ),

                // Time selection for recurring events
                TextButton(
                  onPressed: _pickDateTime, // use a time-only picker
                  child: Text(
                    _selectedDateTime == null
                        ? 'Select Time'
                        : 'Selected: ${TimeOfDay.fromDateTime(_selectedDateTime!).format(context)}',
                  ),
                ),
              ] else ...[
                // Date + time selection for one-time events
                TextButton(
                  onPressed: _pickDateTime,
                  child: Text(
                    _selectedDateTime == null
                        ? 'Select Date & Time'
                        : 'Selected: ${_selectedDateTime!.toLocal()}',
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                _locationAddress != null
                    ? 'Location: $_locationAddress'
                    : 'No location selected.',
              ),
              TextButton.icon(
                icon: const Icon(Icons.location_on),
                label: const Text("Pick Location"),
                onPressed: _openLocationPicker,
              ),


              const SizedBox(height: 20),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              if (_isSubmitting) const CircularProgressIndicator(),

              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitEvent,
                child: Text(
                  _selectedEvent == null ? 'Create Event' : 'Update Event',
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
            picked.latitude, picked.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          setState(() {
            _locationAddress =
            '${place.name}, ${place.locality}, ${place.administrativeArea}';
          });
        }
      } catch (e) {
        setState(() {
          _locationAddress = 'Lat: ${picked.latitude}, Lng: ${picked.longitude}';
        });
      }
    }
  }

  void _searchEvents() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searchResults.clear();
      _lastDocument = null;
      _hasMore = true;
    });

    final results =
        await FirebaseFirestore.instance
            .collection('events')
            .where('title', isGreaterThanOrEqualTo: query)
            .where('title', isLessThanOrEqualTo: query + '')
            .limit(10)
            .get();

    if (results.docs.isNotEmpty) {
      _lastDocument = results.docs.last;
    }

    setState(() {
      _searchResults = results.docs;
      _hasMore = results.docs.length == 10;
    });
  }

  void _loadMoreResults() async {
    if (!_hasMore || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    final query = _searchController.text.trim();
    if (_lastDocument == null) {
      print('[ADMIN] _lastDocument is null → skipping load more');
      return; // ⛔️ do nothing if no last document
    }
    final results =
        await FirebaseFirestore.instance
            .collection('events')
            .where('titleLower', isGreaterThanOrEqualTo: query)
            .where('titleLower', isLessThanOrEqualTo: query + '\uf8ff')
            .startAfterDocument(_lastDocument!) // ✅ safe now
            .limit(10)
            .get();

    if (results.docs.isNotEmpty) {
      _lastDocument = results.docs.last;
    }

    setState(() {
      _searchResults.addAll(results.docs);
      _hasMore = results.docs.length == 10;
      _isLoadingMore = false;
    });
  }

  void _loadEvent(DocumentSnapshot doc) {
    setState(() {
      _selectedEvent = doc;
      _titleController.text = doc['title'] ?? '';
      _venueController.text = doc['venue'] ?? '';
      _categoryController.text = doc['category'] ?? '';
      _descriptionController.text = doc['description'] ?? '';
      _imageUrlController.text = doc['imageUrl'] ?? '';

      // ✅ Check if "location" exists before using it
      if (doc.data() is Map && (doc.data() as Map).containsKey('location')) {
      final location = doc['location'];
      _locationLat = location['lat'];
      _locationLng = location['lng'];
      _locationAddress = location['address'];
      } else {
      _locationLat = null;
      _locationLng = null;
      _locationAddress = null;
      }


  final isRecurring = doc['recurring'] == true;
      _isRecurring = isRecurring;

      if (isRecurring) {
        _selectedDayOfWeek = doc['dayOfWeek'];
        //_selectedDateTime = null;
      } else {
        _selectedDayOfWeek = null;
        
      }
      _selectedDateTime =
            doc['dateTime'] != null
                ? (doc['dateTime'] as Timestamp).toDate()
                : null;
    });
  }

  Future<void> _submitEvent() async {
    setState(() => _isSubmitting = true);

    try {
      if (!_isRecurring && _selectedDateTime == null) {
        throw Exception('Please select a date.');
      }
      if (_isRecurring && _selectedDayOfWeek == null) {
        throw Exception('Please select a day of the week.');
      }
      if (_isRecurring && _selectedDateTime == null) {
        throw Exception('Please select a time.');
      }

      final data = {
        'title': _titleController.text.trim(),
        'venue': _venueController.text.trim(),
        'category': _categoryController.text.trim(),
        'description': _descriptionController.text.trim(),
        'imageUrl': _imageUrlController.text.trim(),
        'titleLower': _titleController.text.trim().toLowerCase(),
        'recurring': _isRecurring,
      };

      if (_isRecurring && _selectedDayOfWeek != null && _selectedDateTime != null) {
        data['dayOfWeek'] = _selectedDayOfWeek!;
        data['dateTime'] = Timestamp.fromDate(_selectedDateTime!);
      } else if (_selectedDateTime != null) {
        data['dateTime'] = Timestamp.fromDate(_selectedDateTime!);
      }
      if (_locationLat != null && _locationLng != null) {
      data['location'] = {
      'lat': _locationLat,
      'lng': _locationLng,
      'address': _locationAddress ?? '',
      };
      }


  if (_selectedEvent == null) {
        await FirebaseFirestore.instance.collection('events').add(data);
      } else {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(_selectedEvent!.id)
            .update(data);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedEvent == null ? 'Event created.' : 'Event updated.',
          ),
        ),
      );

      setState(() {
        _selectedEvent = null;
        _searchResults = [];
        _searchController.clear();
        _titleController.clear();
        _venueController.clear();
        _categoryController.clear();
        _descriptionController.clear();
        _imageUrlController.clear();
        _selectedDateTime = null;
        _selectedDayOfWeek = null;
        _isRecurring = false;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    if (_isRecurring == false) {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: now,
        lastDate: DateTime(now.year + 2),
      );
      if (pickedDate != null) {
        final pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(now),
        );

        if (pickedTime != null) {
          setState(() {
            _selectedDateTime = DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              pickedTime.hour,
              pickedTime.minute,
            );
          });
        }
      }
    } else {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            1900,
            1,
            1,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  void _deleteEvent(DocumentSnapshot doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Delete Event"),
            content: Text("Are you sure you want to delete '${doc['title']}'?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(doc.id)
          .delete();
      setState(() {
        _searchResults.remove(doc);
        if (_selectedEvent?.id == doc.id) {
          _selectedEvent = null;
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Deleted '${doc['title']}'")));
    }
  }
}

class _MapPickerDialog extends StatefulWidget {
  @override
  State<_MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<_MapPickerDialog> {
  LatLng _initialPosition = const LatLng(-33.9249, 18.4241); // Cape Town
  LatLng? _pickedLocation;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Pick Location"),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _initialPosition,
            zoom: 12,
          ),
          onTap: (LatLng pos) {
            setState(() {
              _pickedLocation = pos;
            });
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
          child: const Text("Cancel"),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          child: const Text("Select"),
          onPressed: () {
            if (_pickedLocation != null) {
              Navigator.pop(context, _pickedLocation);
            }
          },
        ),
      ],
    );
  }
}
