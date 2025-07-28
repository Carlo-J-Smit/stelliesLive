//event_card

import 'package:flutter/material.dart';
import '../models/event.dart';
import 'package:url_launcher/url_launcher.dart';

class EventCard extends StatefulWidget {
  final Event event;

  const EventCard({super.key, required this.event});

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final hasImage = event.imageUrl != null && event.imageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: _toggleExpanded,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (hasImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      event.imageUrl!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                if (hasImage) const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (event.venue.isNotEmpty)
                        Text(
                          event.venue,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        event.recurring == true
                            ? '${event.dayOfWeek![0].toUpperCase()}${event.dayOfWeek!.substring(1)} @ ${TimeOfDay.fromDateTime(event.dateTime).format(context)}'
                            : _formatDateTime(event.dateTime),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey[600],
                ),
              ],
            ),

            // 📖 Expandable content
            if (_isExpanded &&
                event.description != null &&
                event.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                event.description!,
                style: const TextStyle(color: Colors.black87),
              ),
            ],

            Text('${event.distance?.toStringAsFixed(0)} meters away'),


            TextButton.icon(
              icon: const Icon(Icons.map_outlined),
              label: const Text('Open in Maps'),
              onPressed: () {
                final lat = event.lat;
                final lng = event.lng;
                if (lat != null && lng != null) {
                  final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
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
