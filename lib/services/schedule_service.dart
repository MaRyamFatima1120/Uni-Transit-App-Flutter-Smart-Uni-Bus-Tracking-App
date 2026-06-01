import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uni_transit/models/bus_schedule.dart';

class ScheduleService {
  final CollectionReference _schedulesRef = FirebaseFirestore.instance
      .collection('schedules');

  // Add a new Schedule (Admin/Driver)
  Future<void> addSchedule(BusSchedule schedule) async {
    try {
      await _schedulesRef.add(schedule.toMap());
    } catch (e) {
      throw Exception("Failed to add schedule: $e");
    }
  }

  // Get Stream of Schedules (For Real-time updates)
  Stream<List<BusSchedule>> getSchedules() {
    return _schedulesRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return BusSchedule.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  // Delete Schedule
  Future<void> deleteSchedule(String id) async {
    await _schedulesRef.doc(id).delete();
  }
}

