// lib/core/utils/location_helper.dart
import 'package:geolocator/geolocator.dart';

class LocationHelper {
  static Future<Map<String, String?>> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return {'latitude': null, 'longitude': null};

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied)
          return {'latitude': null, 'longitude': null};
      }

      if (permission == LocationPermission.deniedForever)
        return {'latitude': null, 'longitude': null};

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return {
        'latitude': position.latitude.toString(),
        'longitude': position.longitude.toString(),
      };
    } catch (e) {
      return {'latitude': null, 'longitude': null};
    }
  }
}
