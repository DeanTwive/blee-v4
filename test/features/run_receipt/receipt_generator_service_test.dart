import 'package:flutter_test/flutter_test.dart';
import 'package:blee/features/run_receipt/domain/receipt_generator_service.dart';
import 'package:blee/features/tracking/domain/run_summary_entity.dart';

void main() {
  group('ReceiptGeneratorService Unit Tests', () {
    test('normalizeRoute returns empty result for empty breadcrumbs', () {
      final route = ReceiptGeneratorService.normalizeRoute(
        [],
        width: 300,
        height: 180,
      );

      expect(route.isEmpty, isTrue);
      expect(route.hasPath, isFalse);
      expect(route.points, isEmpty);
    });

    test('normalizeRoute centers single point', () {
      final breadcrumbs = [
        BreadcrumbPoint(
          runId: 'r1',
          latitude: 14.55,
          longitude: 121.04,
          accuracy: 5,
          timestamp: DateTime.now(),
        ),
      ];

      final route = ReceiptGeneratorService.normalizeRoute(
        breadcrumbs,
        width: 300,
        height: 200,
      );

      expect(route.points.length, 1);
      expect(route.points.first.dx, 150.0);
      expect(route.points.first.dy, 100.0);
      expect(route.hasPath, isFalse);
    });

    test('normalizeRoute fits multi-point route within padding and bounds', () {
      final now = DateTime.now();
      final breadcrumbs = [
        BreadcrumbPoint(
          runId: 'r1',
          latitude: 14.50,
          longitude: 121.00,
          accuracy: 5,
          timestamp: now,
        ),
        BreadcrumbPoint(
          runId: 'r1',
          latitude: 14.60, // North
          longitude: 121.00,
          accuracy: 5,
          timestamp: now.add(const Duration(minutes: 5)),
        ),
        BreadcrumbPoint(
          runId: 'r1',
          latitude: 14.60,
          longitude: 121.10, // East
          accuracy: 5,
          timestamp: now.add(const Duration(minutes: 10)),
        ),
      ];

      const width = 300.0;
      const height = 180.0;
      const padding = 20.0;

      final route = ReceiptGeneratorService.normalizeRoute(
        breadcrumbs,
        width: width,
        height: height,
        padding: padding,
      );

      expect(route.hasPath, isTrue);
      expect(route.points.length, 3);

      for (final p in route.points) {
        expect(p.dx, greaterThanOrEqualTo(padding - 0.001));
        expect(p.dx, lessThanOrEqualTo(width - padding + 0.001));
        expect(p.dy, greaterThanOrEqualTo(padding - 0.001));
        expect(p.dy, lessThanOrEqualTo(height - padding + 0.001));
      }

      // Point 0 (South) must have larger Y than Point 1 (North) because Y increases downward
      expect(route.points[0].dy, greaterThan(route.points[1].dy));
      // Point 2 (East) must have larger X than Point 1 (West)
      expect(route.points[2].dx, greaterThan(route.points[1].dx));
    });

    test('normalizeRouteAsync produces valid route', () async {
      final now = DateTime.now();
      final breadcrumbs = List.generate(
        60,
        (i) => BreadcrumbPoint(
          runId: 'r_large',
          latitude: 14.55 + (i * 0.001),
          longitude: 121.04 + (i * 0.001),
          accuracy: 4,
          timestamp: now.add(Duration(seconds: i * 5)),
        ),
      );

      final route = await ReceiptGeneratorService.normalizeRouteAsync(
        breadcrumbs,
        width: 320,
        height: 200,
      );

      expect(route.points.length, 60);
      expect(route.hasPath, isTrue);
    });
  });
}
