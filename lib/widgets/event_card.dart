//event_card

import 'package:flutter/material.dart';
import 'package:stellieslive/constants/colors.dart';
import '../models/event.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:image_picker/image_picker.dart';

import 'dart:typed_data'; // for web
import 'dart:io' show File; // only for mobile

class EventCard extends StatefulWidget {
  final Event event;
  final Uint8List? pickedBytes; // optional web image
  final XFile? pickedFile;      // optional mobile image

  const EventCard({
    super.key,
    required this.event,
    this.pickedBytes,
    this.pickedFile,
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);
  }

  String _formatPrice(double price) {
    final formatter = NumberFormat.currency(symbol: 'R', decimalDigits: 0);
    return formatter.format(price);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('BUILD: Eventcard');
    final event = widget.event;

    // Determine which image to show: picked (preview) > network image
    Widget? imageWidget;
    if (widget.pickedBytes != null) {
      imageWidget = Image.memory(widget.pickedBytes!, width: 100, height: 100, fit: BoxFit.cover);
    } else if (widget.pickedFile != null) {
      imageWidget = Image.file(File(widget.pickedFile!.path), width: 100, height: 100, fit: BoxFit.cover);
    } else if (event.imageUrl != null && event.imageUrl!.isNotEmpty) {
      imageWidget = Image.network(event.imageUrl!, width: 100, height: 100, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox());
    }

    if (event.imageUrl != null) debugPrint('Loading image: ${event.imageUrl}');


    return GestureDetector(
      onTap: _toggleExpanded,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.eventCardBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow:  [BoxShadow(
            color: Colors.black.withOpacity(0.2), // shadow color
            spreadRadius: 2,
            blurRadius: 6,
            offset: Offset(0, 3), // horizontal & vertical offset
          ),],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 0, right: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (imageWidget != null) ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: imageWidget,
                      ),
                      if (imageWidget != null) const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), softWrap: false,overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            if (event.venue.isNotEmpty) Text(event.venue, style: const TextStyle(color: Colors.grey), softWrap: false,overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(
                              event.recurring == true
                                  ? '${event.dayOfWeek![0].toUpperCase()}${event.dayOfWeek!.substring(1)} @ ${TimeOfDay.fromDateTime(event.dateTime).format(context)}'
                                  : _formatDateTime(event.dateTime),
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 2),
                            if (event.price != null)
                              Text(
                                event.price! > 0 ? _formatPrice(event.price!) : 'Free',
                                style: TextStyle(
                                  color: event.price! > 0 ? Colors.red : Colors.blueGrey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey[600]),
                    ],
                  ),
                  if (_isExpanded && event.description != null && event.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(event.description!, style: const TextStyle(color: Colors.black87)),
                  ],
                  if (event.lat != null && event.lng != null)
                    TextButton.icon(
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Open in Maps'),
                      onPressed: () {
                        final uri = Uri.parse(
                          'https://www.google.com/maps/dir/?api=1&destination=${event.lat},${event.lng}',
                        );
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                    ),
                ],
              ),
            ),
            if (event.tag != null && event.tag!.isNotEmpty)
              Positioned(
                top: 0,
                right: 0,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final showText = screenWidth > 500; // arbitrary breakpoint for small screens

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _tagColor(event.tag!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_tagIcon(event.tag!), color: Colors.white, size: 14),
                          if (showText) ...[
                            const SizedBox(width: 4),
                            Text(
                              event.tag!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),

          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) => "${dt.day}/${dt.month}/${dt.year} @ ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";


  Color _tagColor(String tag) {
    switch (tag) {
      case '18+':
        return Colors.redAccent;
      case 'VIP':
        return Colors.purple;
      case 'Sold Out':
        return Colors.grey;
      case 'Free Entry':
        return Colors.green;
      case 'Popular':
        return Colors.orange;
      case 'Outdoor':
        return Colors.teal;
      case 'Limited Seats':
        return Colors.blue;
      default:
        return Colors.black;
    }
  }

  IconData _tagIcon(String tag) {
    switch (tag) {
      case '18+':
        return Icons.do_not_disturb_alt;
      case 'VIP':
        return Icons.star;
      case 'Sold Out':
        return Icons.block;
      case 'Free Entry':
        return Icons.check_circle_outline;
      case 'Popular':
        return Icons.local_fire_department;
      case 'Outdoor':
        return Icons.park;
      case 'Limited Seats':
        return Icons.event_seat;
      default:
        return Icons.label;
    }
  }

}
