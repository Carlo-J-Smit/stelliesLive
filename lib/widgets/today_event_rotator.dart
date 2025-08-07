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
  static const int _initialPage = 10000;
  late final PageController _pageController;
  late int _currentIndex;
  Timer? _timer;

  final Duration _interval = const Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _initialPage);
    _currentIndex = _initialPage;
    _startRotating();
  }

  void _startRotating() {
    if (widget.events.length <= 1) return;
    _timer = Timer.periodic(_interval, (_) {
      if (!mounted || _pageController.positions.isEmpty) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _resetTimer();
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
    _resetTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    _startRotating();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) return const SizedBox();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 1000;
        final isSuperNarrow = constraints.maxWidth < 500;

        final double height =
        isSuperNarrow
            ? constraints.maxWidth / (16 / 8)
            : isNarrow
            ? constraints.maxWidth / (16 / 6)
            : constraints.maxWidth / (16 / 4);

        final realIndex = _currentIndex % widget.events.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, index) {
                      final actualIndex = index % widget.events.length;
                      return HeroEventCard(
                        key: ValueKey(widget.events[actualIndex].id),
                        event: widget.events[actualIndex],
                      );
                    },
                  ),

                  // ⬅️ Back button
                  if (widget.events.length > 1)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios),
                        onPressed: () => _goToPage(_currentIndex - 1),
                        color: Colors.white,
                      ),
                    ),

                  // ➡️ Forward button
                  if (widget.events.length > 1)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        onPressed: () => _goToPage(_currentIndex + 1),
                        color: Colors.white,
                      ),
                    ),

                  // 🔘 Dot indicators
                  if (widget.events.length > 1)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(widget.events.length, (i) {
                            final isActive = i == realIndex;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: isActive ? 12 : 8,
                              height: isActive ? 12 : 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isActive
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
          ],
        );
      },
    );
  }
}
