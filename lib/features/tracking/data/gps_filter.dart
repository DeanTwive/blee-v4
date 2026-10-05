import 'dart:math' as math;
import '../domain/run_summary_entity.dart';

/// Validation result for raw telemetry coordinates.
class GpsValidationResult {
  final bool isAccepted;
  final bool isNoisy;
  final String? rejectionReason;

  const GpsValidationResult({
    required this.isAccepted,
    this.isNoisy = false,
    this.rejectionReason,
  });

  static const acceptedClean = GpsValidationResult(isAccepted: true, isNoisy: false);
  static const acceptedNoisy = GpsValidationResult(isAccepted: true, isNoisy: true);
  static GpsValidationResult rejected(String reason) =>
      GpsValidationResult(isAccepted: false, rejectionReason: reason);
}

/// Athletic telemetry mathematical engine.
/// Encapsulates Doppler auto-pause, anchor-point elevation, windowed Minetti GAP,
/// dual-speed ACSM energy modeling, and RDP polyline decimation.
abstract final class GpsFilter {
  // Gating & Speed Constants
  static const double maxAcceptableAccuracyMeters = 25.0;
  static const double maxAccuracyMeters = 30.0;
  static const double cleanAccuracyThresholdMeters = 15.0;
  static const double maxSpeedMetersPerSec = 12.5; // 45 km/h
  static const double minDistanceDeltaMeters = 1.2;

  /// Backward-compatible validation check.
  static bool isValid({
    required double latitude,
    required double longitude,
    required double accuracy,
    double? speedMetersPerSec,
  }) {
    return validateFix(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      speedMetersPerSec: speedMetersPerSec,
    ).isAccepted;
  }

  // Auto-pause Hysteresis
  static const double autoPauseThresholdMps = 0.8; // ~2.9 km/h
  static const double autoResumeThresholdMps = 1.2; // ~4.3 km/h
  static const int autoPauseSustainedSeconds = 3;

  // Elevation Hysteresis
  static const double elevationAnchorHysteresisMeters = 2.0;

  // GAP Baseline
  static const double minGapDistanceWarmupMeters = 200.0;
  static const double gapWindowDistanceMeters = 40.0;

  /// Evaluates coordinate accuracy and physical plausibility.
  static GpsValidationResult validateFix({
    required double latitude,
    required double longitude,
    required double accuracy,
    double? speedMetersPerSec,
  }) {
    if (latitude < -90.0 || latitude > 90.0) {
      return GpsValidationResult.rejected('Latitude out of bounds');
    }
    if (longitude < -180.0 || longitude > 180.0) {
      return GpsValidationResult.rejected('Longitude out of bounds');
    }
    if (accuracy <= 0 || accuracy > maxAcceptableAccuracyMeters) {
      return GpsValidationResult.rejected('Accuracy > 25m or invalid: $accuracy');
    }
    if (speedMetersPerSec != null && speedMetersPerSec > maxSpeedMetersPerSec) {
      return GpsValidationResult.rejected('Unrealistic speed burst: $speedMetersPerSec m/s');
    }

    if (accuracy > cleanAccuracyThresholdMeters) {
      return GpsValidationResult.acceptedNoisy;
    }
    return GpsValidationResult.acceptedClean;
  }

  /// 1-Pole Recursive Low-Pass Filter on Doppler Speed.
  /// Smooths out 1 Hz GPS speed noise: v_smooth = 0.6 * v_raw + 0.4 * v_prev.
  static double filterDopplerSpeed(double rawSpeed, double previousSmoothedSpeed) {
    if (rawSpeed < 0) return 0.0;
    const alpha = 0.6;
    return (alpha * rawSpeed) + ((1.0 - alpha) * previousSmoothedSpeed);
  }

  /// Calculates Alberto Minetti Grade Adjusted Pace (GAP).
  /// Cr(i) = 155.4*i^5 - 30.4*i^4 - 43.3*i^3 + 46.3*i^2 + 19.5*i + 3.6 J/(kg*m).
  /// Normalised to flat ground Cr_flat = 3.6 J/(kg*m).
  static double calculateMinettiGap({
    required double actualPaceSecondsPerKm,
    required double gradientFraction, // e.g. +0.08 for 8%
  }) {
    if (actualPaceSecondsPerKm <= 0 || actualPaceSecondsPerKm.isInfinite || actualPaceSecondsPerKm.isNaN) {
      return 0.0;
    }

    // Clamp gradient to Minetti physiological domain [-0.45, +0.45]
    final i = gradientFraction.clamp(-0.45, 0.45);

    // Minetti polynomial
    final i2 = i * i;
    final i3 = i2 * i;
    final i4 = i3 * i;
    final i5 = i4 * i;

    final cr = (155.4 * i5) - (30.4 * i4) - (43.3 * i3) + (46.3 * i2) + (19.5 * i) + 3.6;
    const crFlat = 3.6;

    final costRatio = cr / crFlat;
    if (costRatio <= 0.1) return actualPaceSecondsPerKm;

    return actualPaceSecondsPerKm / costRatio;
  }

  /// Dual-Speed ACSM Metabolic Energy Model.
  /// Computes estimated Kcal burned in a 1-second interval.
  static double calculateAcsmKcalBurnPerSecond({
    required double speedMps,
    required double gradientFraction,
    double runnerWeightKg = 70.0,
  }) {
    if (speedMps <= 0.2) return 0.0; // Stationary energy handled by BMR if desired

    final speedMPerMin = speedMps * 60.0;
    final speedKmH = speedMps * 3.6;
    final uphillGrade = math.max(0.0, gradientFraction);

    double vo2MlPerKgMin;
    if (speedKmH >= 8.0) {
      // ACSM Running Equation: VO2 = (0.2 * S) + (0.9 * S * G) + 3.5
      vo2MlPerKgMin = (0.2 * speedMPerMin) + (0.9 * speedMPerMin * uphillGrade) + 3.5;
    } else {
      // ACSM Walking Equation: VO2 = (0.1 * S) + (1.8 * S * G) + 3.5
      vo2MlPerKgMin = (0.1 * speedMPerMin) + (1.8 * speedMPerMin * uphillGrade) + 3.5;
    }

    // Kcal per minute = (VO2 * Weight / 1000) * 4.86
    final kcalPerMinute = (vo2MlPerKgMin * runnerWeightKg / 1000.0) * 4.86;
    return kcalPerMinute / 60.0; // Scaled to 1 second
  }

  /// 5-Point Median Filter for Continuous Altitude Smoothing.
  static double medianFilter(List<double> recentAltitudes) {
    if (recentAltitudes.isEmpty) return 0.0;
    final sorted = List<double>.from(recentAltitudes)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length % 2 == 1) {
      return sorted[middle];
    } else {
      return (sorted[middle - 1] + sorted[middle]) / 2.0;
    }
  }

  /// Anchor-point elevation gain/loss with hysteresis threshold (e.g. 2.0m).
  /// Prevents GPS vertical multipath noise from artificially inflating total climbing numbers.
  static (double gain, double loss, double newAnchor) calculateAnchorElevationGain({
    required double anchorAltitude,
    required double currentAltitude,
    double hysteresisThresholdMeters = elevationAnchorHysteresisMeters,
  }) {
    final delta = currentAltitude - anchorAltitude;
    if (delta >= hysteresisThresholdMeters) {
      return (delta, 0.0, currentAltitude);
    } else if (delta <= -hysteresisThresholdMeters) {
      return (0.0, -delta, currentAltitude);
    }
    return (0.0, 0.0, anchorAltitude);
  }

  /// Calculates Great-Circle Haversine distance in meters.
  static double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  /// Ramer-Douglas-Peucker (RDP) Polyline Decimation.
  /// Compresses thousands of GPS coordinates into essential vertices for smooth 60 FPS map rendering.
  static List<BreadcrumbPoint> decimatePolyline(
    List<BreadcrumbPoint> points, {
    double epsilonMeters = 2.0,
  }) {
    if (points.length <= 2) return points;

    double maxDistance = 0.0;
    int index = 0;

    for (int i = 1; i < points.length - 1; i++) {
      final d = _perpendicularDistance(
        points[i],
        points.first,
        points.last,
      );
      if (d > maxDistance) {
        maxDistance = d;
        index = i;
      }
    }

    if (maxDistance > epsilonMeters) {
      final left = decimatePolyline(
        points.sublist(0, index + 1),
        epsilonMeters: epsilonMeters,
      );
      final right = decimatePolyline(
        points.sublist(index),
        epsilonMeters: epsilonMeters,
      );
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [points.first, points.last];
    }
  }

  static double _perpendicularDistance(
    BreadcrumbPoint point,
    BreadcrumbPoint lineStart,
    BreadcrumbPoint lineEnd,
  ) {
    final x = point.longitude;
    final y = point.latitude;
    final x1 = lineStart.longitude;
    final y1 = lineStart.latitude;
    final x2 = lineEnd.longitude;
    final y2 = lineEnd.latitude;

    final dx = x2 - x1;
    final dy = y2 - y1;

    if (dx == 0 && dy == 0) {
      return haversineDistance(y, x, y1, x1);
    }

    final numerator = ((dy * x) - (dx * y) + (x2 * y1) - (y2 * x1)).abs();
    final denominator = math.sqrt(dy * dy + dx * dx);

    // Approximate conversion from degrees to meters (~111,320m per degree latitude)
    return (numerator / denominator) * 111320.0;
  }

  /// Calculates peak 1km segment from a list of breadcrumbs.
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

      final delta = haversineDistance(
        prev.latitude,
        prev.longitude,
        curr.latitude,
        curr.longitude,
      );
      accumulatedDistance += delta;

      if (accumulatedDistance >= 1000.0) {
        kmStart ??= prev.timestamp;
        final kmDurationSeconds =
            curr.timestamp.difference(kmStart).inSeconds.toDouble();
        if (kmDurationSeconds > 0) {
          final pace = kmDurationSeconds;
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

  static double _rad(double d) => d * math.pi / 180.0;
}
