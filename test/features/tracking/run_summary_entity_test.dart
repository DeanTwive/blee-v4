import 'package:flutter_test/flutter_test.dart';
import 'package:blee/features/tracking/domain/run_summary_entity.dart';

void main() {
  group('RunSummaryEntity Unit Tests', () {
    final started = DateTime(2026, 10, 2, 6, 0, 0);
    final ended = DateTime(2026, 10, 2, 6, 45, 0);

    test('Calculates distanceKm correctly from distanceMeters', () {
      final summary = RunSummaryEntity(
        runId: 'run-1',
        startedAt: started,
        endedAt: ended,
        distanceMeters: 5240.0,
        durationSeconds: 2700,
        avgPaceSecondsPerKm: 515.2,
        peakKmPaceSecondsPerKm: 480.0,
        peakKmIndex: 3,
        rpe: 7,
        breadcrumbs: const [],
      );

      expect(summary.distanceKm, closeTo(5.24, 0.001));
    });

    test('copyWith properly updates rpe and preserves other fields', () {
      final summary = RunSummaryEntity(
        runId: 'run-1',
        startedAt: started,
        endedAt: ended,
        distanceMeters: 10000.0,
        durationSeconds: 3600,
        avgPaceSecondsPerKm: 360.0,
        peakKmPaceSecondsPerKm: 330.0,
        peakKmIndex: 4,
        rpe: 5,
        breadcrumbs: const [],
      );

      final updated = summary.copyWith(rpe: 8);

      expect(updated.rpe, 8);
      expect(updated.runId, 'run-1');
      expect(updated.distanceMeters, 10000.0);
      expect(updated.durationSeconds, 3600);
      expect(updated.avgPaceSecondsPerKm, 360.0);
      expect(updated.peakKmPaceSecondsPerKm, 330.0);
    });

    test('TrackingState copyWith and getters work as expected', () {
      const state = TrackingState(
        status: TrackingStatus.running,
        distanceMeters: 1500,
        elapsedSeconds: 450,
      );

      expect(state.isActive, isTrue);

      final paused = state.copyWith(status: TrackingStatus.paused);
      expect(paused.isActive, isTrue);
      expect(paused.status, TrackingStatus.paused);

      final stopped = state.copyWith(status: TrackingStatus.stopped);
      expect(stopped.isActive, isFalse);
    });
  });
}
