import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/core/constants/campus_locations.dart';
import 'package:uni_transit/view_models/auth_provider.dart';
import 'package:uni_transit/view_models/driver_trip_provider.dart';
import 'package:uni_transit/models/bus_schedule.dart';
import 'package:uni_transit/services/schedule_service.dart';

class AssignedRoutesScreen extends ConsumerStatefulWidget {
  const AssignedRoutesScreen({super.key});

  @override
  ConsumerState<AssignedRoutesScreen> createState() => _AssignedRoutesScreenState();
}

class _AssignedRoutesScreenState extends ConsumerState<AssignedRoutesScreen> {
  late DateTime _selectedDate;
  late DateTime _currentMonth;
  late ScrollController _calendarScrollController;

  final List<String> _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month);
    _calendarScrollController = ScrollController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDate());
  }

  @override
  void dispose() {
    _calendarScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedDate() {
    if (_calendarScrollController.hasClients) {
      final index = _selectedDate.day - 1;
      _calendarScrollController.animateTo(
        index * 62.0, // Width of date cell (54) + margin (8)
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  List<DateTime> _generateDaysInMonth(DateTime month) {
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);
    return List.generate(
      lastDayOfMonth.day,
      (index) => DateTime(month.year, month.month, index + 1),
    );
  }

  String _getMonthName(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[date.month - 1];
  }

  String _getWeekdayName(DateTime date) {
    return _weekdays[date.weekday - 1];
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + offset);
      if (_currentMonth.year == DateTime.now().year && _currentMonth.month == DateTime.now().month) {
        _selectedDate = DateTime.now();
      } else {
        _selectedDate = DateTime(_currentMonth.year, _currentMonth.month, 1);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDate());
  }

  LatLng _getCampusCoord(String campusName) {
    final nameLower = campusName.toLowerCase();
    if (nameLower.contains('baghdad')) {
      return CampusLocations.baghdadCampus;
    } else if (nameLower.contains('abbasia') || nameLower.contains('old')) {
      return CampusLocations.abbasiaCampus;
    } else if (nameLower.contains('railway')) {
      return const LatLng(29.3970, 71.6850);
    }
    return CampusLocations.baghdadCampus;
  }

  Map<String, dynamic> _parseRouteDetails(String? routeString) {
    final routeStr = routeString ?? '';
    String from = CampusLocations.abbasiaName;
    String to = CampusLocations.baghdadName;
    
    if (routeStr.contains('➔')) {
      final parts = routeStr.split('➔');
      if (parts.length >= 2) {
        from = parts[0].trim();
        to = parts[1].trim();
      }
    } else if (routeStr.contains('->')) {
      final parts = routeStr.split('->');
      if (parts.length >= 2) {
        from = parts[0].trim();
        to = parts[1].trim();
      }
    } else if (routeStr.toLowerCase().contains(' to ')) {
      final match = RegExp(r'\s+to\s+', caseSensitive: false);
      final parts = routeStr.split(match);
      if (parts.length >= 2) {
        from = parts[0].trim();
        to = parts[1].trim();
      }
    } else if (routeStr.toLowerCase().contains(' via ')) {
      final match = RegExp(r'\s+via\s+', caseSensitive: false);
      final parts = routeStr.split(match);
      if (parts.length >= 2) {
        from = parts[0].trim();
        to = "Via ${parts[1].trim()}";
      }
    }
    
    return {
      "from": from,
      "to": to,
      "fromCoord": _getCampusCoord(from),
      "toCoord": _getCampusCoord(to),
    };
  }

  @override
  Widget build(BuildContext context) {
    final days = _generateDaysInMonth(_currentMonth);
    
    try {
      final driverProfileAsync = ref.watch(driverDataStreamProvider);
      final tripState = ref.watch(driverTripProvider);

      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: driverProfileAsync.when(
          data: (driverData) {
            try {
              if (driverData == null) {
                return _buildErrorState(context, "Driver profile not found in database.");
              }

              final assignedBus = (driverData['assignedBus']?.toString() ?? '').trim();
              
              // Safe parsing for assignedRoutes list
              final rawRoutes = driverData['assignedRoutes'];
              final List<dynamic> assignedRoutesList = rawRoutes is List ? rawRoutes : [];

              if (assignedBus.isEmpty && assignedRoutesList.isEmpty) {
                return _buildErrorState(
                  context, 
                  "No Bus or Routes assigned to your profile.\nPlease contact your administrator to set up your schedule.",
                );
              }

              return StreamBuilder<List<BusSchedule>>(
                stream: ScheduleService().getSchedules(),
                builder: (context, snapshot) {
                  try {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy));
                    }

                    if (snapshot.hasError) {
                      return _buildErrorState(context, "Error fetching schedules: ${snapshot.error}");
                    }

                    final allSchedules = snapshot.data ?? [];
                    final matchingSchedules = allSchedules.where((s) {
                      if (assignedRoutesList.isNotEmpty && assignedRoutesList.contains(s.id)) {
                        return true;
                      }
                      if (assignedBus.isNotEmpty) {
                        final sBus = (s.busNumber ?? '').toLowerCase().trim();
                        final dBus = assignedBus.toLowerCase().trim();
                        if (sBus == dBus) return true;
                        final parts = sBus.split(',').map((e) => e.trim());
                        if (parts.contains(dBus)) return true;
                        if (sBus.contains(dBus) || dBus.contains(sBus)) return true;
                      }
                      return false;
                    }).toList();

                    if (matchingSchedules.isEmpty) {
                      return _buildErrorState(
                        context, 
                        "No schedules found matching your assigned Bus ($assignedBus) or Routes.",
                      );
                    }

                    final selectedDateStr = _formatDate(_selectedDate);
                    final selectedDayName = _getWeekdayName(_selectedDate);

                    final filteredSchedules = matchingSchedules.where((schedule) {
                      if (schedule.date != null && schedule.date!.isNotEmpty) {
                        return schedule.date == selectedDateStr;
                      }
                      if (schedule.operatingDays != null && schedule.operatingDays!.isNotEmpty) {
                        return schedule.operatingDays!.contains(selectedDayName);
                      }
                      // Default Daily schedules do not run on weekends
                      return selectedDayName != 'Saturday' && selectedDayName != 'Sunday';
                    }).toList();

                    final assignedRoutes = filteredSchedules.map((schedule) {
                      final parsed = _parseRouteDetails(schedule.route);
                      final type = schedule.type ?? 'Combined';
                      String mappedGender = "Combined";
                      if (type.toLowerCase().contains("girls")) {
                        mappedGender = "Girls";
                      } else if (type.toLowerCase().contains("boys")) {
                        mappedGender = "Boys";
                      }
                      return {
                        "id": schedule.id,
                        "from": parsed['from'],
                        "to": parsed['to'],
                        "fromCoord": parsed['fromCoord'],
                        "toCoord": parsed['toCoord'],
                        "time": schedule.departureTime ?? "Pending",
                        "busId": assignedBus.isNotEmpty ? assignedBus : (schedule.busNumber ?? ''),
                        "gender": mappedGender,
                        "isActive": tripState.isTripStarted && 
                                    tripState.from == parsed['from'] && 
                                    tripState.to == parsed['to'],
                        "stops": "${schedule.stops.length} Stops",
                      };
                    }).toList();

                    return CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        _buildSliverAppBar(context, assignedRoutes.length, assignedBus),
                        
                        // Date picker section
                        SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Month Navigation Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_month_rounded, color: AppColors.primaryNavy, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${_getMonthName(_currentMonth)} ${_currentMonth.year}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed: () => _changeMonth(-1),
                                          icon: const Icon(Icons.chevron_left_rounded, size: 20),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.grey[100],
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          onPressed: () => _changeMonth(1),
                                          icon: const Icon(Icons.chevron_right_rounded, size: 20),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.grey[100],
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                
                                // Horizontal calendar list
                                SizedBox(
                                  height: 72,
                                  child: ListView.builder(
                                    controller: _calendarScrollController,
                                    scrollDirection: Axis.horizontal,
                                    itemCount: days.length,
                                    itemBuilder: (context, index) {
                                      final date = days[index];
                                      final isSelected = date.year == _selectedDate.year &&
                                          date.month == _selectedDate.month &&
                                          date.day == _selectedDate.day;
                                      final isToday = date.year == DateTime.now().year &&
                                          date.month == DateTime.now().month &&
                                          date.day == DateTime.now().day;
                                      final dayOfWeek = _getWeekdayName(date).substring(0, 3);

                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedDate = date;
                                          });
                                        },
                                        child: Container(
                                          width: 54,
                                          margin: const EdgeInsets.only(right: 8),
                                          decoration: BoxDecoration(
                                            gradient: isSelected
                                                ? const LinearGradient(
                                                    colors: [AppColors.primaryNavy, Color(0xFF424F9A)],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  )
                                                : null,
                                            color: isSelected ? null : (isToday ? AppColors.primaryNavy.withValues(alpha: 0.05) : Colors.transparent),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isSelected
                                                  ? Colors.transparent
                                                  : (isToday ? AppColors.primaryNavy.withValues(alpha: 0.3) : Colors.grey[200]!),
                                              width: isToday ? 1.5 : 1,
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                dayOfWeek.toUpperCase(),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 9,
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                  color: isSelected ? Colors.white.withOpacity(0.8) : AppColors.textSecondary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                date.day.toString(),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: isSelected ? Colors.white : AppColors.textDark,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Date Text Indicator
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: Row(
                              children: [
                                Text(
                                  '${_getWeekdayName(_selectedDate)}, ${_selectedDate.day} ${_getMonthName(_selectedDate).substring(0, 3)}',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.primaryNavy,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Empty State vs Route list
                        if (assignedRoutes.isEmpty)
                          _buildSliverEmptyState()
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildProfessionalRouteCard(context, assignedRoutes[index]),
                                childCount: assignedRoutes.length,
                              ),
                            ),
                          ),
                      ],
                    );
                  } catch (e, stack) {
                    debugPrint("AssignedRoutesScreen: Error in StreamBuilder: $e\n$stack");
                    return _buildErrorState(context, "Data rendering issue: $e");
                  }
                },
              );
            } catch (e, stack) {
              debugPrint("AssignedRoutesScreen: Error processing driver profile data: $e\n$stack");
              return _buildErrorState(context, "Data process issue: $e");
            }
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy)),
          error: (e, s) => _buildErrorState(context, "Failed to load driver profile: $e"),
        ),
      );
    } catch (e, stack) {
      debugPrint("AssignedRoutesScreen: Main build error: $e\n$stack");
      return _buildErrorState(context, "Internal Layout Error: $e");
    }
  }

  Widget _buildSliverEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_month_outlined, size: 60, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                "No assigned routes for this date",
                style: GoogleFonts.poppins(
                  color: Colors.grey[500],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, int count, String busNum) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: AppColors.primaryNavy,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F172A), // Deep Slate-900
                Color(0xFF1E293B), // Slate-800
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -40,
                bottom: -40,
                child: CircleAvatar(
                  radius: 120,
                  backgroundColor: Colors.white.withOpacity(0.03),
                ),
              ),
              Positioned(
                left: -20,
                top: -20,
                child: CircleAvatar(
                  radius: 80,
                  backgroundColor: Colors.white.withOpacity(0.02),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 76, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Text(
                        "ASSIGNED WORKLOAD",
                        style: GoogleFonts.poppins(
                          color: Colors.green.shade400,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Assigned Routes",
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "$count Routes Allocated for Bus ${busNum.isNotEmpty ? busNum : 'N/A'}",
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
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

  Widget _buildErrorState(BuildContext context, String message) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "ASSIGNED ROUTES",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800, 
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFE2E8F0),
            height: 1,
          ),
        ),
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Icon(
                  Icons.route_rounded, 
                  size: 44, 
                  color: AppColors.primaryNavy.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Route Allocation Status",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13, 
                  color: Colors.grey.shade500, 
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "RETURN TO DASHBOARD",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfessionalRouteCard(BuildContext context, Map<String, dynamic> route) {
    bool isActive = route['isActive'];
    final fromCoord = route['fromCoord'] as LatLng;
    final toCoord = route['toCoord'] as LatLng;
    final center = LatLng((fromCoord.latitude + toCoord.latitude) / 2, (fromCoord.longitude + toCoord.longitude) / 2);
    final String gender = route['gender'] ?? 'Combined';

    // Premium styling parameters based on gender config
    Color accentColor;
    Color lightAccentColor;
    String genderText;
    IconData genderIcon;

    if (gender == 'Girls') {
      accentColor = const Color(0xFFEC4899); // Pink-500
      lightAccentColor = const Color(0xFFFDF2F8); // Pink-50
      genderText = 'GIRLS SPECIAL';
      genderIcon = Icons.female_rounded;
    } else if (gender == 'Boys') {
      accentColor = const Color(0xFF0284C7); // Sky-600
      lightAccentColor = const Color(0xFFF0F9FF); // Sky-50
      genderText = 'BOYS SPECIAL';
      genderIcon = Icons.male_rounded;
    } else {
      accentColor = const Color(0xFF7C3AED); // Purple-600
      lightAccentColor = const Color(0xFFF5F3FF); // Purple-50
      genderText = 'COMBINED';
      genderIcon = Icons.people_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isActive ? Colors.green.shade400 : const Color(0xFFE2E8F0),
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive 
                ? Colors.green.withOpacity(0.06) 
                : Colors.black.withOpacity(0.03),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: Stack(
          children: [
            // Left Accent Border
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 6,
              child: Container(color: accentColor),
            ),
            
            // Content Layout
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Info Row: Type tags & Live details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: lightAccentColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: accentColor.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Icon(genderIcon, size: 14, color: accentColor),
                                const SizedBox(width: 4),
                                Text(
                                  genderText,
                                  style: GoogleFonts.poppins(
                                    color: accentColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.directions_bus_rounded, size: 14, color: AppColors.primaryNavy),
                                const SizedBox(width: 4),
                                Text(
                                  route['busId'] ?? 'N/A',
                                  style: GoogleFonts.poppins(
                                    color: AppColors.primaryNavy,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (isActive) 
                        const _PulsingLiveBadge()
                      else
                        Text(
                          route['time'] ?? 'Pending',
                          style: GoogleFonts.poppins(
                            color: Colors.green.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),

                  // Hub Route Details Section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timeline Stepper (Left)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTimelineStep(
                              icon: Icons.circle,
                              iconColor: Colors.green.shade500,
                              label: "FROM",
                              hubName: route['from'] ?? 'N/A',
                              subtitle: "Departure Station",
                              isFirst: true,
                            ),
                            _buildTimelineStep(
                              icon: Icons.location_on_rounded,
                              iconColor: Colors.red.shade500,
                              label: "TO",
                              hubName: route['to'] ?? 'N/A',
                              subtitle: "Destination Campus",
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 16),

                      // Interactive Stylized Map Window (Right)
                      Container(
                        width: 100,
                        height: 110,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            ExcludeSemantics(
                              child: AbsorbPointer(
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter: center,
                                    initialZoom: 10.5,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                                      subdomains: const ['a', 'b', 'c', 'd'],
                                    ),
                                    PolylineLayer(
                                      polylines: [
                                        Polyline(
                                          points: [fromCoord, toCoord],
                                          color: accentColor.withOpacity(0.6),
                                          strokeWidth: 3,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [Colors.transparent, Colors.white.withOpacity(0.2)],
                                  stops: const [0.7, 1.0],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Bottom action buttons and stop counts
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.stop_circle_outlined, size: 16, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            route['stops'] ?? '0 Stops',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // Show SnackBar first while context is active
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Selected Route: ${route['from']} ➔ ${route['to']}"),
                              backgroundColor: AppColors.primaryNavy,
                            ),
                          );

                          // Pre-fill trip selection in driverTripProvider
                          ref.read(driverTripProvider.notifier).updateInputs(
                            from: route['from'],
                            to: route['to'],
                            bus: route['busId'],
                            gender: route['gender'],
                          );

                          // Safely synchronize navigation pop with provider updates using post frame callback
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isActive ? Colors.green.shade500 : AppColors.primaryNavy,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              isActive ? "ACTIVE NOW" : "COMMENCE",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String hubName,
    required String subtitle,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              child: Icon(icon, size: 14, color: iconColor),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade400,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hubName,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PulsingLiveBadge extends StatefulWidget {
  const _PulsingLiveBadge();

  @override
  State<_PulsingLiveBadge> createState() => _PulsingLiveBadgeState();
}

class _PulsingLiveBadgeState extends State<_PulsingLiveBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1 + (_controller.value * 0.1)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.green.withOpacity(0.3 + (_controller.value * 0.7)),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green,
                      blurRadius: 4 + (_controller.value * 6),
                      spreadRadius: _controller.value * 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                "ACTIVE",
                style: GoogleFonts.poppins(
                  color: Colors.green,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
