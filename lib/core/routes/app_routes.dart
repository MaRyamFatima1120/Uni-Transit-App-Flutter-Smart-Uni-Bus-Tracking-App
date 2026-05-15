import 'package:flutter/material.dart';

// Auth & Splash
import '../../views/splash_screen.dart';
import '../../views/auth/login_screen.dart';
import '../../views/auth/signup_screen.dart';
import '../../views/auth/forgot_password_screen.dart';

// Common
import '../../views/common/complete_profile_screen.dart';
import '../../views/onboarding_screen.dart';
import '../../views/common/profile_screen.dart';
import '../../views/common/settings_screen.dart';
import '../../views/common/about_screen.dart';
import '../../views/common/help_support_screen.dart';
import '../../views/student/student_profile_screen.dart';
import '../../views/driver/driver_profile_screen.dart';

// Dashboards & Tracking
import '../../views/driver/driver_dashboard.dart';
import '../../views/student/student_dashboard.dart';
import '../../views/admin/admin_dashboard.dart';
import '../../views/live_tracking_screen.dart';
import '../../views/add_schedule_screen.dart';
import '../../views/driver/trip_history_screen.dart';
import '../../views/common/notifications_screen.dart';


class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot_password';
  static const String completeProfile = '/complete_profile';
  static const String profile = '/profile';
  static const String studentProfile = '/student_profile';
  static const String driverProfile = '/driver_profile';
  static const String settings = '/settings';
  static const String tracking = '/tracking';
  static const String driverDashboard = '/driver_dashboard';
  static const String studentDashboard = '/student_dashboard';
  static const String adminDashboard = '/admin_dashboard';
  static const String addSchedule = '/add_schedule';
  static const String tripHistory = '/trip_history';
  static const String support = '/support';
  static const String about = '/about';
  static const String notifications = '/notifications';


  static Map<String, WidgetBuilder> getRoutes() {
    return {
      splash: (context) => const SplashScreen(),
      onboarding: (context) => const OnboardingScreen(),
      login: (context) => const LoginScreen(),
      signup: (context) => const SignUpScreen(),
      forgotPassword: (context) => const ForgotPasswordScreen(),
      completeProfile: (context) => const CompleteProfileScreen(),
      profile: (context) => const ProfileScreen(),
      studentProfile: (context) => const StudentProfileScreen(),
      driverProfile: (context) => const DriverProfileScreen(),
      settings: (context) => const SettingsScreen(),
      tracking: (context) => const LiveTrackingScreen(),
      driverDashboard: (context) => const DriverDashboard(),
      studentDashboard: (context) => const StudentDashboard(),
      adminDashboard: (context) => const AdminDashboard(),
      addSchedule: (context) => const AddScheduleScreen(),
      tripHistory: (context) => const TripHistoryScreen(),
      support: (context) => const HelpSupportScreen(),
      about: (context) => const AboutScreen(),
      notifications: (context) => const NotificationsScreen(),

    };
  }
}
