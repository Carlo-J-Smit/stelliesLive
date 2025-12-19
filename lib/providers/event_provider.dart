import 'package:flutter/material.dart';
import '../models/event.dart';

class EventProvider extends ChangeNotifier {
  List<Event> _allEvents = [];

  List<Event> get allEvents => _allEvents;

  void setEvents(List<Event> events) {
    _allEvents = events;
    notifyListeners();
  }

  void addEvent(Event event) {
    _allEvents.add(event);
    notifyListeners();
  }

  void removeEvent(String eventId) {
    _allEvents.removeWhere((e) => e.id == eventId);
    notifyListeners();
  }
}
