import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blee/features/tracking/data/run_storage_service.dart';
import 'package:blee/features/tracking/domain/run_summary_entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RunStorageService Local Persistence & Offline Sync Queue', () {
    late RunStorageService storage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      // Pass null firestore to test offline fallback behavior
      storage = RunStorageService(firestore: null);
    });

    test('saves run locally in SharedPreferences and loads it back cleanly', () async {
      final run = RunSummaryEntity(
        runId: 'TEST_RUN_101',
        startedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        endedAt: DateTime.now(),
        distanceMeters: 3500.0,
        durationSeconds: 1200,
        movingSeconds: 1180,
        avgPaceSecondsPerKm: 342.0,
        breadcrumbs: [
          BreadcrumbPoint(
            runId: 'TEST_RUN_101',
            latitude: 14.5510,
            longitude: 121.0490,
            accuracy: 3.5,
            timestamp: DateTime.now(),
          ),
        ],
        title: 'Morning Park Run',
        rpe: 7,
      );

      // Save locally
      await storage.saveRunLocally(run, markAsPending: true);

      // Verify loaded back
      final loadedRuns = await storage.loadLocalRuns();
      expect(loadedRuns.length, 1);
      expect(loadedRuns.first.runId, 'TEST_RUN_101');
      expect(loadedRuns.first.title, 'Morning Park Run');
      expect(loadedRuns.first.distanceMeters, 3500.0);
      expect(loadedRuns.first.rpe, 7);

      // Verify pending sync queue contains this runId
      final pending = await storage.getPendingSyncRunIds();
      expect(pending, contains('TEST_RUN_101'));
    });

    test('offline fallback: saveRun preserves run in local storage when Firestore is unavailable', () async {
      final run = RunSummaryEntity(
        runId: 'OFFLINE_RUN_202',
        startedAt: DateTime.now().subtract(const Duration(minutes: 45)),
        endedAt: DateTime.now(),
        distanceMeters: 5000.0,
        durationSeconds: 1500,
        avgPaceSecondsPerKm: 300.0,
        breadcrumbs: const [],
        title: 'Offline Trail Run',
      );

      // Attempt saveRun (no firestore available)
      final isSynced = await storage.saveRun(run, userId: 'user_123');

      // False indicates saved locally but not yet synced to cloud
      expect(isSynced, isFalse);

      // But locally, it is 100% saved!
      final localRuns = await storage.loadLocalRuns();
      expect(localRuns.any((r) => r.runId == 'OFFLINE_RUN_202'), isTrue);

      final pendingIds = await storage.getPendingSyncRunIds();
      expect(pendingIds, contains('OFFLINE_RUN_202'));
    });

    test('markRunSyncedLocally removes run from pending queue', () async {
      final run = RunSummaryEntity(
        runId: 'SYNC_TEST_303',
        startedAt: DateTime.now(),
        endedAt: DateTime.now(),
        distanceMeters: 1000.0,
        durationSeconds: 300,
        avgPaceSecondsPerKm: 300.0,
        breadcrumbs: const [],
      );

      await storage.saveRunLocally(run, markAsPending: true);
      expect(await storage.getPendingSyncRunIds(), contains('SYNC_TEST_303'));

      await storage.markRunSyncedLocally('SYNC_TEST_303');
      expect(await storage.getPendingSyncRunIds(), isNot(contains('SYNC_TEST_303')));
    });

    test('deleteRunLocally removes run from storage and pending queue', () async {
      final run = RunSummaryEntity(
        runId: 'DELETE_TEST_404',
        startedAt: DateTime.now(),
        endedAt: DateTime.now(),
        distanceMeters: 2000.0,
        durationSeconds: 600,
        avgPaceSecondsPerKm: 300.0,
        breadcrumbs: const [],
      );

      await storage.saveRunLocally(run, markAsPending: true);
      expect((await storage.loadLocalRuns()).length, 1);

      await storage.deleteRunLocally('DELETE_TEST_404');
      expect((await storage.loadLocalRuns()).isEmpty, isTrue);
      expect(await storage.getPendingSyncRunIds(), isEmpty);
    });
  });
}
