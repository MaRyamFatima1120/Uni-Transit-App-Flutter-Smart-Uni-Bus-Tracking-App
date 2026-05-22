import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/widgets/custom_app_bar.dart';
import 'package:uni_transit/views/add_schedule_screen.dart';
import 'package:uni_transit/core/routes/app_routes.dart';


/// Admin Dashboard providing oversight of the entire UniTransit system.
/// Shows live bus count, total users, active trips, and emergency alerts.
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "ADMIN PANEL",
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
            icon: const Icon(Icons.notifications_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "System Overview",
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Real-time monitoring of UniTransit operations",
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            // Live Stats Grid
            _buildStatsGrid(),
            const SizedBox(height: 24),

            // Active Buses Section
            Text(
              "ACTIVE BUSES",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryNavy,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            _buildActiveBusesList(),
            const SizedBox(height: 24),

            // Emergency Alerts Section
            Text(
              "RECENT EMERGENCY ALERTS",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.error,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            _buildEmergencyAlerts(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddScheduleScreen()),
        ),
        backgroundColor: AppColors.primaryYellow,
        foregroundColor: AppColors.primaryNavy,
        icon: const Icon(Icons.add_rounded),
        label: Text("Add Schedule", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('buses').onValue,
      builder: (context, busSnapshot) {
        int activeBuses = 0;
        if (busSnapshot.hasData && busSnapshot.data!.snapshot.value != null) {
          final data = busSnapshot.data!.snapshot.value as Map;
          activeBuses = data.length;
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, userSnapshot) {
            int totalUsers = 0;
            int studentCount = 0;
            int driverCount = 0;
            if (userSnapshot.hasData) {
              totalUsers = userSnapshot.data!.docs.length;
              for (var doc in userSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['role'] == 'Student') studentCount++;
                if (data['role'] == 'Driver') driverCount++;
              }
            }

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.4,
              children: [
                _StatCard(
                  icon: Icons.directions_bus_rounded,
                  label: "Live Buses",
                  value: "$activeBuses",
                  color: AppColors.liveStatus,
                ),
                _StatCard(
                  icon: Icons.people_alt_rounded,
                  label: "Total Users",
                  value: "$totalUsers",
                  color: AppColors.primaryNavy,
                ),
                _StatCard(
                  icon: Icons.school_rounded,
                  label: "Students",
                  value: "$studentCount",
                  color: AppColors.boysSpecial,
                ),
                _StatCard(
                  icon: Icons.local_shipping_rounded,
                  label: "Drivers",
                  value: "$driverCount",
                  color: AppColors.combined,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildActiveBusesList() {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('buses').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                "No buses currently active",
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
              ),
            ),
          );
        }

        final buses = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        return Column(
          children: buses.entries.map((entry) {
            final data = Map<String, dynamic>.from(entry.value as Map);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.liveStatus.withValues(alpha: 0.3)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.liveStatus.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.directions_bus_rounded, color: AppColors.liveStatus, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("BUS #${entry.key}", style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryNavy)),
                        Text("${data['from']} ➔ ${data['to']}", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
                        Text("Driver: ${data['driverName'] ?? 'Unknown'}", style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.liveStatus,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text("LIVE", style: GoogleFonts.poppins(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildEmergencyAlerts() {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('emergency_alerts').orderByChild('timestamp').limitToLast(5).onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                "No emergency alerts",
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
              ),
            ),
          );
        }

        final alerts = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        final sortedAlerts = alerts.entries.toList()
          ..sort((a, b) {
            final aTime = (a.value['timestamp'] ?? 0) as num;
            final bTime = (b.value['timestamp'] ?? 0) as num;
            return bTime.compareTo(aTime);
          });

        return Column(
          children: sortedAlerts.map((entry) {
            final data = Map<String, dynamic>.from(entry.value as Map);
            final isActive = data['status'] == 'active';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isActive ? AppColors.error.withValues(alpha: 0.05) : Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isActive ? AppColors.error.withValues(alpha: 0.3) : Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    color: isActive ? AppColors.error : Colors.grey,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['userName'] ?? "Unknown", style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(data['message'] ?? "SOS Alert", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.error : Colors.grey,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isActive ? "ACTIVE" : "RESOLVED",
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const Spacer(),
          Text(value, style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}
