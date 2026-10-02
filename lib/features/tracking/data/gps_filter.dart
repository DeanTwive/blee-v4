import '../domain/run_summary_entity.dart';

/// GPS point sanitisation filter.
/// Applied before any point is stored to SQLite or accumulated in distance.
/// All heavy computation here runs on the GPS stream callback thread
/// (flutter_background_service isolate), never on the UI thread.
abstract final class GpsFilter {
  /// Max acceptable accuracy. Points worse than this are discarded.
  static const double maxAccuracyMeters = 30.0;

  /// Max believable speed for a runner (45 km/h = 12.5 m/s).
  static const double maxSpeedMetersPerSec = 12.5;

  /// Min distance delta before adding haversine distance.
  static const double minDistanceDeltaMeters = 2.5;

  /// Returns true if this point passes all sanity checks.
  static bool isValid({
    required double latitude,
    required double longitude,
    required double accuracy,
    double? speedMetersPerSec,
  }) {
    // Coordinate bounds
    if (latitude < -90.0 || latitude > 90.0) return false;
    if (longitude < -180.0 || longitude > 180.0) return false;

    // Accuracy gate
    if (accuracy <= 0 || accuracy > maxAccuracyMeters) return false;

    // Speed sanity (only if the platform reports speed)
    if (speedMetersPerSec != null && speedMetersPerSec > maxSpeedMetersPerSec) {
      return false;
    }

    return true;
  }

  /// Calculates peak 1km segment from a list of breadcrumbs.
  /// Returns (peakKmIndex, paceSecondsPerKm) or null if < 1km total.
  /// This is designed to run inside compute() on the Dart isolate.
  static ({int peakKmIndex, double paceSecondsPerKm})? findPeakKm(
    List<BreadcrumbPoint> breadcrumbs,
  ) {
    if (breadcrumbs.length < 2) return null;

    double bestPace = double.infinity;
    int bestKmIndex = 0;
    double accumulatedDistance = 0;
    int kmIndex = 0;
    DateTime? kmStart;

    for (int i = 1; i < breadcrumbs.length; i++) {
      final prev = breadcrumbs[i - 1];
      final curr = breadcrumbs[i];

      final delta = _haversine(prev.latitude, prev.longitude, curr.latitude, curr.longitude);
      accumulatedDistance += delta;

      if (accumulatedDistance >= 1000.0) {
        kmStart ??= prev.timestamp;
        final kmDurationSeconds =
            curr.timestamp.difference(kmStart).inSeconds.toDouble();
        if (kmDurationSeconds > 0) {
          final pace = kmDurationSeconds; // seconds per km
          if (pace < bestPace) {
            bestPace = pace;
            bestKmIndex = kmIndex;
          }
        }
        kmIndex++;
        accumulatedDistance -= 1000.0;
        kmStart = curr.timestamp;
      }
    }

    if (bestPace == double.infinity) return null;
    return (peakKmIndex: bestKmIndex, paceSecondsPerKm: bestPace);
  }

  static double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = _sin2(dLat / 2) +
        _cos(_rad(lat1)) * _cos(_rad(lat2)) * _sin2(dLng / 2);
    return 2 * r * _asin(_sqrt(a));
  }

  // Inline trig to avoid dart:math import issues in isolate context
  static double _rad(double d) => d * 3.141592653589793 / 180.0;
  static double _sin2(double x) {
    final s = _sin(x);
    return s * s;
  }

  static double _sin(double x) => _taylorSin(x);
  static double _cos(double x) => _taylorSin(x + 1.5707963267948966);
  static double _asin(double x) {
    // Approximation sufficient for geo distances
    return x + (x * x * x) / 6.0 + (3 * x * x * x * x * x) / 40.0;
  }

  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  // Taylor series sin approximation (sufficient for small angles in haversine)
  static double _taylorSin(double x) {
    // Reduce to [-pi, pi]
    const pi = 3.141592653589793;
    while (x > pi) {
      x -= 2 * pi;
    }
    while (x < -pi) {
      x += 2 * pi;
    }
    final x2 = x * x;
    return x * (1 - x2 / 6 * (1 - x2 / 20 * (1 - x2 / 42)));
  }
}
