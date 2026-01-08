import 'package:flutter/material.dart';
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
    return DefaultTabController(
      length: 2, // two tabs
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Text(
              "Notifications",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "Send updates, promotions, or reminders to your users.",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),

          // Tab bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TabBar(
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).primaryColor,
              tabs: const [
                Tab(text: "Composer"),
                Tab(text: "Sent"),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Tab views
          Expanded(
            child: TabBarView(
              children: [
                // Composer tab
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: NotificationComposer(
                    businessName: businessName,
                    events: events,
                  ),
                ),

                // Sent notifications tab
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SentNotificationsList(
                    businessName: businessName,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
