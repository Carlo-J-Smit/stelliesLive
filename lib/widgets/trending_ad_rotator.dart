import 'dart:async';
import 'package:flutter/material.dart';
import 'native_ad_card.dart';

class TrendingAdRotator extends StatefulWidget {
  const TrendingAdRotator({super.key});

  @override
  State<TrendingAdRotator> createState() => _TrendingAdRotatorState();
}

class _TrendingAdRotatorState extends State<TrendingAdRotator> {
  int _currentIndex = 0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % 3;
        debugPrint('🔄 Rotating ad: Now showing index $_currentIndex');
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  List<Widget> _buildAdCards() => const [
    NativeAdCard(),
    NativeAdCard(),
    NativeAdCard(),
  ];

  @override
  Widget build(BuildContext context) {
    final ads = _buildAdCards();

    return Padding(
      padding: const EdgeInsets.symmetric( vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with text + "Sponsored" tagr
          Center(
            child: Text(
              'No events today. Check what’s trending.',//'No events today. Let’s look at what’s trending',
              textAlign: TextAlign.center, // Makes multiline look nicer
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Animated native ad
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.3, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: ads[_currentIndex],
          ),
        ],
      ),
    );
  }
}
