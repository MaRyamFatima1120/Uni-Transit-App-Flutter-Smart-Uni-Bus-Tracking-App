import 'package:firebase_database/firebase_database.dart';
import 'package:uni_transit/core/util/logger.dart';

class SOSService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('emergency_alerts');

  Future<void> sendSOS({
    required String userId,
    required String userName,
    required double lat,
    required double lng,
    required String message,
    Map<String, dynamic>? extraDetails,
  }) async {
    try {
      final String alertId = _dbRef.push().key!;
      final Map<String, dynamic> payload = {
        'userId': userId,
        'userName': userName,
        'latitude': lat,
        'longitude': lng,
        'message': message,
        'timestamp': ServerValue.timestamp,
        'status': 'active',
      };
      if (extraDetails != null) {
        payload.addAll(extraDetails);
      }
      await _dbRef.child(alertId).set(payload);
      AppLogger.info("SOS Alert Sent: $alertId");
    } catch (e) {
      AppLogger.error("Failed to send SOS: $e");
      rethrow;
    }
  }
}
