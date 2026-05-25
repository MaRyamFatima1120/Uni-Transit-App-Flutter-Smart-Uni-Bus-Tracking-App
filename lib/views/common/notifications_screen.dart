import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/models/notification_model.dart';
import 'package:uni_transit/widgets/custom_app_bar.dart';
import 'package:uni_transit/views/common/sos_review_bottom_sheet.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    _markNotificationsAsRead();
  }

  Future<void> _markNotificationsAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final unreadDocs = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadDocs.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in unreadDocs.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint("Error marking notifications as read: $e");
    }
  }

  Future<void> _deleteAllNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Clear All Notifications?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to permanently delete all notifications from your history?", style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("CANCEL", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("DELETE ALL", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final docs = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .get();

        if (docs.docs.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (var doc in docs.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("All notifications cleared.")),
          );
        }
      } catch (e) {
        debugPrint("Error clearing notifications: $e");
      }
    }
  }

  void _showNotificationSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _NotificationSettingsBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
          ? const Color(0xFF0F172A) 
          : const Color(0xFFF8FAFC),
      appBar: CustomAppBar(
        title: "NOTIFICATIONS",
        showBackArrow: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: "Delete All",
            onPressed: _deleteAllNotifications,
          ),
          IconButton(
            icon: const Icon(Icons.settings_suggest_rounded),
            tooltip: "Notification Options",
            onPressed: _showNotificationSettings,
          ),
        ],
      ),
      body: user == null
          ? _buildEmptyState(context)
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('notifications')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                }
                
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return _buildEmptyState(context);
                }

                final notifications = docs
                    .map((doc) => SystemNotificationModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                    .toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    return _buildNotificationCard(context, notifications[index]);
                  },
                );
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
                      if (notification.type == NotificationType.sosResolved && notification.alertId != null) ...[
                        const SizedBox(height: 12),
                        notification.isReviewed
                            ? Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Reviewed successfully',
                                    style: GoogleFonts.poppins(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              )
                            : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) => SosReviewBottomSheet(
                                        notificationId: notification.id,
                                        alertId: notification.alertId!,
                                        alertMessage: notification.message,
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryYellow,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  icon: const Icon(Icons.rate_review_rounded, size: 16),
                                  label: Text(
                                    'Rate Emergency Assistance Service',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                      ],
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

class _NotificationSettingsBottomSheet extends StatefulWidget {
  const _NotificationSettingsBottomSheet();

  @override
  State<_NotificationSettingsBottomSheet> createState() => _NotificationSettingsBottomSheetState();
}

class _NotificationSettingsBottomSheetState extends State<_NotificationSettingsBottomSheet> {
  bool _inAppAlerts = true;
  bool _localNotifications = true;
  bool _vibrateSounds = true;
  bool _emergencyOnly = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _inAppAlerts = prefs.getBool('pref_in_app_alerts') ?? true;
      _localNotifications = prefs.getBool('pref_local_notifications') ?? true;
      _vibrateSounds = prefs.getBool('pref_vibrate_sounds') ?? true;
      _emergencyOnly = prefs.getBool('pref_emergency_only') ?? false;
      _loading = false;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: _loading 
          ? const Center(child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pull bar
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: AppColors.primaryNavy, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      "NOTIFICATION OPTIONS",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.primaryNavy,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Customize how and when you want to be notified about trips, SOS alerts, and fleet schedules.",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 16),
                _buildToggleRow(
                  title: "In-App Alerts (Snackbars)",
                  subtitle: "Show visual notifications at the bottom of the screen while using the app.",
                  icon: Icons.featured_play_list_rounded,
                  value: _inAppAlerts,
                  onChanged: (val) {
                    setState(() => _inAppAlerts = val);
                    _saveSetting('pref_in_app_alerts', val);
                  },
                ),
                const SizedBox(height: 20),
                _buildToggleRow(
                  title: "System Local Notifications",
                  subtitle: "Receive banner notifications when the app is in the background or screen is locked.",
                  icon: Icons.notifications_active_rounded,
                  value: _localNotifications,
                  onChanged: (val) {
                    setState(() => _localNotifications = val);
                    _saveSetting('pref_local_notifications', val);
                  },
                ),
                const SizedBox(height: 20),
                _buildToggleRow(
                  title: "Vibrations & Audio Alerts",
                  subtitle: "Vibrate your device and play sounds for incoming system alerts.",
                  icon: Icons.vibration_rounded,
                  value: _vibrateSounds,
                  onChanged: (val) {
                    setState(() => _vibrateSounds = val);
                    _saveSetting('pref_vibrate_sounds', val);
                  },
                ),
                const SizedBox(height: 20),
                _buildToggleRow(
                  title: "Critical & Emergency Only",
                  subtitle: "Only trigger alerts for emergency SOS and active tracking updates.",
                  icon: Icons.emergency_share_rounded,
                  value: _emergencyOnly,
                  onChanged: (val) {
                    setState(() => _emergencyOnly = val);
                    _saveSetting('pref_emergency_only', val);
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: value 
                ? AppColors.primaryNavy.withValues(alpha: 0.1) 
                : Colors.grey.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon, 
            color: value ? AppColors.primaryNavy : Colors.grey, 
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white : AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primaryNavy,
        ),
      ],
    );
  }
}
