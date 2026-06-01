import 'package:latlong2/latlong.dart';

class CampusLocations {
  // Official Hub Names
  static const String baghdadName = "Baghdad Campus";
  static const String abbasiaName = "Abbasia Campus";
  static const String railwayName = "Railway Campus";


  // ⚡ FIXED: Baghdad Campus is now exactly at the end of the professional polyline
  static final LatLng baghdadCampus = LatLng(29.378047555871532, 71.75750718286565); 
  
  // Abbasia Campus aligned with the route start
  static final LatLng abbasiaCampus = LatLng(29.398239582972707, 71.69205655369649); 

  static const double arrivalRadiusMeters = 500.0; // 500m radius
}
