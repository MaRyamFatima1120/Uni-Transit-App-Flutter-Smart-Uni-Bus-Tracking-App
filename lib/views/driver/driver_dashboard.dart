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
import 'package:uni_transit/core/routes/app_routes.dart';
import 'package:uni_transit/services/sos_service.dart';
import 'package:uni_transit/services/notification_service.dart';
import 'package:uni_transit/view_models/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uni_transit/views/common/sos_review_bottom_sheet.dart';

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
        ref.read(driverTripProvider.notifier).restoreActiveTrip(user.uid);
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
    if (!tripState.isTripStarted) {
      ref.read(driverTripProvider.notifier).updateInputs(
        bus: _busNumberController.text.trim(),
        plate: _plateNumberController.text.trim(),
      );
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
      if (previous == null || previous.busNumber != next.busNumber) {
        _busNumberController.text = next.busNumber;
      }
      if (previous == null || previous.plateNumber != next.plateNumber) {
        _plateNumberController.text = next.plateNumber;
      }
    });

    final tripState = ref.watch(driverTripProvider);

    if (tripState.isTripStarted && _busNumberController.text.isEmpty) {
      _busNumberController.text = tripState.busNumber;
      _plateNumberController.text = tripState.plateNumber;
    }

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
              if (tripState.isTripStarted && tripState.to != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _getHubPos(tripState.to!), 
                    width: 100, height: 120, 
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _buildHubMarker(tripState.to!, Colors.redAccent, true),
                    )
                  ),
                  if (tripState.from != null)
                    Marker(
                      point: _getHubPos(tripState.from!), 
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
          if (tripState.isTripStarted) Positioned(top: 50, left: 20, right: 20, child: _buildNavigationBanner(tripState)),
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
            bottom: MediaQuery.of(context).size.height * (tripState.isTripStarted ? 0.35 : 0.6) + 20, 
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
          DraggableScrollableSheet(
            initialChildSize: tripState.isTripStarted ? 0.35 : 0.6,
            minChildSize: 0.15,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
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
                      const SizedBox(height: 16),
                      
                      if (!tripState.isTripStarted) 
                        _buildConfigUI(tripState) 
                      else 
                        _buildActiveTripStatus(tripState),
                      
                      const SizedBox(height: 24),
                      
                      SizedBox(
                        width: double.infinity, 
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _onToggle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tripState.isTripStarted ? Colors.red : AppColors.primaryNavy, 
                            foregroundColor: Colors.white, 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                          ),
                          child: Text(
                            tripState.isTripStarted ? "TERMINATE TRIP" : "COMMENCE TRACKING", 
                            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)
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
    return Column(children: [
        Text("READY TO DEPART", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryNavy, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        TextField(controller: _busNumberController, decoration: InputDecoration(hintText: "Bus ID", prefixIcon: const Icon(Icons.numbers, size: 20), filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
        const SizedBox(height: 12),
        TextField(controller: _plateNumberController, decoration: InputDecoration(hintText: "Plate Number", prefixIcon: const Icon(Icons.credit_card, size: 20), filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
        const SizedBox(height: 16),
        _buildGenderSelector(state),
        const SizedBox(height: 16),
        _buildRoutePicker("Beginning Hub", state.from, (v) => ref.read(driverTripProvider.notifier).updateInputs(from: v)),
        const SizedBox(height: 12),
        _buildRoutePicker("Destination Hub", state.to, (v) => ref.read(driverTripProvider.notifier).updateInputs(to: v)),
    ]);
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
            if (state.speed > 0.5) 
              _buildActiveInfo("SPEED", "${state.speed.toStringAsFixed(0)} m/s"), 
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
                          color: Colors.red.withOpacity(0.1),
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
