import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/firestore_service.dart';

class EventProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<Event> _allEvents = [];
  bool _isLoading = false;

  List<Event> get allEvents => _allEvents;
  bool get isLoading => _isLoading;

  // ======================
  // INITIAL LOAD / RELOAD
  // ======================
  Future<void> reloadEvents() async {
    _isLoading = true;
    notifyListeners();

    try {
      final events = await _firestoreService.getEvents();
      _allEvents = events;
    } catch (e) {
      debugPrint('❌ Event reload failed: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ======================
  // EXISTING METHODS
  // ======================
  void setEvents(List<Event> events) {
    _allEvents = events;
    notifyListeners();
  }

  void addEvent(Event e) {
    _allEvents.add(e);
    notifyListeners();
  }

  void updateEvent(String id, Map<String, dynamic> data) {
    final index = _allEvents.indexWhere((e) => e.id == id);
    if (index != -1) {
      _allEvents[index] = Event.fromMap(id, data);
      notifyListeners();
    }
  }

  void removeEvent(String id) {
    _allEvents.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}
