/// Model representing a live bus location broadcast via Firebase RTDB.
/// This provides type-safe access to bus tracking data instead of raw Maps.
class BusLocation {
  final String busNumber;
  final String driverId;
  final String driverName;
  final String plateNumber;
  final double latitude;
  final double longitude;
  final double heading;
  final double speed;
  final String from;
  final String to;
  final String gender;
  final String status;
  final String departureTime;
  final String arrivalTime;
  final int lastUpdated;

  BusLocation({
    required this.busNumber,
    required this.driverId,
    required this.driverName,
    this.plateNumber = '',
    required this.latitude,
    required this.longitude,
    this.heading = 0.0,
    this.speed = 0.0,
    required this.from,
    required this.to,
    this.gender = 'Combined',
    this.status = 'active',
    this.departureTime = '',
    this.arrivalTime = '',
    this.lastUpdated = 0,
  });

  /// Creates a BusLocation from a Firebase RTDB snapshot map.
  /// Backward-compatible: handles missing fields gracefully with defaults.
  factory BusLocation.fromMap(String busId, Map<dynamic, dynamic> map) {
    return BusLocation(
      busNumber: busId,
      driverId: (map['driverId'] ?? '').toString(),
      driverName: (map['driverName'] ?? 'Driver').toString(),
      plateNumber: (map['plateNumber'] ?? '').toString(),
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      heading: (map['heading'] as num?)?.toDouble() ?? 0.0,
      speed: (map['speed'] as num?)?.toDouble() ?? 0.0,
      from: (map['from'] ?? '').toString(),
      to: (map['to'] ?? '').toString(),
      gender: (map['gender'] ?? 'Combined').toString(),
      status: (map['status'] ?? 'active').toString(),
      departureTime: (map['departureTime'] ?? '').toString(),
      arrivalTime: (map['arrivalTime'] ?? '').toString(),
      lastUpdated: (map['lastUpdated'] as num?)?.toInt() ?? 0,
    );
  }

  /// Converts to Map for Firebase RTDB writes.
  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'driverName': driverName,
      'busNumber': busNumber,
      'plateNumber': plateNumber,
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speed': speed,
      'from': from,
      'to': to,
      'gender': gender,
      'status': status,
      'departureTime': departureTime,
      'arrivalTime': arrivalTime,
      'lastUpdated': lastUpdated,
    };
  }

  /// Whether this bus has a valid GPS position (not default 0,0).
  bool get hasValidPosition => latitude != 0.0 || longitude != 0.0;

  /// Whether the bus is currently active/tracking.
  bool get isActive => status == 'active';

  BusLocation copyWith({
    String? busNumber,
    String? driverId,
    String? driverName,
    String? plateNumber,
    double? latitude,
    double? longitude,
    double? heading,
    double? speed,
    String? from,
    String? to,
    String? gender,
    String? status,
    String? departureTime,
    String? arrivalTime,
    int? lastUpdated,
  }) {
    return BusLocation(
      busNumber: busNumber ?? this.busNumber,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      plateNumber: plateNumber ?? this.plateNumber,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      from: from ?? this.from,
      to: to ?? this.to,
      gender: gender ?? this.gender,
      status: status ?? this.status,
      departureTime: departureTime ?? this.departureTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
