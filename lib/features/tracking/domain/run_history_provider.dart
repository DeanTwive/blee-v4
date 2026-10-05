import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'run_summary_entity.dart';

/// State containing all recorded and synced runs for the runner.
class RunHistoryState {
  final List<RunSummaryEntity> runs;

  const RunHistoryState({this.runs = const []});

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
}

class RunHistoryNotifier extends Notifier<RunHistoryState> {
  @override
  RunHistoryState build() {
    return RunHistoryState(runs: _initialRuns());
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
      // Coordinates tracing High Street, 5th Ave, 26th St, 11th Ave, and Track 30th
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

  void addRun(RunSummaryEntity run) {
    final index = state.runs.indexWhere((r) => r.runId == run.runId);
    if (index >= 0) {
      final updated = List<RunSummaryEntity>.from(state.runs);
      updated[index] = run;
      state = RunHistoryState(runs: updated);
    } else {
      state = RunHistoryState(runs: [run, ...state.runs]);
    }
  }

  void updateRun(RunSummaryEntity run) => addRun(run);

  void removeRun(String runId) {
    state = RunHistoryState(
      runs: state.runs.where((r) => r.runId != runId).toList(),
    );
  }
}

final runHistoryNotifierProvider =
    NotifierProvider<RunHistoryNotifier, RunHistoryState>(
  RunHistoryNotifier.new,
);
