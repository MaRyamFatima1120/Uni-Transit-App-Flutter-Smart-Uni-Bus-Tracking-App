import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../core/constants/campus_locations.dart';

class BusState {
  final Map<String, dynamic> liveBusData;
  BusState({this.liveBusData = const {}});
}

class BusNotifier extends Notifier<BusState> {
  @override
  BusState build() {
    _listenToBuses();
    return BusState();
  }

  void _listenToBuses() {
    final sub = FirebaseDatabase.instance.ref('buses').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final rawData = Map<String, dynamic>.from(event.snapshot.value as Map);
        state = BusState(liveBusData: rawData);
      } else {
        state = BusState(liveBusData: const {});
      }
    });
    ref.onDispose(() => sub.cancel());
  }
}

final busProvider = NotifierProvider<BusNotifier, BusState>(() {
  return BusNotifier();
});

class StopState {
  final Map<String, dynamic> stopsData;
  StopState({this.stopsData = const {}});
}

class StopNotifier extends Notifier<StopState> {
  @override
  StopState build() {
    _listenToStops();
    return StopState();
  }

  void _listenToStops() {
    final sub = FirebaseDatabase.instance.ref('stops').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final rawData = Map<String, dynamic>.from(event.snapshot.value as Map);
        state = StopState(stopsData: rawData);
      } else {
        state = StopState(stopsData: {
          "default_stop_1": {
            "name": "One Uni Point",
            "latitude": 29.3850,
            "longitude": 71.7350,
            "route": "Baghdad ➔ Abbasia",
          },
        });
      }
    });
    ref.onDispose(() => sub.cancel());
  }
}

final stopProvider = NotifierProvider<StopNotifier, StopState>(() {
  return StopNotifier();
});

class HubState {
  final Map<String, dynamic> hubsData;
  HubState({this.hubsData = const {}});
}

class HubNotifier extends Notifier<HubState> {
  @override
  HubState build() {
    _listenToHubs();
    return HubState();
  }

  void _listenToHubs() {
    final sub = FirebaseDatabase.instance.ref('hubs').onValue.listen((event) {
      final Map<String, dynamic> mergedHubs = {
        CampusLocations.abbasiaName: {
          "latitude": CampusLocations.abbasiaCampus.latitude,
          "longitude": CampusLocations.abbasiaCampus.longitude,
        },
        CampusLocations.baghdadName: {
          "latitude": CampusLocations.baghdadCampus.latitude,
          "longitude": CampusLocations.baghdadCampus.longitude,
        },
      };

      if (event.snapshot.value != null) {
        final rawData = Map<String, dynamic>.from(event.snapshot.value as Map);
        rawData.forEach((key, value) {
          mergedHubs[key] = value;
        });
      }
      
      state = HubState(hubsData: mergedHubs);
    });
    ref.onDispose(() => sub.cancel());
  }
}

final hubProvider = NotifierProvider<HubNotifier, HubState>(() {
  return HubNotifier();
});

class GenderState {
  final Map<String, dynamic> genderConfigs;
  GenderState({this.genderConfigs = const {}});
}

class GenderConfigNotifier extends Notifier<GenderState> {
  @override
  GenderState build() {
    _listenToGenderConfigs();
    return GenderState(genderConfigs: {
      "Girls": {"color": "0xFFFF4081"},
      "Boys": {"color": "0xFF448AFF"},
      "Combined": {"color": "0xFF000080"},
    });
  }

  void _listenToGenderConfigs() {
    final sub = FirebaseDatabase.instance.ref('gender_configs').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final rawData = Map<String, dynamic>.from(event.snapshot.value as Map);
        state = GenderState(genderConfigs: rawData);
      }
    });
    ref.onDispose(() => sub.cancel());
  }
}

final genderConfigProvider = NotifierProvider<GenderConfigNotifier, GenderState>(() {
  return GenderConfigNotifier();
});

