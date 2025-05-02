import 'dart:async';
import 'package:flutter/material.dart';
import 'package:stellieslive/constants/colors.dart';
import '../models/event.dart';
import 'hero_event_card.dart';

class TodayEventRotator extends StatefulWidget {
  final List<Event> events;

  const TodayEventRotator({super.key, required this.events});

  @override
  State<TodayEventRotator> createState() => _TodayEventRotatorState();
}

class _TodayEventRotatorState extends State<TodayEventRotator> {
  int _currentIndex = 0;
  Timer? _timer;
  final Duration _interval = const Duration(seconds: 5);
  final Duration _fadeDuration = const Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _startRotating();
  }

  void _startRotating() {
    _timer = Timer.periodic(_interval, (_) => _nextEvent());
  }

  void _nextEvent() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.events.length;
    });
  }

  void _previousEvent() {
    setState(() {
      _currentIndex =
          (_currentIndex - 1 + widget.events.length) % widget.events.length;
    });
    _resetTimer();
  }

  void _manualNextEvent() {
    _nextEvent();
    _resetTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    _startRotating();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) {
      return const SizedBox(); // ✅ Don't build anything if list is empty
    }

    final currentEvent =
        widget.events[_currentIndex.clamp(0, widget.events.length - 1)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔁 Rotating hero card + arrows + dots all inside a Stack
        AspectRatio(
          aspectRatio: 16 / 4, // adjust this for banner height
          child: AnimatedSwitcher(
            duration: _fadeDuration,
            child: Stack(
              key: ValueKey(currentEvent),
              children: [
                // 🎞 Hero Event Card
                HeroEventCard(event: currentEvent),

                // ⬅️ Back Arrow
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    onPressed: _previousEvent,
                    color: Colors.white,
                  ),
                ),

                // ➡️ Forward Arrow
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    onPressed: _manualNextEvent,
                    color: Colors.white,
                  ),
                ),

                // 🟣 Dot indicators at the bottom center
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(widget.events.length, (index) {
                        final isActive = index == _currentIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: isActive ? 12 : 8,
                          height: isActive ? 12 : 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                isActive
                                    ? const Color(0xFF4B0B0B)
                                    : Colors.grey[400],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // // 🟣 Dot indicators
  // Center(
  //   child: Row(
  //     mainAxisSize: MainAxisSize.min,
  //     children: List.generate(widget.events.length, (index) {
  //       final isActive = index == _currentIndex;
  //       return AnimatedContainer(
  //         duration: const Duration(milliseconds: 300),
  //         margin: const EdgeInsets.symmetric(horizontal: 4),
  //         width: isActive ? 12 : 8,
  //         height: isActive ? 12 : 8,
  //         decoration: BoxDecoration(
  //           shape: BoxShape.circle,
  //           color: isActive ? const Color(0xFF4B0B0B) : Colors.grey[400],
  //         ),
  //       );
  //     }),
  //   ),
  // ),
}
