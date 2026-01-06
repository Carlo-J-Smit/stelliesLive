import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import '../../models/event.dart';
import '../../constants/colors.dart';

class NotificationComposer extends StatefulWidget {
  final String businessName;
  final List<Event> events;

  const NotificationComposer({
    super.key,
    required this.businessName,
    required this.events,
  });

  @override
  State<NotificationComposer> createState() => _NotificationComposerState();
}

class _NotificationComposerState extends State<NotificationComposer> {
  final _title = TextEditingController();
  final _message = TextEditingController();

  Event? _event;
  String? _type;
  bool _sending = false;

  final _types = ['Update', 'Cancellation', 'Promotion', 'Reminder'];

  final _icons = {
    'Update': Icons.update,
    'Cancellation': Icons.cancel,
    'Promotion': Icons.local_offer,
    'Reminder': Icons.alarm,
  };

  bool get _canSend =>
      _title.text.isNotEmpty &&
          _message.text.isNotEmpty &&
          !_sending;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);

    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'business': widget.businessName,
        'title': _title.text,
        'message': _message.text,
        'eventId': _event?.id,
        'type': _type ?? 'General',
        'status': 'Pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Notification sent")),
      );

      _title.clear();
      _message.clear();
      setState(() {
        _event = null;
        _type = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed: $e")),
      );
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _type,
              hint: const Text("Notification type"),
              items: _types.map((t) {
                return DropdownMenuItem(
                  value: t,
                  child: Row(
                    children: [
                      Icon(_icons[t], color: AppColors.primaryRed),
                      const SizedBox(width: 8),
                      Text(t),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<Event>(
              value: _event,
              hint: const Text("Link to event (optional)"),
              items: widget.events.map((e) {
                return DropdownMenuItem(value: e, child: Text(e.title ?? "Untitled"));
              }).toList(),
              onChanged: (v) => setState(() => _event = v),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: "Title",
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _message,
              maxLines: 4,
              maxLength: 240,
              decoration: const InputDecoration(
                labelText: "Message",
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 16),

            /// Preview
            ListTile(
              leading: Icon(
                _icons[_type] ?? Icons.notifications,
                color: AppColors.primaryRed,
              ),
              title: Text(_title.text.isEmpty ? "Preview title" : _title.text),
              subtitle: Text(_message.text.isEmpty ? "Preview message" : _message.text),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              icon: _sending
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.send),
              label: const Text("Send"),
              onPressed: _canSend ? _send : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
