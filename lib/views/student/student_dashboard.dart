import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/widgets/student_drawer.dart';
import 'package:uni_transit/widgets/custom_app_bar.dart';
import 'package:uni_transit/core/routes/app_routes.dart';

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

class StudentDashboard extends ConsumerWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          IconButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
            icon: const Icon(Icons.notifications_outlined),
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

