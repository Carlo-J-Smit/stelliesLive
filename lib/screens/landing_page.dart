import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_screen.dart';
import 'events_screen.dart';
import 'study_screen.dart';
import '../widgets/nav_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    FirebaseAuth.instance.authStateChanges().listen((user) {
      setState(() {
        _user = user;
      });
    });
  }

   Future<void> preloadEvents() async {
    await FirebaseFirestore.instance
        .collection('events')
        .get(const GetOptions(source: Source.serverAndCache));
    // Optional: setState or store data in a global state provider if needed
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    // No need to call setState manually; the listener will trigger rebuild.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Navbar(),
          const SizedBox(height: 40),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'StelliesLive',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Your guide to Stellenbosch nightlife & student support.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  if (_user == null)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AuthScreen()),
                        );
                      },
                      child: const Text('Login / Register'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _logout,
                      child: const Text('Logout'),
                    ),

                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EventsScreen()),
                      );
                    },
                    child: const Text('View Events'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const StudyScreen()),
                      );
                    },
                    child: const Text('Study & Tutors'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
