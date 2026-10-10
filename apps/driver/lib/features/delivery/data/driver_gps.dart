import 'package:geolocator_android/geolocator_android.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

class LocationCaptureException implements Exception {
  const LocationCaptureException(this.message);
  final String message;
}

Future<DriverLocationFix> captureDriverLocation() async {
  if (!await GeolocatorAndroid().isLocationServiceEnabled()) {
    throw const LocationCaptureException(
        'Turn on phone location, then try again.');
  }
  var permission = await GeolocatorAndroid().checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await GeolocatorAndroid().requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    throw const LocationCaptureException(
        'Allow location in app settings, then try again.');
  }
  if (permission == LocationPermission.denied) {
    throw const LocationCaptureException(
        'Location permission is needed to share your position.');
  }
  final position = await GeolocatorAndroid().getCurrentPosition(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
  return DriverLocationFix(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      capturedAt: position.timestamp);
}
