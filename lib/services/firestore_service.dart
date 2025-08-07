import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';

class FirestoreService {
  final _events = FirebaseFirestore.instance.collection('events');

  Future<List<Event>> getEvents() async {
    final now = DateTime.now();
    final eightHoursAgo = now.subtract(const Duration(hours: 8));

    // 1️ Non-recurring events happening in the future or last 8 hours
    final nonRecurringSnapshot = await _events
        .where('recurring', isEqualTo: false)
        .where('dateTime', isGreaterThan: Timestamp.fromDate(eightHoursAgo))
        .get();

    final nonRecurringEvents = nonRecurringSnapshot.docs.map((doc) {
      return Event.fromMap(doc.id, doc.data());
    }).toList();

    // 2️ All recurring events (we include them no matter the date)
    final recurringSnapshot = await _events
        .where('recurring', isEqualTo: true)
        .get();

    final recurringEvents = recurringSnapshot.docs.map((doc) {
      return Event.fromMap(doc.id, doc.data());
    }).toList();

    // 3️ Sort both groups individually by dateTime (just in case)
    recurringEvents.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    nonRecurringEvents.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    // 4️ Combine with recurring events shown first
    return [...recurringEvents, ...nonRecurringEvents];
  }
}
