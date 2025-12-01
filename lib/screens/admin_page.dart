import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:stellieslive/constants/colors.dart';
import 'dart:typed_data'; // for web
import 'dart:io' show File; // only for mobile
//import 'dart:html' as html; // only used on web
import '../models/event.dart';
import '../widgets/event_card.dart';



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
  final _priceController = TextEditingController();
  DateTime? _selectedDateTime;
  bool _isRecurring = false;
  String? _selectedDayOfWeek;

  bool _isSubmitting = false;
  String? _error;
  String? _locationAddress;
  double? _locationLat;
  double? _locationLng;
  String? _selectedTag;
  //Uint8List? _imageWebFileData;
  //File? _imageFile;
  String? _imageUrl;
  bool _imageUploaded = false;
  XFile? _pickedImage;
  Uint8List? _pickedBytes; // only used on Web







  List<DocumentSnapshot> _searchResults = [];
  DocumentSnapshot? _selectedEvent;

  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  final User? user = FirebaseAuth.instance.currentUser;

  String _formatPrice(double price) {
    final formatter = NumberFormat.currency(symbol: 'R', decimalDigits: 0);
    return formatter.format(price);
  }

  Widget _buildImagePreview() {
    if (_pickedImage != null) {
      // User picked a new image
      return kIsWeb
          ? (_pickedBytes != null
          ? Image.memory(_pickedBytes!, fit: BoxFit.cover)
          : const SizedBox())
          : Image.file(File(_pickedImage!.path), fit: BoxFit.cover);
    }

    // Show existing image from Firestore
    if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      return Image.network(_imageUrl!, fit: BoxFit.cover);
    }

    return const SizedBox();
  }


  List<TextSpan> highlightMatch(String source, String query) {
    if (query.isEmpty) return [TextSpan(text: source)];

    final lowerSource = source.toLowerCase();
    final lowerQuery = query.toLowerCase();

    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerSource.indexOf(lowerQuery, start);
      if (index < 0) {
        spans.add(TextSpan(text: source.substring(start)));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: source.substring(start, index)));
      }

      spans.add(
        TextSpan(
          text: source.substring(index, index + query.length),
          style: const TextStyle(
            backgroundColor: Colors.yellow,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = index + query.length;
    }

    return spans;
  }

  Color _tagColor(String tag) {
    switch (tag) {
      case '18+':
        return Colors.redAccent;
      case 'VIP':
        return Colors.purple;
      case 'Sold Out':
        return Colors.grey;
      case 'Free Entry':
        return Colors.green;
      case 'Popular':
        return Colors.orange;
      case 'Outdoor':
        return Colors.teal;
      case 'Limited Seats':
        return Colors.blue;
      default:
        return Colors.black;
    }
  }

  IconData _tagIcon(String tag) {
    switch (tag) {
      case '18+':
        return Icons.do_not_disturb_alt;
      case 'VIP':
        return Icons.star;
      case 'Sold Out':
        return Icons.block;
      case 'Free Entry':
        return Icons.check_circle_outline;
      case 'Popular':
        return Icons.local_fire_department;
      case 'Outdoor':
        return Icons.park;
      case 'Limited Seats':
        return Icons.event_seat;
      default:
        return Icons.label;
    }
  }



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
                  title: Text.rich(
                    TextSpan(
                      children: highlightMatch(doc['title'], _searchController.text),
                    ),
                  ),
                  subtitle: Text.rich(
                    TextSpan(
                      children: highlightMatch(doc['venue'], _searchController.text),
                    ),
                  ),
                      onTap: () {
                        // Clear all fields before loading new event
                        setState(() {
                          _titleController.clear();
                          _venueController.clear();
                          _categoryController.clear();
                          _descriptionController.clear();
                          _selectedDateTime = null;
                          _selectedDayOfWeek = null;
                          _isRecurring = false;
                          _priceController.clear();
                          _locationLat = null;
                          _locationLng = null;
                          _locationAddress = null;
                          _selectedTag = null;
                          _imageUrl = null;
                          _pickedBytes = null;
                          _pickedImage = null;
                        });

                        // Then load the event
                        _loadEvent(doc);
                      },
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
                maxLength: 40, // ⬅️ Limit to 40 characters
                decoration: const InputDecoration(
                  labelText: 'Title',
                  counterText: '', // optional: hides default counter text
                  helperText: 'Max 40 characters',
                ),
              ),

              TextField(
                controller: _venueController,
                decoration: const InputDecoration(labelText: 'Venue'),
              ),
              DropdownButtonFormField<String>(
                value: _categoryController.text.isNotEmpty ? _categoryController.text : null,
                onChanged: (val) => setState(() => _categoryController.text = val ?? ''),
                items: const [
                  'Live Music',
                  'Games',
                  'Karaoke',
                  'Market',
                  'Sport',
                  'Other',
                ]
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                decoration: const InputDecoration(labelText: 'Category'),
              ),

              DropdownButtonFormField<String>(
                value: _selectedTag,
                onChanged: (val) => setState(() => _selectedTag = val),
                items: const [
                  'None',
                  '18+',
                  'VIP',
                  'Sold Out',
                  'Outdoor',
                  'Limited Seats',
                ].map(
                      (tag) => DropdownMenuItem(
                    value: tag == 'None' ? null : tag,
                    child: Text(tag),
                  ),
                ).toList(),

                decoration: const InputDecoration(labelText: 'Event Tag (optional)'),
              ),


              if (_selectedTag != null && _selectedTag!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Builder(
                    builder: (context) {
                      final tag = _selectedTag!;
                      return Row(
                        children: [
                          const Text(
                            'Tag Preview:',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(_tagIcon(tag), color: _tagColor(tag), size: 20),
                          const SizedBox(width: 6),
                          Text(
                            tag,
                            style: TextStyle(
                              color: _tagColor(tag),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],




              const SizedBox(height: 10),
              TextField(
                controller: _descriptionController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  hintText: 'Use bullets (-, •) and line breaks to format.',
                  border: OutlineInputBorder(),
                ),
              ),


              // Conditional drag-drop on web vs button on mobile:
              // Conditional image preview / upload button
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  // Clear previous image preview first
                  setState(() {
                    _imageUrl = null;
                    _pickedBytes = null;
                    _pickedImage = null;
                    _imageUploaded = false;
                  });

                  // Pick a new image
                  await pickImage(); // Make sure pickImage updates _imageUrl

                  // Update uploaded state if image exists
                  if (_imageUrl != null && _imageUrl!.isNotEmpty) {
                    setState(() {
                      _imageUploaded = true;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.upload_file, color: AppColors.primaryRed),
                      const SizedBox(width: 8),
                      Text(
                        _imageUploaded ? 'Uploaded' : 'Upload / Update Image',
                        style: const TextStyle(
                          color: AppColors.primaryRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_pickedImage != null || (_imageUrl != null && _imageUrl!.isNotEmpty))
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(width: 80, height: 80, child: _buildImagePreview()),
                          ),
                        ),



                    ],
                  ),
                ),
              ),




              const SizedBox(height: 10),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Event Price',
                  prefixText: 'R ',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontWeight: FontWeight.w500),
                validator: (value) {
                  final price = double.tryParse(value ?? '');
                  if (price == null || price < 0) {
                    return 'Enter a valid price';
                  }
                  return null;
                },
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

  // Future<void> pickImage() async {
  //   print('[pickImage] called');
  //   if (kIsWeb) {
  //     print('[pickImage] running on Web');
  //
  //     final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
  //     uploadInput.accept = 'image/*';
  //     uploadInput.click();
  //
  //     uploadInput.onChange.listen((e) async {
  //       final files = uploadInput.files;
  //       if (files == null || files.isEmpty) {
  //         print('[pickImage] No files selected');
  //         return;
  //       }
  //
  //       print('[pickImage] File selected: ${files[0].name}');
  //
  //       final reader = html.FileReader();
  //       reader.readAsArrayBuffer(files[0]);
  //
  //       reader.onLoadEnd.listen((event) {
  //         setState(() {
  //           _imageWebFileData = reader.result as Uint8List;
  //           _imageFile = null;
  //         });
  //         print('[pickImage] _imageWebFileData length: ${_imageWebFileData?.length}');
  //       });
  //     });
  //   } else {
  //     // MOBILE
  //     print('[pickImage] running on Mobile');
  //
  //     try {
  //       final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
  //       if (picked != null) {
  //         setState(() {
  //           _imageFile = File(picked.path);
  //           _imageWebFileData = null;
  //         });
  //         print('[pickImage] File selected: ${picked.path}');
  //       } else {
  //         print('[pickImage] No file picked');
  //       }
  //     } catch (e) {
  //       print('[pickImage] Error picking image: $e');
  //     }
  //   }
  // }

  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return; // user cancelled

    setState(() => _pickedImage = image);

    if (kIsWeb) {
      // web: read as bytes
      _pickedBytes = await image.readAsBytes();
    }
  }




  // Future<void> uploadEventPic(String eventId, String eventTitle) async {
  //   print('[uploadEventPic] called');
  //
  //   final safeTitle = eventTitle.trim().replaceAll(RegExp(r'[^\w\s-]'), '_');
  //   final ref = FirebaseStorage.instance
  //       .ref()
  //       .child('event_pics/$eventId/$safeTitle.png');
  //
  //   try {
  //     if (kIsWeb && _imageWebFileData != null) {
  //       print('[uploadEventPic] Uploading web image, size: ${_imageWebFileData!.length}');
  //       await ref.putData(_imageWebFileData!);
  //     } else if (_imageFile != null) {
  //       print('[uploadEventPic] Uploading mobile File: ${_imageFile!.path}');
  //       await ref.putFile(_imageFile!);
  //     } else {
  //       print('[uploadEventPic] No file to upload');
  //       return;
  //     }
  //
  //     _imageUrl = await ref.getDownloadURL();
  //     print('[uploadEventPic] Upload successful, URL: $_imageUrl');
  //   } catch (e) {
  //     print('[uploadEventPic] Error uploading file: $e');
  //   }
  // }

  Future<void> uploadEventPic(String eventId, String eventTitle) async {
    if (_pickedImage == null && _pickedBytes == null) return;

    // Replace spaces and slashes with underscores
    final safeTitle = eventTitle
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_') // replace anything not alphanumeric with _
        .replaceAll(RegExp(r'_+'), '_');           // collapse multiple _ into single _


    // Upload path
    final String path = 'event_pics/$eventId/$safeTitle.png';
    final Reference ref = FirebaseStorage.instance.ref().child(path);

    if (kIsWeb) {
      await ref.putData(_pickedBytes!, SettableMetadata(contentType: 'image/png'));
    } else {
      await ref.putFile(File(_pickedImage!.path));
    }

    // Store the exact URL in Firestore for deletion later
    _imageUrl = await ref.getDownloadURL();
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
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return;

    setState(() {
      _searchResults.clear();
      _lastDocument = null;
      _hasMore = true;
    });

    final titleQuery = FirebaseFirestore.instance
        .collection('events')
        .where('titleLower', isGreaterThanOrEqualTo: query)
        .where('titleLower', isLessThanOrEqualTo: query + '\uf8ff')
        .limit(10)
        .get();

    final venueQuery = FirebaseFirestore.instance
        .collection('events')
        .where('venueLower', isGreaterThanOrEqualTo: query)
        .where('venueLower', isLessThanOrEqualTo: query + '\uf8ff')
        .limit(10)
        .get();

    final results = await Future.wait([titleQuery, venueQuery]);

    final combined = <DocumentSnapshot>{}
      ..addAll(results[0].docs)
      ..addAll(results[1].docs);

    final sortedResults = combined.toList()
      ..sort((a, b) => (a['title'] ?? '').compareTo(b['title'] ?? ''));

    setState(() {
      _searchResults = sortedResults;
      _hasMore = false; // pagination for now skipped
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
      _imageUrl = doc['imageUrl'];
      _priceController.text = (doc['price'] as num?)?.toStringAsFixed(2) ?? '';
      _selectedTag = doc['tag'];





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
      // Validation
      if (!_isRecurring && _selectedDateTime == null) throw Exception('Please select a date.');
      if (_isRecurring && _selectedDayOfWeek == null) throw Exception('Please select a day of the week.');
      if (_isRecurring && _selectedDateTime == null) throw Exception('Please select a time.');

      // Prepare data for preview
      final previewData = {
        'title': _titleController.text.trim(),
        'venue': _venueController.text.trim(),
        'category': _categoryController.text.trim(),
        'description': _descriptionController.text.trim(),
        'imageUrl': _imageUrl ?? '', // use existing or null
        'titleLower': _titleController.text.trim().toLowerCase(),
        'recurring': _isRecurring,
        'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
        'dayOfWeek': _selectedDayOfWeek,
        'dateTime': _selectedDateTime != null ? Timestamp.fromDate(_selectedDateTime!) : null,
        'location': _locationLat != null && _locationLng != null
            ? {
          'lat': _locationLat,
          'lng': _locationLng,
          'address': _locationAddress ?? '',
        }
            : null,
        'tag': _selectedTag,
      };

      // Show preview
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          final screenWidth = MediaQuery.of(context).size.width;
          return AlertDialog(
            title: const Text('Preview Event'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: screenWidth * 0.7,
                child: EventCard(
                  event: Event.fromMap('preview', previewData),
                  pickedBytes: _pickedBytes, // use picked image for preview
                  pickedFile: _pickedImage,
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
            ],
          );
        },
      );

      if (confirmed != true) return; // user cancelled

      // Prepare Firestore data
      final data = Map<String, dynamic>.from(previewData)..remove('imageUrl'); // remove temp preview image

      // Create or update event
      DocumentReference eventRef;
      if (_selectedEvent == null) {
        eventRef = await FirebaseFirestore.instance.collection('events').add(data);
      } else {
        eventRef = FirebaseFirestore.instance.collection('events').doc(_selectedEvent!.id);
        await eventRef.update(data);
      }

      // Upload image if picked
      if (_pickedImage != null || _pickedBytes != null) {
        await uploadEventPic(eventRef.id, _titleController.text.trim());
        // Update Firestore with actual download URL
        await eventRef.update({'imageUrl': _imageUrl});
      }

      // Success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_selectedEvent == null ? 'Event created.' : 'Event updated.')),
      );

      // Reset state
      setState(() {
        _selectedEvent = null;
        _searchResults = [];
        _searchController.clear();
        _titleController.clear();
        _venueController.clear();
        _categoryController.clear();
        _descriptionController.clear();
        _selectedDateTime = null;
        _selectedDayOfWeek = null;
        _isRecurring = false;
        _priceController.clear();
        _locationLat = null;
        _locationLng = null;
        _locationAddress = null;
        _selectedTag = null;
        _imageUrl = null;
        _pickedBytes = null;
        _pickedImage = null;
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
  LatLng? _pickedLocation;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Position>(
      future: Geolocator.getCurrentPosition(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final position = snapshot.data!;
        final LatLng initialPosition = LatLng(position.latitude, position.longitude);

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
              onTap: (LatLng pos) {
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
      },
    );
  }
}

