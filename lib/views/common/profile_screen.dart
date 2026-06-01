import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/view_models/auth_provider.dart';
import 'package:uni_transit/core/routes/app_routes.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider);
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: user == null
            ? const Center(child: Text("Not Logged In", style: TextStyle(color: AppColors.textDark)))
            : userProfile.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy)),
                error: (err, stack) => Center(child: Text("Error: $err", style: const TextStyle(color: AppColors.error))),
                data: (data) {
                  if (data == null) return const Center(child: Text("No Profile Found", style: TextStyle(color: AppColors.textDark)));

                  final name = data['name'] ?? "Welcome User";
                  final role = data['role'] ?? "Student";
                  final email = user.email ?? "user@iub.edu.pk";
                  final rollNo = data['rollNo'] ?? "Not Found";
                  final dept = data['department'] ?? "Not Set";
                  final regNo = data['regNo'] ?? "N/A";
                  final semester = data['semester'] ?? "N/A";

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildTopBar(context),
                        _buildProfileHeader(data, name, role),
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle("ACADEMIC INFORMATION"),
                              _buildInfoTile(
                                icon: Icons.school_rounded,
                                label: "Department",
                                value: dept,
                              ),
                              _buildInfoTile(
                                icon: Icons.badge_rounded,
                                label: "Roll Number",
                                value: rollNo,
                              ),
                              _buildInfoTile(
                                icon: Icons.assignment_ind_rounded,
                                label: "Registration",
                                value: regNo,
                              ),
                              _buildInfoTile(
                                icon: Icons.layers_rounded,
                                label: "Semester",
                                value: semester,
                              ),
                              
                              const SizedBox(height: 24),
                              _buildSectionTitle("CONTACT DETAILS"),
                              _buildInfoTile(
                                icon: Icons.email_rounded,
                                label: "Email Address",
                                value: email,
                              ),
                              _buildInfoTile(
                                icon: Icons.phone_android_rounded,
                                label: "Phone Number",
                                value: data['phone'] ?? "Verification Pending",
                              ),

                              const SizedBox(height: 40),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pushReplacementNamed(
                                    context, 
                                    role == 'Driver' ? '/driver_dashboard' : '/student_dashboard'
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryNavy,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 2,
                                    shadowColor: AppColors.primaryNavy.withValues(alpha: 0.3),
                                  ),
                                  child: Text(
                                    "BACK TO DASHBOARD",
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w800, letterSpacing: 1),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 50),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            "MY PROFILE",
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: AppColors.primaryNavy, size: 28),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.completeProfile),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> data, String name, String role) {
    final profileUrl = data['profileImage'] ?? data['profileImageUrl'] ?? "";

    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primaryNavy.withValues(alpha: 0.2), width: 2),
          ),
          child: CircleAvatar(
            radius: 55,
            backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.05),
            backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
            child: profileUrl.isEmpty
                ? const Icon(Icons.person, color: AppColors.textSecondary, size: 60) 
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          name,
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryNavy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryNavy.withValues(alpha: 0.15)),
          ),
          child: Text(
            role.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryNavy,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
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
              color: AppColors.primaryNavy,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({required IconData icon, required String label, required String value}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryNavy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primaryNavy, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10, 
                    color: AppColors.textSecondary, 
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
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
