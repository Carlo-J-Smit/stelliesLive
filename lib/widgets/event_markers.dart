import 'dart:math'; // for min/max
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stellieslive/models/event.dart';
import 'package:stellieslive/widgets/event_card.dart';
import 'package:stellieslive/constants/colors.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventFeedbackDialog extends StatefulWidget {
  final Event event;
  final bool isDarkMode;

  const EventFeedbackDialog({
    super.key,
    required this.event,
    required this.isDarkMode,
  });

  @override
  State<EventFeedbackDialog> createState() => _EventFeedbackDialogState();
}

class _EventFeedbackDialogState extends State<EventFeedbackDialog> {
  String? _selectedBusyness;
  bool _liked = false;
  bool _disliked = false;
  int _likes = 0;
  int _dislikes = 0;

  @override
  void initState() {
    super.initState();
    _likes = widget.event.likes ?? 0;
    _dislikes = widget.event.dislikes ?? 0;
  }

  Future<void> _submitBusynessFeedback(Event event, String level) async {
    final pos = await Geolocator.getCurrentPosition();
    await FirebaseFirestore.instance.collection('event_feedback').add({
      'eventId': event.id,
      'timestamp': Timestamp.now(),
      'busyness': level,
      'userId': FirebaseAuth.instance.currentUser?.uid,
      'lat': pos.latitude,
      'lng': pos.longitude,
    });
    debugPrint("Busyness feedback submitted: ${event.title} -> $level");
  }

  Future<void> _submitLikeDislike(Event event, {required bool liked}) async {
    final eventRef = FirebaseFirestore.instance.collection('events').doc(event.id);
    await eventRef.update({
      'likes': liked ? FieldValue.increment(1) : FieldValue.increment(0),
      'dislikes': liked ? FieldValue.increment(0) : FieldValue.increment(1),
    });
    debugPrint("${liked ? "Liked" : "Disliked"} event: ${event.title}");
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final minCardWidth = 300.0;
    final maxCardWidth = screenWidth * 0.9;
    final dialogWidth = min(screenWidth * 0.9, 600).toDouble();

    return AlertDialog(
      backgroundColor: widget.isDarkMode
          ? AppColors.textLight.withOpacity(0.6)
          : AppColors.textLight.withOpacity(0.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.all(16),
      content: SizedBox(
        width: min(MediaQuery.of(context).size.width * 0.9, 600),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: dialogWidth,
                child: EventCard(event: widget.event),
              ),
              const SizedBox(height: 16),
              // Use MediaQuery to switch layout
              Builder(builder: (context) {
                final isNarrow = MediaQuery.of(context).size.width < 700;
                if (isNarrow) {
                  return Column(
                    children: [
                      SizedBox(width: dialogWidth, child: _busynessSection()),
                      const SizedBox(height: 16),
                      SizedBox(width: dialogWidth, child: _ratingsSection()),
                    ],
                  );
                } else {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: dialogWidth/1.5, child: _busynessSection()),
                      const SizedBox(width: 20),
                      SizedBox(width: dialogWidth/3.5, child: _ratingsSection()),
                    ],
                  );
                }
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------
  // Busyness Section
  // ----------------------
  Widget _busynessSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.darkInteract.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Current Busyness:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Calm', 'Moderate', 'Busy'].map((level) {
              Color bgColor = switch (level) {
                'Calm' => Colors.green,
                'Moderate' => Colors.orange,
                'Busy' => Colors.red,
                _ => Colors.grey,
              };

              final isDisabled = _selectedBusyness != null;

              int flex = switch (level) {
                'Medium' => 3, // middle button wider
                _ => 2,        // ends slightly shorter
              };

              return Expanded(
                flex: flex,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _AnimatedFeedbackButton(
                    label: level,
                    color: isDisabled ? Colors.grey : bgColor,
                    onTap: isDisabled
                        ? null
                        : () async {
                      await _submitBusynessFeedback(widget.event, level);
                      setState(() => _selectedBusyness = level);
                    },
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }


  // ----------------------
  // Ratings Section
  // ----------------------
  Widget _ratingsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.darkInteract.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Ratings',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LikeDislikeButton(
                icon: Icons.thumb_up,
                color: Colors.green,
                count: _likes,
                disabled: _liked || _disliked,
                onTap: _liked || _disliked
                    ? null
                    : () async {
                  await _submitLikeDislike(widget.event, liked: true);
                  setState(() {
                    _liked = true;
                    _likes += 1;
                  });
                },
              ),
              const SizedBox(width: 16),
              _LikeDislikeButton(
                icon: Icons.thumb_down,
                color: Colors.red,
                count: _dislikes,
                disabled: _liked || _disliked,
                onTap: _liked || _disliked
                    ? null
                    : () async {
                  await _submitLikeDislike(widget.event, liked: false);
                  setState(() {
                    _disliked = true;
                    _dislikes += 1;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ----------------------
/// Reusable Button Widgets
/// ----------------------

class _AnimatedFeedbackButton extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final Color color;
  final VoidCallback? onTap;

  const _AnimatedFeedbackButton({
    super.key,
    this.label,
    this.icon,
    required this.color,
    this.onTap,
  });

  @override
  State<_AnimatedFeedbackButton> createState() => _AnimatedFeedbackButtonState();
}

class _AnimatedFeedbackButtonState extends State<_AnimatedFeedbackButton>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  void _animate() async {
    setState(() => _scale = 1.2);
    await Future.delayed(const Duration(milliseconds: 100));
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap == null
          ? null
          : () {
        _animate();
        widget.onTap?.call();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.icon != null
            ? CircleAvatar(
          backgroundColor: widget.color,
          child: Icon(widget.icon, color: Colors.white),
        )
            : ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            backgroundColor: widget.color,
            foregroundColor: Colors.white,
          ),
          onPressed: widget.onTap,
          child: Text(widget.label!,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.textLight,
            ),
            textAlign: TextAlign.center,
            softWrap: false,
          ),
        ),
      ),
    );
  }
}

class _LikeDislikeButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback? onTap;
  final bool disabled;

  const _LikeDislikeButton({
    super.key,
    required this.icon,
    required this.color,
    required this.count,
    this.onTap,
    this.disabled = false,
  });

  @override
  State<_LikeDislikeButton> createState() => _LikeDislikeButtonState();
}

class _LikeDislikeButtonState extends State<_LikeDislikeButton>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  bool _hovering = false;

  void _animateTap() async {
    setState(() => _scale = 1.2);
    await Future.delayed(const Duration(milliseconds: 100));
    setState(() => _scale = _hovering ? 1.05 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.disabled ? Colors.grey : widget.color;
    return MouseRegion(
      onEnter: (_) => setState(() {
        _hovering = true;
        _scale = 1.05;
      }),
      onExit: (_) => setState(() {
        _hovering = false;
        _scale = 1.0;
      }),
      cursor:
      widget.disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.disabled
            ? null
            : () {
          _animateTap();
          widget.onTap?.call();
        },
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  widget.count.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.normal,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
