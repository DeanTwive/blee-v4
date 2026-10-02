import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blee/core/theme/app_theme.dart';
import 'package:blee/features/auth/domain/profile_entity.dart';
import 'package:blee/features/auth/presentation/auth_providers.dart';
import 'package:blee/features/run_receipt/presentation/run_receipt_widget.dart';
import 'package:blee/features/tracking/domain/run_summary_entity.dart';

void main() {
  group('RunReceiptWidget Tests', () {
    final now = DateTime(2026, 10, 2, 6, 14, 0);
    final mockSummary = RunSummaryEntity(
      runId: 'b7c3d2e1-4567-89ab-cdef-0123456789ab',
      startedAt: now,
      endedAt: now.add(const Duration(minutes: 58, seconds: 32)),
      distanceMeters: 10200.0,
      durationSeconds: 3512,
      avgPaceSecondsPerKm: 344.0, // 5:44
      peakKmPaceSecondsPerKm: 298.0, // 4:58
      peakKmIndex: 7,
      rpe: 8,
      breadcrumbs: [
        BreadcrumbPoint(
          runId: 'b7c3d2e1',
          latitude: 14.550,
          longitude: 121.045,
          accuracy: 4,
          timestamp: now,
        ),
        BreadcrumbPoint(
          runId: 'b7c3d2e1',
          latitude: 14.558,
          longitude: 121.052,
          accuracy: 4,
          timestamp: now.add(const Duration(minutes: 30)),
        ),
        BreadcrumbPoint(
          runId: 'b7c3d2e1',
          latitude: 14.562,
          longitude: 121.048,
          accuracy: 4,
          timestamp: now.add(const Duration(minutes: 58)),
        ),
      ],
    );

    final mockProfile = ProfileEntity(
      id: 'runner-123',
      displayName: 'Coach Carlos',
      username: 'coachcarlos',
      tier: 'strider',
      createdAt: now,
    );

    testWidgets('Renders all receipt metrics, tier badge, header, and barcode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) => Stream.value(mockProfile)),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: RunReceiptWidget(summary: mockSummary),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header
      expect(find.text('🐝 BLEE'), findsOneWidget);
      expect(find.text('STRIDER'), findsOneWidget);
      expect(find.text('Coach Carlos'), findsOneWidget);

      // Distance Hero
      expect(find.text('10.20'), findsOneWidget);
      expect(find.text('KILOMETERS'), findsOneWidget);

      // Stats
      expect(find.text('DURATION'), findsOneWidget);
      expect(find.text('58:32'), findsOneWidget);
      expect(find.text('AVG PACE'), findsOneWidget);
      expect(find.text('5:44'), findsOneWidget);
      expect(find.text('PEAK KM'), findsOneWidget);
      expect(find.text('4:58'), findsOneWidget);

      // Footer
      expect(find.text('BGC, Manila'), findsOneWidget);
      expect(find.text('blee.app · Identity > Telemetry'), findsOneWidget);
      expect(find.text('RUN ID: B7C3D2E1'), findsOneWidget);

      // CustomPainter route silhouette exists
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
