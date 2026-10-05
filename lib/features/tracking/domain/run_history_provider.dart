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
    return [
      RunSummaryEntity(
        runId: 'B7C3D2E1',
        startedAt: now.subtract(const Duration(hours: 3)),
        endedAt: now.subtract(const Duration(hours: 2, minutes: 32)),
        distanceMeters: 5200,
        durationSeconds: 1695, // 28:15
        avgPaceSecondsPerKm: 326, // 5:26 /km
        peakKmPaceSecondsPerKm: 298, // 4:58 /km
        peakKmIndex: 4,
        rpe: 6,
        breadcrumbs: const [],
      ),
    ];
  }

  void addRun(RunSummaryEntity run) {
    state = RunHistoryState(runs: [run, ...state.runs]);
  }

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
