import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/core/constants/app_assets.dart';
import 'package:uni_transit/view_models/auth_provider.dart';
import 'package:uni_transit/view_models/driver_trip_provider.dart';
import 'package:uni_transit/views/driver/trip_history_screen.dart';
import 'package:uni_transit/views/driver/assigned_routes_screen.dart';


class DriverDrawer extends ConsumerStatefulWidget {
  const DriverDrawer({super.key});

  @override
  ConsumerState<DriverDrawer> createState() => _DriverDrawerState();
}

class _DriverDrawerState extends ConsumerState<DriverDrawer> {
  void _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Logout", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to end your session?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel", style: TextStyle(color: Colors.grey[600]))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Logout", style: TextStyle(color: AppColors.error))),
        ],
      ),
    );

    if (confirmed == true) {
      ref.invalidate(driverTripProvider);
      ref.read(authStateProvider.notifier).logout();
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  void _navigateTopLevel(String routeName) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute != routeName) {
      Navigator.pop(context); // Always close drawer first for smooth back transition
      Navigator.pushNamed(context, routeName);
    } else {
      Navigator.pop(context); // Just close drawer if already on that screen
    }
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProfile = ref.watch(driverDataStreamProvider);

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Column(children: [
        userProfile.when(
          data: (driverData) => _buildHeader(driverData), 
          loading: () => _buildHeader(null, isLoading: true), 
          error: (err, stack) => _buildHeader(null)
        ),
        Expanded(child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16), 
          children: [
            const SizedBox(height: 20),
            _buildSectionTitle("DRIVER PANEL"),
            _DrawerTile(icon: Icons.dashboard_rounded, title: "Trip Dashboard", onTap: () {
              Navigator.pop(context); // Close the drawer
              
              final currentRoute = ModalRoute.of(context)?.settings.name;
              if (currentRoute == '/driver_dashboard') {
                return; // Already on dashboard, do nothing
              }

              bool hasDashboard = false;
              Navigator.popUntil(context, (route) {
                if (route.settings.name == '/driver_dashboard') {
                  hasDashboard = true;
                  return true;
                }
                return route.isFirst;
              });

              if (!hasDashboard) {
                Navigator.pushNamedAndRemoveUntil(context, '/driver_dashboard', (r) => false);
              }
            }),
            _DrawerTile(icon: Icons.history_rounded, title: "My Trip History", onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TripHistoryScreen()));
            }),
            _DrawerTile(icon: Icons.route_rounded, title: "Assigned Routes", onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AssignedRoutesScreen()));
            }),

            
            const SizedBox(height: 20),
            _buildSectionTitle("ACCOUNT"),
            _DrawerTile(icon: Icons.person_outline_rounded, title: "Driver Profile", onTap: () => _navigateTopLevel('/driver_profile')),
            
            const SizedBox(height: 20),
            _buildSectionTitle("SUPPORT"),
            _DrawerTile(icon: Icons.help_outline_rounded, title: "Support", onTap: () => _navigateTopLevel('/support')),
            _DrawerTile(icon: Icons.info_outline_rounded, title: "About App", onTap: () => _navigateTopLevel('/about')),
          ]
        )),
        _buildFooter(),
      ]),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 12), 
      child: Text(title, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 1.2))
    );
  }

  Widget _buildHeader(Map<String, dynamic>? userData, {bool isLoading = false}) {
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.value;
    String name = isLoading ? "Loading..." : (userData?['name'] ?? "Driver User");
    String email = userData?['email'] ?? currentUser?.email ?? (isLoading ? "..." : "driver.support@iub.edu.pk");
    String profileUrl = userData?['profileUrl'] ?? userData?['profileImage'] ?? userData?['profileImageUrl'] ?? "";

    return Container(
      width: double.infinity, 
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20, bottom: 20, left: 24, right: 24),
      decoration: const BoxDecoration(
        color: AppColors.primaryNavy, 
        borderRadius: BorderRadius.only(bottomRight: Radius.circular(40))
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primaryYellow, width: 2)), 
            child: CircleAvatar(
              radius: 35, 
              backgroundColor: isLoading ? Colors.white10 : AppColors.primaryYellow.withValues(alpha: 0.2),
              backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null, 
              child: profileUrl.isEmpty
                  ? isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          name.isNotEmpty ? name.trim()[0].toUpperCase() : 'D',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryYellow,
                          ),
                        )
                  : null,
            )
          ),
          if (!isLoading) Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
            decoration: BoxDecoration(color: AppColors.primaryYellow, borderRadius: BorderRadius.circular(20)), 
            child: Text("OFFICIAL DRIVER", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black))
          ),
        ]),
        const SizedBox(height: 20),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)), 
          Text(email, style: GoogleFonts.poppins(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)))
        ])
      ]),
    );
  }

  Widget _buildFooter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20), 
      decoration: BoxDecoration(border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!))),
      child: Column(children: [
        _DrawerTile(icon: Icons.logout_rounded, title: "Sign Out", iconColor: AppColors.error, textColor: AppColors.error, onTap: _logout),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ClipOval(
            child: Image.asset(AppAssets.iubLogo, height: 20, width: 20, fit: BoxFit.cover),
          ), 
          const SizedBox(width: 10), 
          Text("Driver Edition v1.2.0", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[400]))
        ]),
      ]),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  const _DrawerTile({required this.icon, required this.title, required this.onTap, this.iconColor, this.textColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(icon, color: iconColor ?? (isDark ? Colors.white.withValues(alpha: 0.7) : AppColors.primaryNavy.withValues(alpha: 0.7))),
      title: Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: textColor ?? (isDark ? Colors.white : AppColors.textDark))),
      dense: true, 
      contentPadding: const EdgeInsets.symmetric(horizontal: 12), 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
      onTap: onTap,
    );
  }
}
