import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/view_models/auth_provider.dart';
import 'package:uni_transit/core/routes/app_routes.dart';

class DriverProfileScreen extends ConsumerWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverProfile = ref.watch(driverDataStreamProvider);
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

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
          child: user == null
              ? const Center(child: Text("Not Logged In", style: TextStyle(color: Colors.white)))
              : driverProfile.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryYellow)),
                  error: (err, stack) => Center(child: Text("Error: $err", style: const TextStyle(color: Colors.white))),
                  data: (data) {
                    if (data == null) return const Center(child: Text("No Profile Found", style: TextStyle(color: Colors.white)));

                    final name = data['name'] ?? "Driver Name";
                    final email = data['email'] ?? user.email ?? "N/A";
                    final busId = data['assignedBus'] ?? "Not Assigned";
                    final cnic = data['cnic'] ?? "N/A";
                    final license = data['licenseNumber'] ?? "N/A";
                    final experience = data['experience'] ?? "N/A";
                    final profileUrl = data['profileUrl'] ?? "";

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          _buildCustomHeader(context, name, profileUrl),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader("VEHICLE & DUTY"),
                                _buildInfoTile(
                                  icon: Icons.directions_bus_rounded,
                                  label: "Assigned Bus ID",
                                  value: busId,
                                ),
                                _buildInfoTile(
                                  icon: Icons.work_history_rounded,
                                  label: "Driving Experience",
                                  value: experience,
                                ),
                                
                                const SizedBox(height: 32),
                                _buildSectionHeader("PERSONAL & LEGAL"),
                                _buildInfoTile(
                                  icon: Icons.email_rounded,
                                  label: "Official Email",
                                  value: email,
                                ),
                                _buildInfoTile(
                                  icon: Icons.phone_android_rounded,
                                  label: "Contact Number",
                                  value: data['phoneNumber'] ?? "Not Provided",
                                ),
                                _buildInfoTile(
                                  icon: Icons.badge_rounded,
                                  label: "CNIC Number",
                                  value: cnic,
                                ),
                                _buildInfoTile(
                                  icon: Icons.description_rounded,
                                  label: "License Number",
                                  value: license,
                                ),

                                const SizedBox(height: 40),
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryYellow,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      elevation: 4,
                                      shadowColor: AppColors.primaryYellow.withOpacity(0.3),
                                    ),
                                    child: Text(
                                      "RETURN TO CONSOLE",
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildCustomHeader(BuildContext context, String name, String profileUrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              Text(
                "DRIVER PROFILE",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withOpacity(0.4),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 24), // Placeholder for alignment
            ],
          ),
          const SizedBox(height: 40),
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryYellow.withOpacity(0.5), width: 2),
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white.withOpacity(0.05),
                  backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                  child: profileUrl.isEmpty
                      ? const Icon(Icons.person, color: Colors.white24, size: 60) 
                      : null,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: AppColors.primaryYellow, shape: BoxShape.circle),
                child: const Icon(Icons.verified_rounded, size: 20, color: Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryYellow.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primaryYellow.withOpacity(0.2)),
            ),
            child: Text(
              "OFFICIAL TRANSIT DRIVER",
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryYellow,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, left: 4),
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
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white.withOpacity(0.4),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({required IconData icon, required String label, required String value}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryYellow.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: AppColors.primaryYellow, size: 22),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10, 
                    color: Colors.white.withOpacity(0.3), 
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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
