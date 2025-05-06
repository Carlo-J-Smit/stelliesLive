import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';

class EventCache {
  static List<Map<String, dynamic>> _events = [];

  // Raw data (includes 'id')
  static List<Map<String, dynamic>> get rawEvents => _events;

  // Return as List<Event> using fromMap with id
  static List<Event> get events =>
      _events.map((e) => Event.fromMap(e['id'], e)).toList();

  static Future<void> preload() async {
    final query = await FirebaseFirestore.instance
        .collection('events')
        .get(const GetOptions(source: Source.serverAndCache));

    _events = query.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id; // inject Firestore doc ID into the map
      return data;
    }).toList();
  }

  static List<Event> search(String query) {
    return events
        .where((event) => event.title
            .toLowerCase()
            .contains(query.toLowerCase()))
        .toList();
  }
}
