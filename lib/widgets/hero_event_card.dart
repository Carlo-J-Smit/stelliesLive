import 'package:flutter/material.dart';
import 'package:stellieslive/constants/colors.dart';
import '../models/event.dart';

class HeroEventCard extends StatelessWidget {
  final Event event;

  const HeroEventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AspectRatio(
        aspectRatio: 16 / 5,
        child: Stack(
          children: [
            // Background image with gradient overlay
            Container(
              width: double.infinity,
              height: 350, // you can adjust
              decoration: BoxDecoration(
                image:
                    event.imageUrl != null
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

            // Right-hand info
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.45,
                margin: const EdgeInsets.only(right: 30),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
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
                    const SizedBox(height: 10),
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${event.venue} • ${_formatDateTime(event.dateTime)}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return "${dt.day}/${dt.month}/${dt.year} @ ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
}
