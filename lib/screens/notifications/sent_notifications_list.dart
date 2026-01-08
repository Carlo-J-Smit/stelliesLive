import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SentNotificationsList extends StatefulWidget {
  final String businessName;

  const SentNotificationsList({super.key, required this.businessName});

  @override
  State<SentNotificationsList> createState() => _SentNotificationsListState();
}

class _SentNotificationsListState extends State<SentNotificationsList> {
  String _query = '';
  final DateFormat _dateFormat = DateFormat('d MMM yyyy, HH:mm');

  Color _statusColor(String status) {
    switch (status) {
      case 'Sent':
        return Colors.green;
      case 'Pending':
        return Colors.orange;
      case 'Failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _resendNotification(Map<String, dynamic> data) async {
    try {
      // Create new notification doc
      final newDoc = {
        'business': data['business'],
        'title': data['title'],
        'message': data['message'],
        'type': data['type'] ?? 'Update',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'Pending',
      };

      await FirebaseFirestore.instance.collection('notifications').add(newDoc);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification resent successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resend: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Sent Notifications",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: "Search notifications...",
          ),
          onChanged: (v) => setState(() => _query = v.toLowerCase()),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('business', isEqualTo: widget.businessName)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!.docs
                  .map((d) {
                final data = d.data() as Map<String, dynamic>;
                data['docId'] = d.id;
                return data;
              })
                  .where((data) =>
              (data['title'] ?? '').toLowerCase().contains(_query) ||
                  (data['message'] ?? '').toLowerCase().contains(_query))
                  .toList();

              if (docs.isEmpty) {
                return const Center(child: Text("No matching notifications"));
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i];
                  final status = data['status'] ?? 'Pending';
                  final processedAt = data['processedAt'] != null
                      ? _dateFormat.format((data['processedAt'] as Timestamp).toDate())
                      : 'N/A';
                  final timestamp = data['timestamp'] != null
                      ? _dateFormat.format((data['timestamp'] as Timestamp).toDate())
                      : 'N/A';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ExpansionTile(
                      leading: const Icon(Icons.notifications),
                      title: Text(data['title'] ?? 'No title'),
                      subtitle: Text(data['type'] ?? 'Update'),
                      trailing: Text(
                        status,
                        style: TextStyle(
                          color: _statusColor(status),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Use SelectableText for full message display
                              SelectableText(
                                data['message'] ?? '',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text("Created: $timestamp",
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              Text("Status updated: $processedAt",
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.copy),
                                    label: const Text("Copy"),
                                    onPressed: () {
                                      Clipboard.setData(
                                          ClipboardData(text: data['message'] ?? ''));
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    icon: const Icon(Icons.refresh),
                                    label: const Text("Resend"),
                                    onPressed: () => _resendNotification(data),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
