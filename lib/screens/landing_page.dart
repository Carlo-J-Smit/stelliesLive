import 'package:flutter/material.dart';
import 'auth_screen.dart';
import 'events_screen.dart';
import 'study_screen.dart';
import '../widgets/nav_bar.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Navbar(), // ✅ full-width top nav bar

          const SizedBox(height: 40),

          // ✅ Page content below nav bar
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

                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AuthScreen()));
                    },
                    child: const Text('Login / Register'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const EventsScreen()));
                    },
                    child: const Text('View Events'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const StudyScreen()));
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
