import 'package:cloud_firestore/cloud_firestore.dart';

class EventCache {
  static List<Map<String, dynamic>> _events = [];

  static List<Map<String, dynamic>> get events => _events;

  static Future<void> preload() async {
    final query = await FirebaseFirestore.instance
        .collection('events')
        .get(const GetOptions(source: Source.serverAndCache));

    _events = query.docs.map((doc) => doc.data()).toList();
  }

  static List<Map<String, dynamic>> search(String query) {
    return _events
        .where((event) => event['title']
            .toString()
            .toLowerCase()
            .contains(query.toLowerCase()))
        .toList();
  }
}
