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
  });
}
