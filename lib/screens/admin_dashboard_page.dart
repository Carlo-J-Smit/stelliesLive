import 'package:flutter/material.dart';
import 'package:stellieslive/constants/colors.dart';
import '../models/event.dart';
import '../widgets/event_card.dart';
import 'package:provider/provider.dart';
import '../providers/event_provider.dart';
import '../screens/event_form.dart';
import 'dart:math';
import '../widgets/nav_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


class AdminDashboardPage extends StatefulWidget {
  final String businessName;

  const AdminDashboardPage({
    super.key,
    required this.businessName,
  });

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}


class _AdminDashboardPageState extends State<AdminDashboardPage> {

  // Example events list (replace with provider / Firebase)
  late List<Event> _events = [];

  // Search controller
  final TextEditingController _searchController = TextEditingController();
  List<Event> _filteredEvents = [];

  // Currently selected tab
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();

    // Access events from provider
    final provider = Provider.of<EventProvider>(context, listen: false);
    _events = provider.allEvents;

    // Initialize filteredEvents
    _filteredEvents = List.from(_events);
    _filterEvents(_searchController.text);

    _searchController.addListener(() {
      _filterEvents(_searchController.text);
    });
  }

  void _filterEvents(String query) {
    final q = query.toLowerCase();

    setState(() {
      _filteredEvents = _events.where((event) {
        // Always filter by business
        if ((event.business ?? '').toLowerCase() != widget.businessName.toLowerCase()) {
          return false;
        }

        // If no search query, include all business events
        if (q.isEmpty) return true;

        // Otherwise also filter by title or venue
        return event.title.toLowerCase().contains(q) ||
            event.venue.toLowerCase().contains(q);
      }).toList();

      _filteredEvents.sort(
            (a, b) => (a.title ?? '').compareTo(b.title ?? ''),
      );
    });
  }


  void _openEventDetail(Event? event) {
    showDialog(
      context: context,
      builder:
          (_) => EventDetailDialog(
            event: event,
            onEdit: () {
              Navigator.pop(context);
              _openEventForm(event: event);
            },
          ),
    );
  }

  void _openEventForm({Event? event}) async {
    final provider = Provider.of<EventProvider>(context, listen: false);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventFormPage(
          event: event,
          provider: provider, // <-- pass it here-
          businessName: widget.businessName,
        ),
      ),
    );

    // Refresh events after returning
    setState(() {
      _events = provider.allEvents;
      _filterEvents(_searchController.text);
    });
  }



  Widget _buildSidebar({VoidCallback? onClose}) {
    final isNarrow = MediaQuery.of(context).size.width < 700;

    return SafeArea(
      child: Container(
        width: 200,
        color: Colors.grey[100],
        child: Column(
          children: [
            // Close button on narrow screens
            if (isNarrow && onClose != null)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.red),
                  onPressed: onClose,
                ),
              ),
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: Text(
                widget.businessName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(color: AppColors.primaryRed),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _sidebarItem("Events", 0),
                    _sidebarItem("Analytics", 1),
                    _sidebarItem("Settings", 2),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebarItem(String title, int index) {
    final selected = _selectedTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        color: selected ? Colors.red[100] : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Row(
          children: [
            Icon(
              index == 0
                  ? Icons.event
                  : index == 1
                  ? Icons.bar_chart
                  : Icons.settings,
              color: selected ? AppColors.accent : AppColors.darkInteract,
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                color: selected ?  AppColors.accent : AppColors.darkInteract,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildEventGrid() {
    // +1 for the "Create New Event" tile
    final itemCount = _filteredEvents.length + 1;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        //crossAxisCount: 3, // adjust based on screen width if needed
        maxCrossAxisExtent: 280,
        childAspectRatio: 0.9,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          // Create New Event tile
          return InkWell(
            onTap: () => _openEventForm(),
            child: Card(
              color: Colors.grey[200],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.add, size: 50, color: AppColors.primaryRed),
                    SizedBox(height: 8),
                    Text(
                      "Create New Event",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final event = _filteredEvents[index - 1];
        return InkWell(
          onTap: () => _openEventDetail(event),
          child: Card(
            clipBehavior: Clip.hardEdge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child:
                      event.imageUrl != null
                          ? Image.network(event.imageUrl!, fit: BoxFit.cover)
                          : Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.event, size: 40),
                          ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    event.title ?? "Untitled",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    if (event.venue != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 8),
                        child: Row(
                          children: [
                            Text(
                              event.venue!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    // if (event.tag != null)
                    //   Padding(
                    //     padding: const EdgeInsets.only(left: 8, bottom: 8),
                    //     child: Row(
                    //       children: [
                    //         Icon(
                    //           _tagIcon(event.tag!),
                    //           size: 16,
                    //           color: _tagColor(event.tag!),
                    //         ),
                    //         const SizedBox(width: 4),
                    //         Text(
                    //           event.tag!,
                    //           style: TextStyle(
                    //             color: _tagColor(event.tag!),
                    //             fontSize: 12,
                    //           ),
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 700;

    Widget content;
    switch (_selectedTabIndex) {
      case 0:
        content = Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: "Search Events",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(child: _buildEventGrid()),
          ],
        );
        break;
      case 1:
        content = const Center(child: Text("Analytics coming soon"));
        break;
      case 2:
        content = AccountManagementTab(businessName: widget.businessName);
        break;
      default:
        content = const SizedBox.shrink();
    }

    return Scaffold(
      drawer: isNarrow
          ? Drawer(
        child: _buildSidebar(onClose: () => Navigator.of(context).pop()),
      )
          : null,
      body: Column(
        children: [
          // Always show your custom Navbar
          const Navbar(),

          // "Secondary app bar" inside the body for both desktop and mobile
          if (isNarrow)
            Container(
              color: AppColors.adminBar, // customize your AppBar color
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 56,
              child: Row(
                children: [
                  if (isNarrow)
                    Builder(
                      builder: (context) => IconButton(
                        icon: const Icon(Icons.tune, color: Colors.white),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                  Text(
                    '${widget.businessName} Dashboard',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // Main content + sidebar
          Expanded(
            child: Row(
              children: [
                if (!isNarrow)
                  _buildSidebar(), // permanently show on desktop
                Expanded(child: content),
              ],
            ),
          ),
        ],
      ),
    );

  }


  // Tag helpers
  Color _tagColor(String tag) {
    switch (tag) {
      case '18+':
        return Colors.redAccent;
      case 'VIP':
        return Colors.purple;
      case 'Sold Out':
        return Colors.grey;
      case 'Free Entry':
        return Colors.green;
      case 'Popular':
        return Colors.orange;
      case 'Outdoor':
        return Colors.teal;
      case 'Limited Seats':
        return Colors.blue;
      default:
        return Colors.black;
    }
  }

  IconData _tagIcon(String tag) {
    switch (tag) {
      case '18+':
        return Icons.do_not_disturb_alt;
      case 'VIP':
        return Icons.star;
      case 'Sold Out':
        return Icons.block;
      case 'Free Entry':
        return Icons.check_circle_outline;
      case 'Popular':
        return Icons.local_fire_department;
      case 'Outdoor':
        return Icons.park;
      case 'Limited Seats':
        return Icons.event_seat;
      default:
        return Icons.label;
    }
  }
}

// ================= Event Detail Dialog =================

class EventDetailDialog extends StatelessWidget {
  final Event? event;
  final VoidCallback onEdit;

  const EventDetailDialog({super.key, this.event, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxCardWidth = screenWidth * 0.9;

    if (event == null) return const SizedBox();

    // Calculate like/dislike ratio
    final totalVotes = (event!.likes ?? 0) + (event!.dislikes ?? 0);
    final likeRatio = totalVotes > 0 ? (event!.likes! / totalVotes) : 0.5;
    final dislikeRatio = totalVotes > 0 ? (event!.dislikes! / totalVotes) : 0.5;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      title: const Text(
        'Event Preview',
        style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: min(maxCardWidth, 800)),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Event preview card
              SizedBox(
                width: max(screenWidth, maxCardWidth),
                child: EventCard(event: event!),
              ),
              const SizedBox(height: 20),

              // Split Like/Dislike infographic
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Likes vs Dislikes',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: (likeRatio * 100).round(),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.horizontal(
                                left: Radius.circular(10),
                                right:
                                    totalVotes == 0
                                        ? Radius.circular(10)
                                        : Radius.zero,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: (dislikeRatio * 100).round(),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.horizontal(
                                right: Radius.circular(10),
                                left:
                                    totalVotes == 0
                                        ? Radius.circular(10)
                                        : Radius.zero,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${event!.likes ?? 0} Likes • ${event!.dislikes ?? 0} Dislikes',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              BusynessIndicator(busynessLevel: event!.busynessLevel),

            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: onEdit, child: const Text('Edit Event')),
      ],
    );
  }
}

class BusynessIndicator extends StatefulWidget {
  final String? busynessLevel; // "quiet", "moderate", "busy"

  const BusynessIndicator({super.key, this.busynessLevel});

  @override
  State<BusynessIndicator> createState() => _BusynessIndicatorState();
}

class _BusynessIndicatorState extends State<BusynessIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _value = 0;

  @override
  void initState() {
    super.initState();

    // Map levels to % for progress bar
    switch (widget.busynessLevel?.toLowerCase()) {
      case "quiet":
        _value = 0.25;
        break;
      case "moderate":
        _value = 0.55;
        break;
      case "busy":
        _value = 0.9;
        break;
      default:
        _value = 0.0;
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(); // continuous loop
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  LinearGradient _getGradient() {
    switch (widget.busynessLevel?.toLowerCase()) {
      case "quiet":
        return LinearGradient(
          colors: [Colors.green, Colors.green.shade900, Colors.green],
          tileMode: TileMode.repeated,
        );
      case "moderate":
        return LinearGradient(
          colors: [Colors.orange.shade900, Colors.orange, Colors.orange.shade900],
          tileMode: TileMode.repeated,
        );
      case "busy":
        return LinearGradient(
          colors: [Colors.redAccent, Colors.red.shade900, Colors.redAccent],
          tileMode: TileMode.repeated,
        );
      default:
        return LinearGradient(
          colors: [Colors.grey, Colors.grey],
          tileMode: TileMode.repeated,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Current Busyness',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          height: 20,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                // Background (remaining portion)
                FractionallySizedBox(
                  widthFactor: 1,
                  child: Container(color: Colors.grey[300]),
                ),

                // Filled portion with seamless animated gradient
                FractionallySizedBox(
                  widthFactor: _value,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return ShaderMask(
                        shaderCallback: (rect) {
                          return _getGradient().createShader(
                            Rect.fromLTWH(
                              -rect.width + 2 * rect.width * _controller.value,
                              0,
                              rect.width,
                              rect.height,
                            ),
                          );
                        },
                        blendMode: BlendMode.srcATop,
                        child: Container(color: Colors.white.withOpacity(0.8)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.busynessLevel != null
              ? '${widget.busynessLevel![0].toUpperCase()}${widget.busynessLevel!.substring(1)}'
              : 'Unknown',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

class AccountManagementTab extends StatefulWidget {
  final String businessName;

  const AccountManagementTab({super.key, required this.businessName});

  @override
  State<AccountManagementTab> createState() => _AccountManagementTabState();
}

class _AccountManagementTabState extends State<AccountManagementTab> {
  final TextEditingController _emailController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference get _businessRef =>
      _firestore.collection('businesses').doc(widget.businessName);

  /// Add user to business
  Future<void> _addUserEmail() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) return;

    final businessSnap = await _businessRef.get();
    if (!businessSnap.exists) {
      // Option 1: show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Business '${widget.businessName}' does not exist.")),
      );

      // Option 2: auto-create (uncomment if you want)
      await _businessRef.set({'userEmails': [], 'user_uids': []}, SetOptions(merge: true));


      return;
    }



    try {
      // Find user
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("User not found.")),
        );
        return;
      }

      final userRef = userQuery.docs.first.reference;
      final userUid = userQuery.docs.first.id;
      final userData = userQuery.docs.first.data();

      final businessRef = _businessRef;
      final batch = _firestore.batch();

      // Add business ID to user
      List<String> userBusinesses = List<String>.from(userData['business_ids'] ?? []);
      if (!userBusinesses.contains(widget.businessName)) {
        userBusinesses.add(widget.businessName);
      }

      batch.update(userRef, {
        'business_ids': userBusinesses,
        'role': 'business',
        'business_name' : widget.businessName,
      });

      // Add user UID to business
      batch.update(businessRef, {
        'user_uids': FieldValue.arrayUnion([userUid]),
        'userEmails': FieldValue.arrayUnion([email]),
      });

      await batch.commit();

      _emailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$email added successfully.")),
      );
      setState(() {}); // Refresh list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to add user: $e")),
      );
    }
  }

  /// Remove user from business
  Future<void> _removeUserEmail(String email) async {
    try {
      // Find user
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("User not found.")),
        );
        return;
      }

      final userRef = userQuery.docs.first.reference;
      final userUid = userQuery.docs.first.id;
      final userData = userQuery.docs.first.data()!;

      List<String> userBusinesses = List<String>.from(userData['business_ids'] ?? []);
      userBusinesses.remove(widget.businessName);

      final newRole = userBusinesses.isEmpty ? 'user' : 'business';

      final batch = _firestore.batch();

      batch.update(userRef, {
        'business_ids': userBusinesses,
        'role': newRole,
        'business_name' : '',
      });

      final businessRef = _businessRef;
      batch.update(businessRef, {
        'user_uids': FieldValue.arrayRemove([userUid]),
        'userEmails': FieldValue.arrayRemove([email]),
      });

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$email removed successfully.")),
      );
      setState(() {}); // Refresh list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to remove user: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Account Management",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Manage who has access to this business dashboard.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          /// ADD USER
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "Add user by email",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text("Add"),
                onPressed: _addUserEmail,
              )
            ],
          ),

          const SizedBox(height: 32),

          /// USER LIST
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _businessRef.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                final List users = data['userEmails'] ?? [];

                if (users.isEmpty) {
                  return const Center(
                    child: Text(
                      "No users added yet.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final email = users[index];

                    return ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(email),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Remove user"),
                              content: Text("Remove $email from this business?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text("Cancel"),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Remove"),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            _removeUserEmail(email);
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


