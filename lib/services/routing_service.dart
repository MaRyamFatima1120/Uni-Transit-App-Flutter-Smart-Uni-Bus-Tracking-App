import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:uni_transit/core/util/logger.dart';

class RouteData {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  RouteData({required this.points, required this.distanceMeters, required this.durationSeconds});
}

class RoutingService {
  static const String _baseUrl = 'https://router.project-osrm.org/route/v1/driving/';

  /// Fetches the road-based polyline points and trip metadata with optional Waypoints
  /// [points] should include [Start, ...Waypoints, End]
  static Future<RouteData?> getFullRoute(List<LatLng> points) async {
    if (points.length < 2) return null;

    // Road Strictness: Using OSRM with multiple points ensures the route 
    // follows the specific 'University Road' if waypoints are provided.
    final coordsString = points.map((p) => '${p.longitude},${p.latitude}').join(';');
    final url = Uri.parse('$_baseUrl$coordsString?overview=full&geometries=geojson');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final List coordinates = route['geometry']['coordinates'];
          
          return RouteData(
            points: coordinates.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList(),
            distanceMeters: (route['distance'] as num).toDouble(),
            durationSeconds: (route['duration'] as num).toDouble(),
          );
        }
      }
    } catch (e) {
      AppLogger.error("Failed to fetch route: $e");
    }
    return null;
  }

  static Future<List<LatLng>> getRoute(List<LatLng> points) async {
    final data = await getFullRoute(points);
    return data?.points ?? points;
  }
}
