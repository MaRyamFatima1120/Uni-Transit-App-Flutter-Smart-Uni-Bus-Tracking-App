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
  String _selectedFilter = 'Unread'; // Default to Unread

  Future<void> _markAsRead(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(docId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint("Error marking notification as read: $e");
    }
  }

  Future<void> _deleteNotification(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(docId)
          .delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Notification deleted", style: GoogleFonts.poppins(fontSize: 12)),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.primaryNavy,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error deleting notification: $e");
    }
  }

  Future<void> _markAllAsRead() async {
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("All notifications marked as read", style: GoogleFonts.poppins(fontSize: 12)),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("No unread notifications", style: GoogleFonts.poppins(fontSize: 12)),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.primaryNavy,
            ),
          );
        }
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
        title: Text("Clear Notification History?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
        content: Text("This will permanently remove all notifications from your account. This action cannot be undone.", style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("CANCEL", style: GoogleFonts.poppins(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text("CLEAR ALL", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
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
            SnackBar(
              content: Text("Notification history cleared", style: GoogleFonts.poppins(fontSize: 12)),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.primaryNavy,
            ),
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

  void _showImageDialog(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: CustomAppBar(
        title: "NOTIFICATIONS",
        showBackArrow: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) {
              if (value == 'read') {
                _markAllAsRead();
              } else if (value == 'clear') {
                _deleteAllNotifications();
              } else if (value == 'settings') {
                _showNotificationSettings();
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: 'read',
                child: Row(
                  children: [
                    Icon(Icons.done_all_rounded, color: AppColors.primaryNavy, size: 20),
                    const SizedBox(width: 12),
                    Text('Mark all read', style: GoogleFonts.poppins(fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 12),
                    Text('Clear all history', style: GoogleFonts.poppins(fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: Colors.blueGrey, size: 20),
                    const SizedBox(width: 12),
                    Text('Alert settings', style: GoogleFonts.poppins(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: user == null
          ? _buildEmptyState(context)
          : Column(
              children: [
                _buildFilterChips(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('notifications')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryNavy)));
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text("Error: ${snapshot.error}", style: GoogleFonts.poppins(color: Colors.red)));
                      }
                      
                      final docs = snapshot.data?.docs ?? [];
                      final allNotifications = docs
                          .map((doc) => SystemNotificationModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                          .toList();

                      final notifications = allNotifications.where((n) {
                        if (_selectedFilter == 'Unread') {
                          return !n.isRead;
                        } else if (_selectedFilter == 'Alerts') {
                          return n.type == NotificationType.alert || n.type == NotificationType.warning;
                        }
                        return true; // 'All'
                      }).toList();

                      if (notifications.isEmpty) {
                        return _buildEmptyState(context);
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final item = notifications[index];
                          return Dismissible(
                            key: Key(item.id),
                            direction: DismissDirection.endToStart,
                            onDismissed: (direction) => _deleteNotification(item.id),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 28),
                            ),
                            child: _buildNotificationCard(context, item, isDark),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChips() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _buildChip('Unread', Icons.mark_email_unread_outlined),
          const SizedBox(width: 8),
          _buildChip('All', Icons.mail_outline_rounded),
          const SizedBox(width: 8),
          _buildChip('Alerts', Icons.warning_amber_rounded),
        ],
      ),
    );
  }

  Widget _buildChip(String label, IconData icon) {
    final isSelected = _selectedFilter == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = label == 'Alerts' ? Colors.redAccent : AppColors.primaryNavy;
    
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            size: 14, 
            color: isSelected 
                ? Colors.white 
                : (isDark ? Colors.white70 : Colors.blueGrey[600]),
          ),
          const SizedBox(width: 6),
          Text(
            label, 
            style: GoogleFonts.poppins(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 12,
              color: isSelected 
                  ? Colors.white 
                  : (isDark ? Colors.white70 : Colors.blueGrey[800]),
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = label;
          });
        }
      },
      selectedColor: activeColor,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected 
              ? Colors.transparent 
              : (isDark ? Colors.white10 : Colors.grey[200]!),
        ),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }



  Widget _buildNotificationCard(BuildContext context, SystemNotificationModel notification, bool isDark) {
    final accentColor = notification.color;
    final cardBgColor = notification.isRead 
        ? (isDark ? const Color(0xFF1E293B) : Colors.white)
        : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.3) : accentColor.withValues(alpha: 0.05));
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: notification.isRead ? 0.03 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: notification.isRead
              ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100]!)
              : accentColor.withValues(alpha: 0.2),
          width: notification.isRead ? 1.0 : 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _markAsRead(notification.id),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Highlight indicator bar on left
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(notification.icon, size: 18, color: accentColor),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  notification.title.toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 9,
                                    letterSpacing: 0.5,
                                    color: accentColor,
                                  ),
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
                          height: 1.45,
                          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600,
                          color: notification.isRead 
                              ? (isDark ? Colors.white70 : Colors.blueGrey[800])
                              : (isDark ? Colors.white : AppColors.primaryNavy),
                        ),
                      ),
                      if (notification.imageUrl != null && notification.imageUrl!.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => _showImageDialog(context, notification.imageUrl!, notification.title),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              constraints: const BoxConstraints(maxHeight: 180),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey[100],
                                border: Border.all(
                                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]!,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Image.network(
                                notification.imageUrl!,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    height: 120,
                                    alignment: Alignment.center,
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                                      strokeWidth: 2,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 100,
                                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.broken_image_outlined, color: isDark ? Colors.white30 : Colors.grey[400]),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Failed to load image",
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: isDark ? Colors.white30 : Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
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
                const SizedBox(width: 8),

                // Mark as Read Button & Badge Indicator
                if (!notification.isRead)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                          color: Colors.blueAccent,
                        ),
                        tooltip: "Mark Read",
                        onPressed: () => _markAsRead(notification.id),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.only(top: 8),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String subText;
    if (_selectedFilter == 'Unread') {
      subText = "You have no unread notifications.";
    } else if (_selectedFilter == 'Alerts') {
      subText = "You have no alerts at this time.";
    } else {
      subText = "Notification history is empty.";
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : AppColors.primaryNavy.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _selectedFilter == 'Alerts' ? Icons.warning_amber_rounded : Icons.notifications_none_rounded,
              size: 64,
              color: isDark ? Colors.white30 : AppColors.primaryNavy.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "All Caught Up!",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: isDark ? Colors.white70 : AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subText,
            style: GoogleFonts.inter(
              color: isDark ? Colors.white54 : Colors.grey,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) {
      return "just now";
    } else if (difference.inMinutes < 60) {
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: _loading 
          ? const Center(child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryNavy)),
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
                      "OPTIONS & ALERTS",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.primaryNavy,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  "Customize how and when you want to be notified about trips, SOS alerts, and fleet schedules.",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 20),
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
