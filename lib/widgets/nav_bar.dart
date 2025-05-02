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

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
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

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

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
    final isAdmin = _role == 'admin';
  print('[NAVBAR] Current role in build: $_role');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      height: 60,
      width: double.infinity,
      color: AppColors.primaryRed,
      child: Row(
        children: [
          const Text('StelliesLive',
              style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 28)),
          const Spacer(),

          TextButton(
            onPressed: () {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => const LandingPage()));
            },
            child: const Text('Home', style: TextStyle(color: AppColors.textLight)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => const EventsScreen()));
            },
            child: const Text('Events', style: TextStyle(color: AppColors.textLight)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => const StudyScreen()));
            },
            child: const Text('Study & Tutors', style: TextStyle(color: AppColors.textLight)),
          ),

          if (_user == null)
            TextButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const AuthScreen()));
              },
              child: const Text('Login', style: TextStyle(color: AppColors.textLight)),
            ),

          // ✅ Show only if user is an admin
          if (isAdmin)
            TextButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const AdminPage()));
              },
              child: const Text('Admin', style: TextStyle(color: Colors.yellow)),
            ),
        ],
      ),
    );
  }
}
