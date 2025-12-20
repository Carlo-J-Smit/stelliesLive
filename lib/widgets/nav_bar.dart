import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/colors.dart';
import '../screens/activity.dart';
import '../screens/events_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/admin_page.dart';
import '../screens/admin_dashboard_page.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import '../models/event.dart';
import 'package:url_launcher/url_launcher.dart';




class Navbar extends StatefulWidget {
  const Navbar({super.key});

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  User? _user;
  String? _role;
  String? _business;
  late final StreamSubscription<User?> _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _launchFeedbackForm() async {
    const url = 'https://docs.google.com/forms/d/e/1FAIpQLSe1tEAuqDT4VEjqggP633DLwzqsI3xpEKaP_su4AI_K4KqooA/viewform?usp=dialog';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open feedback form.')),
      );
    }
  }


  Future<void> _onAuthChanged(User? user) async {
    if (!mounted) return;

    if (user == null) {
      if (mounted) {
        setState(() {
          _user = null;
          _role = null;
          _business = null;
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
        if (_role == 'business') {
          _business = doc.data()?['business_name'];
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _user = user;
          _role = null;
          _business = null;
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

    if (!mounted) return;

    // Close ALL pages and go back to public landing page
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const EventsScreen()),
          (route) => false,
    );
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
    final isBusiness = _role == 'business';

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
        if (isBusiness)
          _navButton(
            context,
            'Business Management',
                () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminDashboardPage(businessName: _business ?? '')),
              );
            },
            color: Colors.yellow,
          ),
        if (_user != null)
          _navButton(context, 'Logout', _logout),
        if (isAdmin)
          _navButton(
            context,
            'Data Management',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminPage()),
              );
            },
            color: Colors.yellow,
          ),
        _navButton(context, 'Feedback', _launchFeedbackForm),


      ],
    );
  }

  Widget _buildMobileNav(BuildContext context) {
    final isAdmin = _role == 'admin';
    final isBusiness = _role == 'business';

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
              case 'BusinessManagement':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AdminDashboardPage(businessName: _business ?? '')),
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
              case 'Feedback':
                _launchFeedbackForm();
                break;

            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'Activity', child: Text('Activity')),
            const PopupMenuItem(value: 'Events', child: Text('Events')),
            if (_user == null)
              const PopupMenuItem(value: 'Login', child: Text('Business Login')),
            if (isBusiness)
              const PopupMenuItem(value: 'BusinessManagement', child: Text('Business Management')),
            if (_user != null)
              const PopupMenuItem(value: 'Logout', child: Text('Logout')),
            if (isAdmin)
              const PopupMenuItem(value: 'Admin', child: Text('Data Management')),
            const PopupMenuItem(value: 'Feedback', child: Text('Feedback')),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('BUILD: nav bar');
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
