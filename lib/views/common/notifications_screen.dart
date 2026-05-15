import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/models/notification_model.dart';
import 'package:uni_transit/widgets/custom_app_bar.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data for now, will be connected to Firestore via Provider later
    final List<SystemNotificationModel> mockNotifications = [
      SystemNotificationModel(
        id: '1',
        title: 'New Bus Schedule',
        message: 'The new schedule for Semester Spring 2024 has been uploaded. Please check the schedule tab.',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        type: NotificationType.success,
      ),
      SystemNotificationModel(
        id: '2',
        title: 'Route Delay Alert',
        message: 'Bus No. 15 on Baghdad to Abbasia route is delayed by 15 minutes due to heavy traffic at Rafi Qamar Road.',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        type: NotificationType.alert,
      ),
      SystemNotificationModel(
        id: '3',
        title: 'Support Ticket Update',
        message: 'Your query regarding bus seat availability has been resolved. Tap to view the response.',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        type: NotificationType.support,
      ),
      SystemNotificationModel(
        id: '4',
        title: 'Weather Warning',
        message: 'Expect heavy rain today. All buses will follow extra safety protocols. Expect minor delays.',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        type: NotificationType.warning,
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
          ? const Color(0xFF0F172A) 
          : const Color(0xFFF8FAFC),
      appBar: const CustomAppBar(
        title: "NOTIFICATIONS",
        showBackArrow: true,
      ),
      body: mockNotifications.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: mockNotifications.length,
              itemBuilder: (context, index) {
                return _buildNotificationCard(context, mockNotifications[index]);
              },
            ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, SystemNotificationModel notification) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100]!,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Color strip indicating type
              Container(
                width: 6,
                color: notification.color,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(notification.icon, size: 18, color: notification.color),
                              const SizedBox(width: 8),
                              Text(
                                notification.title.toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                  color: notification.color,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _getTimeAgo(notification.timestamp),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: isDark ? Colors.white54 : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        notification.message,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.5,
                          color: isDark ? Colors.white70 : Colors.blueGrey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 80,
            color: AppColors.primaryNavy.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            "All Caught Up!",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You have no new notifications.",
            style: GoogleFonts.inter(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 60) {
      return "${difference.inMinutes}m ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours}h ago";
    } else {
      return "${difference.inDays}d ago";
    }
  }
}
