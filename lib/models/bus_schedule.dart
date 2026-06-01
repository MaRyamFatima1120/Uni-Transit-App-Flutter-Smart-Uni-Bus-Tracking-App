class BusSchedule {
  final String id;
  final String busNumber;
  final String route;
  final String departureTime;
  final List<String> stops;
  final String type; // Boys Special, Girls Special, Combined
  final List<String>? operatingDays; // e.g. ["Monday", "Tuesday"]
  final String? date; // Specific date in YYYY-MM-DD format

  BusSchedule({
    required this.id,
    required this.busNumber,
    required this.route,
    required this.departureTime,
    required this.stops,
    required this.type,
    this.operatingDays,
    this.date,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'busNumber': busNumber,
      'route': route,
      'departureTime': departureTime,
      'stops': stops,
      'type': type,
      'operatingDays': operatingDays ?? [],
      'date': date,
    };
  }

  // Create Object from Firestore Map
  factory BusSchedule.fromMap(String id, Map<String, dynamic> map) {
    return BusSchedule(
      id: id,
      busNumber: map['busNumber'] ?? map['bus_number'] ?? '',
      route: map['route'] ?? '',
      departureTime: map['departureTime'] ?? map['departure_time'] ?? '',
      stops: List<String>.from(map['stops'] ?? []),
      type: map['type'] ?? 'Combined',
      operatingDays: map['operatingDays'] != null 
          ? List<String>.from(map['operatingDays']) 
          : (map['operating_days'] != null ? List<String>.from(map['operating_days']) : null),
      date: map['date'],
    );
  }
}

