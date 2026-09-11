import 'package:geolocator/geolocator.dart';

class LocationResult {
  const LocationResult.available({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.capturedAt,
  })  : available = true,
        reason = null;

  const LocationResult.unavailable({required this.reason})
      : available = false,
        latitude = null,
        longitude = null,
        accuracy = null,
        capturedAt = null;

  final bool available;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final DateTime? capturedAt;
  final String? reason;
}

class LocationService {
  const LocationService();

  Future<LocationResult> captureLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.unavailable(
          reason: 'Location services are unavailable.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocationResult.unavailable(
          reason: 'Location permission was not granted.',
        );
      }

      final position = await Geolocator.getCurrentPosition();
      return LocationResult.available(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        capturedAt: DateTime.now().toUtc(),
      );
    } catch (_) {
      return const LocationResult.unavailable(
        reason: 'Location could not be obtained.',
      );
    }
  }
}
