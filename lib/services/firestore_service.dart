import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';

class FirestoreService {
  final _events = FirebaseFirestore.instance.collection('events');

  Future<List<Event>> getEvents() async {
    final querySnapshot = await _events.orderBy('dateTime').get();

    return querySnapshot.docs.map((doc) {
      return Event.fromMap(doc.id, doc.data());
    }).toList();
  }
}
