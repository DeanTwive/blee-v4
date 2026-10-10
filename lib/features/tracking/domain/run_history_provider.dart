import 'dart:async';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/user_entity.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/run_storage_service.dart';
import 'run_summary_entity.dart';

/// State containing all recorded and synced runs for the runner.
class RunHistoryState {
  final List<RunSummaryEntity> runs;
  final bool isLoading;
  final int pendingSyncCount;

  const RunHistoryState({
    this.runs = const [],
    this.isLoading = false,
    this.pendingSyncCount = 0,
  });

  double get totalDistanceKm =>
      runs.fold(0.0, (acc, r) => acc + r.distanceKm);

  double get weeklyDistanceKm {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return runs
        .where((r) => r.endedAt.isAfter(startOfWeek))
        .fold(0.0, (acc, r) => acc + r.distanceKm);
  }

  int get weeklyRunsCount {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return runs.where((r) => r.endedAt.isAfter(startOfWeek)).length;
  }

  List<RunSummaryEntity> get recentRuns {
    final copy = List<RunSummaryEntity>.from(runs);
    copy.sort((a, b) => b.endedAt.compareTo(a.endedAt));
    return copy;
  }

  RunHistoryState copyWith({
    List<RunSummaryEntity>? runs,
    bool? isLoading,
    int? pendingSyncCount,
  }) {
    return RunHistoryState(
      runs: runs ?? this.runs,
      isLoading: isLoading ?? this.isLoading,
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
    );
  }
}

class RunHistoryNotifier extends Notifier<RunHistoryState> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  RunStorageService get _storage => ref.read(runStorageServiceProvider);

  String? get _currentUserId => ref.read(authStateProvider).value?.id;

  @override
  RunHistoryState build() {
    // 1. Start with initial runs immediately for instant UI render
    final initialState = RunHistoryState(runs: _initialRuns());

    // 2. Initialize persistent storage and cloud sync
    Future.microtask(() => _initializePersistence());

    // 3. Listen to auth changes: when user signs in, sync their runs
    ref.listen<AsyncValue<UserEntity?>>(authStateProvider, (prev, next) {
      final user = next.value;
      if (user != null) {
        _syncWithFirestore(user.id);
      }
    });

    // 4. Listen to network connectivity restoration to sync any pending runs
    _listenToConnectivity();

    return initialState;
  }

  void _listenToConnectivity() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        debugPrint('[RunHistoryNotifier] Network restored, syncing pending runs...');
        syncPending();
      }
    });

    ref.onDispose(() {
      _connectivitySub?.cancel();
    });
  }

  Future<void> _initializePersistence() async {
    try {
      // Step A: Load local persistent runs first (SharedPreferences)
      // This is instant and guarantees runs survive browser refresh (F5) or offline launch.
      final localRuns = await _storage.loadLocalRuns();
      final pendingIds = await _storage.getPendingSyncRunIds();

      final runIds = <String>{};
      final merged = <RunSummaryEntity>[];

      // Local user runs take precedence over initial demo runs
      for (final r in localRuns) {
        if (runIds.add(r.runId)) {
          merged.add(r);
        }
      }

      // Add demo runs if not already in local storage
      for (final r in _initialRuns()) {
        if (runIds.add(r.runId)) {
          merged.add(r);
        }
      }

      state = state.copyWith(
        runs: merged,
        pendingSyncCount: pendingIds.length,
      );

      // Step B: If user is logged in, sync with Cloud Firestore
      final userId = _currentUserId;
      await _syncWithFirestore(userId);
    } catch (e) {
      debugPrint('[RunHistoryNotifier] Error initializing persistence: $e');
    }
  }

  Future<void> _syncWithFirestore(String? userId) async {
    try {
      // 1. Upload any runs queued locally while offline
      await _storage.syncPendingRuns(userId: userId);

      // 2. Fetch runs from Firestore
      final cloudRuns = await _storage.fetchUserRunsFromFirestore(userId: userId);
      if (cloudRuns.isNotEmpty) {
        final runIds = <String>{};
        final merged = <RunSummaryEntity>[];

        for (final r in cloudRuns) {
          if (runIds.add(r.runId)) {
            merged.add(r);
          }
        }
        for (final r in state.runs) {
          if (runIds.add(r.runId)) {
            merged.add(r);
          }
        }

        final pendingIds = await _storage.getPendingSyncRunIds();
        state = state.copyWith(
          runs: merged,
          pendingSyncCount: pendingIds.length,
        );
      }
    } catch (e) {
      debugPrint('[RunHistoryNotifier] Background cloud sync error: $e');
    }
  }

  /// Adds a newly completed run.
  /// 1. Updates in-memory state immediately for zero-latency UI reaction.
  /// 2. Saves to local storage (SharedPreferences) so refresh preserves it.
  /// 3. Asynchronously syncs to Cloud Firestore; queues locally if offline.
  void addRun(RunSummaryEntity run) {
    final index = state.runs.indexWhere((r) => r.runId == run.runId);
    List<RunSummaryEntity> updated;
    if (index >= 0) {
      updated = List<RunSummaryEntity>.from(state.runs);
      updated[index] = run;
    } else {
      updated = [run, ...state.runs];
    }
    state = state.copyWith(runs: updated);

    // Save locally and push to Firestore
    _persistRun(run);
  }

  void updateRun(RunSummaryEntity run) => addRun(run);

  void removeRun(String runId) {
    state = state.copyWith(
      runs: state.runs.where((r) => r.runId != runId).toList(),
    );
    _deleteRun(runId);
  }

  Future<void> _persistRun(RunSummaryEntity run) async {
    try {
      final synced = await _storage.saveRun(run, userId: _currentUserId);
      final pendingIds = await _storage.getPendingSyncRunIds();
      state = state.copyWith(pendingSyncCount: pendingIds.length);
      if (synced) {
        debugPrint('[RunHistoryNotifier] Run ${run.runId} successfully saved to Cloud Firestore.');
      } else {
        debugPrint('[RunHistoryNotifier] Run ${run.runId} saved to local storage (offline queue).');
      }
    } catch (e) {
      debugPrint('[RunHistoryNotifier] Error persisting run: $e');
    }
  }

  Future<void> _deleteRun(String runId) async {
    try {
      await _storage.deleteRunLocally(runId);
      await _storage.deleteRunFromFirestore(runId);
      final pendingIds = await _storage.getPendingSyncRunIds();
      state = state.copyWith(pendingSyncCount: pendingIds.length);
    } catch (e) {
      debugPrint('[RunHistoryNotifier] Error deleting run $runId: $e');
    }
  }

  /// Triggers a manual sync for all offline-queued runs.
  Future<void> syncPending() async {
    try {
      final synced = await _storage.syncPendingRuns(userId: _currentUserId);
      final pendingIds = await _storage.getPendingSyncRunIds();
      state = state.copyWith(pendingSyncCount: pendingIds.length);
      if (synced > 0) {
        debugPrint('[RunHistoryNotifier] Successfully synced $synced pending runs to Firestore.');
      }
    } catch (e) {
      debugPrint('[RunHistoryNotifier] Error syncing pending runs: $e');
    }
  }

  static List<RunSummaryEntity> _initialRuns() {
    final now = DateTime.now();
    final startedAt = now.subtract(const Duration(hours: 3));
    final endedAt = now.subtract(const Duration(hours: 2, minutes: 31, seconds: 45));

    // Realistic 5.2K scenic loop around Bonifacio Global City (BGC) Manila
    const baseLat = 14.5510;
    const baseLng = 121.0490;
    final initialBreadcrumbs = List<BreadcrumbPoint>.generate(48, (i) {
      final t = (i / 48) * 2 * math.pi;
      final latOffset = 0.0035 * math.sin(t) + 0.0012 * math.sin(2 * t);
      final lngOffset = 0.0042 * math.cos(t) - 0.0008 * math.cos(3 * t);
      final altitude = 24.0 + 14.0 * (1.0 - ((i - 24).abs() / 24.0));

      return BreadcrumbPoint(
        runId: 'B7C3D2E1',
        epochId: 0,
        latitude: baseLat + latOffset,
        longitude: baseLng + lngOffset,
        altitude: altitude,
        accuracy: 3.2,
        dopplerSpeed: 3.15,
        hardwareSteps: (i * 105),
        monotonicMs: i * 35000,
        timestamp: startedAt.add(Duration(seconds: (i * 35))),
      );
    });

    final splits = [
      const RunSplit(
        kilometer: 1,
        splitDurationSeconds: 320,
        averagePaceSecondsPerKm: 320.0,
        gapSecondsPerKm: 318.0,
        elevationChangeMeters: 6.0,
        averageCadenceSpm: 174.0,
      ),
      const RunSplit(
        kilometer: 2,
        splitDurationSeconds: 315,
        averagePaceSecondsPerKm: 315.0,
        gapSecondsPerKm: 312.0,
        elevationChangeMeters: -3.0,
        averageCadenceSpm: 176.0,
      ),
      const RunSplit(
        kilometer: 3,
        splitDurationSeconds: 335,
        averagePaceSecondsPerKm: 335.0,
        gapSecondsPerKm: 330.0,
        elevationChangeMeters: 12.0,
        averageCadenceSpm: 173.0,
      ),
      const RunSplit(
        kilometer: 4,
        splitDurationSeconds: 298,
        averagePaceSecondsPerKm: 298.0,
        gapSecondsPerKm: 294.0,
        elevationChangeMeters: 2.0,
        averageCadenceSpm: 182.0,
      ),
      const RunSplit(
        kilometer: 5,
        splitDurationSeconds: 340,
        averagePaceSecondsPerKm: 340.0,
        gapSecondsPerKm: 336.0,
        elevationChangeMeters: 4.0,
        averageCadenceSpm: 171.0,
      ),
    ];

    return [
      RunSummaryEntity(
        runId: 'B7C3D2E1',
        startedAt: startedAt,
        endedAt: endedAt,
        distanceMeters: 5200,
        durationSeconds: 1695, // 28:15
        movingSeconds: 1680,
        avgPaceSecondsPerKm: 326, // 5:26 /km
        peakKmPaceSecondsPerKm: 298, // 4:58 /km
        peakKmIndex: 4,
        elevationGainMeters: 38.0,
        elevationLossMeters: 35.0,
        totalSteps: 4950,
        avgCadenceSpm: 176.0,
        avgStepLengthMeters: 1.05,
        estimatedCalories: 342.0,
        splits: splits,
        rpe: 6,
        breadcrumbs: initialBreadcrumbs,
      ),
    ];
  }
}

final runHistoryNotifierProvider =
    NotifierProvider<RunHistoryNotifier, RunHistoryState>(
  RunHistoryNotifier.new,
);
