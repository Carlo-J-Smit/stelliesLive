import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String title;
  final String description;
  final String venue;
  final DateTime dateTime;
  final String? imageUrl;
  final String category;
  final bool? recurring;
  final String? dayOfWeek;
  final double? lat;
  final double? lng;
  double? distance;
  final int? popularity; // 1 = Quiet, 2 = Moderate, 3 = Busy
  final double? price;
  final String? tag;




  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.venue,
    required this.dateTime,
    required this.category,
    this.recurring,
    this.dayOfWeek,
    this.imageUrl,
    this.lat,
    this.lng,
    this.distance,
    this.popularity,
    this.price,
    this.tag,
  });

  factory Event.fromMap(String id, Map<String, dynamic> data) {
    final location = data['location'] as Map<String, dynamic>?;

    return Event(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      venue: data['venue'] ?? '',
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      imageUrl: data['imageUrl'],
      category: data['category'] ?? '',
      recurring: data['recurring'] is bool ? data['recurring'] : null,
      dayOfWeek: data['dayOfWeek'],
      lat: (location?['lat'] as num?)?.toDouble(),
      lng: (location?['lng'] as num?)?.toDouble(),
      popularity: data['popularity'],
      price: (data['price'] as num?)?.toDouble(),
      tag: data['tag'],
    );
  }


  factory Event.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Event.fromMap(doc.id, data);
  }
}
