import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// Predetermined templates for each type
  final Map<String, String> _templates = {
    'Update': "There is an update for <event> on <date>. Please check details.",
    'Cancellation': "The event <event> scheduled on <date> has been cancelled.",
    'Promotion': "Special promotion for <event> happening on <date>! Don't miss out.",
    'Reminder': "Reminder: <event> is coming up on <date>. Stay tuned!",
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

  /// Autofill title and message when type or event changes
  void _applyTemplate() {
    if (_type == null) return;

    String eventTitle = _event?.title ?? "<event>";
    String template = _templates[_type!] ?? "";

    _title.text = _type!; // simple default title is type
    _message.text = template.replaceAll("<event>", eventTitle);
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // Notification type
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
                      onChanged: (v) {
                        setState(() {
                          _type = v;
                          _applyTemplate();
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Event selector (purely template helper)
                    DropdownButtonFormField<Event>(
                      value: _event,
                      hint: const Text("Autofill from event (optional)"),
                      items: widget.events.map((e) {
                        return DropdownMenuItem(
                          value: e,
                          child: Text(e.title ?? "Untitled"),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setState(() {
                          _event = v;
                          _applyTemplate();
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Title
                    TextField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: "Title",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),

                    // Message
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
                      title: Text(
                          _title.text.isEmpty ? "Preview title" : _title.text),
                      subtitle: Text(
                          _message.text.isEmpty ? "Preview message" : _message
                              .text),
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
            ),
          );
        },
      ),
    );
  }
}

