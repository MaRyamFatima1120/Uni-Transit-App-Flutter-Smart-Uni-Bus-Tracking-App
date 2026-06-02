import 'dart:async';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_transit/services/location_service.dart';
import 'package:uni_transit/services/routing_service.dart';
import 'package:uni_transit/services/notification_service.dart';
import 'package:uni_transit/core/util/logger.dart';
import 'package:uni_transit/core/constants/campus_locations.dart';
import 'package:uni_transit/services/trip_alert_service.dart';
import 'package:uni_transit/core/constants/custom_routes.dart';
import 'package:uni_transit/models/eta_info.dart';

class DriverTripState {
  final bool isTripStarted;
  final String? activeTripId;
  final String busNumber;
  final String plateNumber;
  final String? from;
  final String? to;
  final String gender;
  final String departureTime;   // e.g. "07:30 AM" — shown on dashboard
  final List<LatLng> routePoints;
  final String remainingDistance;
  final String remainingTime;
  final LatLng currentLocation;
  final double heading;
  final double speed;
  final bool isLoading;
  final bool hasRestored;

  DriverTripState({
    this.isTripStarted = false,
    this.activeTripId,
    this.busNumber = "",
    this.plateNumber = "",
    this.from,
    this.to,
    this.gender = "Combined",
    this.departureTime = "",
    this.routePoints = const [],
    this.remainingDistance = "---",
    this.remainingTime = "---",
    this.currentLocation = const LatLng(29.3794, 71.6707),
    this.heading = 0.0,
    this.speed = 0.0,
    this.isLoading = false,
    this.hasRestored = false,
  });

  DriverTripState copyWith({
    bool? isTripStarted,
    String? activeTripId,
    String? busNumber,
    String? plateNumber,
    String? from,
    String? to,
    String? gender,
    String? departureTime,
    List<LatLng>? routePoints,
    String? remainingDistance,
    String? remainingTime,
    LatLng? currentLocation,
    double? heading,
    double? speed,
    bool? isLoading,
    bool? hasRestored,
  }) {
    return DriverTripState(
      isTripStarted: isTripStarted ?? this.isTripStarted,
      activeTripId: activeTripId ?? this.activeTripId,
      busNumber: busNumber ?? this.busNumber,
      plateNumber: plateNumber ?? this.plateNumber,
      from: from ?? this.from,
      to: to ?? this.to,
      gender: gender ?? this.gender,
      departureTime: departureTime ?? this.departureTime,
      routePoints: routePoints ?? this.routePoints,
      remainingDistance: remainingDistance ?? this.remainingDistance,
      remainingTime: remainingTime ?? this.remainingTime,
      currentLocation: currentLocation ?? this.currentLocation,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      isLoading: isLoading ?? this.isLoading,
      hasRestored: hasRestored ?? this.hasRestored,
    );
  }
}

class DriverTripNotifier extends Notifier<DriverTripState> {
  final LocationService _locationService = LocationService();

  // Throttle navigation refresh to avoid excessive API calls
  DateTime _lastRefresh = DateTime.fromMillisecondsSinceEpoch(0);
  static const _refreshInterval = Duration(seconds: 15);

  @override
  DriverTripState build() {
    return DriverTripState();
  }

  void updateLocation(LatLng loc, double heading, {double speed = 0.0}) {
    state = state.copyWith(
      currentLocation: loc,
      heading: heading,
      speed: speed,
    );
    if (state.isTripStarted) {
      // Throttle navigation refresh to every 15 seconds
      final now = DateTime.now();
      if (now.difference(_lastRefresh) > _refreshInterval) {
        _lastRefresh = now;
        _refreshNavigation();
      }
      // Always update tracking position with latest ETA data
      _locationService.updateTracking(
        state.busNumber,
        loc.latitude,
        loc.longitude,
        heading,
        speed: speed,
        remainingTime: state.remainingTime,
        remainingDistance: state.remainingDistance,
        arrivalTime:
            state.remainingTime != "---"
                ? _calculateClockTime(state.remainingTime)
                : "Calculating...",
      );
    }
  }

  String _calculateClockTime(String remainingStr) {
    try {
      int minutes = 0;
      if (remainingStr.contains('h')) {
        final parts = remainingStr.split('h');
        final hours = int.parse(parts[0].trim());
        final minsStr = parts[1].replaceAll('m', '').trim();
        final mins = minsStr.isNotEmpty ? int.parse(minsStr) : 0;
        minutes = (hours * 60) + mins;
      } else {
        minutes = int.parse(remainingStr.split(' ')[0]);
      }
      final arrival = DateTime.now().add(Duration(minutes: minutes));
      return DateFormat('hh:mm a').format(arrival);
    } catch (e) {
      return "Calculating...";
    }
  }

  void updateInputs({
    String? bus,
    String? plate,
    String? from,
    String? to,
    String? gender,
    String? departureTime,
  }) {
    // Sanitize: ignore literal 'null' strings or empty from/to
    final safeFrom = (from != null && from.trim().isNotEmpty && from.trim().toLowerCase() != 'null')
        ? from.trim()
        : state.from;
    final safeTo = (to != null && to.trim().isNotEmpty && to.trim().toLowerCase() != 'null')
        ? to.trim()
        : state.to;

    state = state.copyWith(
      busNumber: (bus != null && bus.trim().isNotEmpty) ? bus.trim() : null,
      plateNumber: plate,
      from: safeFrom,
      to: safeTo,
      gender: gender,
      departureTime: (departureTime != null && departureTime.trim().isNotEmpty)
          ? departureTime.trim()
          : null,
    );

    if (safeFrom != null && safeTo != null) {
      _refreshNavigation();
    }
  }

  Future<void> restoreActiveTrip(String uid) async {
    state = state.copyWith(isLoading: true);
    try {
      final activeTrip = await _locationService.getActiveTrip(uid);
      if (activeTrip != null) {
        state = state.copyWith(
          isTripStarted: true,
          activeTripId: activeTrip['tripId'],
          busNumber: activeTrip['busNumber'],
          plateNumber: activeTrip['plateNumber'],
          from: activeTrip['from'],
          to: activeTrip['to'],
          gender: activeTrip['gender'],
        );
        // Fixed: now passes uid so restoreTracking can re-create RTDB entry
        await _locationService.restoreTracking(uid, state.busNumber);
        await _refreshNavigation();
      }
    } catch (e) {
      AppLogger.error("Restore failed: $e");
    } finally {
      state = state.copyWith(
        isLoading: false,
        hasRestored: true,
      );
    }
  }

  Future<void> _refreshNavigation() async {
    if (state.from == null || state.to == null) return;

    final routeName = "${state.from} ➔ ${state.to}";
    final manualPoints = CustomRoutes.getRoutePoints(routeName);

    final startHubCoord = _getHubCoord(state.from!);
    final target = _getHubCoord(state.to!);
    if (target == null) return;

    // Use Start Hub coordinates if trip has not started yet, otherwise use current live location.
    final origin = state.isTripStarted 
        ? state.currentLocation 
        : (startHubCoord ?? state.currentLocation);

    final fallbackEta = EtaInfo.estimateFromCoordinates(origin, target);
    final fallbackDistance = fallbackEta.distanceDisplay;
    final fallbackTime = fallbackEta.etaDisplay;

    if (manualPoints.isNotEmpty && manualPoints.length > 2) {
      // ⚡ PROFESSIONAL: Use manual points for the map path
      final routeData = await RoutingService.getFullRoute([
        origin,
        target,
      ]);
      state = state.copyWith(
        routePoints: manualPoints,
        remainingDistance:
            routeData != null
                ? "${(routeData.distanceMeters / 1000).toStringAsFixed(1)} KM"
                : (state.remainingDistance != "---" ? state.remainingDistance : fallbackDistance),
        remainingTime:
            routeData != null
                ? "${(routeData.durationSeconds / 60).ceil()} MIN"
                : (state.remainingTime != "---" ? state.remainingTime : fallbackTime),
      );
    } else {
      // Fallback to OSRM if no manual points are defined
      final routeData = await RoutingService.getFullRoute([
        origin,
        target,
      ]);
      if (routeData != null) {
        state = state.copyWith(
          routePoints: routeData.points,
          remainingDistance:
              "${(routeData.distanceMeters / 1000).toStringAsFixed(1)} KM",
          remainingTime: "${(routeData.durationSeconds / 60).ceil()} MIN",
        );
      } else {
        state = state.copyWith(
          remainingDistance: state.remainingDistance != "---" ? state.remainingDistance : fallbackDistance,
          remainingTime: state.remainingTime != "---" ? state.remainingTime : fallbackTime,
        );
      }
    }

    // ⚡ UPDATE FIREBASE: Push the freshly calculated remainingTime, remainingDistance and arrivalTime to Firebase immediately
    if (state.isTripStarted) {
      final arrivalTime = state.remainingTime != "---" && state.remainingTime != "Calculating..."
          ? _calculateClockTime(state.remainingTime)
          : "Calculating...";
      await _locationService.updateTracking(
        state.busNumber,
        state.currentLocation.latitude,
        state.currentLocation.longitude,
        state.heading,
        speed: state.speed,
        remainingTime: state.remainingTime,
        remainingDistance: state.remainingDistance,
        arrivalTime: arrivalTime,
      );
    }
  }

  Future<void> toggleTrip(String uid, String driverName) async {
    if (!state.isTripStarted) {
      if (state.from == null || state.to == null) return;
      if (state.busNumber.trim().isEmpty) {
        NotificationService.show(
          title: "Missing Info",
          message: "Please enter a Bus ID before starting.",
          type: NotificationType.warning,
        );
        return;
      }
      try {
        // ⚡ NEW: Capture actual location immediately to avoid (0,0) ocean bug
        final pos = await Geolocator.getCurrentPosition();
        final nowFormatted = DateFormat('hh:mm a').format(DateTime.now());

        // ⚡ UX OPTIMIZATION: Calculate straight-line estimates immediately to prevent initial empty or "---" fields in student dashboard
        String initialTime = "---";
        String initialDistance = "---";
        String initialArrival = "Arrival Pending";
        
        final startLatLng = LatLng(pos.latitude, pos.longitude);
        final targetHubCoord = _getHubCoord(state.to!);
        if (targetHubCoord != null) {
          final initialEta = EtaInfo.estimateFromCoordinates(startLatLng, targetHubCoord);
          initialTime = initialEta.etaDisplay;
          initialDistance = initialEta.distanceDisplay;
          try {
            int minutes = 0;
            if (initialTime.contains('h')) {
              final parts = initialTime.split('h');
              final hours = int.parse(parts[0].trim());
              final minsStr = parts[1].replaceAll('m', '').trim();
              final mins = minsStr.isNotEmpty ? int.parse(minsStr) : 0;
              minutes = (hours * 60) + mins;
            } else {
              minutes = int.parse(initialTime.split(' ')[0]);
            }
            final arrival = DateTime.now().add(Duration(minutes: minutes));
            initialArrival = DateFormat('hh:mm a').format(arrival);
          } catch (_) {}
        }

        await _locationService.startSharingLocation(
          uid,
          state.busNumber,
          from: state.from!,
          to: state.to!,
          gender: state.gender,
          driverName: driverName,
          departureTime: nowFormatted,
          arrivalTime: initialArrival,
          plateNumber: state.plateNumber,
          lat: pos.latitude,
          lng: pos.longitude,
          remainingTime: initialTime,
          remainingDistance: initialDistance,
        );

        final activeTrip = await _locationService.getActiveTrip(uid);
        state = state.copyWith(
          isTripStarted: true,
          activeTripId: activeTrip?['tripId'],
          remainingTime: initialTime,
          remainingDistance: initialDistance,
        );

        // ⚡ PROFESSIONAL: Publish trip alert for students and Admin Panel
        await TripAlertService().publishTripStart(
          busId: state.busNumber,
          from: state.from!,
          to: state.to!,
          driverName: driverName,
        );

        await _refreshNavigation();

        NotificationService.show(
          title: "Trip Started",
          message:
              "You are now live-tracking from ${state.from} to ${state.to}.",
          type: NotificationType.success,
        );
      } catch (e) {
        NotificationService.show(
          title: "Error",
          message: "Failed to start trip: $e",
          type: NotificationType.error,
        );
      }
    } else {
      final oldBusNumber = state.busNumber;
      final oldFrom = state.from ?? "Unknown Origin";
      final oldTo = state.to ?? "Unknown Destination";
      final oldTripId = state.activeTripId;

      // Terminate Trip: Perform a FULL RESET of the state
      if (oldTripId != null) {
        await _locationService.stopSharingLocation(
          uid,
          oldBusNumber,
          oldTripId,
        );
      }

      // ⚡ Publish trip completion alert to RTDB for Students and Admin
      await TripAlertService().publishTripEnd(
        busId: oldBusNumber,
        from: oldFrom,
        to: oldTo,
        driverName: driverName,
      );

      state = state.copyWith(
        isTripStarted: false,
        activeTripId: null,
        busNumber: "", // Clear bus info
        plateNumber: "",
        from: null, // Reset hubs
        to: null,
        routePoints: [], // Clear map path
        remainingDistance: "---", // Reset indicators
        remainingTime: "---",
      );

      NotificationService.show(
        title: "Route Completed! 🎉",
        message: "Congratulations! You have successfully completed your assigned route.",
        type: NotificationType.success,
      );
    }
  }

  /// Helper to robustly get hub coordinates from loose string matches
  LatLng? _getHubCoord(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('baghdad')) return CampusLocations.baghdadCampus;
    if (lower.contains('abbasia') || lower.contains('abasia') || lower.contains('old')) return CampusLocations.abbasiaCampus;
    if (lower.contains('railway')) return const LatLng(29.3970, 71.6850);
    return null;
  }
}

final driverTripProvider =
    NotifierProvider<DriverTripNotifier, DriverTripState>(
      () => DriverTripNotifier(),
    );
