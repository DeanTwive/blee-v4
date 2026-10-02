import 'dart:math' as math;

/// Geo math utilities for Blee GPS engine.
/// All computations use double-precision floating-point arithmetic.
abstract final class GeoMath {
  static const double _earthRadiusMeters = 6371000.0;

  /// Calculates the Haversine distance (in meters) between two lat/lng points.
  /// Used to accumulate distance during a run.
  static double haversineDistance({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  /// Converts a duration in seconds to a formatted pace string "M:SS /km".
  /// Returns "--:--" for zero or invalid inputs.
  static String formatPace(double paceSecondsPerKm) {
    if (paceSecondsPerKm <= 0 || paceSecondsPerKm.isInfinite || paceSecondsPerKm.isNaN) {
      return '--:--';
    }
    final minutes = (paceSecondsPerKm / 60).floor();
    final seconds = (paceSecondsPerKm % 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Formats elapsed seconds into "HH:MM:SS" display string.
  static String formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Validates that a coordinate pair is within legal GPS bounds.
  static bool isValidCoordinate(double lat, double lng) {
    return lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;
  }

  /// Ramer-Douglas-Peucker polyline simplification.
  /// Reduces point count while preserving route fidelity.
  /// [epsilon] ≈ 0.00005 degrees (~5 meters).
  static List<({double lat, double lng})> simplifyPolyline(
    List<({double lat, double lng})> points, {
    double epsilon = 0.00005,
  }) {
    if (points.length <= 2) return points;
    return _rdp(points, epsilon);
  }

  static List<({double lat, double lng})> _rdp(
    List<({double lat, double lng})> points,
    double epsilon,
  ) {
    if (points.length <= 2) return points;

    double maxDist = 0;
    int maxIndex = 0;
    final end = points.length - 1;

    for (int i = 1; i < end; i++) {
      final d = _perpendicularDistance(points[i], points[0], points[end]);
      if (d > maxDist) {
        maxDist = d;
        maxIndex = i;
      }
    }

    if (maxDist > epsilon) {
      final left = _rdp(points.sublist(0, maxIndex + 1), epsilon);
      final right = _rdp(points.sublist(maxIndex), epsilon);
      return [...left.sublist(0, left.length - 1), ...right];
    }

    return [points.first, points.last];
  }

  static double _perpendicularDistance(
    ({double lat, double lng}) point,
    ({double lat, double lng}) start,
    ({double lat, double lng}) end,
  ) {
    final dx = end.lng - start.lng;
    final dy = end.lat - start.lat;
    final magnitude = math.sqrt(dx * dx + dy * dy);
    if (magnitude == 0) {
      return math.sqrt(
        math.pow(point.lng - start.lng, 2) + math.pow(point.lat - start.lat, 2),
      );
    }
    return ((dy * point.lng - dx * point.lat + end.lng * start.lat - end.lat * start.lng) / magnitude).abs();
  }

  static double _toRad(double degrees) => degrees * math.pi / 180.0;
}
