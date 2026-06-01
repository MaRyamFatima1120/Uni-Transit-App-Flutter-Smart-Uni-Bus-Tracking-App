import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uni_transit/core/constants/app_colors.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildSectionTitle("NOTIFICATIONS"),
                    _buildSettingsTile(
                      icon: Icons.notifications_active_rounded,
                      title: "Push Notifications",
                      subtitle: "Get alerts for bus arrivals and SOS",
                      trailing: Switch(
                        value: true,
                        activeColor: AppColors.primaryYellow,
                        activeTrackColor: AppColors.primaryYellow.withOpacity(0.3),
                        inactiveThumbColor: Colors.white24,
                        inactiveTrackColor: Colors.white10,
                        onChanged: (val) {},
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    _buildSectionTitle("DATA & STORAGE"),
                    _buildSettingsTile(
                      icon: Icons.cloud_done_rounded,
                      title: "Offline Maps",
                      subtitle: "Download maps for offline use",
                      onTap: () {},
                    ),
                    _buildSettingsTile(
                      icon: Icons.delete_sweep_rounded,
                      title: "Clear Cache",
                      subtitle: "Free up space on your device",
                      onTap: () {},
                    ),

                    const SizedBox(height: 32),
                    _buildSectionTitle("SECURITY"),
                    _buildSettingsTile(
                      icon: Icons.lock_outline_rounded,
                      title: "Change Password",
                      subtitle: "Update your login credentials",
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text(
            "SETTINGS",
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white.withOpacity(0.6),
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.primaryYellow,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white.withOpacity(0.4),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryYellow.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: AppColors.primaryYellow, size: 22),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 15, 
            fontWeight: FontWeight.bold, 
            color: Colors.white
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 11, 
            color: Colors.white.withOpacity(0.4)
          ),
        ),
        trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.3)),
      ),
    );
  }
}
