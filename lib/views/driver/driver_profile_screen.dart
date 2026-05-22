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
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: user == null
            ? const Center(child: Text("Not Logged In", style: TextStyle(color: AppColors.textDark)))
            : driverProfile.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy)),
                error: (err, stack) => Center(child: Text("Error: $err", style: const TextStyle(color: Colors.red))),
                data: (data) {
                  if (data == null) return const Center(child: Text("No Profile Found", style: TextStyle(color: AppColors.textDark)));

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

                              const SizedBox(height: 32),
                              _buildSectionHeader("OFFICIAL DOCUMENTS"),
                              if (data['cnicFrontUrl'] != null || data['cnicBackUrl'] != null || data['licenseImageUrl'] != null)
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: Row(
                                    children: [
                                      if (data['cnicFrontUrl'] != null)
                                        _buildDocThumbnail(context, "CNIC Front", data['cnicFrontUrl']),
                                      if (data['cnicBackUrl'] != null)
                                        _buildDocThumbnail(context, "CNIC Back", data['cnicBackUrl']),
                                      if (data['licenseImageUrl'] != null)
                                        _buildDocThumbnail(context, "Driving License", data['licenseImageUrl']),
                                    ],
                                  ),
                                )
                              else
                                const Text("No documents uploaded.", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),

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
    );
  }

  Widget _buildCustomHeader(BuildContext context, String name, String profileUrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
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
                "DRIVER PROFILE",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
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
                decoration: BoxDecoration(
                  color: Colors.green.shade500, 
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.verified_rounded, size: 16, color: Colors.white),
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
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryNavy.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primaryNavy.withValues(alpha: 0.2)),
            ),
            child: Text(
              "OFFICIAL TRANSIT DRIVER",
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

  Widget _buildDocThumbnail(BuildContext context, String label, String url) {
    if (url.isEmpty) return const SizedBox.shrink();
    
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(10),
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 90,
              width: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: AppColors.textSecondary),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy));
                },
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
