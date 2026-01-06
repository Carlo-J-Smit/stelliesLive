import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import '../../models/event.dart';

class SentNotificationsList extends StatefulWidget {
  final String businessName;
  final List<Event> events;

  const SentNotificationsList({
    super.key,
    required this.businessName,
    required this.events,
  });

  @override
  State<SentNotificationsList> createState() => _SentNotificationsListState();
}

class _SentNotificationsListState extends State<SentNotificationsList> {
  String _query = '';

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

        SizedBox(
          height: 420,
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

              final docs = snap.data!.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return data['title']
                    .toString()
                    .toLowerCase()
                    .contains(_query) ||
                    data['message']
                        .toString()
                        .toLowerCase()
                        .contains(_query);
              }).toList();

              if (docs.isEmpty) {
                return const Center(child: Text("No matching notifications"));
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;

                  return Card(
                    child: ExpansionTile(
                      leading: const Icon(Icons.notifications),
                      title: Text(data['title']),
                      subtitle: Text(data['type']),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(data['message']),
                        ),
                        ButtonBar(
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.copy),
                              label: const Text("Copy"),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: data['message']),
                                );
                              },
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text("Resend"),
                              onPressed: () {
                                // reuse send logic
                              },
                            ),
                          ],
                        )
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
