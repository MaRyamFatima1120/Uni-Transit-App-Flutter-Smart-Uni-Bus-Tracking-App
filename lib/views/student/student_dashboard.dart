import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/widgets/student_drawer.dart';
import 'package:uni_transit/widgets/custom_app_bar.dart';
import 'package:uni_transit/core/routes/app_routes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uni_transit/view_models/auth_provider.dart';
import 'package:uni_transit/services/notification_service.dart';
import 'package:uni_transit/views/common/sos_review_bottom_sheet.dart';

import 'map_screen.dart';
import 'schedule_screen.dart';

class StudentNavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index;
}

final studentNavIndexProvider = NotifierProvider<StudentNavIndexNotifier, int>(() {
  return StudentNavIndexNotifier();
});

class StudentDashboard extends ConsumerStatefulWidget {
  const StudentDashboard({super.key});

  @override
  ConsumerState<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends ConsumerState<StudentDashboard> {
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  final DateTime _appStartTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Mark student as Online when they open the app
    _updateStatus('Online');
    _listenForPushNotifications();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForPendingSosReviews();
    });
  }

  Future<void> _checkForPendingSosReviews() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('type', isEqualTo: 'sos_resolved')
          .get();

      final unreviewedDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        return data['isReviewed'] != true && data['alertId'] != null;
      }).toList();

      if (unreviewedDocs.isNotEmpty && mounted) {
        final doc = unreviewedDocs.first;
        final data = doc.data();
        final alertId = data['alertId'].toString();
        final message = data['message'] ?? 'SOS Alert Resolved';

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => SosReviewBottomSheet(
            notificationId: doc.id,
            alertId: alertId,
            alertMessage: message,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error checking for pending SOS reviews: $e");
    }
  }

  void _listenForPushNotifications() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _notificationSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(_appStartTime))
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>?;
          if (data != null) {
            final title = data['title'] ?? 'New Support Alert';
            final message = data['message'] ?? '';
            
            // Trigger local/push notification
            NotificationService.showLocalNotification(
              title: title,
              body: message,
            );
            
            // Show custom in-app visual snackbar
            NotificationService.show(
              title: title,
              message: message,
              type: NotificationType.info,
            );

            // Pop up review dialog directly if this is an SOS resolution alert
            if (data['type'] == 'sos_resolved' && data['alertId'] != null && data['isReviewed'] != true) {
              Future.delayed(const Duration(milliseconds: 1000), () {
                if (mounted) {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => SosReviewBottomSheet(
                      notificationId: change.doc.id,
                      alertId: data['alertId'].toString(),
                      alertMessage: message,
                    ),
                  );
                }
              });
            }
          }
        }
      }
    }, onError: (error) {
      debugPrint("Error listening for user notifications: $error");
    });
  }

  @override
  void dispose() {
    // Mark student as Offline when they leave the dashboard
    _updateStatus('Offline');
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _updateStatus(String status) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'status': status});
    } catch (_) {} // Silently ignore
  }

  @override
  Widget build(BuildContext context) {
    // Listen to real-time verification and block status
    ref.listen<AsyncValue<Map<String, dynamic>?>>(userProfileProvider, (previous, next) {
      if (next.hasValue) {
        if (next.value == null) {
          // Only treat null as "deleted" if the user is still authenticated.
          if (FirebaseAuth.instance.currentUser == null) return;
          // Account was deleted by admin
          ref.read(authStateProvider.notifier).logout();
          Navigator.pushReplacementNamed(context, AppRoutes.login);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account has been deleted by the administration.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final isBlocked = next.value?['isBlocked'] == true || next.value?['isBlocked'] == 'true';

        if (isBlocked) {
          Navigator.pushReplacementNamed(context, AppRoutes.blockedStudent);
        }
      }
    });

    final currentIndex = ref.watch(studentNavIndexProvider);
    final theme = Theme.of(context);

    // ⚡ SPEED OPT: Use IndexedStack to keep both screens alive in memory.
    // Prevents expensive map re-initialization when switching tabs.
    return Scaffold(
      extendBody: true,
      appBar: CustomAppBar(
        title: currentIndex == 0 ? "STUDENT DASHBOARD" : "SCHEDULE",
        showLogo: false,
        showBackArrow: false,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid)
                .collection('notifications')
                .where('isRead', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              final bool hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
              return IconButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
                icon: Badge(
                  isLabelVisible: hasUnread,
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.notifications_outlined),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),

      drawer: const StudentDrawer(),
      body: IndexedStack(
        index: currentIndex,
        children: const [
          MapScreen(),
          ScheduleScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: theme.brightness == Brightness.dark ? Colors.white10 : Colors.grey[100]!,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(
                context,
                index: 0,
                icon: Icons.map_rounded,
                activeIcon: Icons.map_rounded,
                label: "LIVE TRACKING",
                isActive: currentIndex == 0,
                onTap: () => ref.read(studentNavIndexProvider.notifier).setIndex(0),
              ),
              _buildNavItem(
                context,
                index: 1,
                icon: Icons.calendar_today_rounded,
                activeIcon: Icons.calendar_month_rounded,
                label: "SCHEDULE",
                isActive: currentIndex == 1,
                onTap: () => ref.read(studentNavIndexProvider.notifier).setIndex(1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutQuint,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
            ? AppColors.primaryNavy
            : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.primaryYellow : (isDark ? Colors.white54 : Colors.grey[400]),
              size: 22,
            ),
            if (isActive) ...[
              const SizedBox(width: 12),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
