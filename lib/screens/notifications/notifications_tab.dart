import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import '../../models/event.dart';
import '../notifications/notification_composer.dart';
import '../notifications/sent_notifications_list.dart';


class NotificationsTab extends StatelessWidget {
  final String businessName;
  final List<Event> events;

  const NotificationsTab({
    super.key,
    required this.businessName,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Notifications",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Send updates, promotions, or reminders to your users.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          NotificationComposer(
            businessName: businessName,
            events: events,
          ),

          const SizedBox(height: 32),

          SentNotificationsList(
            businessName: businessName,
            events: events,
          ),
        ],
      ),
    );
  }
}
