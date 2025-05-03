import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/colors.dart';
import '../screens/landing_page.dart';
import '../screens/events_screen.dart';
import '../screens/study_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/admin_page.dart';
import 'dart:async';


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
      child: Text(label, style: TextStyle(color: color)),
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
        _navButton(context, 'Home', () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LandingPage()),
          );
        }),
        _navButton(context, 'Events', () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const EventsScreen()),
          );
        }),
        _navButton(context, 'Study & Tutors', () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const StudyScreen()),
          );
        }),
        if (_user == null)
          _navButton(context, 'Login', () {
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
            'Admin',
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
              case 'Home':
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LandingPage()),
                );
                break;
              case 'Events':
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const EventsScreen()),
                );
                break;
              case 'Study':
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const StudyScreen()),
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
            const PopupMenuItem(value: 'Home', child: Text('Home')),
            const PopupMenuItem(value: 'Events', child: Text('Events')),
            const PopupMenuItem(value: 'Study', child: Text('Study & Tutors')),
            if (_user == null)
              const PopupMenuItem(value: 'Login', child: Text('Login')),
            if (_user != null)
              const PopupMenuItem(value: 'Logout', child: Text('Logout')),
            if (isAdmin)
              const PopupMenuItem(value: 'Admin', child: Text('Admin')),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          height: 60,
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
