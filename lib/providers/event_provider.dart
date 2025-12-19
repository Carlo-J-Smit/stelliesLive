import 'package:flutter/material.dart';
import '../models/event.dart';

class EventProvider extends ChangeNotifier {
  List<Event> _allEvents = [];

  List<Event> get allEvents => _allEvents;

  void setEvents(List<Event> events) {
    _allEvents = events;
    notifyListeners();
  }

  void addEvent(Event e) {
    allEvents.add(e);
    notifyListeners();
  }

  void updateEvent(String id, Map<String, dynamic> data) {
    final index = allEvents.indexWhere((e) => e.id == id);
    if (index != -1) {
      allEvents[index] = Event.fromMap(id, data);
      notifyListeners();
    }
  }

  void removeEvent(String id) {
    allEvents.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}
