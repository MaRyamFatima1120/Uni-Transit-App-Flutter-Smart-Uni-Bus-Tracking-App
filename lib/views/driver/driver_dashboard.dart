import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/core/constants/campus_locations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uni_transit/services/auth_service.dart';
import 'package:uni_transit/services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uni_transit/widgets/driver_drawer.dart';
import 'package:uni_transit/view_models/driver_trip_provider.dart';
import 'package:uni_transit/view_models/bus_provider.dart';
import 'package:uni_transit/view_models/schedule_provider.dart';
import 'package:uni_transit/core/routes/app_routes.dart';
import 'package:uni_transit/services/sos_service.dart';
import 'package:uni_transit/services/notification_service.dart';
import 'package:uni_transit/view_models/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uni_transit/views/common/sos_review_bottom_sheet.dart';
import 'package:uni_transit/views/driver/assigned_routes_screen.dart';

class DriverDashboard extends ConsumerStatefulWidget {
  const DriverDashboard({super.key});

  @override
  ConsumerState<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends ConsumerState<DriverDashboard>
    with TickerProviderStateMixin {
  final _authService = AuthService();
  final _busNumberController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final MapController _mapController = MapController();
  late AnimationController _pulseController;
  
  StreamSubscription? _locationSubscription;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  final DateTime _appStartTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Mark driver as Online
    _updateStatus('Online');
    _listenForPushNotifications();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = _authService.currentUser;
      if (user != null) {
        final tripState = ref.read(driverTripProvider);
        if (!tripState.isTripStarted && !tripState.hasRestored) {
          ref.read(driverTripProvider.notifier).restoreActiveTrip(user.uid);
        }
      }
      _initLocationTracking();
      _checkForPendingSosReviews();
    });
  }

  Future<void> _checkForPendingSosReviews() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('type', isEqualTo: 'sos_resolved')
          .get();

      final unreviewedDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        return data['isReviewed'] != true && data['alertId'] != null;
      }).toList();

      if (unreviewedDocs.isNotEmpty && mounted) {
        final doc = unreviewedDocs.first;
        final data = doc.data();
        final alertId = data['alertId'].toString();
        final message = data['message'] ?? 'SOS Alert Resolved';

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => SosReviewBottomSheet(
            notificationId: doc.id,
            alertId: alertId,
            alertMessage: message,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error checking for pending SOS reviews: $e");
    }
  }

  void _listenForPushNotifications() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _notificationSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(_appStartTime))
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>?;
          if (data != null) {
            final title = data['title'] ?? 'New Support Alert';
            final message = data['message'] ?? '';
            
            // Trigger local/push notification
            NotificationService.showLocalNotification(
              title: title,
              body: message,
            );
            
            // Show custom in-app visual snackbar
            NotificationService.show(
              title: title,
              message: message,
              type: NotificationType.info,
            );

            // Pop up review dialog directly if this is an SOS resolution alert
            if (data['type'] == 'sos_resolved' && data['alertId'] != null && data['isReviewed'] != true) {
              Future.delayed(const Duration(milliseconds: 1000), () {
                if (mounted) {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => SosReviewBottomSheet(
                      notificationId: change.doc.id,
                      alertId: data['alertId'].toString(),
                      alertMessage: message,
                    ),
                  );
                }
              });
            }
          }
        }
      }
    }, onError: (error) {
      debugPrint("Error listening for user notifications: $error");
    });
  }

  Future<void> _updateStatus(String status) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(uid)
          .update({'status': status});
    } catch (_) {}
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final latTween = Tween<double>(
      begin: _mapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _mapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: destZoom,
    );

    final controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.fastOutSlowIn,
    );

    controller.addListener(() {
      if (mounted) {
        _mapController.move(
          LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
          zoomTween.evaluate(animation),
        );
      }
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  Future<void> _initLocationTracking() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    final hasPermission = await LocationService.handleLocationPermission();
    if (!hasPermission) return;

    _locationSubscription = LocationService().locationStream.listen((pos) {
      if (mounted) {
        final newLoc = LatLng(pos.latitude, pos.longitude);
        ref.read(driverTripProvider.notifier).updateLocation(
          newLoc, 
          pos.heading,
          speed: pos.speed,
        );
      }
    });
  }

  @override
  void dispose() {
    // Mark driver as Offline when they leave the dashboard
    _updateStatus('Offline');
    _locationSubscription?.cancel();
    _notificationSubscription?.cancel();
    _pulseController.dispose();
    _busNumberController.dispose();
    _plateNumberController.dispose();
    super.dispose();
  }

  void _onToggle() async {
    final user = _authService.currentUser;
    if (user == null) return;

    final tripState = ref.read(driverTripProvider);

    // Guard: if trip not started yet, validate all fields first
    if (!tripState.isTripStarted) {
      // Update bus/plate from controllers
      ref.read(driverTripProvider.notifier).updateInputs(
        bus: _busNumberController.text.trim(),
        plate: _plateNumberController.text.trim(),
      );

      // Re-read state after updateInputs
      final updated = ref.read(driverTripProvider);

      // Check if route is selected
      if (updated.from == null || updated.to == null) {
        // Safe fallback in case they still somehow trigger this
        NotificationService.show(
          title: "No Route Selected",
          message: "Please select your assigned route first.",
          type: NotificationType.warning,
        );
        return;
      }

      // Check if bus number is present
      if (updated.busNumber.trim().isEmpty) {
        NotificationService.show(
          title: "Bus Number Missing",
          message: "Please select your assigned route first — it will auto-fill your bus number.",
          type: NotificationType.warning,
        );
        return;
      }
    }

    await ref.read(driverTripProvider.notifier).toggleTrip(user.uid, user.displayName ?? "Driver");
  }

  void _handleSOS() {
    final user = _authService.currentUser;
    if (user != null) {
      final tripState = ref.read(driverTripProvider);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return _DriverSOSOptionsBottomSheet(
            userId: user.uid,
            userName: user.displayName ?? "Driver",
            lat: tripState.currentLocation.latitude,
            lng: tripState.currentLocation.longitude,
          );
        },
      );
    }
  }
  bool _hasShownUpcomingTripPrompt = false;

  bool _isTimePassed(String timeStr) {
    if (timeStr.isEmpty || timeStr.toLowerCase() == 'pending') return false;
    final now = DateTime.now();
    try {
      int hour = 0;
      int minute = 0;

      final isPM = timeStr.toLowerCase().contains('pm');
      final isAM = timeStr.toLowerCase().contains('am');
      
      final cleanTime = timeStr.replaceAll(RegExp(r'[^0-9:]'), '');
      final parts = cleanTime.split(':');
      if (parts.length >= 2) {
        hour = int.tryParse(parts[0]) ?? 0;
        minute = int.tryParse(parts[1]) ?? 0;
        
        if (isPM && hour < 12) hour += 12;
        if (isAM && hour == 12) hour = 0;
        
        final scheduleTime = DateTime(now.year, now.month, now.day, hour, minute);
        // If it's more than 30 minutes past the scheduled departure, don't show it as upcoming
        return now.isAfter(scheduleTime.add(const Duration(minutes: 30)));
      }
    } catch (e) {
      debugPrint("Error parsing time: $e");
    }
    return false;
  }

  bool _isTripSoon(String timeStr) {
    if (timeStr.isEmpty || timeStr.toLowerCase() == 'pending') return false;
    final now = DateTime.now();
    try {
      int hour = 0;
      int minute = 0;

      final isPM = timeStr.toLowerCase().contains('pm');
      final isAM = timeStr.toLowerCase().contains('am');
      
      final cleanTime = timeStr.replaceAll(RegExp(r'[^0-9:]'), '');
      final parts = cleanTime.split(':');
      if (parts.length >= 2) {
        hour = int.tryParse(parts[0]) ?? 0;
        minute = int.tryParse(parts[1]) ?? 0;
        
        if (isPM && hour < 12) hour += 12;
        if (isAM && hour == 12) hour = 0;
        
        final scheduleTime = DateTime(now.year, now.month, now.day, hour, minute);
        final difference = scheduleTime.difference(now);
        // Alert if the trip starts within the next 60 minutes, and has not passed yet
        return difference.inMinutes >= 0 && difference.inMinutes <= 60;
      }
    } catch (e) {
      debugPrint("Error checking if trip is soon: $e");
    }
    return false;
  }

  void _checkAndShowUpcomingTripPrompt(Map<String, dynamic>? driverData, dynamic allSchedules) {
    if (driverData == null || allSchedules == null) return;
    
    // Cast appropriately since we didn't import the model explicitly everywhere
    final List<dynamic> schedules = allSchedules as List<dynamic>;
    if (schedules.isEmpty) return;

    final assignedBus = (driverData['assignedBus']?.toString() ?? '').trim();
    final rawRoutes = driverData['assignedRoutes'];
    final List<dynamic> assignedRoutesList = rawRoutes is List ? rawRoutes : [];

    if (assignedBus.isEmpty && assignedRoutesList.isEmpty) return;

    final matchingSchedules = schedules.where((s) {
      // 1. Match by Route ID or Route Name
      if (assignedRoutesList.isNotEmpty) {
        if (assignedRoutesList.contains(s.id)) return true;
        if (assignedRoutesList.any((r) => r.toString().toLowerCase().trim() == s.route.toLowerCase().trim())) {
          return true;
        }
      }

      // 2. Match by Bus Number
      if (assignedBus.isNotEmpty) {
        final sBus = s.busNumber.toLowerCase().trim();
        final dBus = assignedBus.toLowerCase().trim();
        if (sBus == dBus) return true;
        final parts = sBus.split(',').map((e) => e.trim()).toList();
        if (parts.contains(dBus)) return true;
        if (sBus.contains(dBus) || dBus.contains(sBus)) return true;
        
        final sBusNum = RegExp(r'\d+').firstMatch(sBus)?.group(0);
        final dBusNum = RegExp(r'\d+').firstMatch(dBus)?.group(0);
        if (sBusNum != null && dBusNum != null && sBusNum == dBusNum) return true;
      }
      return false;
    }).toList();

    if (matchingSchedules.isEmpty) return;

    final now = DateTime.now();
    final selectedDateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final selectedDayName = weekdays[now.weekday - 1];

    final todaySchedules = matchingSchedules.where((schedule) {
      bool isToday = false;
      if (schedule.date != null && schedule.date!.isNotEmpty) {
        isToday = schedule.date == selectedDateStr;
      } else if (schedule.operatingDays != null && schedule.operatingDays!.isNotEmpty) {
        isToday = schedule.operatingDays!.any((day) => 
          day.toLowerCase().trim() == selectedDayName.toLowerCase()
        );
      } else {
        isToday = selectedDayName != 'Saturday' && selectedDayName != 'Sunday';
      }

      if (!isToday) return false;

      // Check if time has already passed or if trip starts soon (within 60 minutes)
      final depTime = schedule.departureTime?.toString() ?? '';
      if (!_isTripSoon(depTime)) return false;

      return true;
    }).toList();

    if (todaySchedules.isEmpty) return;

    _hasShownUpcomingTripPrompt = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildUpcomingTripBottomSheet(
          context, 
          todaySchedules.first,
          assignedBus: assignedBus,  // pass driver's actual assigned bus
        ),
      );
    });
  }

  Widget _buildUpcomingTripBottomSheet(
    BuildContext context, 
    dynamic schedule, {
    String assignedBus = '',
  }) {
    String from = CampusLocations.abbasiaName;
    String to = CampusLocations.baghdadName;
    final routeStr = schedule.route ?? '';
    
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
    }

    String mappedGender = "Combined";
    final type = schedule.type.toString().toLowerCase();
    if (type.contains("girls")) {
      mappedGender = "Girls";
    } else if (type.contains("boys")) {
      mappedGender = "Boys";
    }

    // Resolve bus number: prefer driver's assigned bus over schedule's busNumber
    // Schedule busNumber can be 'TBA', empty, or incorrect
    final schedBus = schedule.busNumber?.toString().trim() ?? '';
    final resolvedBus = (assignedBus.isNotEmpty && assignedBus.toLowerCase() != 'tba')
        ? assignedBus
        : (schedBus.isNotEmpty && schedBus.toLowerCase() != 'tba' ? schedBus : 'Not Assigned');

    // Validate departure time — reject junk values like 'Live', 'Restored', etc.
    final rawTime = schedule.departureTime?.toString().trim() ?? '';
    final timeIsValid = rawTime.isNotEmpty &&
        rawTime.toLowerCase() != 'pending' &&
        rawTime.toLowerCase() != 'live' &&
        rawTime.toLowerCase() != 'restored' &&
        rawTime.toLowerCase() != 'calculating...' &&
        rawTime.toLowerCase() != 'tba';
    final displayTime = timeIsValid ? rawTime : 'Pending';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40, height: 5,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.directions_bus_rounded, size: 48, color: Colors.red),
          ),
          const SizedBox(height: 16),
          Text(
            "UPCOMING TRIP ALERT",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.red.shade700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You have an assigned route today.\nAre you ready to commence tracking?",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryNavy.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryNavy.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  icon: Icons.access_time_filled_rounded,
                  label: "Departure Time",
                  value: displayTime,
                  valueColor: displayTime == 'Pending' ? Colors.orange.shade700 : AppColors.primaryNavy,
                ),
                const Divider(height: 20),
                _buildInfoRow(
                  icon: Icons.route_rounded,
                  label: "Route",
                  value: "$from → $to",
                ),
                const Divider(height: 20),
                _buildInfoRow(
                  icon: Icons.directions_bus_rounded,
                  label: "Bus Number",
                  value: resolvedBus,
                  valueColor: resolvedBus == 'Not Assigned' ? Colors.orange.shade700 : AppColors.primaryNavy,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    "LATER",
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    // Set state BEFORE popping to avoid race condition
                    ref.read(driverTripProvider.notifier).updateInputs(
                      from: from,
                      to: to,
                      bus: resolvedBus,
                      gender: mappedGender,
                      departureTime: displayTime,
                      scheduleId: schedule.id,
                    );
                    Navigator.pop(context);
                    NotificationService.show(
                      title: "Route Selected",
                      message: "$from → $to${displayTime != 'Pending' ? ' · $displayTime' : ''}",
                      type: NotificationType.success,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    "PREPARE ROUTE",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Helper row for the upcoming trip info card
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryNavy.withValues(alpha: 0.6)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: valueColor ?? AppColors.primaryNavy,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to real-time verification and block status
    ref.listen<AsyncValue<Map<String, dynamic>?>>(driverDataStreamProvider, (previous, next) {
      if (next.hasValue) {
        if (next.value == null) {
          // Only treat null as "deleted" if the user is still authenticated.
          // If currentUser is null, it means they simply logged out — not deleted.
          if (FirebaseAuth.instance.currentUser == null) return;
          // Account was deleted by admin
          ref.read(authStateProvider.notifier).logout();
          Navigator.pushReplacementNamed(context, AppRoutes.login);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account has been deleted by the administration.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final isBlocked = next.value?['isBlocked'] == true || next.value?['isBlocked'] == 'true';
        final isVerified = next.value?['isVerified'] == true || next.value?['isVerified'] == 'true';
        
        if (isBlocked) {
          Navigator.pushReplacementNamed(context, AppRoutes.blockedDriver);
        } else if (!isVerified) {
          Navigator.pushReplacementNamed(context, AppRoutes.unverifiedDriver);
        }

        // Auto-populate assigned bus number from profile if controllers are currently empty
        final assignedBus = next.value?['assignedBus'] as String?;
        if (assignedBus != null && assignedBus.isNotEmpty && _busNumberController.text.isEmpty) {
          _busNumberController.text = assignedBus;
          ref.read(driverTripProvider.notifier).updateInputs(bus: assignedBus);
        }
      }
    });

    // Listen to trip state changes (e.g. from assigned routes screen selection)
    ref.listen<DriverTripState>(driverTripProvider, (previous, next) {
      debugPrint("DriverDashboard: driverTripProvider state updated. "
          "Previous state: busNumber='${previous?.busNumber}', from='${previous?.from}', to='${previous?.to}'. "
          "Next state: busNumber='${next.busNumber}', from='${next.from}', to='${next.to}', isTripStarted=${next.isTripStarted}");
      if (previous == null || previous.busNumber != next.busNumber) {
        _busNumberController.text = next.busNumber;
      }
      if (previous == null || previous.plateNumber != next.plateNumber) {
        _plateNumberController.text = next.plateNumber;
      }

      // ⚡ When trip starts (commences), animate the map camera to the start location of the route!
      if (next.isTripStarted && previous != null && !previous.isTripStarted) {
        final startLatLng = next.routePoints.isNotEmpty 
            ? next.routePoints.first 
            : (next.from != null ? _getHubPos(next.from!) : next.currentLocation);
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _animatedMapMove(startLatLng, 16.5);
        });
      } else if (next.routePoints.isNotEmpty && 
          (previous == null || previous.routePoints != next.routePoints)) {
        // ⚡ Auto-zoom and Fit bounds to Route Points if route has changed or selected (only when trip is NOT started)
        if (!next.isTripStarted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final bounds = LatLngBounds.fromPoints(next.routePoints);
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: bounds, 
                padding: const EdgeInsets.only(top: 80, bottom: 280, left: 50, right: 50),
              ),
            );
          });
        }
      }

      // Center back to driver location when trip/route is terminated/cleared
      if (next.routePoints.isEmpty && previous != null && previous.routePoints.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _animatedMapMove(next.currentLocation, 15.0);
        });
      }
    });

    final tripState = ref.watch(driverTripProvider);
    final driverProfileAsync = ref.watch(driverDataStreamProvider);
    final schedulesAsync = ref.watch(schedulesStreamProvider);

    if (!_hasShownUpcomingTripPrompt && tripState.hasRestored && !tripState.isTripStarted) {
      if (driverProfileAsync.hasValue && schedulesAsync.hasValue) {
        _checkAndShowUpcomingTripPrompt(driverProfileAsync.value, schedulesAsync.value);
      }
    }

    debugPrint("DriverDashboard: building with tripState: "
        "isTripStarted=${tripState.isTripStarted}, "
        "busNumber='${tripState.busNumber}', "
        "plateNumber='${tripState.plateNumber}', "
        "from='${tripState.from}', "
        "to='${tripState.to}', "
        "isLoading=${tripState.isLoading}");

    // Guard: If state is loading or active trip check hasn't finished, return a loading indicator instead of building layout.
    if (tripState.isLoading || !tripState.hasRestored) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryNavy),
          ),
        ),
      );
    }

    if (tripState.isTripStarted && _busNumberController.text.isEmpty) {
      _busNumberController.text = tripState.busNumber;
      _plateNumberController.text = tripState.plateNumber;
    }

    try {
      return Scaffold(
        drawer: const DriverDrawer(),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: tripState.currentLocation, initialZoom: 15),
              children: [
                TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', subdomains: const ['a', 'b', 'c', 'd']),
                if (tripState.routePoints.isNotEmpty)
                  PolylineLayer(polylines: [
                    Polyline(
                      points: tripState.routePoints,
                      color: const Color(0xFF1A237E),
                      strokeWidth: 5.0,
                      borderStrokeWidth: 2.0,
                      borderColor: const Color(0xFFE8EAF6),
                    ),
                  ]),
                if (tripState.to != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: tripState.routePoints.isNotEmpty ? tripState.routePoints.last : _getHubPos(tripState.to!), 
                      width: 100, height: 120, 
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _buildHubMarker(tripState.to!, Colors.redAccent, true),
                      )
                    ),
                    if (tripState.from != null)
                      Marker(
                        point: tripState.routePoints.isNotEmpty ? tripState.routePoints.first : _getHubPos(tripState.from!), 
                        width: 100, height: 120, 
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _buildHubMarker(tripState.from!, Colors.greenAccent[700]!, false),
                        )
                      ),
                  ]),
                MarkerLayer(
                  markers: [
                    if (tripState.isTripStarted)
                      Marker(
                        point: tripState.currentLocation,
                        width: 100,
                        height: 100,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _buildBusMarker(tripState.heading),
                        ),
                      )
                    else
                      // ⚡ FIX: Only show a subtle dot when not "Live Tracking"
                      Marker(
                        point: tripState.currentLocation,
                        width: 20,
                        height: 20,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primaryNavy,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 10),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(top: 40, left: 20, child: Builder(builder: (context) => _buildCircleButton(Icons.menu, () => Scaffold.of(context).openDrawer()))),
            Positioned(
              top: 40,
              right: 20,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .collection('notifications')
                    .where('isRead', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  final bool hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                  return GestureDetector(
                    onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                      ),
                      child: Badge(
                        isLabelVisible: hasUnread,
                        backgroundColor: Colors.red,
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: AppColors.primaryNavy,
                          size: 24,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            Positioned(
              right: 20, 
              bottom: MediaQuery.of(context).size.height * (
                tripState.isTripStarted 
                    ? 0.35 
                    : ((tripState.from != null && tripState.to != null && tripState.busNumber.isNotEmpty) ? 0.48 : 0.35)
              ) + 10, 
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildPulseEffect(Colors.red),
                      _buildMapControlButton(
                        icon: Icons.emergency_rounded,
                        color: Colors.red,
                        iconColor: Colors.white,
                        onPressed: _handleSOS,
                      ),
                    ],
                  ),
                  _buildMapControlButton(
                    icon: Icons.add_rounded,
                    color: AppColors.primaryNavy,
                    iconColor: Colors.white,
                    onPressed: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(_mapController.camera.center, currentZoom + 1);
                    },
                  ),
                  _buildMapControlButton(
                    icon: Icons.remove_rounded,
                    color: AppColors.primaryNavy,
                    iconColor: Colors.white,
                    onPressed: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(_mapController.camera.center, currentZoom - 1);
                    },
                  ),
                  _buildMapControlButton(
                    icon: Icons.my_location_rounded, 
                    color: AppColors.primaryYellow,
                    onPressed: () => _mapController.move(tripState.currentLocation, 15),
                  ),
                ],
              ),
            ),

            // ⚡ PROFESSIONAL: Draggable Bottom Sheet
            Consumer(
              builder: (context, ref, child) {
                final bool hasRoute = tripState.from != null && 
                                      tripState.to != null && 
                                      tripState.busNumber.isNotEmpty;

                final double initialSize;
                final double maxSize;

                if (tripState.isTripStarted) {
                  initialSize = 0.32;
                  maxSize = 0.5;
                } else if (!hasRoute) {
                  initialSize = 0.32; // Tight and compact size if no route is selected
                  maxSize = 0.45;
                } else {
                  initialSize = 0.45; // Moderate size showing selected route details
                  maxSize = 0.65;
                }

                return DraggableScrollableSheet(
                  initialChildSize: initialSize,
                  minChildSize: 0.15,
                  maxChildSize: maxSize,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
                      ),
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Handle
                            Container(
                              width: 40, 
                              height: 5, 
                              decoration: BoxDecoration(
                                color: Colors.grey[300], 
                                borderRadius: BorderRadius.circular(10)
                              )
                            ),
                            const SizedBox(height: 12),
                            
                            if (!tripState.isTripStarted) 
                              _buildConfigUI(tripState) 
                            else 
                              _buildActiveTripStatus(tripState),
                            
                            const SizedBox(height: 16),
                        
                        SizedBox(
                          width: double.infinity, 
                          height: 56,
                          child: Consumer(
                            builder: (context, ref, child) {
                              final bool hasRoute = tripState.from != null && 
                                                    tripState.to != null && 
                                                    tripState.busNumber.isNotEmpty;
                              
                              final String buttonText;
                              final Color buttonColor;
                              final VoidCallback buttonAction;

                              if (tripState.isTripStarted) {
                                buttonText = "TERMINATE TRIP";
                                buttonColor = Colors.red;
                                buttonAction = _onToggle;
                              } else if (!hasRoute) {
                                buttonText = "SELECT ROUTE TO START";
                                buttonColor = AppColors.primaryNavy;
                                buttonAction = () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const AssignedRoutesScreen()),
                                  );
                                };
                              } else {
                                buttonText = "COMMENCE TRACKING";
                                buttonColor = AppColors.primaryNavy;
                                buttonAction = _onToggle;
                              }

                              return ElevatedButton(
                                onPressed: buttonAction,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: buttonColor, 
                                  foregroundColor: Colors.white, 
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                ),
                                child: Text(
                                  buttonText, 
                                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)
                                ),
                              );
                            }
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    ),
  );
    } catch (e, stack) {
      debugPrint("CRITICAL: DriverDashboard build error captured: $e\n$stack");
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
                const SizedBox(height: 16),
                Text(
                  "Unable to render Dashboard",
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                ),
                const SizedBox(height: 8),
                Text(
                  "An unexpected error occurred: $e\n\nPlease try resetting your selected route or contact administration.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    ref.read(driverTripProvider.notifier).updateInputs(
                      bus: "",
                      plate: "",
                      from: null,
                      to: null,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Reset Assignment State"),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  LatLng _getHubPos(String name) {
    final map = {
      CampusLocations.baghdadName: CampusLocations.baghdadCampus,
      CampusLocations.abbasiaName: CampusLocations.abbasiaCampus,
    };
    return map[name] ?? CampusLocations.baghdadCampus;
  }

  Widget _buildHubMarker(String name, Color color, bool isDestination) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Text(
            name.split(' ')[0], 
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Stack(
          alignment: Alignment.center,
          children: [
            if (!isDestination) _buildPulseEffect(color), 
            Icon(Icons.location_on_rounded, color: color, size: 38),
            const Positioned(
              top: 8,
              child: Icon(Icons.circle, color: Colors.white, size: 10),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPulseEffect(Color color) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.5, end: 1.0),
      duration: const Duration(seconds: 2),
      curve: Curves.easeInOut,
      builder: (context, double value, child) {
        return Container(
          width: 50 * value,
          height: 50 * value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 1.0 - value),
          ),
        );
      },
    );
  }

  Widget _buildBusMarker(double heading) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryYellow.withValues(alpha: 0.15),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryYellow.withValues(alpha: 0.2),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryNavy,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: const Text(
                "MY BUS", 
                style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)
              ),
            ),
            const SizedBox(height: 2),
            Transform.rotate(
              angle: (heading * (3.14159 / 180)), 
              child: const Icon(
                Icons.navigation_rounded, 
                color: AppColors.primaryYellow, 
                size: 40,
                shadows: [Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
              )
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavigationBanner(DriverTripState state) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.primaryNavy, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 15)]),
      child: Row(children: [
          const CircleAvatar(backgroundColor: AppColors.primaryYellow, child: Icon(Icons.directions_rounded, color: AppColors.primaryNavy)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("NAVIGATING TO ${state.to?.toUpperCase()}", style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                Row(children: [
                    Text(state.remainingDistance, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(width: 8), const Text("•", style: TextStyle(color: Colors.white24)), const SizedBox(width: 8),
                    Text(state.remainingTime, style: const TextStyle(color: AppColors.primaryYellow, fontWeight: FontWeight.bold, fontSize: 18)),
                ]),
          ])),
      ]));
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]), child: Icon(icon, color: AppColors.primaryNavy, size: 24)));
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
    Color? iconColor,
  }) {
    return Container(
      width: 42,
      height: 42,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: iconColor ?? AppColors.primaryNavy, size: 20),
      ),
    );
  }

  Widget _buildConfigUI(DriverTripState state) {
    final bool hasSelectedRoute = state.from != null && state.to != null && state.busNumber.isNotEmpty;

    if (!hasSelectedRoute) {
      return Consumer(
        builder: (context, ref, child) {
          final driverProfileAsync = ref.watch(driverDataStreamProvider);
          final schedulesAsync = ref.watch(schedulesStreamProvider);

          int todayRoutesCount = 0;
          
          if (driverProfileAsync.hasValue && schedulesAsync.hasValue) {
            final driverData = driverProfileAsync.value;
            final allSchedules = schedulesAsync.value ?? [];
            if (driverData != null) {
              final assignedBus = (driverData['assignedBus']?.toString() ?? '').trim();
              final rawRoutes = driverData['assignedRoutes'];
              final List<dynamic> assignedRoutesList = rawRoutes is List ? rawRoutes : [];

              final matchingSchedules = allSchedules.where((s) {
                // 1. Match by Route ID or Route Name
                if (assignedRoutesList.isNotEmpty) {
                  if (assignedRoutesList.contains(s.id)) return true;
                  if (assignedRoutesList.any((r) => r.toString().toLowerCase().trim() == s.route.toLowerCase().trim())) {
                    return true;
                  }
                }

                // 2. Match by Bus Number
                if (assignedBus.isNotEmpty) {
                  final sBus = s.busNumber.toLowerCase().trim();
                  final dBus = assignedBus.toLowerCase().trim();
                  if (sBus == dBus) return true;
                  final parts = sBus.split(',').map((e) => e.trim()).toList();
                  if (parts.contains(dBus)) return true;
                  if (sBus.contains(dBus) || dBus.contains(sBus)) return true;

                  final sBusNum = RegExp(r'\d+').firstMatch(sBus)?.group(0);
                  final dBusNum = RegExp(r'\d+').firstMatch(dBus)?.group(0);
                  if (sBusNum != null && dBusNum != null && sBusNum == dBusNum) return true;
                }
                return false;
              }).toList();

              final now = DateTime.now();
              final selectedDateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
              final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
              final selectedDayName = weekdays[now.weekday - 1];

              todayRoutesCount = matchingSchedules.where((schedule) {
                if (schedule.date != null && schedule.date!.isNotEmpty) {
                  return schedule.date == selectedDateStr;
                }
                if (schedule.operatingDays != null && schedule.operatingDays!.isNotEmpty) {
                  return schedule.operatingDays!.any((day) => 
                    day.toLowerCase().trim() == selectedDayName.toLowerCase()
                  );
                }
                return selectedDayName != 'Saturday' && selectedDayName != 'Sunday';
              }).length;
            }
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (todayRoutesCount > 0) ...[
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.8, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_rounded, color: Colors.red, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              "YOU HAVE $todayRoutesCount SCHEDULED ROUTE${todayRoutesCount > 1 ? 'S' : ''} TODAY",
                              style: GoogleFonts.poppins(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
              ],
              Icon(Icons.route_rounded, size: 38, color: AppColors.primaryNavy.withValues(alpha: 0.25)),
              const SizedBox(height: 8),
              Text(
                "NO ACTIVE ROUTE SELECTED",
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  todayRoutesCount > 0 
                    ? "It is time for your shift! Tap below to select your route and commence tracking."
                    : "Please select one of your assigned routes to commence tracking.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5, 
                    color: todayRoutesCount > 0 ? Colors.red.shade400 : Colors.grey[500],
                    fontWeight: todayRoutesCount > 0 ? FontWeight.w600 : FontWeight.normal,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          );
        }
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "SELECTED ASSIGNMENT",
              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryNavy, letterSpacing: 1),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AssignedRoutesScreen()),
                );
              },
              icon: const Icon(Icons.edit, size: 14),
              label: const Text("Change Route", style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryNavy,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              // Bus Number row
              Row(
                children: [
                  const Icon(Icons.directions_bus_rounded, color: AppColors.primaryNavy, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("BUS NUMBER", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                        Text(
                          state.busNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryYellow.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      state.gender.toUpperCase(),
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              // Route row
              Row(
                children: [
                  const Icon(Icons.route, color: AppColors.primaryNavy, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("ROUTE DIRECTION", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                        Text(
                          "${state.from} ➔ ${state.to}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Departure time row — only show if we have a time
              if (state.departureTime.isNotEmpty) ...[
                const Divider(height: 20),
                Row(
                  children: [
                    const Icon(Icons.access_time_filled_rounded, color: AppColors.primaryNavy, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("DEPARTURE TIME", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                          Text(
                            state.departureTime,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        "SCHEDULED",
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSelector(DriverTripState state) {
    final genderConfigs = ref.watch(genderConfigProvider).genderConfigs;
    final List<String> genders = genderConfigs.keys.toList();
    if (genders.isEmpty) genders.addAll(["Girls", "Boys", "Combined"]);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: genders.map((g) {
          bool isSelected = state.gender == g;

          Color activeColor = AppColors.primaryYellow;
          if (genderConfigs.containsKey(g)) {
            final colorStr = genderConfigs[g]['color'] as String?;
            if (colorStr != null) {
              try {
                String cleanColor =
                    colorStr.replaceAll('#', '').replaceAll('0x', '');
                if (cleanColor.length == 6) cleanColor = 'FF$cleanColor';
                activeColor = Color(int.parse(cleanColor, radix: 16));
              } catch (e) {
                debugPrint("Error parsing color: $e");
              }
            }
          }

          return GestureDetector(
            onTap: () =>
                ref.read(driverTripProvider.notifier).updateInputs(gender: g),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? activeColor : Colors.grey[200]!,
                ),
              ),
              child: Text(
                g,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.blueGrey,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActiveTripStatus(DriverTripState state) {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.primaryNavy, borderRadius: BorderRadius.circular(24)),
      child: Column(children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(state.plateNumber, style: const TextStyle(color: AppColors.primaryYellow, fontSize: 10, fontWeight: FontWeight.bold)),
                Text("${state.from} ➔ ${state.to}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ])),
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)), child: Text("ID: ${state.busNumber}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
        ]),
        const Divider(color: Colors.white24, height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
          children: [
            _buildActiveInfo("DISTANCE", state.remainingDistance), 
            _buildActiveInfo("ETA", state.remainingTime), 
            _buildActiveInfo("SPEED", "${(state.speed * 3.6).toStringAsFixed(0)} KM/H"), 
            _buildActiveInfo("TRACKING", "LIVE"),
          ]
        ),
      ]),
    );
  }

  Widget _buildActiveInfo(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildRoutePicker(String label, String? value, Function(String?) onChanged) {
    final hubs = [CampusLocations.baghdadName, CampusLocations.abbasiaName];
    final safeValue = hubs.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      isExpanded: true, value: safeValue, hint: Text(label, style: const TextStyle(fontSize: 12)), 
      decoration: InputDecoration(filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
      items: hubs.map((h) => DropdownMenuItem(value: h, child: Text(h, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)))).toList(),
      onChanged: onChanged,
    );
  }
}

class _DriverSOSOptionsBottomSheet extends StatefulWidget {
  final String userId;
  final String userName;
  final double lat;
  final double lng;

  const _DriverSOSOptionsBottomSheet({
    required this.userId,
    required this.userName,
    required this.lat,
    required this.lng,
  });

  @override
  State<_DriverSOSOptionsBottomSheet> createState() => _DriverSOSOptionsBottomSheetState();
}

class _DriverSOSOptionsBottomSheetState extends State<_DriverSOSOptionsBottomSheet> {
  final TextEditingController _customReasonController = TextEditingController();
  Timer? _countdownTimer;
  int _secondsRemaining = 5;
  bool _isSending = false;

  final List<Map<String, dynamic>> _presets = [
    {
      'label': 'Accident / Collision',
      'icon': Icons.car_crash_rounded,
      'color': Colors.red[800]!,
      'message': 'Bus Accident / Collision reported.',
    },
    {
      'label': 'Medical Emergency',
      'icon': Icons.medical_services_rounded,
      'color': Colors.redAccent,
      'message': 'Driver/Passenger Medical emergency.',
    },
    {
      'label': 'Security / Dispute',
      'icon': Icons.security_rounded,
      'color': Colors.red[900]!,
      'message': 'Security threat / Passenger dispute reported.',
    },
    {
      'label': 'Bus Breakdown',
      'icon': Icons.build_rounded,
      'color': Colors.amber[800]!,
      'message': 'Bus Breakdown / Engine failure.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _customReasonController.addListener(_onTextChanged);
    _startCountdown();
  }

  void _onTextChanged() {
    if (_customReasonController.text.isNotEmpty && _countdownTimer != null) {
      setState(() {
        _countdownTimer?.cancel();
        _countdownTimer = null;
      });
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        if (mounted) {
          setState(() {
            _secondsRemaining--;
          });
        }
      } else {
        _countdownTimer?.cancel();
        _sendAlert('Driver Panic SOS triggered.');
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _customReasonController.dispose();
    super.dispose();
  }

  Future<void> _sendAlert(String message) async {
    if (_isSending) return;
    if (mounted) {
      setState(() {
        _isSending = true;
      });
    }
    _countdownTimer?.cancel();

    try {
      Map<String, dynamic>? driverDetails;
      try {
        final doc = await FirebaseFirestore.instance.collection('drivers').doc(widget.userId).get();
        if (doc.exists) {
          driverDetails = doc.data();
        }
      } catch (e) {
        debugPrint("Error loading driver details for SOS: $e");
      }

      final Map<String, dynamic> extraDetails = {
        'role': 'Driver',
      };
      if (driverDetails != null) {
        if (driverDetails['assignedBus'] != null) extraDetails['assignedBus'] = driverDetails['assignedBus'];
        if (driverDetails['licenseNumber'] != null) extraDetails['licenseNumber'] = driverDetails['licenseNumber'];
        if (driverDetails['cnic'] != null) extraDetails['cnic'] = driverDetails['cnic'];
        if (driverDetails['experience'] != null) extraDetails['experience'] = driverDetails['experience'];
        if (driverDetails['phoneNumber'] != null) extraDetails['phoneNumber'] = driverDetails['phoneNumber'];
        if (driverDetails['phone'] != null) extraDetails['phone'] = driverDetails['phone'];
        if (driverDetails['email'] != null) extraDetails['email'] = driverDetails['email'];
        if (driverDetails['isVerified'] != null) extraDetails['isVerified'] = driverDetails['isVerified'];
        if (driverDetails['isBlocked'] != null) extraDetails['isBlocked'] = driverDetails['isBlocked'];
        if (driverDetails['profileUrl'] != null) extraDetails['profileUrl'] = driverDetails['profileUrl'];
        if (driverDetails['cnicFrontUrl'] != null) extraDetails['cnicFrontUrl'] = driverDetails['cnicFrontUrl'];
        if (driverDetails['cnicBackUrl'] != null) extraDetails['cnicBackUrl'] = driverDetails['cnicBackUrl'];
        if (driverDetails['licenseImageUrl'] != null) extraDetails['licenseImageUrl'] = driverDetails['licenseImageUrl'];
      }

      await SOSService().sendSOS(
        userId: widget.userId,
        userName: widget.userName,
        lat: widget.lat,
        lng: widget.lng,
        message: message,
        extraDetails: extraDetails,
      );

      if (mounted) {
        Navigator.pop(context);
        NotificationService.show(
          title: "SOS Triggered",
          message: "Emergency alert sent to university admin.",
          type: NotificationType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send SOS: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Flashing Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.emergency_rounded, color: Colors.red, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'DRIVER SOS PANEL',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () {
                      _countdownTimer?.cancel();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (_countdownTimer != null) ...[
                // Countdown indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          value: _secondsRemaining / 5.0,
                          strokeWidth: 3,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sending automatic SOS in $_secondsRemaining seconds...',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              
              Text(
                'Please select emergency type for the dispatcher:',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              
              // Presets Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.2,
                ),
                itemCount: _presets.length,
                itemBuilder: (context, index) {
                  final preset = _presets[index];
                  final label = preset['label'] as String;
                  final icon = preset['icon'] as IconData;
                  final color = preset['color'] as Color;
                  final msg = preset['message'] as String;
                  
                  return InkWell(
                    onTap: () => _sendAlert(msg),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(icon, color: color, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              label,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              
              // Custom Text Field
              TextField(
                controller: _customReasonController,
                decoration: InputDecoration(
                  hintText: 'Type custom details (e.g. Route blocked)...',
                  hintStyle: GoogleFonts.poppins(fontSize: 12),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.red),
                    onPressed: () {
                      final val = _customReasonController.text.trim();
                      if (val.isNotEmpty) {
                        _sendAlert('Custom SOS: $val');
                      } else {
                        _sendAlert('Driver Panic SOS triggered.');
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Instant SOS Button
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _sendAlert('Driver Panic SOS triggered.'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'INSTANT SOS',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
