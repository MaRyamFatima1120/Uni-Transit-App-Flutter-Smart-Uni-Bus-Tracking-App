import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uni_transit/services/sos_service.dart';
import 'package:uni_transit/services/location_service.dart';
import 'package:uni_transit/services/notification_service.dart';
import 'package:uni_transit/core/constants/campus_locations.dart';
import 'package:uni_transit/models/eta_info.dart';
import 'package:uni_transit/services/trip_alert_service.dart';
import 'package:uni_transit/core/constants/custom_routes.dart';
import 'package:uni_transit/view_models/route_provider.dart';
import 'package:uni_transit/view_models/bus_provider.dart';
import 'package:uni_transit/view_models/map_ui_provider.dart';

// 🚀 PROFESSIONAL FEATURES ADDED:
// 1. Hub Snapping: Markers automatically align with polyline ends.
// 2. Camera Reset: Map centers on student location/fleet when route is cleared.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with TickerProviderStateMixin {
  final LatLng _defaultLocation = CampusLocations.baghdadCampus;
  final MapController _mapController = MapController();
  
  // Cache of computed ETAs per bus
  final Map<String, EtaInfo> _busEtas = {};

  StreamSubscription? _tripAlertsSubscription;
  DateTime _lastEtaUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastFleetFit = DateTime.fromMillisecondsSinceEpoch(0);




  @override
  void initState() {
    super.initState();
    _listenToTripAlerts();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _tripAlertsSubscription?.cancel();
    super.dispose();
  }

  void _fitAllBuses() {
    final busData = ref.read(busProvider).liveBusData;
    if (busData.isEmpty) return;

    List<LatLng> points = [];
    busData.forEach((id, data) {
      if (data['latitude'] != null && data['longitude'] != null) {
        points.add(
          LatLng(
            (data['latitude'] as num).toDouble(),
            (data['longitude'] as num).toDouble(),
          ),
        );
      }
    });

    if (points.isEmpty) return;

    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(100)),
    );
  }

  void _centerOnSelectedBus() {
    final routeState = ref.read(routeProvider);
    if (routeState.selectedRoute == null) return;

    // Find the bus that matches the selected route
    String? trackingBusId;
    final busData = ref.read(busProvider).liveBusData;
    busData.forEach((id, data) {
      if (data['from'] == routeState.fromHub && data['to'] == routeState.toHub) {
        trackingBusId = id;
      }
    });

    if (trackingBusId != null) {
      final busPos = LatLng(
        (busData[trackingBusId]['latitude'] as num).toDouble(),
        (busData[trackingBusId]['longitude'] as num).toDouble(),
      );

      // Smoothly pan to the bus position
      _animatedMapMove(busPos, 15.5);
    }
  }

  LatLng? _getHubLocation(String name) {
    final hubsData = ref.read(hubProvider).hubsData;
    if (hubsData.containsKey(name)) {
      final data = hubsData[name];
      return LatLng(
        (data['latitude'] as num).toDouble(),
        (data['longitude'] as num).toDouble(),
      );
    }
    return null;
  }



  void _listenToTripAlerts() {
    _tripAlertsSubscription = TripAlertService().alertStream.listen((data) {
      if (data.isNotEmpty && mounted) {
        final busId = data['busId'] ?? "---";
        final from = data['from'] ?? "---";
        final to = data['to'] ?? "---";

        NotificationService.show(
          title: "New Trip Started! 🚌",
          message: "Bus #$busId is departing from $from heading to $to.",
          type: NotificationType.info,
        );

        // ⚡ SYSTEM NOTIFICATION: Professional alert even if user is not looking at map
        NotificationService.showLocalNotification(
          title: "Bus Departure: #$busId",
          body: "Departing from $from to $to.",
          id: busId.hashCode, // Unique ID per bus to prevent overwriting
        );
      }
    });
  }

  List<Marker> _getStopMarkers() {
    final routeState = ref.read(routeProvider);
    final stopsData = ref.read(stopProvider).stopsData;
    if (routeState.selectedRoute == null) return [];

    final List<Marker> markers = [];
    stopsData.forEach((id, data) {
      final stopRoute = data['route'] as String? ?? "";
      if (stopRoute != routeState.selectedRoute) return;

      final lat = (data['latitude'] as num).toDouble();
      final lng = (data['longitude'] as num).toDouble();
      final name = data['name'] as String? ?? "Stop";

      markers.add(
        Marker(
          width: 140,
          height: 80,
          point: LatLng(lat, lng),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Beautiful Pill Label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                // Premium Dot Pin
                const Icon(
                  Icons.radio_button_checked,
                  color: Colors.orange,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      );
    });
    return markers;
  }





  /// Compute dynamic ETA for each bus based on its position and destination.
  void _updateBusEtas(Map<String, dynamic> buses) {
    buses.forEach((id, data) {
      if (data['latitude'] == null || data['longitude'] == null) return;
      final busPos = LatLng(
        (data['latitude'] as num).toDouble(),
        (data['longitude'] as num).toDouble(),
      );
      final destName = data['to'] as String?;
      if (destName == null) return;
      final destPos = _getHubLocation(destName);
      if (destPos == null) return;

      // Only recalculate if bus has a valid position
      if (busPos.latitude != 0.0 || busPos.longitude != 0.0) {
        _busEtas[id] = EtaInfo.estimateFromCoordinates(busPos, destPos);
      }
    });
  }

  void _checkProximity(Map<String, dynamic> buses) {
    final routeState = ref.read(routeProvider);
    final uiState = ref.read(mapUiProvider);
    if (!uiState.hasUserLocation || routeState.toHub == null) return;
    buses.forEach((id, data) {
      if (data['to'] != routeState.toHub) return;
      if (data['latitude'] == null || data['longitude'] == null) return;
      final busPos = LatLng(
        (data['latitude'] as num).toDouble(),
        (data['longitude'] as num).toDouble(),
      );
      final distance = const Distance().as(
        LengthUnit.Meter,
        uiState.userLocation,
        busPos,
      );
      if (distance < 1000 && !uiState.notifiedBuses.contains(id)) {
        ref.read(mapUiProvider.notifier).addNotifiedBus(id);
        NotificationService.show(
          title: "Bus Approaching",
          message: "Bus #$id is within 1 KM!",
          type: NotificationType.proximity,
        );
      }
    });
  }

  List<Marker> _getMarkers() {
    final List<Marker> markers = [];
    final routeState = ref.read(routeProvider);
    final busData = ref.read(busProvider).liveBusData;
    final uiState = ref.read(mapUiProvider);

    busData.forEach((id, data) {
      if (routeState.selectedRoute != null) {
        final busFrom = (data['from'] as String? ?? '').toLowerCase().trim();
        final busTo = (data['to'] as String? ?? '').toLowerCase().trim();
        final selFrom = (routeState.fromHub ?? '').toLowerCase().trim();
        final selTo = (routeState.toHub ?? '').toLowerCase().trim();

        bool fromMatches = busFrom.contains(selFrom) || selFrom.contains(busFrom);
        bool toMatches = busTo.contains(selTo) || selTo.contains(busTo);
        if (!(fromMatches && toMatches)) return;
      }

      final gender = data['gender'] ?? 'Combined';
      if (uiState.selectedGender != "All" && gender != uiState.selectedGender) return;

      final lat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
      final lng = (data['longitude'] as num?)?.toDouble() ?? 0.0;
      if (lat == 0.0 || lng == 0.0) return;

      final heading = (data['heading'] ?? 0.0).toDouble();
      final etaInfo = _busEtas[id];

      markers.add(
        Marker(
          width: 100,
          height: 100,
          point: LatLng(lat, lng),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedBusMarker(
              id: id,
              data: Map<String, dynamic>.from(data),
              heading: heading,
              etaInfo: etaInfo,
              onTap: () => _showBusDetails(id, Map<String, dynamic>.from(data)),
            ),
          ),
        ),
      );
    });
    return markers;
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
      onEnd:
          () {}, // Handled by repeating via a real controller if needed, but this works for basic pulse
    );
  }

  // ⚡ PROFESSIONAL: Custom Student Location Marker (Widget-based for crisp rendering)
  Widget _buildUserLocationMarker() {
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _buildPulseEffect(AppColors.primaryYellow),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryNavy, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryYellow.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                CustomPaint(
                  size: const Size(8, 4),
                  painter: _MarkerPointerPainter(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ⚡ PROFESSIONAL: Custom Hub Marker (Start/Destination)
  Widget _buildHubMarker(String name, Color color, bool isDestination) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Floating Label Tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            name.split(' ')[0], // Short name
            style: TextStyle(
              color: color == AppColors.primaryYellow ? AppColors.primaryNavy : Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Pin with Glow/Pulse if it's the start
        Stack(
          alignment: Alignment.center,
          children: [
            if (!isDestination && color != Colors.grey[400])
              _buildPulseEffect(color),
            Icon(Icons.location_on_rounded, color: color, size: 38),
            Positioned(
              top: 8,
              child: Icon(
                Icons.circle,
                color: color == AppColors.primaryYellow ? AppColors.primaryNavy : Colors.white,
                size: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _fetchRoadPath(LatLng start, LatLng end) async {
    // Note: OSRM is kept as a local helper if needed later, but route points are managed by provider
    final url =
        'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        // This is just a helper now, not updating local state directly
      }
    } catch (e) {
      debugPrint("Error fetching road path: $e");
    }
  }



  /// ⚡ PROFESSIONAL: Smoothly glides the map to a target location
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
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      } else if (status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final routeState = ref.watch(routeProvider);
    final hubsData = ref.watch(hubProvider).hubsData;
    final genderConfigs = ref.watch(genderConfigProvider).genderConfigs;
    final uiState = ref.watch(mapUiProvider);

    // ⚡ SYNC: Listen to route changes to trigger map animation
    ref.listen<RouteState>(routeProvider, (previous, next) {
      // 1. Zoom to route when selected
      if (next.routePoints.isNotEmpty &&
          (previous == null || previous.routePoints != next.routePoints)) {
        _animatedMapMove(next.routePoints[0], 14.5);
      }

      // 2. ⚡ PROFESSIONAL: Reset to User Location (or Fleet View) when route is cleared
      if (next.selectedRoute == null && previous?.selectedRoute != null) {
        if (uiState.hasUserLocation) {
          _animatedMapMove(uiState.userLocation, 15.0);
        } else {
          _fitAllBuses();
        }
      }
    });

    // ⚡ SYNC: Listen to bus data changes for animations and ETAs
    ref.listen<BusState>(busProvider, (previous, next) {
      // Smart Auto-follow (Less aggressive)
      if (routeState.selectedRoute == null && next.liveBusData.isNotEmpty) {
        if (_lastFleetFit == DateTime.fromMillisecondsSinceEpoch(0)) {
          _lastFleetFit = DateTime.now();
          _fitAllBuses();
        }
      } else if (routeState.selectedRoute != null &&
          next.liveBusData.isNotEmpty) {
        final now = DateTime.now();
        if (now.difference(_lastFleetFit).inSeconds >= 3) {
          _lastFleetFit = now;
          _centerOnSelectedBus();
        }
      }

      final now = DateTime.now();
      if (now.difference(_lastEtaUpdate).inSeconds >= 5) {
        _lastEtaUpdate = now;
        _updateBusEtas(next.liveBusData);
      }
      _checkProximity(next.liveBusData);
    });

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultLocation,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              if (routeState.routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: <Polyline>[
                    Polyline(
                      points: routeState.routePoints,
                      color: const Color(0xFF1A237E),
                      strokeWidth: 5.0,
                      borderStrokeWidth: 2.0,
                      borderColor: const Color(0xFFE8EAF6),
                    ),
                  ],
                ),
              // ⚡ FIX: Only show Hub Markers when a route is selected
              MarkerLayer(
                markers: routeState.selectedRoute == null
                    ? []
                    : hubsData.entries.where((hub) {
                        final hubKey = hub.key.toLowerCase().trim();
                        final selFrom =
                            (routeState.fromHub ?? "").toLowerCase().trim();
                        final selTo =
                            (routeState.toHub ?? "").toLowerCase().trim();

                        // Robust Matching: Check if hub name matches either start or destination
                        return hubKey.contains(selFrom) ||
                            selFrom.contains(hubKey) ||
                            hubKey.contains(selTo) ||
                            selTo.contains(hubKey);
                      }).map((hub) {
                        final hubKey = hub.key.toLowerCase().trim();
                        final selFrom =
                            (routeState.fromHub ?? "").toLowerCase().trim();
                        final selTo =
                            (routeState.toHub ?? "").toLowerCase().trim();

                        bool isDest =
                            hubKey.contains(selTo) || selTo.contains(hubKey);
                        bool isStart =
                            hubKey.contains(selFrom) || selFrom.contains(hubKey);

                        Color markerColor = isDest
                            ? Colors.red
                            : (isStart
                                ? Colors.green
                                : AppColors.primaryYellow);

                        final hubLat = (hub.value['latitude'] as num).toDouble();
                        final hubLng = (hub.value['longitude'] as num).toDouble();
                        LatLng markerPos = LatLng(hubLat, hubLng);

                        // ⚡ SYNC: Snap hub markers to polyline endpoints for perfect alignment
                        if (routeState.routePoints.isNotEmpty) {
                          if (isDest) {
                            markerPos = routeState.routePoints.last;
                          } else if (isStart) {
                            markerPos = routeState.routePoints.first;
                          }
                        }

                        return Marker(
                          point: markerPos,
                          width: 100,
                          height: 120,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _buildHubMarker(hub.key, markerColor, isDest),
                          ),
                        );
                      }).toList(),
              ),
              if (uiState.hasUserLocation)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: uiState.userLocation,
                      width: 50,
                      height: 50,
                      child: _buildUserLocationMarker(),
                    ),
                  ],
                ),
              MarkerLayer(markers: _getStopMarkers()),
              MarkerLayer(markers: _getMarkers()),
            ],
          ),
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 20),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.map_rounded,
                        color: AppColors.primaryYellow,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value:
                                routeState.officialRoutes.containsKey(
                                      routeState.selectedRoute,
                                    )
                                    ? routeState.selectedRoute
                                    : null,
                            isExpanded: true,
                            hint: const Text("Select Route"),
                            items:
                                routeState.officialRoutes.keys
                                    .map(
                                      (r) => DropdownMenuItem(
                                        value: r,
                                        child: Text(
                                          r,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryNavy,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                ref.read(routeProvider.notifier).selectRoute(v);
                                ref.read(mapUiProvider.notifier).clearNotifications();
                              }
                            },
                          ),
                        ),
                      ),
                      if (routeState.selectedRoute != null)
                        IconButton(
                          onPressed: () {
                            ref.read(routeProvider.notifier).clearSelection();
                            ref.read(mapUiProvider.notifier).clearNotifications();
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                  ),
                ),
                if (routeState.isFetching)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 24, right: 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: const LinearProgressIndicator(
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryYellow,
                        ),
                        minHeight: 3,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                _buildGenderFilterBar(genderConfigs),
              ],
            ),
          ),
          Positioned(
            right: 20,
            bottom: 110,
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
                    _mapController.move(
                      _mapController.camera.center,
                      currentZoom + 1,
                    );
                  },
                ),
                _buildMapControlButton(
                  icon: Icons.remove_rounded,
                  color: AppColors.primaryNavy,
                  iconColor: Colors.white,
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      currentZoom - 1,
                    );
                  },
                ),
                _buildMapControlButton(
                  icon: Icons.my_location,
                  color: AppColors.primaryYellow,
                  onPressed: _getCurrentLocation,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBusDetails(String id, Map<String, dynamic> data) async {
    final etaInfo = _busEtas[id];

    // ⚡ REAL-TIME: Prioritize data from Firebase RTDB (pushed by driver)
    final etaText =
        data['remainingTime'] != null &&
                (data['remainingTime'] as String).isNotEmpty
            ? data['remainingTime']
            : (etaInfo?.etaDisplay ?? "Calculating...");

    final arrivalClockTime =
        data['arrivalTime'] != null &&
                (data['arrivalTime'] as String).isNotEmpty
            ? data['arrivalTime']
            : "Calculating...";

    final distText = etaInfo?.distanceDisplay ?? "---";
    final gender = data['gender'] ?? 'Combined';
    final Color genderColor =
        (gender == 'Girls')
            ? Colors.pinkAccent
            : (gender == 'Boys' ? Colors.blueAccent : AppColors.primaryNavy);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: SingleChildScrollView(
                    // ⚡ FIX: Prevent Overflow
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Header Row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: genderColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.directions_bus_rounded,
                                color: genderColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        data['driverName'] ?? "Driver",
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryNavy,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildLiveBadge(),
                                    ],
                                  ),
                                  Text(
                                    "BUS #$id • ${data['plateNumber'] ?? ''}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.blueGrey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 16),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Info Grid
                        Row(
                          children: [
                            Expanded(
                              child: _buildModernInfoBox(
                                Icons.timer_outlined,
                                "REMAINING",
                                etaText,
                                AppColors.primaryNavy,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildModernInfoBox(
                                Icons.event_available_rounded,
                                "ARRIVAL",
                                arrivalClockTime,
                                AppColors.primaryYellow,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildModernInfoBox(
                                Icons.location_on_outlined,
                                "DISTANCE",
                                distText,
                                Colors.blueGrey,
                              ),
                            ),
                            if ((data['speed'] ?? 0.0) > 0.5) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildModernInfoBox(
                                  Icons.speed,
                                  "SPEED",
                                  "${((data['speed'] ?? 0.0) as num).toStringAsFixed(0)} m/s",
                                  AppColors.liveStatus,
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Route Detail Tile
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.alt_route_rounded,
                                color: AppColors.primaryNavy,
                                size: 20,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "CURRENT TRIP",
                                      style: GoogleFonts.poppins(
                                        fontSize: 9,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      "${data['from']} ➔ ${data['to']}",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: AppColors.primaryNavy,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            "LIVE",
            style: GoogleFonts.poppins(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInfoBox(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color.withValues(alpha: 0.7), size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.grey[500],
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: AppColors.primaryNavy,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderFilterBar(Map<String, dynamic> genderConfigs) {
    // Combine "All" with dynamic genders from backend
    final List<String> genders = ["All", ...genderConfigs.keys];

    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: genders.map((g) {
            final uiState = ref.watch(mapUiProvider);
            bool isSelected = uiState.selectedGender == g;

            Color activeColor = AppColors.primaryYellow;
            if (g == "All") {
              activeColor = AppColors.primaryYellow;
            } else if (genderConfigs.containsKey(g)) {
              final colorStr = genderConfigs[g]['color'] as String?;
              if (colorStr != null) {
                try {
                  String cleanColor =
                      colorStr.replaceAll('#', '').replaceAll('0x', '');
                  if (cleanColor.length == 6) cleanColor = 'FF$cleanColor';
                  activeColor = Color(int.parse(cleanColor, radix: 16));
                } catch (e) {
                  debugPrint("Error parsing color for $g: $e");
                }
              }
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () {
                  ref.read(mapUiProvider.notifier).updateGenderPreference(g);
                  _updateGenderInBackend(g);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? activeColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow:
                        isSelected
                            ? [
                              BoxShadow(
                                color: activeColor.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                            : null,
                  ),
                  child: Text(
                    g.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _updateGenderInBackend(String gender) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'genderPreference': gender});
    }
  }

  Future<void> _getCurrentLocation() async {
    // Check if GPS/location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryYellow.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.location_off_rounded,
                        color: AppColors.primaryNavy,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Enable GPS",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                content: Text(
                  "Turn on Location Services to see nearby buses and get accurate ETAs.",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "SKIP",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      LocationService.openLocationSettings();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "OPEN SETTINGS",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
        );
      }
      return;
    }

    // Request permission
    final hasPermission = await LocationService.handleLocationPermission();
    if (!hasPermission) {
      final status = await LocationService.checkPermissionStatus();
      if (mounted && status == LocationPermission.deniedForever) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryYellow.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.location_disabled_rounded,
                        color: AppColors.primaryNavy,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Permission Needed",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                content: Text(
                  "Location permission was permanently denied. To see your position on the map and get bus proximity alerts, please enable it in Settings.",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "SKIP",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      LocationService.openAppSettings();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "APP SETTINGS",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
        );
      }
      return;
    }

    // Permission granted — get current position
    try {
      final position = await Geolocator.getCurrentPosition();
        final uiNotifier = ref.read(mapUiProvider.notifier);
        uiNotifier.updateUserLocation(
          LatLng(position.latitude, position.longitude),
        );
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          14,
        );
    } catch (e) {
      // Silently handle — user location is optional enhancement
    }
  }

  void _handleSOS() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uiState = ref.read(mapUiProvider);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return _SOSOptionsBottomSheet(
            userId: user.uid,
            userName: user.displayName ?? "Student",
            lat: uiState.userLocation.latitude,
            lng: uiState.userLocation.longitude,
          );
        },
      );
    }
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
}

/// Custom painter for the marker's downward pointer triangle
class _MarkerPointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = AppColors.primaryNavy
          ..style = PaintingStyle.fill;

    final path =
        ui.Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width / 2, size.height)
          ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AnimatedBusMarker extends ConsumerWidget {
  final String id;
  final Map<String, dynamic> data;
  final double heading;
  final EtaInfo? etaInfo;
  final VoidCallback onTap;

  const AnimatedBusMarker({
    super.key,
    required this.id,
    required this.data,
    required this.heading,
    this.etaInfo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gender = data['gender'] ?? 'Combined';
    final genderConfigs = ref.watch(genderConfigProvider).genderConfigs;
    
    Color markerColor = const Color(0xFF000080); // Default Navy
    
    if (genderConfigs.containsKey(gender)) {
      final colorStr = genderConfigs[gender]['color'] as String?;
      if (colorStr != null) {
        try {
          String cleanColor = colorStr.replaceAll('#', '').replaceAll('0x', '');
          if (cleanColor.length == 6) cleanColor = 'FF$cleanColor';
          markerColor = Color(int.parse(cleanColor, radix: 16));
        } catch (e) {}
      }
    } else if (gender == 'Girls') {
      markerColor = Colors.pinkAccent;
    } else if (gender == 'Boys') {
      markerColor = Colors.blueAccent;
    }

    final etaText = data['remainingTime'] != null && (data['remainingTime'] as String).isNotEmpty
        ? data['remainingTime']
        : (etaInfo?.etaMarkerDisplay ?? "---");

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _PulseEffect(color: markerColor),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: markerColor,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: markerColor.withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    etaText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: markerColor, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: markerColor.withOpacity(0.1),
                        child: Icon(
                          Icons.directions_bus_rounded,
                          color: markerColor,
                          size: 18,
                        ),
                      ),
                    ),
                    Transform.rotate(
                      angle: (heading * (3.14159 / 180)),
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: Stack(
                          children: [
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Icon(
                                Icons.navigation_rounded,
                                color: markerColor,
                                size: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseEffect extends StatefulWidget {
  final Color color;
  const _PulseEffect({required this.color});

  @override
  State<_PulseEffect> createState() => _PulseEffectState();
}

class _PulseEffectState extends State<_PulseEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.6, end: 0.0).animate(_controller),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.5, end: 1.2).animate(_controller),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class _SOSOptionsBottomSheet extends StatefulWidget {
  final String userId;
  final String userName;
  final double lat;
  final double lng;

  const _SOSOptionsBottomSheet({
    required this.userId,
    required this.userName,
    required this.lat,
    required this.lng,
  });

  @override
  State<_SOSOptionsBottomSheet> createState() => _SOSOptionsBottomSheetState();
}

class _SOSOptionsBottomSheetState extends State<_SOSOptionsBottomSheet> {
  final TextEditingController _customReasonController = TextEditingController();
  Timer? _countdownTimer;
  int _secondsRemaining = 5;
  bool _isSending = false;

  final List<Map<String, dynamic>> _presets = [
    {
      'label': 'Accident / Hadsa',
      'icon': Icons.car_crash_rounded,
      'color': Colors.red[800]!,
      'message': 'Accident / Collision reported.',
    },
    {
      'label': 'Medical Emergency',
      'icon': Icons.medical_services_rounded,
      'color': Colors.redAccent,
      'message': 'Medical assistance needed.',
    },
    {
      'label': 'Security / Threat',
      'icon': Icons.security_rounded,
      'color': Colors.red[900]!,
      'message': 'Harassment / Security threat reported.',
    },
    {
      'label': 'Bus Breakdown',
      'icon': Icons.build_rounded,
      'color': Colors.amber[800]!,
      'message': 'Technical breakdown reported.',
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
        _sendAlert('General Panic SOS triggered.');
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
      Map<String, dynamic>? studentDetails;
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
        if (doc.exists) {
          studentDetails = doc.data();
        }
      } catch (e) {
        debugPrint("Error loading student details for SOS: $e");
      }

      final Map<String, dynamic> extraDetails = {
        'role': 'Student',
      };
      if (studentDetails != null) {
        if (studentDetails['studentId'] != null) extraDetails['studentId'] = studentDetails['studentId'];
        if (studentDetails['rollNo'] != null) extraDetails['rollNo'] = studentDetails['rollNo'];
        if (studentDetails['regNo'] != null) extraDetails['regNo'] = studentDetails['regNo'];
        if (studentDetails['department'] != null) extraDetails['department'] = studentDetails['department'];
        if (studentDetails['semester'] != null) extraDetails['semester'] = studentDetails['semester'];
        if (studentDetails['phoneNumber'] != null) extraDetails['phoneNumber'] = studentDetails['phoneNumber'];
        if (studentDetails['phone'] != null) extraDetails['phone'] = studentDetails['phone'];
        if (studentDetails['email'] != null) extraDetails['email'] = studentDetails['email'];
        if (studentDetails['gender'] != null) extraDetails['gender'] = studentDetails['gender'];
        if (studentDetails['genderPreference'] != null) extraDetails['genderPreference'] = studentDetails['genderPreference'];
        if (studentDetails['profileImage'] != null) extraDetails['profileImage'] = studentDetails['profileImage'];
        if (studentDetails['profileUrl'] != null) extraDetails['profileUrl'] = studentDetails['profileUrl'];
        if (studentDetails['isVerified'] != null) extraDetails['isVerified'] = studentDetails['isVerified'];
        if (studentDetails['isBlocked'] != null) extraDetails['isBlocked'] = studentDetails['isBlocked'];
        if (studentDetails['status'] != null) extraDetails['status'] = studentDetails['status'];
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
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.emergency_rounded, color: Colors.red, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'EMERGENCY SOS',
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
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
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
                'If possible, select a reason below for faster dispatch:',
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
                        color: color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
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
                  hintText: 'Or type custom emergency reason here...',
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
                        _sendAlert('General Panic SOS triggered.');
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
                      onPressed: () => _sendAlert('General Panic SOS triggered.'),
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
