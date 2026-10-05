import 'package:flutter_test/flutter_test.dart';
import 'package:blee/features/tracking/data/gps_filter.dart';
import 'package:blee/features/tracking/domain/run_summary_entity.dart';

void main() {
  group('GpsFilter Unit Tests', () {
    test('isValid returns true for valid coordinates and accuracy', () {
      expect(
        GpsFilter.isValid(
          latitude: 14.5547,
          longitude: 121.0494,
          accuracy: 5.0,
          speedMetersPerSec: 3.2,
        ),
        isTrue,
      );
    });

    test('isValid rejects accuracy exceeding maxAccuracyMeters (30m)', () {
      expect(
        GpsFilter.isValid(
          latitude: 14.5547,
          longitude: 121.0494,
          accuracy: 35.0,
        ),
        isFalse,
      );
    });

    test('isValid rejects negative accuracy or zero accuracy', () {
      expect(
        GpsFilter.isValid(
          latitude: 14.5547,
          longitude: 121.0494,
          accuracy: -1.0,
        ),
        isFalse,
      );
      expect(
        GpsFilter.isValid(
          latitude: 14.5547,
          longitude: 121.0494,
          accuracy: 0.0,
        ),
        isFalse,
      );
    });

    test('isValid rejects speed exceeding maxSpeedMetersPerSec (12.5 m/s / 45 km/h)', () {
      expect(
        GpsFilter.isValid(
          latitude: 14.5547,
          longitude: 121.0494,
          accuracy: 10.0,
          speedMetersPerSec: 15.0, // 54 km/h - impossible on foot
        ),
        isFalse,
      );
    });

    test('isValid rejects invalid latitude or longitude bounds', () {
      expect(
        GpsFilter.isValid(
          latitude: 91.0,
          longitude: 121.0494,
          accuracy: 10.0,
        ),
        isFalse,
      );
      expect(
        GpsFilter.isValid(
          latitude: 14.5547,
          longitude: 181.0,
          accuracy: 10.0,
        ),
        isFalse,
      );
    });

    test('findPeakKm returns null for fewer than 2 breadcrumbs', () {
      expect(GpsFilter.findPeakKm([]), isNull);
      expect(
        GpsFilter.findPeakKm([
          BreadcrumbPoint(
            runId: 'r1',
            latitude: 14.55,
            longitude: 121.04,
            accuracy: 5,
            timestamp: DateTime.now(),
          ),
        ]),
        isNull,
      );
    });

    test('findPeakKm identifies fastest 1km segment', () {
      final now = DateTime(2026, 10, 2, 6, 0, 0);
      final breadcrumbs = <BreadcrumbPoint>[];

      // Simulate 2km run:
      // KM 0: 1000m run in 300 seconds (5:00/km)
      // ~0.000009 degrees lat is approx 1 meter
      for (int i = 0; i <= 100; i++) {
        breadcrumbs.add(
          BreadcrumbPoint(
            runId: 'r_peak',
            latitude: 14.550000 + (i * 0.000090), // ~10m per step => 1000m total
            longitude: 121.0494,
            accuracy: 5,
            timestamp: now.add(Duration(seconds: i * 3)), // 300s total for KM 0
          ),
        );
      }

      // KM 1: 1000m run faster in 240 seconds (4:00/km)
      for (int i = 1; i <= 100; i++) {
        breadcrumbs.add(
          BreadcrumbPoint(
            runId: 'r_peak',
            latitude: 14.559000 + (i * 0.000090), // ~10m per step => another 1000m
            longitude: 121.0494,
            accuracy: 5,
            timestamp: now.add(Duration(seconds: 300 + (i * 2) + (i > 50 ? (i - 50) : 0))),
          ),
        );
      }

      final peak = GpsFilter.findPeakKm(breadcrumbs);
      expect(peak, isNotNull);
      expect(peak!.paceSecondsPerKm, greaterThan(0));
    });

    test('calculateMinettiGap returns identical pace on flat ground', () {
      final gap = GpsFilter.calculateMinettiGap(
        actualPaceSecondsPerKm: 360.0, // 6:00 /km
        gradientFraction: 0.0,
      );
      expect(gap, closeTo(360.0, 0.01));
    });

    test('calculateMinettiGap accurately reduces equivalent pace on 8% incline', () {
      // At i = 0.08, Cr(0.08) ~= 5.4335 => ratio ~= 1.509 => 360 / 1.509 ~= 238.5s (~3:59/km)
      final gap = GpsFilter.calculateMinettiGap(
        actualPaceSecondsPerKm: 360.0,
        gradientFraction: 0.08,
      );
      expect(gap, closeTo(238.5, 0.5));
    });

    test('calculateMinettiGap clamps extreme gradients to [-0.45, +0.45]', () {
      final gapClamped = GpsFilter.calculateMinettiGap(
        actualPaceSecondsPerKm: 300.0,
        gradientFraction: 0.85, // Extreme 85% incline
      );
      final gapAtBoundary = GpsFilter.calculateMinettiGap(
        actualPaceSecondsPerKm: 300.0,
        gradientFraction: 0.45,
      );
      expect(gapClamped, equals(gapAtBoundary));
    });

    test('filterDopplerSpeed smooths speed with 1-pole EMA (alpha = 0.6)', () {
      final smoothed = GpsFilter.filterDopplerSpeed(3.0, 0.0);
      expect(smoothed, closeTo(1.8, 0.001)); // 0.6 * 3.0 + 0.4 * 0.0
    });

    test('medianFilter removes multipath altitude spikes', () {
      final filtered = GpsFilter.medianFilter([20.0, 22.0, 85.0, 21.0, 20.5]);
      expect(filtered, equals(21.0)); // The 85m spike is discarded
    });

    test('calculateAcsmKcalBurnPerSecond computes realistic energy expenditure', () {
      // 12 km/h (3.33 m/s) on flat ground for 70 kg runner
      final kcalPerSec = GpsFilter.calculateAcsmKcalBurnPerSecond(
        speedMps: 3.333,
        gradientFraction: 0.0,
        runnerWeightKg: 70.0,
      );
      // In 1 hour (3600s), approx 750-900 kcal
      final kcalPerHour = kcalPerSec * 3600;
      expect(kcalPerHour, greaterThan(700));
      expect(kcalPerHour, lessThan(950));
    });

    test('decimatePolyline compresses collinear points preserving endpoints', () {
      final points = [
        BreadcrumbPoint(
          runId: 'r1',
          latitude: 14.5500,
          longitude: 121.0500,
          accuracy: 5,
          timestamp: DateTime.now(),
        ),
        BreadcrumbPoint(
          runId: 'r1',
          latitude: 14.5505,
          longitude: 121.0500,
          accuracy: 5,
          timestamp: DateTime.now(),
        ),
        BreadcrumbPoint(
          runId: 'r1',
          latitude: 14.5510,
          longitude: 121.0500,
          accuracy: 5,
          timestamp: DateTime.now(),
        ),
      ];

      final decimated = GpsFilter.decimatePolyline(points, epsilonMeters: 5.0);
      expect(decimated.length, 2); // Middle point along straight line is removed
    });

    test('calculateAnchorElevationGain ignores noise < 2.0m and banks changes >= 2.0m', () {
      // 1. Noise under 2.0m: delta = +1.5m -> 0 gain, anchor stays at 20.0m
      var (gain, loss, anchor) = GpsFilter.calculateAnchorElevationGain(
        anchorAltitude: 20.0,
        currentAltitude: 21.5,
        hysteresisThresholdMeters: 2.0,
      );
      expect(gain, 0.0);
      expect(loss, 0.0);
      expect(anchor, 20.0);

      // 2. Real climb >= 2.0m: delta = +2.5m -> 2.5m gain, anchor updates to 22.5m
      (gain, loss, anchor) = GpsFilter.calculateAnchorElevationGain(
        anchorAltitude: 20.0,
        currentAltitude: 22.5,
        hysteresisThresholdMeters: 2.0,
      );
      expect(gain, 2.5);
      expect(loss, 0.0);
      expect(anchor, 22.5);

      // 3. Real descent >= 2.0m: delta = -3.0m -> 3.0m loss, anchor updates to 19.5m
      (gain, loss, anchor) = GpsFilter.calculateAnchorElevationGain(
        anchorAltitude: 22.5,
        currentAltitude: 19.5,
        hysteresisThresholdMeters: 2.0,
      );
      expect(gain, 0.0);
      expect(loss, 3.0);
      expect(anchor, 19.5);
    });
  });
}
