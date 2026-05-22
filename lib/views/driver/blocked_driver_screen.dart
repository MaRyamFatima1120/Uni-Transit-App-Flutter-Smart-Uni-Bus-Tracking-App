import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/core/routes/app_routes.dart';
import 'package:uni_transit/view_models/auth_provider.dart';

class BlockedDriverScreen extends ConsumerWidget {
  const BlockedDriverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to real-time updates from Firestore to unblock immediately
    ref.listen<AsyncValue<Map<String, dynamic>?>>(driverDataStreamProvider, (previous, next) {
      if (next.hasValue) {
        // Only treat null as "deleted" if the user is still authenticated.
        // If currentUser is null, it means they simply logged out — not deleted.
        if (next.value == null) {
          if (FirebaseAuth.instance.currentUser == null) return; // Normal logout — do nothing
          ref.read(authStateProvider.notifier).logout();
          Navigator.pushReplacementNamed(context, AppRoutes.login);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your account has been deleted by the administration.'), backgroundColor: Colors.red),
          );
          return;
        }

        final isBlocked = next.value?['isBlocked'] == true || next.value?['isBlocked'] == 'true';
        final isVerified = next.value?['isVerified'] == true || next.value?['isVerified'] == 'true';
        if (!isBlocked) {
          if (isVerified) {
            Navigator.pushReplacementNamed(context, AppRoutes.driverDashboard);
          } else {
            Navigator.pushReplacementNamed(context, AppRoutes.unverifiedDriver);
          }
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
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block_flipped,
                  size: 100,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "Account Blocked",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Your driver account has been temporarily blocked by the administration due to policy violations or security concerns.\n\nPlease contact the Support Admin for further details.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.support);
                  },
                  icon: const Icon(Icons.support_agent),
                  label: const Text(
                    "Contact Support",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
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
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
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
