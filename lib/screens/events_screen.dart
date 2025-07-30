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
            final lowerQuery = _searchQuery.toLowerCase();
            final matchesSearch = event.title.toLowerCase().contains(lowerQuery) ||
                event.venue.toLowerCase().contains(lowerQuery);

            final matchesFilter =
                _filterType == 'All' || event.category == _filterType;
            return matchesSearch && matchesFilter;
          }).toList();
    });
  }


  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        //const Navbar(),
        return Scaffold(
          // appBar:
          //     isNarrow
          //         ? AppBar(
          //           title: const Text('Events'),
          //           leading: Builder(
          //             builder:
          //                 (context) => IconButton(
          //                   icon: const Icon(Icons.menu),
          //                   onPressed: () => Scaffold.of(context).openDrawer(),
          //                 ),
          //           ),
          //         )
          //         : null,
          drawer:
              isNarrow
                  ? Drawer(
                    child: Sidebar(
                      onSearchChanged: (query) {
                        _searchQuery = query;
                        _applyFilters();
                      },
                      onFilterChanged: (filter) {
                        _filterType = filter ?? 'All';
                        _applyFilters();
                      },
                      onClose: () => Navigator.of(context).pop(),
                    ),
                  )
                  : null,

          body: Column(
            children: [
              // if (!isNarrow)
              const Navbar(),

              Expanded(
                child: Row(
                  children: [
                    if (!isNarrow)
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
                    Expanded(
                      // child: Padding(
                      //   padding: const EdgeInsets.all(16),
                      child: FutureBuilder<List<Event>>(
                        future: _eventsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          } else if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}'),
                            );
                          } else if (_filteredEvents.isEmpty) {
                            return const Center(
                              child: Text('No events match your search.'),
                            );
                          }

                          final now = DateTime.now();
                          final today =
                              [
                                'monday',
                                'tuesday',
                                'wednesday',
                                'thursday',
                                'friday',
                                'saturday',
                                'sunday',
                              ][now.weekday - 1];

                          final todayEvents =
                              _filteredEvents.where((event) {
                                if (event.recurring == true &&
                                    event.dayOfWeek == today)
                                  return true;
                                if (event.dateTime != null) {
                                  return event.dateTime.year == now.year &&
                                      event.dateTime.month == now.month &&
                                      event.dateTime.day == now.day;
                                }
                                return false;
                              }).toList();

                          return ListView(
                            padding:
                                isNarrow
                                    ? const EdgeInsets.only(bottom: 16)
                                    : const EdgeInsets.all(16),
                            children: [
                              if (todayEvents.isNotEmpty)
                                TodayEventRotator(events: todayEvents),
                              const SizedBox(height: 20),

                              Builder(
                                builder:
                                    (context) => Row(
                                      children: [
                                        if (isNarrow)
                                          IconButton(
                                            icon: const Icon(Icons.tune),
                                            onPressed:
                                                () =>
                                                    Scaffold.of(
                                                      context,
                                                    ).openDrawer(),
                                          ),
                                        const Text(
                                          'All Events',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                              ),

                              const SizedBox(height: 10),
                              ..._filteredEvents.map(
                                (event) => EventCard(event: event),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    //),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
