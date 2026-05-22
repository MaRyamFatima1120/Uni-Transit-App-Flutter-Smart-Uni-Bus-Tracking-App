import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/core/constants/app_assets.dart';
import 'package:uni_transit/core/routes/app_routes.dart';
import 'package:uni_transit/view_models/auth_provider.dart';

class UnverifiedDriverScreen extends ConsumerWidget {
  const UnverifiedDriverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to real-time updates from Firestore
    ref.listen<AsyncValue<Map<String, dynamic>?>>(driverDataStreamProvider, (previous, next) {
      if (next.hasValue) {
        if (next.value == null) {
          ref.read(authStateProvider.notifier).logout();
          Navigator.pushReplacementNamed(context, AppRoutes.login);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your account has been deleted by the administration.'), backgroundColor: Colors.red),
          );
          return;
        }

        final isVerified = next.value?['isVerified'] ?? false;
        if (isVerified) {
          // If verified by admin in real-time, automatically redirect to dashboard
          Navigator.pushReplacementNamed(context, AppRoutes.driverDashboard);
        }
      }
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  size: 100,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "Account Not Verified",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Your driver account is currently under review or has not been verified yet.\n\nPlease contact the Support Admin to verify your account and gain access to the dashboard.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to support or show contact info
                    Navigator.pushNamed(context, AppRoutes.support);
                  },
                  icon: const Icon(Icons.support_agent),
                  label: const Text(
                    "Contact Support",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryYellow,
                    foregroundColor: AppColors.primaryNavy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
                  onPressed: () async {
                    await ref.read(authStateProvider.notifier).logout();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, AppRoutes.login);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryNavy,
                    side: const BorderSide(color: AppColors.primaryNavy),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    "Logout",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
