import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uni_transit/core/util/logger.dart';

class LocationService {
  final DatabaseReference _busesRef = FirebaseDatabase.instance.ref('buses');
  final DatabaseReference _tripsRef = FirebaseDatabase.instance.ref('driver_trips');

  /// 🔋 BATTERY OPT: Driver GPS stream — high accuracy, 10m filter (was 5m)
  /// 10m reduces GPS wake-ups by ~50% while still providing smooth bus tracking
  Stream<Position> get locationStream => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
      // timeLimit sets max time between position updates
    ),
  );

  /// 🔋 BATTERY OPT: Student GPS — low accuracy, only for "my location" dot
  /// Uses significantly less battery since students don't need precise GPS
  Stream<Position> get studentLocationStream => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 50,
    ),
  );

  /// Checks and requests location permission. Returns true if granted.
  /// Shows the system permission dialog if not yet decided.
  static Future<bool> handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Step 1: Check if location services (GPS) are enabled on the device
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      AppLogger.warning("Location services are disabled on device");
      return false;
    }

    // Step 2: Check current permission status
    permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      // Step 3: Request permission — this shows the system dialog
      AppLogger.info("Requesting location permission from user...");
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        AppLogger.warning("Location permission denied by user");
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // User permanently denied — must open app settings manually
      AppLogger.warning("Location permission permanently denied");
      return false;
    }
    
    AppLogger.info("Location permission granted: $permission");
    return true;
  }

  /// Returns the current permission status without requesting.
  static Future<LocationPermission> checkPermissionStatus() async {
    return await Geolocator.checkPermission();
  }

  /// Opens the device's app settings page so user can manually enable permissions.
  static Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Opens the device's location settings page so user can enable GPS.
  static Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  Future<void> startSharingLocation(
    String uid, String busNumber, {
    required String from, required String to, 
    required String gender, required String driverName,
    required String departureTime, required String arrivalTime,
    required double lat, required double lng,
    String plateNumber = "",
    String remainingTime = "Calculating...",
    String remainingDistance = "Calculating...",
    String scheduleId = "",
  }) async {

    final tripId = DateTime.now().millisecondsSinceEpoch.toString();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
    
    // Validate inputs before writing to RTDB
    if (busNumber.trim().isEmpty) {
      throw Exception("Bus number cannot be empty");
    }
    if (from.trim().isEmpty || to.trim().isEmpty) {
      throw Exception("Origin and destination are required");
    }
    
    await _busesRef.child(busNumber).set({
      'driverId': uid,
      'driverName': driverName,
      'busNumber': busNumber,
      'plateNumber': plateNumber,
      'latitude': lat,
      'longitude': lng,
      'heading': 0.0,
      'speed': 0.0,
      'from': from,
      'to': to,
      'gender': gender,
      'status': 'active',
      'departureTime': departureTime,
      'arrivalTime': arrivalTime,
      'remainingTime': remainingTime,
      'remainingDistance': remainingDistance,
      'scheduleId': scheduleId,
      'tripId': tripId,
      'lastUpdated': ServerValue.timestamp,
    });

    await _tripsRef.child(uid).child(tripId).set({
      'tripId': tripId,
      'driverName': driverName,
      'busNumber': busNumber,
      'plateNumber': plateNumber,
      'from': from,
      'to': to,
      'gender': gender,
      'startTime': ServerValue.timestamp,
      'status': 'active',
      'scheduleId': scheduleId,
      'departureTime': departureTime,
      'date': todayStr,
    });

    // ⚡ REAL-TIME SYNC: Update Firestore status so Admin Panel sees driver as Online
    try {
      await FirebaseFirestore.instance.collection('drivers').doc(uid).update({'status': 'Online'});
    } catch (e) {
      AppLogger.warning("Failed to update Firestore status to Online: $e");
    }

    // Write to Firestore 'trips' collection
    try {
      await FirebaseFirestore.instance.collection('trips').doc(tripId).set({
        'tripId': tripId,
        'driverId': uid,
        'driverName': driverName,
        'busNumber': busNumber,
        'plateNumber': plateNumber,
        'from': from,
        'to': to,
        'gender': gender,
        'startTime': FieldValue.serverTimestamp(),
        'status': 'active',
        'scheduleId': scheduleId,
        'departureTime': departureTime,
        'date': todayStr,
      });
    } catch (e) {
      AppLogger.warning("Failed to write to Firestore trips collection: $e");
    }

    // Write to Firestore 'active_trips' collection
    try {
      await FirebaseFirestore.instance.collection('active_trips').doc(tripId).set({
        'tripId': tripId,
        'driverId': uid,
        'driverName': driverName,
        'busNumber': busNumber,
        'plateNumber': plateNumber,
        'from': from,
        'to': to,
        'gender': gender,
        'startTime': FieldValue.serverTimestamp(),
        'status': 'active',
        'scheduleId': scheduleId,
        'departureTime': departureTime,
        'date': todayStr,
      });
    } catch (e) {
      AppLogger.warning("Failed to write to Firestore active_trips collection: $e");
    }
  }

  /// Updates the live tracking data for a bus in RTDB.
  /// Now includes speed tracking and real-time ETA for students.
  Future<void> updateTracking(
    String busNumber, 
    double lat, 
    double lng, 
    double heading, {
    double speed = 0.0,
    String remainingTime = "",
    String remainingDistance = "",
    String arrivalTime = "",
  }) async {
    // Validate coordinates before writing
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      AppLogger.warning("Invalid coordinates rejected: ($lat, $lng)");
      return;
    }
    
    await _busesRef.child(busNumber).update({
      'latitude': lat,
      'longitude': lng,
      'heading': heading,
      'speed': speed,
      'remainingTime': remainingTime,
      if (remainingDistance.isNotEmpty) 'remainingDistance': remainingDistance,
      'arrivalTime': arrivalTime,
      'lastUpdated': ServerValue.timestamp,
    });
  }

  /// Stops location sharing: removes the bus from RTDB and marks the trip as completed.
  /// Fixed: uses 'completed' consistently (matching trip_history_screen checks).
  /// Stops location sharing: removes the bus and ensures ALL active trips for this driver are marked completed.
  Future<void> stopSharingLocation(String uid, String busNumber, String tripId) async {
    // 1. Remove the live bus entry
    await _busesRef.child(busNumber).remove();
    
    // Fetch trip details from RTDB first so we can write to Firestore completed_trips with full info
    Map<String, dynamic>? tripData;
    try {
      final tripSnap = await _tripsRef.child(uid).child(tripId).get();
      if (tripSnap.exists) {
        tripData = Map<String, dynamic>.from(tripSnap.value as Map);
      }
    } catch (e) {
      AppLogger.warning("Failed to fetch trip details from RTDB for Firestore sync: $e");
    }

    // 2. Mark the specific trip as completed in RTDB
    await _tripsRef.child(uid).child(tripId).update({
      'endTime': ServerValue.timestamp,
      'status': 'completed',
    });

    // ⚡ REAL-TIME SYNC: Update Firestore status so Admin Panel sees driver as Offline
    try {
      await FirebaseFirestore.instance.collection('drivers').doc(uid).update({'status': 'Offline'});
    } catch (e) {
      AppLogger.warning("Failed to update Firestore status to Offline: $e");
    }

    // Update Firestore 'trips' collection to status = completed
    try {
      await FirebaseFirestore.instance.collection('trips').doc(tripId).update({
        'endTime': FieldValue.serverTimestamp(),
        'status': 'completed',
      });
    } catch (e) {
      AppLogger.warning("Failed to update Firestore trips collection: $e");
    }

    // Delete Firestore 'active_trips' collection
    try {
      await FirebaseFirestore.instance.collection('active_trips').doc(tripId).delete();
    } catch (e) {
      AppLogger.warning("Failed to delete from Firestore active_trips: $e");
    }

    // Add to Firestore 'completed_trips' collection
    try {
      await FirebaseFirestore.instance.collection('completed_trips').doc(tripId).set({
        'tripId': tripId,
        'driverId': uid,
        'driverName': tripData?['driverName'] ?? 'Driver',
        'busNumber': busNumber,
        'plateNumber': tripData?['plateNumber'] ?? '',
        'from': tripData?['from'] ?? 'Unknown',
        'to': tripData?['to'] ?? 'Unknown',
        'gender': tripData?['gender'] ?? 'Combined',
        'startTime': tripData?['startTime'] != null 
            ? Timestamp.fromMillisecondsSinceEpoch(tripData!['startTime'] as int) 
            : FieldValue.serverTimestamp(),
        'endTime': FieldValue.serverTimestamp(),
        'status': 'completed',
        'scheduleId': tripData?['scheduleId'] ?? '',
        'date': tripData?['date'] ?? DateTime.now().toIso8601String().substring(0, 10),
        'revenue': 0.0,
      });
    } catch (e) {
      AppLogger.warning("Failed to write to Firestore completed_trips collection: $e");
    }

    // 3. 🧹 CLEANUP: Find any other 'active' trips that might be stuck and close them
    // This prevents "ghost" ongoing trips from appearing in history
    final snapshot = await _tripsRef.child(uid).orderByChild('status').equalTo('active').get();
    if (snapshot.exists) {
      final updates = <String, dynamic>{};
      final data = snapshot.value as Map;
      data.forEach((key, value) {
        final stId = key.toString();
        updates['$stId/status'] = 'completed';
        updates['$stId/endTime'] = ServerValue.timestamp;
        
        // Also cleanup corresponding Firestore docs
        FirebaseFirestore.instance.collection('trips').doc(stId).update({
          'endTime': FieldValue.serverTimestamp(),
          'status': 'completed',
        }).catchError((_) {});
        
        FirebaseFirestore.instance.collection('active_trips').doc(stId).delete().catchError((_) {});
      });
      await _tripsRef.child(uid).update(updates);
    }
  }


  Future<Map<String, dynamic>?> getActiveTrip(String uid) async {
    final snapshot = await _tripsRef.child(uid).orderByChild('status').equalTo('active').limitToFirst(1).get();
    if (snapshot.exists) {
      final data = snapshot.value as Map;
      return Map<String, dynamic>.from(data.values.first);
    }
    return null;
  }

  /// Restores bus tracking entry in RTDB when driver returns to an active trip.
  /// Previously a no-op — now re-establishes the bus entry if the trip is still active.
  Future<void> restoreTracking(String uid, String busNumber) async {
    try {
      final activeTrip = await getActiveTrip(uid);
      if (activeTrip == null) return;
      
      // Check if bus entry still exists in RTDB
      final busSnapshot = await _busesRef.child(busNumber).get();
      if (!busSnapshot.exists) {
        // Re-create the bus entry from the active trip data
        AppLogger.info("Restoring bus tracking for $busNumber");
        await _busesRef.child(busNumber).set({
          'driverId': uid,
          'driverName': activeTrip['driverName'] ?? 'Driver',
          'busNumber': busNumber,
          'plateNumber': activeTrip['plateNumber'] ?? '',
          'latitude': 0.0,
          'longitude': 0.0,
          'heading': 0.0,
          'speed': 0.0,
          'from': activeTrip['from'] ?? '',
          'to': activeTrip['to'] ?? '',
          'gender': activeTrip['gender'] ?? 'Combined',
          'status': 'active',
          'departureTime': 'Restored',
          'arrivalTime': 'Pending',
          'lastUpdated': ServerValue.timestamp,
        });
      }
    } catch (e) {
      AppLogger.error("Failed to restore tracking: $e");
    }
  }

  /// Fetches the entire trip history for a specific driver
  Future<List<Map<String, dynamic>>> getTripHistory(String uid) async {
    final snapshot = await _tripsRef.child(uid).get();
    if (snapshot.exists) {
       final data = snapshot.value as Map;
       final List<Map<String, dynamic>> history = [];
       data.forEach((key, value) {
         history.add(Map<String, dynamic>.from(value as Map));
       });
       // Sort by start time (newest first)
       history.sort((a, b) => (b['startTime'] ?? 0).compareTo(a['startTime'] ?? 0));
       return history;
    }
    return [];
  }

  /// Stream of trip history for a specific driver
  Stream<List<Map<String, dynamic>>> getTripHistoryStream(String uid) {
    return _tripsRef.child(uid).onValue.map((event) {
      if (event.snapshot.value == null) return [];
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final List<Map<String, dynamic>> history = [];
      data.forEach((key, value) {
        history.add(Map<String, dynamic>.from(value as Map));
      });
      // Sort by start time (newest first)
      history.sort((a, b) => (b['startTime'] ?? 0).compareTo(a['startTime'] ?? 0));
      return history;
    });
  }

  /// Listens to all active buses for student-side tracking
  Stream<DatabaseEvent> get activeBusesStream => _busesRef.onValue;
}

