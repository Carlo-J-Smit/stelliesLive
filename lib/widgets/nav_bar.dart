import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/colors.dart';
import '../screens/landing_page.dart';
import '../screens/events_screen.dart';
import '../screens/study_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/admin_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<String?> getUserRole() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final doc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  if (!doc.exists) return null;

  return doc.data()?['role'];
}

class Navbar extends StatefulWidget {
  const Navbar({super.key});

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  User? _user;
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        print('[NAVBAR] Logged in as: ${user.email}');

        final doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (doc.exists) {
          final role = doc.data()?['role'];
          print('[NAVBAR] Role from Firestore: $role');

          setState(() {
            _user = user;
            _role = role;
          });
        } else {
          print('[NAVBAR] No user document found in Firestore.');
          setState(() {
            _user = user;
            _role = null;
          });
        }
      } else {
        print('[NAVBAR] No user logged in.');
        setState(() {
          _user = null;
          _role = null;
        });
      }
    });
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
          child:
              isNarrow ? _buildMobileNav(context) : _buildDesktopNav(context),
        );
      },
    );
  }

  Widget _navButton(
    bool isAdmin,
    BuildContext context,
    String label,
    Widget page, {
    Color color = AppColors.textLight,
  }) {
    return TextButton(
      onPressed: () {
        if (isAdmin) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => page),
          );
        }
      },
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
        _navButton(isAdmin, context, 'Home', const LandingPage()),
        _navButton(isAdmin, context, 'Events', const EventsScreen()),
        _navButton(isAdmin, context, 'Study & Tutors', const StudyScreen()),
        if (_user == null)
          _navButton(isAdmin, context, 'Login', const AuthScreen()),
        if (isAdmin)
          _navButton(
            isAdmin,
            context,
            'Admin',
            const AdminPage(),
            color: Colors.yellow,
          ),
      ],
    );
  }

  Widget _buildMobileNav(BuildContext context) {
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
              case 'Admin':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminPage()),
                );
                break;
            }
          },
          itemBuilder:
              (context) => [
                const PopupMenuItem(value: 'Home', child: Text('Home')),
                const PopupMenuItem(value: 'Events', child: Text('Events')),
                const PopupMenuItem(
                  value: 'Study',
                  child: Text('Study & Tutors'),
                ),
                if (_user == null)
                  const PopupMenuItem(value: 'Login', child: Text('Login')),
                if (_role == 'admin')
                  const PopupMenuItem(value: 'Admin', child: Text('Admin')),
              ],
        ),
      ],
    );
  }
}
