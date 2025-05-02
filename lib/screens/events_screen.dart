import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/event.dart';
import '../widgets/event_card.dart';
import '../widgets/nav_bar.dart';
import '../widgets/sidebar.dart';
import '../widgets/today_event_rotator.dart';


class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late Future<List<Event>> _eventsFuture;
  List<Event> _allEvents = [];
  List<Event> _filteredEvents = [];
  String _searchQuery = '';
  String _filterType = 'All';

  @override
  void initState() {
    super.initState();
    _eventsFuture = _firestoreService.getEvents().then((events) {
      _allEvents = events;
      _applyFilters();
      return events;
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredEvents =
          _allEvents.where((event) {
            final matchesSearch = event.title.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
            final matchesFilter =
                _filterType == 'All' || event.category == _filterType;
            return matchesSearch && matchesFilter;
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Sidebar on the left
          const Navbar(),

          // Main content
          Expanded(
            child: Row(
              children: [
                Sidebar(
                  onSearchChanged: (query) {
                    _searchQuery = query;
                    _applyFilters();
                  },
                  onFilterChanged: (filter) {
                    _filterType = filter ?? 'All';
                    _applyFilters();
                  },
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FutureBuilder<List<Event>>(
                      future: _eventsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        } else if (_filteredEvents.isEmpty) {
                          return const Center(child: Text('No events match your search.'));
                        }

                        final now = DateTime.now();
                        final todayEvents = _filteredEvents.where((event) {
                          return event.dateTime.year == now.year &&
                                event.dateTime.month == now.month &&
                                event.dateTime.day == now.day;
                        }).toList();

                        return ListView(
                          children: [
                            
                            if (todayEvents.isNotEmpty)
                              TodayEventRotator(events: todayEvents),
                            const SizedBox(height: 20),

                            const Text(
                              'All Events',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),

                            ..._filteredEvents.map((event) => EventCard(event: event)),
                          ],
                        );
                      },
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
