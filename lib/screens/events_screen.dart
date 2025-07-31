import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/event.dart';
import '../widgets/event_card.dart';
import '../widgets/nav_bar.dart';
import '../widgets/sidebar.dart';
import '../widgets/today_event_rotator.dart';
import '../widgets/native_ad_card.dart';
import '../widgets/trending_ad_rotator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/colors.dart';








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
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool get _isMobile {
    return !kIsWeb && (Theme.of(context).platform == TargetPlatform.android || Theme.of(context).platform == TargetPlatform.iOS);
  }
  final List<NativeAd> _loadedAds = [];
  final int _adFrequency = 4;
  final int _maxAds = 10;



  @override
  void initState() {
    super.initState();
    _eventsFuture = _firestoreService.getEvents().then((events) {
      _allEvents = events;
      _applyFilters();
      return events;
    });
    preloadNativeAds();

  }

  void preloadNativeAds() {
    for (int i = 0; i < _maxAds; i++) {
      final nativeAd = NativeAd(
        adUnitId: 'ca-app-pub-3940256099942544/2247696110',
        factoryId: 'listTile',
        request: const AdRequest(),
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            setState(() {
              _loadedAds.add(ad as NativeAd);
            });
            debugPrint('✅ Preloaded ad $i loaded');
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            debugPrint('❌ Preloaded ad $i failed: $error');
          },
        ),
      );

      nativeAd.load();
    }
  }


  void _applyFilters() {
    setState(() {
      final lowerQuery = _searchController.text.toLowerCase();
      _filteredEvents = _allEvents.where((event) {
        final matchesSearch = event.title.toLowerCase().contains(lowerQuery) ||
            event.venue.toLowerCase().contains(lowerQuery);
        final matchesFilter =
            _filterType == 'All' || event.category == _filterType;
        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  void _clearFilters() {
    _searchController.clear();
    _filterType = 'All';
    _applyFilters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final ad in _loadedAds) {
      ad.dispose();
    }
    super.dispose();
  }

  List<Widget> _buildEventListWithAds() {
    final widgets = <Widget>[];
    int eventIndex = 0;
    int adIndex = 0;

    for (int i = 0; eventIndex < _filteredEvents.length; i++) {
      // Every nth item is an ad
      if (i != 0 && i % _adFrequency == 0 && adIndex < _loadedAds.length) {
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sponsored',
                  style: TextStyle(
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: AdWidget(ad: _loadedAds[adIndex]),
                ),
              ],
            ),
          ),
        );
        adIndex++;
      } else if (eventIndex < _filteredEvents.length) {
        widgets.add(EventCard(event: _filteredEvents[eventIndex]));
        eventIndex++;
      }
    }

    return widgets;
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
                      onSearchChanged: (query) => _applyFilters(),
                      onFilterChanged: (filter) {
                        _filterType = filter ?? 'All';
                        _applyFilters();
                      },
                      onClearFilters: _clearFilters,
                      onClose: () => Navigator.of(context).pop(),
                      searchController: _searchController,
                      selectedFilter: _filterType,
                    )

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
                        onSearchChanged: (query) => _applyFilters(),
                        onFilterChanged: (filter) {
                          _filterType = filter ?? 'All';
                          _applyFilters();
                        },
                        onClearFilters: _clearFilters,
                        onClose: () => Navigator.of(context).pop(),
                        searchController: _searchController,
                        selectedFilter: _filterType,
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
                          } else {
                            final now = DateTime.now();
                            final today = [
                              'monday',
                              'tuesday',
                              'wednesday',
                              'thursday',
                              'friday',
                              'saturday',
                              'sunday',
                            ][now.weekday - 1];

                            final todayEvents = _filteredEvents.where((event) {
                              if (event.recurring == true && event.dayOfWeek == today) return true;
                              if (event.dateTime != null) {
                                return event.dateTime.year == now.year &&
                                    event.dateTime.month == now.month &&
                                    event.dateTime.day == now.day;
                              }
                              return false;
                            }).toList();

                            return ListView(
                              padding: isNarrow
                                  ? const EdgeInsets.only(bottom: 16)
                                  : const EdgeInsets.all(16),
                              children: [
                                if (todayEvents.isNotEmpty)
                                  TodayEventRotator(events: todayEvents)
                                else if (_isMobile)
                                  const TrendingAdRotator(),
                                // else
                                //   const Padding(
                                //     padding: EdgeInsets.symmetric(vertical: 24),
                                //     child: Center(
                                //       child: Text(
                                //         'No events today.',
                                //         style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                //       ),
                                //     ),
                                //   ),



                                const SizedBox(height: 20),

                                Builder(
                                  builder: (context) => Row(
                                    children: [
                                      if (isNarrow)
                                        IconButton(
                                          icon: const Icon(Icons.tune),
                                          onPressed: () => Scaffold.of(context).openDrawer(),
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

                                if (_filteredEvents.isEmpty)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 32),
                                      child: Text(
                                        'No events match your search.',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  )
                                else
                                  ..._buildEventListWithAds(),
                              ],
                            );
                          }

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


