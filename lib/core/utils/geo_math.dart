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
    if (paceSecondsPerKm <= 0 ||
        paceSecondsPerKm.isInfinite ||
        paceSecondsPerKm.isNaN ||
        paceSecondsPerKm >= 1800) {
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

  /// Resolves an accurate human-readable location description based on GPS coordinates.
  /// Never hardcodes a fixed location.
  static String resolveApproximateLocation(double lat, double lng) {
    // Taiwan (21.5°N - 25.5°N, 119.5°E - 122.5°E)
    if (lat >= 21.5 && lat <= 25.5 && lng >= 119.5 && lng <= 122.5) {
      if (lat >= 25.04 && lat <= 25.12 && lng >= 121.32 && lng <= 121.42) {
        return 'Linkou, New Taipei City';
      }
      if (lat >= 24.95 && lat <= 25.22 && lng >= 121.43 && lng <= 121.68) {
        return 'Taipei City, Taiwan';
      }
      if (lat >= 24.88 && lat <= 25.12 && lng >= 121.18 && lng <= 121.42) {
        return 'Taoyuan City, Taiwan';
      }
      if (lat >= 24.85 && lat <= 25.35 && lng >= 121.25 && lng <= 121.85) {
        return 'New Taipei City, Taiwan';
      }
      if (lat >= 24.68 && lat < 24.95 && lng >= 120.90 && lng <= 121.25) {
        return 'Hsinchu, Taiwan';
      }
      if (lat >= 24.05 && lat < 24.40 && lng >= 120.50 && lng <= 121.00) {
        return 'Taichung, Taiwan';
      }
      if (lat >= 22.90 && lat < 23.40 && lng >= 120.10 && lng <= 120.50) {
        return 'Tainan, Taiwan';
      }
      if (lat >= 22.45 && lat < 22.90 && lng >= 120.20 && lng <= 120.60) {
        return 'Kaohsiung, Taiwan';
      }
      return 'Taiwan';
    }

    // Philippines (4.5°N - 21.0°N, 116.5°E - 126.5°E)
    if (lat >= 4.5 && lat <= 21.0 && lng >= 116.5 && lng <= 126.5) {
      if (lat >= 14.53 && lat <= 14.565 && lng >= 121.04 && lng <= 121.065) {
        return 'Bonifacio Global City, Taguig';
      }
      if (lat >= 14.54 && lat <= 14.57 && lng >= 121.00 && lng <= 121.04) {
        return 'Makati, Metro Manila';
      }
      if (lat >= 14.40 && lat <= 14.75 && lng >= 120.90 && lng <= 121.15) {
        return 'Metro Manila, Philippines';
      }
      return 'Philippines';
    }

    // Global major running hubs
    if (lat >= 1.2 && lat <= 1.5 && lng >= 103.6 && lng <= 104.1) {
      return 'Singapore';
    }
    if (lat >= 22.15 && lat <= 22.58 && lng >= 113.8 && lng <= 114.4) {
      return 'Hong Kong';
    }
    if (lat >= 35.5 && lat <= 35.8 && lng >= 139.5 && lng <= 139.9) {
      return 'Tokyo, Japan';
    }

    final latDir = lat >= 0 ? 'N' : 'S';
    final lngDir = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(2)}°$latDir, ${lng.abs().toStringAsFixed(2)}°$lngDir';
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
