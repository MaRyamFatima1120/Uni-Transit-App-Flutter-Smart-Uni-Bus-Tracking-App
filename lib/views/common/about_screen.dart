import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/core/constants/app_assets.dart';
import 'package:uni_transit/view_models/app_info_provider.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appInfoAsync = ref.watch(appInfoProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: appInfoAsync.when(
          data: (appInfo) => SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _buildTopBar(context),
                const SizedBox(height: 20),
                
                // Brand Section
                Center(
                  child: Hero(
                    tag: 'app_logo',
                    child: Container(
                      width: 130,
                      height: 130,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryNavy.withValues(alpha: 0.1),
                            blurRadius: 30,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: ClipOval(
                        child: appInfo.appLogoUrl.isNotEmpty 
                          ? Image.network(
                              appInfo.appLogoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Image.asset(AppAssets.iubLogo, fit: BoxFit.cover),
                            )
                          : Image.asset(AppAssets.iubLogo, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  (appInfo.appName ?? "UniTransit").isEmpty ? "UniTransit" : appInfo.appName, 
                  style: GoogleFonts.poppins(
                    fontSize: 32, 
                    fontWeight: FontWeight.w900, 
                    color: AppColors.textDark, 
                    letterSpacing: 2
                  )
                ),
                const SizedBox(height: 4),
                Text(
                  (appInfo.appTagline ?? "Smart University Transport System").isEmpty ? "Smart University Transport System" : appInfo.appTagline, 
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12, 
                    color: AppColors.primaryNavy, 
                    fontWeight: FontWeight.w700, 
                    letterSpacing: 1.5
                  )
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryNavy.withValues(alpha: 0.08), 
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primaryNavy.withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    appInfo.version.isEmpty ? "Version 1.2.0 (Stable)" : "Version ${appInfo.version}", 
                    style: GoogleFonts.poppins(
                      fontSize: 11, 
                      fontWeight: FontWeight.w700, 
                      color: AppColors.primaryNavy
                    )
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Project Details Section
                _buildDetailSection(
                  title: appInfo.visionHeader.isEmpty ? "PROJECT VISION" : appInfo.visionHeader.toUpperCase(),
                  content: appInfo.vision.isEmpty 
                    ? "UniTransit is a state-of-the-art solution designed for The Islamia University of Bahawalpur to digitize the bus tracking experience. It leverages real-time GPS data, Firebase synchronization, and smart routing algorithms to ensure students never miss their commute."
                    : appInfo.vision,
                ),
                
                const SizedBox(height: 24),
                
                // Contributors Section
                _buildDetailSection(
                  title: "CONTRIBUTORS",
                  isList: true,
                  items: appInfo.contributors.isEmpty ? [
                    {"role": "Lead Developer", "name": "Noor Mustafa", "subtitle": "Roll No: F22BDOCS1M01160"},
                    {"role": "Supervisor", "name": "Dr. Umar Farooq Shafi", "subtitle": "Department of CS & IT, IUB"},
                  ] : appInfo.contributors.map((c) => {
                    "role": c.role,
                    "name": c.name,
                    "subtitle": c.subtitle,
                  }).toList(),
                ),
                
                const SizedBox(height: 60),
                
                // IUB Branding
                Column(
                  children: [
                    Text(
                      appInfo.university.isEmpty ? "THE ISLAMIA UNIVERSITY OF BAHAWALPUR" : appInfo.university.toUpperCase(), 
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 10, 
                        fontWeight: FontWeight.w800, 
                        color: AppColors.textSecondary.withValues(alpha: 0.7), 
                        letterSpacing: 1.5
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy)),
          error: (err, stack) => Center(child: Text("Error loading info", style: TextStyle(color: AppColors.textDark))),
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text(
            "ABOUT APP",
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildDetailSection({required String title, String? content, bool isList = false, List<Map<String, String>>? items}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  color: AppColors.primaryNavy, 
                  letterSpacing: 1.5
                )
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!isList && content != null)
            Text(
              content, 
              textAlign: TextAlign.justify, 
              style: GoogleFonts.poppins(
                fontSize: 14, 
                height: 1.7, 
                color: AppColors.textDark
              )
            )
          else if (isList && items != null)
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['role']!, 
                    style: GoogleFonts.poppins(
                      fontSize: 10, 
                      color: AppColors.textSecondary, 
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5
                    )
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['name']!, 
                    style: GoogleFonts.poppins(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold, 
                      color: AppColors.textDark
                    )
                  ),
                  if (item['subtitle'] != null)
                    Text(
                      item['subtitle']!, 
                      style: GoogleFonts.poppins(
                        fontSize: 12, 
                        color: AppColors.textSecondary
                      )
                    ),
                ],
              ),
            )).toList(),
        ],
      ),
    );
  }
}
