import 'package:firebase_database/firebase_database.dart';
import 'package:uni_transit/core/util/logger.dart';

class TripAlertService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('trip_alerts');

  /// Publishes a trip start alert to Firebase RTDB for students to see.
  /// This also acts as a log for the Admin Panel.
  Future<void> publishTripStart({
    required String busId,
    required String from,
    required String to,
    required String driverName,
  }) async {
    try {
      final String alertId = _dbRef.push().key!;
      await _dbRef.child(alertId).set({
        'busId': busId,
        'from': from,
        'to': to,
        'driverName': driverName,
        'timestamp': ServerValue.timestamp,
        'type': 'trip_started',
      });
      AppLogger.info("Trip Alert Published: $busId");
    } catch (e) {
      AppLogger.error("Failed to publish trip alert: $e");
    }
  }

  /// Publishes a trip completion alert to Firebase RTDB for students and Admin.
  Future<void> publishTripEnd({
    required String busId,
    required String from,
    required String to,
    required String driverName,
  }) async {
    try {
      final String alertId = _dbRef.push().key!;
      await _dbRef.child(alertId).set({
        'busId': busId,
        'from': from,
        'to': to,
        'driverName': driverName,
        'timestamp': ServerValue.timestamp,
        'type': 'trip_completed',
      });
      AppLogger.info("Trip End Alert Published: $busId");
    } catch (e) {
      AppLogger.error("Failed to publish trip end alert: $e");
    }
  }

  /// Listens for new trip alerts and triggers a callback.
  /// Throttles to only show alerts created after the listener started.
  Stream<Map<String, dynamic>> get alertStream {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    
    return _dbRef
        .orderByChild('timestamp')
        .startAt(startTime)
        .onChildAdded
        .map((event) {
          if (event.snapshot.value != null) {
            return Map<String, dynamic>.from(event.snapshot.value as Map);
          }
          return {};
        });
  }
}
