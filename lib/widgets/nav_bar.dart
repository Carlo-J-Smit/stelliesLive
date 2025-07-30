import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/colors.dart';
import '../screens/activity.dart';
import '../screens/events_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/admin_page.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import '../models/event.dart';



class Navbar extends StatefulWidget {
  const Navbar({super.key});

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  User? _user;
  String? _role;
  late final StreamSubscription<User?> _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    if (!mounted) return;

    if (user == null) {
      if (mounted) {
        setState(() {
          _user = null;
          _role = null;
        });
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;
      setState(() {
        _user = user;
        _role = doc.data()?['role'];
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _user = user;
          _role = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  Widget _navButton(BuildContext context, String label, VoidCallback onTap,
      {Color color = AppColors.textLight}) {
    return TextButton(
      onPressed: onTap,
      child: Text(label, style: TextStyle(color: color, fontSize: 16)),
    );
  }

  Widget _buildDesktopNav(BuildContext context) {
    final isAdmin = _role == 'admin';

    return Row(
      children: [
        const Text(
          'StelliesLive',
          style: TextStyle(
            color: AppColors.textLight,
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
        const Spacer(),
        _navButton(context, 'Activity', () async {
          final eventsSnapshot = await FirebaseFirestore.instance.collection('events').get();
          final events = eventsSnapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => ActivityScreen(events: events)),
          );
        }),
        _navButton(context, 'Events', () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const EventsScreen()),
          );
        }),
        if (_user == null)
          _navButton(context, 'Business Login', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AuthScreen()),
            );
          }),
        if (_user != null)
          _navButton(context, 'Logout', _logout),
        if (isAdmin)
          _navButton(
            context,
            'Business Management',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminPage()),
              );
            },
            color: Colors.yellow,
          ),
      ],
    );
  }

  Widget _buildMobileNav(BuildContext context) {
    final isAdmin = _role == 'admin';

    return Row(
      children: [
        const Text(
          'StelliesLive',
          style: TextStyle(
            color: AppColors.textLight,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        const Spacer(),
        PopupMenuButton<String>(
          icon: const Icon(Icons.menu, color: Colors.white),
          onSelected: (value) {
            switch (value) {
              case 'Activity':
                () async {
                  final eventsSnapshot = await FirebaseFirestore.instance.collection('events').get();
                  final events = eventsSnapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();

                  if (!mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => ActivityScreen(events: events)),
                  );
                }();
                break;

              case 'Events':
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const EventsScreen()),
                );
                break;
              case 'Login':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                );
                break;
              case 'Logout':
                _logout();
                break;
              case 'Admin':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminPage()),
                );
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'Activity', child: Text('Activity')),
            const PopupMenuItem(value: 'Events', child: Text('Events')),
            if (_user == null)
              const PopupMenuItem(value: 'Login', child: Text('Business Login')),
            if (_user != null)
              const PopupMenuItem(value: 'Logout', child: Text('Logout')),
            if (isAdmin)
              const PopupMenuItem(value: 'Admin', child: Text('Business Management')),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    double topPadding = 20; // default
    if (!kIsWeb && Platform.isAndroid) {
      // Add system status bar height + extra spacing for Android
      topPadding = MediaQuery.of(context).padding.top + 15;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;

        return Container(
          padding: EdgeInsets.fromLTRB(20, topPadding, 20, 5),
          width: double.infinity,
          color: AppColors.primaryRed,
          child: isNarrow
              ? _buildMobileNav(context)
              : _buildDesktopNav(context),
        );
      },
    );
  }
}
