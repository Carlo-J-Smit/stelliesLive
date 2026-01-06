import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/event.dart';
import '../widgets/event_card.dart';
import '../widgets/nav_bar.dart';
import '../widgets/sidebar.dart';
import '../widgets/today_event_rotator.dart';

// import '../widgets/trending_ad_rotator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

//import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/colors.dart';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/event_provider.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  // final FirestoreService _firestoreService = FirestoreService();
  // late Future<List<Event>> _eventsFuture;
  List<Event> _allEvents = [];
  List<Event> _filteredEvents = [];
  String _searchQuery = '';
  String _filterType = 'All';
  String _selectedTag = 'All';
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool get _isMobile {
    return !kIsWeb &&
        (Theme.of(context).platform == TargetPlatform.android ||
            Theme.of(context).platform == TargetPlatform.iOS);
  }

  // final List<NativeAd> _loadedAds = [];
  // final int _adFrequency = 4;
  // final int _maxAds = 10;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<EventProvider>(context, listen: false);

      if (provider.allEvents.isEmpty) {
        await provider.reloadEvents();
      }

      _allEvents = provider.allEvents;
      _applyFilters();
    });

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // preloadNativeAds();
    }
  }

  Future<void> _refreshEvents() async {
    final provider = Provider.of<EventProvider>(context, listen: false);

    await provider.reloadEvents();

    setState(() {
      _allEvents = provider.allEvents;
      _applyFilters();
    });
  }

  // void preloadNativeAds() {
  //   for (int i = 0; i < _maxAds; i++) {
  //     final nativeAd = NativeAd(
  //       adUnitId: 'ca-app-pub-3940256099942544/2247696110',
  //       factoryId: 'listTile',
  //       request: const AdRequest(),
  //       listener: NativeAdListener(
  //         onAdLoaded: (ad) {
  //           setState(() {
  //             _loadedAds.add(ad as NativeAd);
  //           });
  //           debugPrint('✅ Preloaded ad $i loaded');
  //         },
  //         onAdFailedToLoad: (ad, error) {
  //           ad.dispose();
  //           debugPrint('❌ Preloaded ad $i failed: $error');
  //         },
  //       ),
  //     );
  //
  //     nativeAd.load();
  //   }
  // }

  void _applyFilters() {
    setState(() {
      final lowerQuery = _searchController.text.toLowerCase();
      _filteredEvents =
          _allEvents.where((event) {
            final matchesSearch =
                event.title.toLowerCase().contains(lowerQuery) ||
                event.venue.toLowerCase().contains(lowerQuery);
            final matchesCategory =
                _filterType == 'All' || event.category == _filterType;
            final matchesTag =
                _selectedTag == 'All' ||
                (event.tag?.contains(_selectedTag) ?? false);
            return matchesSearch && matchesCategory && matchesTag;
          }).toList();
    });
  }

  void _clearFilters() {
    _searchController.clear();
    _filterType = 'All';
    _selectedTag = 'All';
    _applyFilters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    // for (final ad in _loadedAds) {
    //   ad.dispose();
    // }
    super.dispose();
  }

  List<Widget> _buildEventListWithAds() {
    final widgets = <Widget>[];
    int eventIndex = 0;
    int adIndex = 0;

    for (int i = 0; eventIndex < _filteredEvents.length; i++) {
      // Every nth item is an ad
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        // if (i != 0 && i % _adFrequency == 0 && adIndex < _loadedAds.length) {
        //   widgets.add(
        //     Container(
        //       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        //       decoration: BoxDecoration(
        //         color: Colors.white,
        //         border: Border.all(color: Colors.grey.shade200),
        //         borderRadius: BorderRadius.circular(16),
        //         boxShadow: const [
        //           BoxShadow(
        //             color: Colors.black12,
        //             blurRadius: 6,
        //             offset: Offset(0, 2),
        //           ),
        //         ],
        //       ),
        //       padding: const EdgeInsets.all(12),
        //       child: Column(
        //         crossAxisAlignment: CrossAxisAlignment.start,
        //         children: [
        //           const Text(
        //             'Sponsored',
        //             style: TextStyle(
        //               color: AppColors.primaryRed,
        //               fontWeight: FontWeight.bold,
        //               fontSize: 12,
        //               letterSpacing: 0.5,
        //             ),
        //           ),
        //           const SizedBox(height: 8),
        //           SizedBox(
        //             height: 100,
        //             child: AdWidget(ad: _loadedAds[adIndex]),
        //           ),
        //         ],
        //       ),
        //     ),
        //   );
        //   adIndex++;

        // } else if (eventIndex < _filteredEvents.length) {
        if (eventIndex < _filteredEvents.length) {
          widgets.add(EventCard(event: _filteredEvents[eventIndex]));
          eventIndex++;
        }
      } else if (eventIndex < _filteredEvents.length) {
        widgets.add(EventCard(event: _filteredEvents[eventIndex]));
        eventIndex++;
      }
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('BUILD: EventsScreen');
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
                      onSearchChanged: (_) => _applyFilters(),
                      onFilterChanged: (value) {
                        _filterType = value ?? 'All';
                        _applyFilters();
                      },
                      onTagChanged: (value) {
                        _selectedTag = value ?? 'All';
                        _applyFilters();
                      },
                      onClearFilters: _clearFilters,
                      searchController: _searchController,
                      selectedFilter: _filterType,
                      selectedTag: _selectedTag,
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
                        onSearchChanged: (_) => _applyFilters(),
                        onFilterChanged: (value) {
                          _filterType = value ?? 'All';
                          _applyFilters();
                        },
                        onTagChanged: (value) {
                          _selectedTag = value ?? 'All';
                          _applyFilters();
                        },
                        onClearFilters: _clearFilters,
                        searchController: _searchController,
                        selectedFilter: _filterType,
                        selectedTag: _selectedTag,
                        onClose: () => Navigator.of(context).pop(),
                      ),

                    Expanded(
                      child: Consumer<EventProvider>(
                        builder: (context, eventProvider, _) {
                          if (eventProvider.isLoading &&
                              eventProvider.allEvents.isEmpty) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          _allEvents = eventProvider.allEvents;

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
                                    event.dayOfWeek == today) {
                                  return true;
                                }
                                if (event.dateTime != null) {
                                  return event.dateTime.year == now.year &&
                                      event.dateTime.month == now.month &&
                                      event.dateTime.day == now.day;
                                }
                                return false;
                              }).toList();

                          return RefreshIndicator(
                            onRefresh: _refreshEvents,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding:
                                  isNarrow
                                      ? const EdgeInsets.only(bottom: 16)
                                      : const EdgeInsets.all(16),
                              children: [
                                if (todayEvents.isNotEmpty)
                                  TodayEventRotator(events: todayEvents),

                                const SizedBox(height: 20),

                                Row(
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

                                const SizedBox(height: 10),

                                if (_filteredEvents.isEmpty)
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 32,
                                        horizontal: 16,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            'No events match your search.',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'Want to see something added?',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          const SizedBox(height: 8),
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              const url =
                                                  'https://docs.google.com/forms/d/e/1FAIpQLSe1tEAuqDT4VEjqggP633DLwzqsI3xpEKaP_su4AI_K4KqooA/viewform?usp=dialog';
                                              launchUrl(Uri.parse(url));
                                            },
                                            icon: const Icon(
                                              Icons.add_circle_outline,
                                            ),
                                            label: const Text(
                                              'Request an Event',
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primaryRed,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                    vertical: 12,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  ..._buildEventListWithAds(),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
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
