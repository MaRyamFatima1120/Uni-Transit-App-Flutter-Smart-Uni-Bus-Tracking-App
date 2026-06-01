import 'package:latlong2/latlong.dart';

/// Structured ETA information for a bus relative to a destination.
/// Replaces hardcoded "~12 MIN" strings with real-time calculations.
class EtaInfo {
  /// Remaining distance in meters
  final double distanceMeters;

  /// Estimated remaining time in seconds
  final double durationSeconds;

  /// Timestamp when this ETA was last calculated
  final DateTime calculatedAt;

  EtaInfo({
    required this.distanceMeters,
    required this.durationSeconds,
    DateTime? calculatedAt,
  }) : calculatedAt = calculatedAt ?? DateTime.now();

  /// Human-readable distance string (e.g., "2.3 KM" or "850 M")
  String get distanceDisplay {
    if (distanceMeters >= 1000) {
      return "${(distanceMeters / 1000).toStringAsFixed(1)} KM";
    }
    return "${distanceMeters.toInt()} M";
  }

  /// Human-readable ETA string (e.g., "12 MIN" or "1h 5m")
  String get etaDisplay {
    final minutes = (durationSeconds / 60).ceil();
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return "${hours}h ${mins}m";
    }
    return "$minutes MIN";
  }

  /// Short ETA string for map markers (e.g., "~12 MIN")
  String get etaMarkerDisplay => "~$etaDisplay";

  /// Whether the ETA is still fresh (calculated within last 30 seconds)
  bool get isFresh =>
      DateTime.now().difference(calculatedAt).inSeconds < 30;

  /// Quick straight-line ETA estimation without routing API.
  /// Uses Haversine distance and an average urban bus speed of 25 km/h.
  /// Falls back to this when routing API is unavailable.
  static EtaInfo estimateFromCoordinates(LatLng busPos, LatLng destination) {
    const averageBusSpeedKmh = 25.0;
    final distance = const Distance().as(LengthUnit.Meter, busPos, destination);

    // Apply a road-factor of 1.3x to straight-line distance for more realistic ETA
    final adjustedDistance = distance * 1.3;
    final durationSeconds = (adjustedDistance / 1000) / averageBusSpeedKmh * 3600;

    return EtaInfo(
      distanceMeters: adjustedDistance,
      durationSeconds: durationSeconds,
    );
  }
}
