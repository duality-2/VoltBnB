import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userUid', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoading(context);
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load notifications: ${snapshot.error}',
                style: GoogleFonts.inter(color: Colors.red),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final title = (data['title'] ?? 'Update').toString();
              final body = (data['body'] ?? '').toString();
              final createdAt = data['createdAt'] is Timestamp
                  ? (data['createdAt'] as Timestamp).toDate()
                  : DateTime.now();
              final read = data['read'] == true;
              final type = (data['type'] ?? 'general').toString();

              // Determine icon and theme color based on notification type
              IconData iconData = Icons.notifications_active_rounded;
              Color themeColor = const Color(0xFF3B82F6); // Default Blue

              if (type == 'queue') {
                iconData = Icons.group_add_rounded;
                themeColor = const Color(0xFFF59E0B); // Orange
              } else if (type == 'nudge' || type == 'idle_fee') {
                iconData = Icons.warning_amber_rounded;
                themeColor = const Color(0xFFEF4444); // Red
              } else if (type == 'reroute') {
                iconData = Icons.alt_route_rounded;
                themeColor = const Color(0xFF8B5CF6); // Purple
              }

              // Fallback to standard outlined icon if read and general
              if (read && type == 'general') {
                iconData = Icons.notifications_none_rounded;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 0,
                  color: read ? Colors.white : const Color(0xFFEFF6FF), // Tinted blue for unread
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: read ? const Color(0xFFE5E7EB) : const Color(0xFFDBEAFE),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: read ? const Color(0xFFF3F4F6) : themeColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        iconData,
                        color: read ? const Color(0xFF6B7280) : Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontWeight: read ? FontWeight.w600 : FontWeight.w700,
                        color: const Color(0xFF111827),
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          body,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF4B5563),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('MMM d, h:mm a').format(createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      if (!read) {
                        docs[index].reference.update({'read': true});
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 100,
            width: double.infinity,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 48,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No notifications yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "We'll notify you about your bookings here.",
            style: GoogleFonts.inter(
              color: const Color(0xFF6B7280),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}