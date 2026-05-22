import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:uni_transit/core/constants/app_assets.dart';
import 'package:uni_transit/core/constants/app_colors.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../view_models/auth_provider.dart';
import '../../core/routes/app_routes.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty) {
      _showError("Email address is compulsory");
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showError("Please enter a valid email address");
      return;
    }
    if (password.isEmpty) {
      _showError("Password is compulsory");
      return;
    }

    await ref.read(authStateProvider.notifier).login(email, password);

    // Check for errors or success
    final authState = ref.read(authStateProvider);
    if (authState.hasError) {
      if (mounted) {
        _showError(authState.error.toString());
      }
    } else if (authState.hasValue && authState.value != null) {
      if (!mounted) return;

      // Show a small loading indicator while we confirm the role
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primaryYellow)),
      );

      final prefs = await SharedPreferences.getInstance();
      String? role = prefs.getString('user_role');

      // Force fetch if missing
      if (role == null) {
        final authService = ref.read(authServiceProvider);
        role = await authService.getUserRole(authState.value!.uid);
        if (role != null) await prefs.setString('user_role', role);
      }

      if (mounted) Navigator.pop(context); // Remove loading dialog

      if (role == null) {
        _showError("Account role not found. Please contact admin.");
        return;
      }

      final roleLower = role.toLowerCase().trim();
      
      if (roleLower == 'driver') {
        // Check if driver is verified and blocked
        final driverDoc = await FirebaseFirestore.instance.collection('drivers').doc(authState.value!.uid).get();
        bool isVerified = false;
        bool isBlocked = false;
        if (driverDoc.exists) {
          final data = driverDoc.data();
          isVerified = data?['isVerified'] == true || data?['isVerified'] == 'true';
          isBlocked = data?['isBlocked'] == true || data?['isBlocked'] == 'true';
        }
        
        if (isBlocked) {
          Navigator.pushReplacementNamed(context, AppRoutes.blockedDriver);
        } else if (isVerified) {
          Navigator.pushReplacementNamed(context, AppRoutes.driverDashboard);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.unverifiedDriver);
        }
      } else if (roleLower == 'admin') {
        Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
      } else if (roleLower == 'student') {
        final studentDoc = await FirebaseFirestore.instance.collection('users').doc(authState.value!.uid).get();
        bool isBlocked = false;
        if (studentDoc.exists) {
          final data = studentDoc.data();
          isBlocked = data?['isBlocked'] == true || data?['isBlocked'] == 'true';
        }
        if (isBlocked) {
          Navigator.pushReplacementNamed(context, AppRoutes.blockedStudent);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.studentDashboard);
        }
      } else {
        _showError("Unknown role: $role. Redirecting to student dashboard.");
        final studentDoc = await FirebaseFirestore.instance.collection('users').doc(authState.value!.uid).get();
        bool isBlocked = false;
        if (studentDoc.exists) {
          final data = studentDoc.data();
          isBlocked = data?['isBlocked'] == true || data?['isBlocked'] == 'true';
        }
        if (isBlocked) {
          Navigator.pushReplacementNamed(context, AppRoutes.blockedStudent);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.studentDashboard);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primaryNavy, Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 450,
                ), // Responsive Constraint
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Hero(
                        tag: 'app_logo',
                        child: Image.asset(AppAssets.iubLogo, height: 100),
                      ),
                    ),
                    Text(
                      "Welcome Back",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "Login to your account",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 40),

                    _buildTextField(
                      controller: _emailController,
                      label: "Email Address",
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),

                    // Password Field
                    _buildTextField(
                      controller: _passwordController,
                      label: "Password",
                      icon: Icons.lock_outline,
                      isPassword: true,
                      obscureText: _obscurePassword,
                      togglePassword:
                          () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.forgotPassword,
                          );
                        },
                        child: Text(
                          "Forgot Password?",
                          style: const TextStyle(
                            color: AppColors.primaryYellow,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Login Button
                    SizedBox(
                      height: 55,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryYellow,
                          foregroundColor: AppColors.primaryNavy,
                          elevation: 4,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                "LOGIN",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(color: Colors.white70),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/signup');
                          },
                          child: const Text(
                            "SIGN UP",
                            style: TextStyle(
                              color: AppColors.primaryYellow,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? togglePassword,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: AppColors.primaryYellow),
        suffixIcon:
            isPassword
                ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white70,
                  ),
                  onPressed: togglePassword,
                )
                : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.primaryYellow),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
