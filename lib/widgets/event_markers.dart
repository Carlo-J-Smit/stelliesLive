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
    final eventRef = FirebaseFirestore.instance
        .collection('events')
        .doc(event.id);
    await eventRef.update({
      'likes': liked ? FieldValue.increment(1) : FieldValue.increment(0),
      'dislikes': liked ? FieldValue.increment(0) : FieldValue.increment(1),
    });
    debugPrint("${liked ? "Liked" : "Disliked"} event: ${event.title}");
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('BUILD: event_marker 1');
    final screenWidth = MediaQuery.of(context).size.width;
    final minCardWidth = 600.0;
    final maxCardWidth = screenWidth * 0.9;

    return AlertDialog(
      backgroundColor:
          widget.isDarkMode
              ? AppColors.textLight.withOpacity(0.6)
              : AppColors.textLight.withOpacity(0.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.all(16),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minCardWidth,
          maxWidth: max(maxCardWidth, minCardWidth),
        ),
        child: SingleChildScrollView(
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EventCard(event: widget.event),
                const SizedBox(height: 16),

                // Row: Busyness (left) and Ratings (right)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left side: Busyness
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.darkInteract.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Current Busyness:',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textLight,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children:
                                    ['Quiet', 'Moderate', 'Busy'].map((level) {
                                      Color bgColor;
                                      switch (level) {
                                        case 'Quiet':
                                          bgColor = Colors.green;
                                          break;
                                        case 'Moderate':
                                          bgColor = Colors.orange;
                                          break;
                                        case 'Busy':
                                          bgColor = Colors.red;
                                          break;
                                        default:
                                          bgColor = Colors.grey;
                                      }

                                      final isDisabled =
                                          _selectedBusyness != null;

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 12,
                                        ),
                                        child: _AnimatedFeedbackButton(
                                          label: level,
                                          color:
                                              isDisabled
                                                  ? Colors.grey
                                                  : bgColor,
                                          onTap:
                                              isDisabled
                                                  ? null
                                                  : () async {
                                                    await _submitBusynessFeedback(
                                                      widget.event,
                                                      level,
                                                    );
                                                    setState(
                                                      () =>
                                                          _selectedBusyness =
                                                              level,
                                                    );
                                                  },
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 20),

                      // Right side: Ratings
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.darkInteract.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
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
                                    count: _likes, //(_liked ? _likes + 1 : _likes),
                                    disabled: _liked || _disliked,
                                    onTap:
                                        _liked || _disliked
                                            ? null
                                            : () async {
                                              await _submitLikeDislike(
                                                widget.event,
                                                liked: true,
                                              );
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
                                        //(_disliked ? _dislikes + 1 : _dislikes),
                                    disabled: _liked || _disliked,
                                    onTap:
                                        _liked || _disliked
                                            ? null
                                            : () async {
                                              await _submitLikeDislike(
                                                widget.event,
                                                liked: false,
                                              );
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
                        ),
                      ),
                    ],
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
  State<_AnimatedFeedbackButton> createState() =>
      _AnimatedFeedbackButtonState();
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
    debugPrint('BUILD: Event marker 2');
    return GestureDetector(
      onTap:
          widget.onTap == null
              ? null
              : () {
                _animate();
                widget.onTap?.call();
              },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child:
            widget.icon != null
                ? CircleAvatar(
                  backgroundColor: widget.color,
                  child: Icon(widget.icon, color: Colors.white),
                )
                : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.color,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: widget.onTap,
                  child: Text(widget.label!),
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
    debugPrint('BUILD: event marker 3');
    final bgColor = widget.disabled ? Colors.grey : widget.color;
    return MouseRegion(
      onEnter:
          (_) => setState(() {
            _hovering = true;
            _scale = 1.05;
          }),
      onExit:
          (_) => setState(() {
            _hovering = false;
            _scale = 1.0;
          }),
      cursor:
          widget.disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap:
            widget.disabled
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
