import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/services/location_service.dart';
import 'package:uni_transit/services/auth_service.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final _locationService = LocationService();
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    if (user == null)
      return const Scaffold(body: Center(child: Text("Unauthorized")));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          elevation: 0,
          toolbarHeight: 70,
          backgroundColor: Colors.white,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.primaryNavy,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          title: Text(
            "Trip History",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.primaryNavy,
              letterSpacing: -0.5,
            ),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              height: 48,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9), // Subtle slate grey
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryNavy.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                labelColor: AppColors.primaryNavy,
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                unselectedLabelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: const [Tab(text: "Ongoing"), Tab(text: "Completed")],
              ),
            ),
          ),
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _locationService.getTripHistoryStream(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryNavy,
                  strokeWidth: 2,
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState();
            }

            final allTrips = snapshot.data!;
            final now = DateTime.now().millisecondsSinceEpoch;
            const threeHoursInMs = 3 * 60 * 60 * 1000;

            // Filter trips: Ongoing must be 'active' AND started within the last 3 hours
            final ongoingTrips =
                allTrips.where((t) {
                  final startTime = t['startTime'] as int? ?? 0;
                  final isRecentlyStarted = (now - startTime) < threeHoursInMs;
                  return t['status'] == 'active' && isRecentlyStarted;
                }).toList();

            // Completed includes 'completed' status OR old 'active' trips that timed out
            final completedTrips =
                allTrips.where((t) {
                  final startTime = t['startTime'] as int? ?? 0;
                  final isStale = (now - startTime) >= threeHoursInMs;
                  return t['status'] == 'completed' ||
                      (t['status'] == 'active' && isStale);
                }).toList();

            return TabBarView(
              children: [
                _buildTripList(ongoingTrips, "No active trips right now"),
                _buildTripList(completedTrips, "No completed trips yet"),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTripList(List<Map<String, dynamic>> trips, String emptyMessage) {
    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Icon(
                Icons.history_toggle_off_rounded,
                size: 48,
                color: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              emptyMessage,
              style: GoogleFonts.poppins(
                color: Colors.grey[500],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        return _buildTripCard(trip);
      },
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final startTime = trip['startTime'] as int? ?? 0;
    final date = DateTime.fromMillisecondsSinceEpoch(startTime);
    final now = DateTime.now().millisecondsSinceEpoch;
    const threeHoursInMs = 3 * 60 * 60 * 1000;

    final rawStatus = (trip['status'] as String? ?? 'active').toLowerCase();
    final isStale = (now - startTime) >= threeHoursInMs;

    Color statusColor;
    String statusText;

    // Logic: If active but > 3 hours old, show as TIMEOUT or COMPLETED
    if (rawStatus == 'active' && !isStale) {
      statusColor = Colors.green;
      statusText = "ONGOING";
    } else if (rawStatus == 'active' && isStale) {
      statusColor = AppColors.primaryYellow;
      statusText = "TIMEOUT";
    } else if (rawStatus == 'reached') {
      statusColor = AppColors.primaryYellow;
      statusText = "REACHED";
    } else {
      statusColor = AppColors.primaryNavy;
      statusText = "COMPLETED";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: statusColor.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Card Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('MMM dd, yyyy').format(date),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.poppins(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Route Info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Column(
                  children: [
                    const Icon(
                      Icons.radio_button_checked_rounded,
                      size: 16,
                      color: Colors.green,
                    ),
                    Container(
                      width: 2,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.green,
                            Colors.red.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.location_on_rounded,
                      size: 18,
                      color: Colors.red,
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "FROM",
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        trip['from'] ?? "Unknown",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "DESTINATION",
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        trip['to'] ?? "Unknown",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Card Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoPair("BUS ID", trip['busNumber'] ?? "---"),
                _buildInfoPair("PLATE", trip['plateNumber'] ?? "---"),
                _buildInfoPair("TIME", DateFormat('hh:mm a').format(date)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPair(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.grey,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: AppColors.primaryNavy,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_toggle_off_rounded,
              size: 64,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "No trips recorded yet",
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Your trip history will appear here.",
            style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }
}
