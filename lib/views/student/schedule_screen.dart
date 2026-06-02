import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uni_transit/models/bus_schedule.dart';
import 'package:uni_transit/services/schedule_service.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/views/student/map_screen.dart';
import 'package:uni_transit/view_models/bus_provider.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  final _scheduleService = ScheduleService();
  final _busesRef = FirebaseDatabase.instance.ref('buses');
  
  late DateTime _selectedDate;
  late DateTime _currentMonth;
  late ScrollController _calendarScrollController;
  String _selectedTypeFilter = 'All';
  String _selectedSession = 'All'; // For Morning/Afternoon/Evening dropdown
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
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
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

  String _getShift(String timeStr) {
    timeStr = timeStr.toUpperCase().trim();
    if (timeStr.contains('PM')) {
      final hourPart = timeStr.split(':')[0];
      final hour = int.tryParse(hourPart) ?? 12;
      if (hour == 12 || hour < 4) {
        return 'Afternoon';
      } else {
        return 'Evening';
      }
    } else {
      return 'Morning';
    }
  }

  @override
  void dispose() {
    _calendarScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = _generateDaysInMonth(_currentMonth);
    final genderConfigs = ref.watch(genderConfigProvider).genderConfigs;
    final List<String> genders = ["All", ...genderConfigs.keys];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Calendar Header Section
          Container(
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
                // Month Navigation
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
                
                // Horizontal scroll list of dates
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

          // Filters and Date Indicator Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_getWeekdayName(_selectedDate)}, ${_selectedDate.day} ${_getMonthName(_selectedDate).substring(0, 3)}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    // Session Dropdown
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedSession,
                          icon: const Icon(Icons.arrow_drop_down, size: 20, color: AppColors.primaryNavy),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: AppColors.primaryNavy,
                          ),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedSession = newValue;
                              });
                            }
                          },
                          items: <String>['All', 'Morning', 'Afternoon', 'Evening']
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Gender Filter Badges
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: genders.length,
                    itemBuilder: (context, index) {
                      final filter = genders[index];
                      final isSelected = _selectedTypeFilter == filter;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTypeFilter = filter;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryYellow : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? AppColors.primaryYellow : Colors.grey[300]!,
                              ),
                            ),
                            child: Text(
                              filter,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: isSelected ? AppColors.primaryNavy : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Bus Schedules List
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _busesRef.onValue,
              builder: (context, liveSnapshot) {
                Map<dynamic, dynamic> activeBuses = {};
                if (liveSnapshot.hasData && liveSnapshot.data!.snapshot.value != null) {
                  try {
                    activeBuses = liveSnapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                  } catch (_) {}
                }

                return StreamBuilder<List<BusSchedule>>(
                  stream: _scheduleService.getSchedules(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return _buildEmptyState();
                    }

                    final allSchedules = snapshot.data!;
                    final selectedDateStr = _formatDate(_selectedDate);
                    final selectedDayName = _getWeekdayName(_selectedDate);

                    final filteredSchedules = allSchedules.where((schedule) {
                      // 0. Filter out TBA placeholders
                      if (schedule.busNumber == 'TBA' || schedule.departureTime == 'TBA') {
                        return false;
                      }

                      // 1. Filter by Type (Gender)
                      if (_selectedTypeFilter != 'All') {
                        final typeLower = schedule.type.toLowerCase();
                        final filterLower = _selectedTypeFilter.toLowerCase();
                        if (!typeLower.contains(filterLower) && !filterLower.contains(typeLower)) {
                          return false;
                        }
                      }

                      // 2. Filter by Date or Days
                      if (schedule.date != null && schedule.date!.isNotEmpty) {
                        return schedule.date == selectedDateStr;
                      }
                      if (schedule.operatingDays != null && schedule.operatingDays!.isNotEmpty) {
                        return schedule.operatingDays!.contains(selectedDayName);
                      }
                      // Default Daily schedules do not run on weekends (Saturday & Sunday)
                      return selectedDayName != 'Saturday' && selectedDayName != 'Sunday';
                    }).toList();

                    if (filteredSchedules.isEmpty) {
                      return _buildEmptyState();
                    }

                    // Group schedules by Shift
                    final Map<String, List<BusSchedule>> shiftGroups = {
                      'Morning': [],
                      'Afternoon': [],
                      'Evening': [],
                    };

                    for (var schedule in filteredSchedules) {
                      final shift = _getShift(schedule.departureTime);
                      shiftGroups[shift]!.add(schedule);
                    }

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      children: [
                        if ((_selectedSession == 'All' || _selectedSession == 'Morning') && shiftGroups['Morning']!.isNotEmpty)
                          _buildMobileShiftTable(context, 'MORNING SESSION', shiftGroups['Morning']!, activeBuses),
                        if ((_selectedSession == 'All' || _selectedSession == 'Afternoon') && shiftGroups['Afternoon']!.isNotEmpty)
                          _buildMobileShiftTable(context, 'AFTERNOON SESSION', shiftGroups['Afternoon']!, activeBuses),
                        if ((_selectedSession == 'All' || _selectedSession == 'Evening') && shiftGroups['Evening']!.isNotEmpty)
                          _buildMobileShiftTable(context, 'EVENING SESSION', shiftGroups['Evening']!, activeBuses),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileShiftTable(
    BuildContext context,
    String title,
    List<BusSchedule> schedules,
    Map<dynamic, dynamic> activeBuses,
  ) {
    schedules.sort((a, b) => a.departureTime.compareTo(b.departureTime));

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[150] ?? const Color(0xFFF3F4F6)),
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
          // Header Bar for Shift
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryNavy.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  title.contains('MORNING')
                      ? Icons.light_mode_rounded
                      : (title.contains('AFTERNOON') ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded),
                  color: AppColors.primaryNavy,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: AppColors.primaryNavy,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Custom Table Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('TIME', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey[400])),
                ),
                Expanded(
                  flex: 5,
                  child: Text('ROUTE', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey[400])),
                ),
                Expanded(
                  flex: 4,
                  child: Text('BUS IDS', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey[400])),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text('LIVE', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey[400])),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),

          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: schedules.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.borderLight),
            itemBuilder: (context, index) {
              final schedule = schedules[index];

              // Check if any bus in this schedule is live
              String? liveBusId;
              List<String> scheduledBuses = schedule.busNumber
                  .split(RegExp(r'[-, ]+'))
                  .where((s) => s.isNotEmpty)
                  .toList();

              for (var bus in scheduledBuses) {
                if (activeBuses.containsKey(bus)) {
                  liveBusId = bus;
                  break;
                }
              }
              final isLive = liveBusId != null;

              Color typeColor = AppColors.primaryNavy;
              final typeLower = schedule.type.toLowerCase();
              if (typeLower.contains('girls')) {
                typeColor = AppColors.girlsSpecial;
              } else if (typeLower.contains('boys')) {
                typeColor = AppColors.boysSpecial;
              }

              return InkWell(
                onTap: isLive ? () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MapScreen()));
                } : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      // Time
                      Expanded(
                        flex: 3,
                        child: Text(
                          schedule.departureTime,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      // Route
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              schedule.route,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              schedule.type,
                              style: GoogleFonts.poppins(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: typeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Bus Numbers
                      Expanded(
                        flex: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            schedule.busNumber,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryNavy,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      // Live Action Button
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: isLive
                              ? Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent[700]!.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.gps_fixed_rounded,
                                    size: 14,
                                    color: Colors.greenAccent[700],
                                  ),
                                )
                              : Icon(
                                  Icons.gps_off_rounded,
                                  size: 14,
                                  color: Colors.grey[300],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month_outlined, size: 50, color: Colors.grey[200]),
          const SizedBox(height: 12),
          Text("No active schedules", style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    );
  }
}
