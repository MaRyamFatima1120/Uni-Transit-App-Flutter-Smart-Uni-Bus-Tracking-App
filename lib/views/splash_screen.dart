import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/core/constants/app_assets.dart';
import 'package:uni_transit/core/util/logger.dart';
import 'package:uni_transit/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _checkLoginStatus() async {
    // ⚡ SPEED OPT: Reduced from 3.5s to 2s — animation completes at 1.5s so 2s is enough
    await Future.delayed(const Duration(milliseconds: 2000));

    final prefs = await SharedPreferences.getInstance();
    final bool onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

    if (!onboardingCompleted) {
      if (mounted) Navigator.pushReplacementNamed(context, '/onboarding');
      return;
    }

    if (!mounted) return;

    final user = _authService.currentUser;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      String? role = prefs.getString('user_role');

      if (role == null) {
        try {
          role = await _authService.getUserRole(user.uid);
          if (role != null) await prefs.setString('user_role', role);
        } catch (e) {
          AppLogger.error("Error fetching role: $e");
        }
      }

      if (mounted) {
        String routeName = '/login';
        final roleLower = role?.toLowerCase();
        if (roleLower == 'student') {
          final studentDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          bool isBlocked = false;
          if (studentDoc.exists) {
            final data = studentDoc.data();
            isBlocked = data?['isBlocked'] == true || data?['isBlocked'] == 'true';
          }
          if (isBlocked) {
            routeName = '/blocked_student';
          } else {
            routeName = '/student_dashboard';
          }
        } else if (roleLower == 'driver') {
          // Check if driver is verified and blocked
          final driverDoc = await FirebaseFirestore.instance.collection('drivers').doc(user.uid).get();
          bool isVerified = false;
          bool isBlocked = false;
          if (driverDoc.exists) {
            final data = driverDoc.data();
            isVerified = data?['isVerified'] == true || data?['isVerified'] == 'true';
            isBlocked = data?['isBlocked'] == true || data?['isBlocked'] == 'true';
          }
          if (isBlocked) {
            routeName = '/blocked_driver';
          } else if (isVerified) {
            routeName = '/driver_dashboard';
          } else {
            routeName = '/unverified_driver';
          }
        } else if (roleLower == 'admin') {
          routeName = '/admin_dashboard';
        }
        Navigator.pushReplacementNamed(context, routeName);
      }
    } else {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryNavy, 
              Color(0xFF1E293B),
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Stack(
            children: [
              Center(
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white, // Solid white so it blends with logo background
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Hero(
                            tag: 'app_logo',
                            child: Image.asset(
                              AppAssets.iubLogo, 
                              height: 130,
                              width: 130,
                              fit: BoxFit.cover, // Ensures the square image perfectly fills the circle
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        "UNITRANSIT",
                        style: GoogleFonts.poppins(
                          fontSize: 42,
                          letterSpacing: 8,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 4,
                        width: 60,
                        decoration: BoxDecoration(
                          color: AppColors.primaryYellow,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryYellow.withValues(alpha: 0.4),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white24),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      "THE ISLAMIA UNIVERSITY OF BAHAWALPUR",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        letterSpacing: 3,
                        color: Colors.white38,
                        fontWeight: FontWeight.w600,
                      ),
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
}
