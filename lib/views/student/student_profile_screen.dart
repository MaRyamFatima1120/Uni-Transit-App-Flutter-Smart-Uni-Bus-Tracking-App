import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/view_models/auth_provider.dart';
import 'package:uni_transit/core/routes/app_routes.dart';

class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key});

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

                  final name = data['name'] ?? "Welcome Student";
                  final email = user.email ?? "user@iub.edu.pk";
                  final rollNo = data['rollNo'] ?? "N/A";
                  final dept = data['department'] ?? "N/A";
                  final profileUrl = data['profileImage'] ?? data['profileImageUrl'] ?? "";

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
                              _buildSectionHeader("ACADEMIC IDENTITY"),
                              _buildInfoTile(
                                icon: Icons.school_rounded,
                                label: "University Department",
                                value: dept,
                              ),
                              _buildInfoTile(
                                icon: Icons.badge_rounded,
                                label: "Roll Number / ID",
                                value: rollNo,
                              ),
                              _buildInfoTile(
                                icon: Icons.assignment_ind_rounded,
                                label: "Registration Number",
                                value: data['regNo'] ?? "N/A",
                              ),
                              
                              const SizedBox(height: 32),
                              _buildSectionHeader("COMMUNICATION"),
                              _buildInfoTile(
                                icon: Icons.email_rounded,
                                label: "Academic Email",
                                value: email,
                              ),
                              _buildInfoTile(
                                icon: Icons.phone_android_rounded,
                                label: "Phone Number",
                                value: data['phone'] ?? "Not Provided",
                              ),

                              const SizedBox(height: 40),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryNavy,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 2,
                                    shadowColor: AppColors.primaryNavy.withValues(alpha: 0.3),
                                  ),
                                  child: Text(
                                    "RETURN TO DASHBOARD",
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
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              Text(
                "STUDENT PROFILE",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 2,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.edit_note_rounded, color: AppColors.primaryNavy, size: 24),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.completeProfile),
              ),
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
                  border: Border.all(color: AppColors.primaryNavy.withValues(alpha: 0.2), width: 2),
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.05),
                  backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                  child: profileUrl.isEmpty
                      ? const Icon(Icons.person, color: AppColors.textSecondary, size: 60) 
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
              color: AppColors.textDark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryNavy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primaryNavy.withValues(alpha: 0.15)),
            ),
            child: Text(
              "IUB ENROLLED STUDENT",
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryNavy,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryNavy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: AppColors.primaryNavy, size: 22),
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
                    color: AppColors.textSecondary, 
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
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
