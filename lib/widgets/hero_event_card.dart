import 'package:flutter/material.dart';
import '../models/event.dart';

class HeroEventCard extends StatelessWidget {
  final Event event;

  const HeroEventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    debugPrint('BUILD: hero event card');
    final screenWidth = MediaQuery.of(context).size.width;
    final textAreaWidth = screenWidth * 0.8; // ⬅️ Slightly wider than before

    return SizedBox(
      width: double.infinity,
      child: AspectRatio(
        aspectRatio: 16 / 4,
        child: Stack(
          children: [
            // Background image with gradient overlay
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                image: event.imageUrl != null
                    ? DecorationImage(
                  image: NetworkImage(event.imageUrl!),
                  fit: BoxFit.fitWidth,
                )
                    : null,
              ),
              foregroundDecoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    Colors.black54,
                    Colors.black87,
                    Colors.black,
                  ],
                ),
              ),
            ),

            // Right-hand content
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: textAreaWidth,
                margin: const EdgeInsets.only(right: 25), // ⬅️ Shift left by 32px
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "TODAY'S HIGHLIGHT",
                      style: TextStyle(
                        color: Color.fromARGB(255, 243, 49, 49),
                        fontSize: 14,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),

                    /// Allow the title to take more space
                    Align(
                      alignment: Alignment.centerRight,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: textAreaWidth, // more space for long titles
                        ),
                        child: Text(
                          event.title,
                          textAlign: TextAlign.right,
                          softWrap: true,
                          overflow: TextOverflow.visible,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    Text(
                      '${event.venue} @ ${TimeOfDay.fromDateTime(event.dateTime).format(context)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
