import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';


import 'package:uni_transit/widgets/custom_app_bar.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final DatabaseReference _busesRef = FirebaseDatabase.instance.ref('buses');
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: "Live Bus Tracking"),
      body: StreamBuilder<DatabaseEvent>(
        stream: _busesRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          List<Marker> markers = [];
          Map<dynamic, dynamic> buses = {};

          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            buses = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

            buses.forEach((key, value) {
              final busNum = key.toString();
              final busData = value as Map<dynamic, dynamic>;

              final double lat = busData['latitude'] ?? 0.0;
              final double lng = busData['longitude'] ?? 0.0;
              final String status = busData['status'] ?? 'Unknown';
              final String driverId = busData['driverId'] ?? 'Unknown';

              markers.add(
                Marker(
                  point: LatLng(lat, lng),
                  width: 100,
                  height: 100,
                  child: GestureDetector(
                    onTap: () {
                      _showBusDetails(
                        context,
                        busNum,
                        status,
                        driverId,
                        busData['speed']?.toString() ?? '0',
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 2),
                            ],
                          ),
                          child: Text(
                            busNum,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.directions_bus,
                          color: Colors.orange,
                          size: 35,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            });
          }

          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(29.3794, 71.6707), // IUB BJ Campus
              initialZoom: 14.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all, // Enables Scroll Wheel Zoom
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.uni_transit',
              ),
              MarkerLayer(markers: markers),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "admin_zoom_in",
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () {
              final currentZoom = _mapController.camera.zoom;
              _mapController.move(
                _mapController.camera.center,
                currentZoom + 1,
              );
            },
            child: const Icon(Icons.add, color: Colors.black),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "admin_zoom_out",
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () {
              final currentZoom = _mapController.camera.zoom;
              _mapController.move(
                _mapController.camera.center,
                currentZoom - 1,
              );
            },
            child: const Icon(Icons.remove, color: Colors.black),
          ),
        ],
      ),
    );
  }

  void _showBusDetails(
    BuildContext context,
    String busNum,
    String status,
    String driverId,
    String speed,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Bus #$busNum",
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _detailRow(Icons.info_outline, "Status", status),
                const SizedBox(height: 12),
                _detailRow(Icons.speed, "Speed", "$speed m/s"),
                const SizedBox(height: 12),
                _detailRow(Icons.person, "Driver ID", driverId),
                const SizedBox(height: 24),
              ],
            ),
          ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.blueGrey, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
