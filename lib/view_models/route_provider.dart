import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants/campus_locations.dart';
import '../core/constants/custom_routes.dart';

class RouteState {
  final Map<String, dynamic> officialRoutes;
  final Map<String, List<LatLng>> manualRoutes;
  final String? selectedRoute;
  final List<LatLng> routePoints;
  final String? fromHub;
  final String? toHub;
  final bool isFetching;

  RouteState({
    this.officialRoutes = const {},
    this.manualRoutes = const {},
    this.selectedRoute,
    this.routePoints = const [],
    this.fromHub,
    this.toHub,
    this.isFetching = false,
  });

  RouteState copyWith({
    Map<String, dynamic>? officialRoutes,
    Map<String, List<LatLng>>? manualRoutes,
    String? selectedRoute,
    bool clearSelectedRoute = false,
    List<LatLng>? routePoints,
    String? fromHub,
    bool clearHubs = false,
    String? toHub,
    bool? isFetching,
  }) {
    return RouteState(
      officialRoutes: officialRoutes ?? this.officialRoutes,
      manualRoutes: manualRoutes ?? this.manualRoutes,
      selectedRoute: clearSelectedRoute ? null : (selectedRoute ?? this.selectedRoute),
      routePoints: routePoints ?? this.routePoints,
      fromHub: clearHubs ? null : (fromHub ?? this.fromHub),
      toHub: clearHubs ? null : (toHub ?? this.toHub),
      isFetching: isFetching ?? this.isFetching,
    );
  }
}

class RouteNotifier extends Notifier<RouteState> {
  @override
  RouteState build() {
    _listenToOfficialRoutes();
    _listenToCustomPolylines();
    return RouteState();
  }

  void _listenToOfficialRoutes() {
    final sub = FirebaseDatabase.instance
        .ref('official_routes')
        .onValue
        .listen((event) {
      final Map<String, dynamic> mergedRoutes = {
        "Abbasia ➔ Baghdad": {
          "from": CampusLocations.abbasiaName,
          "to": CampusLocations.baghdadName,
        },
      };

      if (event.snapshot.value != null) {
        final rawData = Map<String, dynamic>.from(event.snapshot.value as Map);
        rawData.forEach((key, value) {
          String cleanKey = key.trim();
          if (cleanKey != "Abbasia ➔ Baghdad" && cleanKey != "Abbasia -> Baghdad") {
            mergedRoutes[cleanKey] = value;
          }
        });
      }

      state = state.copyWith(officialRoutes: mergedRoutes);
    });
    ref.onDispose(() => sub.cancel());
  }

  void _listenToCustomPolylines() {
    final sub = FirebaseDatabase.instance
        .ref('custom_polylines')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final Map<String, List<LatLng>> newRoutes = {};

        data.forEach((routeName, points) {
          if (points is List) {
            newRoutes[routeName] = points.map((p) {
              final point = Map<String, dynamic>.from(p as Map);
              return LatLng(
                (point['lat'] as num).toDouble(),
                (point['lng'] as num).toDouble(),
              );
            }).toList();
          }
        });

        state = state.copyWith(manualRoutes: newRoutes);
      }
    });
    ref.onDispose(() => sub.cancel());
  }

  void selectRoute(String routeName) {
    final data = state.officialRoutes[routeName];
    if (data == null) return;

    final from = data['from'] as String? ?? CampusLocations.baghdadName;
    final to = data['to'] as String? ?? CampusLocations.abbasiaName;

    state = state.copyWith(
      selectedRoute: routeName,
      fromHub: from,
      toHub: to,
      routePoints: [],
    );

    _calculatePoints(routeName);
  }

  void clearSelection() {
    state = state.copyWith(
      clearSelectedRoute: true,
      clearHubs: true,
      routePoints: [],
    );
  }

  void _calculatePoints(String routeName) {
    // 1. Try direct match
    final firebasePoints = state.manualRoutes[routeName];
    final localPoints = CustomRoutes.getRoutePoints(routeName);

    if (firebasePoints != null && firebasePoints.isNotEmpty) {
      state = state.copyWith(routePoints: firebasePoints);
      return;
    } else if (localPoints.isNotEmpty && localPoints.length > 2) {
      state = state.copyWith(routePoints: localPoints);
      return;
    }

    // 2. Try reversed match
    final parts = _splitRouteName(routeName);
    if (parts.length == 2) {
      final from = parts[0];
      final to = parts[1];
      final reversedKeys = [
        "$to ➔ $from",
        "$to -> $from",
        "$to → $from",
      ];

      for (final revKey in reversedKeys) {
        final revFbPoints = state.manualRoutes[revKey];
        if (revFbPoints != null && revFbPoints.isNotEmpty) {
          state = state.copyWith(routePoints: revFbPoints.reversed.toList());
          return;
        }

        final revLocalPoints = CustomRoutes.getRoutePoints(revKey);
        if (revLocalPoints.isNotEmpty && revLocalPoints.length > 2) {
          state = state.copyWith(routePoints: revLocalPoints.reversed.toList());
          return;
        }
      }
    }

    state = state.copyWith(routePoints: []);
  }

  List<String> _splitRouteName(String routeName) {
    if (routeName.contains('➔')) {
      return routeName.split('➔').map((s) => s.trim()).toList();
    } else if (routeName.contains('->')) {
      return routeName.split('->').map((s) => s.trim()).toList();
    } else if (routeName.contains('→')) {
      return routeName.split('→').map((s) => s.trim()).toList();
    }
    return [];
  }
}

final routeProvider = NotifierProvider<RouteNotifier, RouteState>(() {
  return RouteNotifier();
});
