import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/auth_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view notifications.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userUid', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load notifications: ${snapshot.error}'),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, _) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final title = (data['title'] ?? 'Update').toString();
              final body = (data['body'] ?? '').toString();
              final createdAt = data['createdAt'] is Timestamp
                  ? (data['createdAt'] as Timestamp).toDate()
                  : DateTime.now();
              final read = data['read'] == true;

              return ListTile(
                leading: Icon(
                  read ? Icons.notifications_none : Icons.notifications_active,
                ),
                title: Text(title),
                subtitle: Text(
                  '${DateFormat('MMM d, h:mm a').format(createdAt)}\n$body',
                ),
                isThreeLine: true,
                trailing: !read
                    ? const Icon(Icons.circle, size: 10, color: Colors.red)
                    : null,
                onTap: () {
                  docs[index].reference.update({'read': true});
                },
              );
            },
          );
        },
      ),
    );
  }
}
