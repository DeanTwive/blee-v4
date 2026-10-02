import 'dart:async';
import '../../../core/utils/crash_reporter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../data/gps_filter.dart';
import '../data/gps_repository.dart';
import '../domain/run_summary_entity.dart';
import '../../../core/utils/geo_math.dart';

final trackingNotifierProvider =
    NotifierProvider<TrackingNotifier, TrackingState>(TrackingNotifier.new);

class TrackingNotifier extends Notifier<TrackingState> {
  StreamSubscription<Position>? _positionSub;
  Timer? _clockTimer;
  double? _lastLat;
  double? _lastLng;

  IGpsRepository get _gpsRepo => ref.read(gpsRepositoryProvider);

  @override
  TrackingState build() {
    ref.onDispose(_cleanup);
    return const TrackingState();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> startRun() async {
    if (state.isActive) return;
    state = TrackingState(
      status: TrackingStatus.acquiring,
      runId: const Uuid().v4(),
    );

    final permission = await _gpsRepo.requestPermission();
    if (!permission) {
      state = state.copyWith(
        status: TrackingStatus.idle,
        errorMessage: 'Location permission denied. Please enable it in Settings.',
      );
      return;
    }

    _startClock();
    _startPositionStream();
  }

  void pauseRun() {
    if (state.status != TrackingStatus.running) return;
    _positionSub?.pause();
    _clockTimer?.cancel();
    state = state.copyWith(status: TrackingStatus.paused);
  }

  void resumeRun() {
    if (state.status != TrackingStatus.paused) return;
    _positionSub?.resume();
    _startClock();
    state = state.copyWith(status: TrackingStatus.running);
  }

  Future<RunSummaryEntity?> stopRun() async {
    if (!state.isActive) return null;
    _cleanup();

    final breadcrumbs = state.breadcrumbs;
    final distanceM = state.distanceMeters;
    final durationSec = state.elapsedSeconds;
    final runId = state.runId!;

    state = const TrackingState(status: TrackingStatus.stopped);

    if (breadcrumbs.length < 2) return null;

    // Find peak km in isolate — never block the UI thread
    final peakResult = await compute(GpsFilter.findPeakKm, breadcrumbs);

    final avgPace = durationSec > 0 && distanceM > 0
        ? (durationSec / (distanceM / 1000.0))
        : 0.0;

    return RunSummaryEntity(
      runId: runId,
      startedAt: breadcrumbs.first.timestamp,
      endedAt: breadcrumbs.last.timestamp,
      distanceMeters: distanceM,
      durationSeconds: durationSec,
      avgPaceSecondsPerKm: avgPace,
      peakKmPaceSecondsPerKm: peakResult?.paceSecondsPerKm,
      peakKmIndex: peakResult?.peakKmIndex,
      breadcrumbs: breadcrumbs,
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  void _startPositionStream() {
    _positionSub = _gpsRepo.getPositionStream().listen(
      _onPosition,
      onError: (Object e, StackTrace st) {
        AppCrashReporter.recordError(e, st, reason: 'gps_stream_error');
        state = state.copyWith(
          errorMessage: 'GPS signal lost. Attempting to reconnect...',
        );
      },
    );
  }

  void _onPosition(Position pos) {
    // GPS filter: discard bad points. No allocations beyond what's necessary.
    if (!GpsFilter.isValid(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracy: pos.accuracy,
      speedMetersPerSec: pos.speed > 0 ? pos.speed : null,
    )) {
      state = state.copyWith(
        currentAccuracyMeters: pos.accuracy,
        status: pos.accuracy > GpsFilter.maxAccuracyMeters
            ? TrackingStatus.acquiring
            : state.status,
      );
      return;
    }

    // Accumulate distance
    double addedDistance = 0;
    if (_lastLat != null && _lastLng != null) {
      final delta = GeoMath.haversineDistance(
        lat1: _lastLat!,
        lng1: _lastLng!,
        lat2: pos.latitude,
        lng2: pos.longitude,
      );
      if (delta >= GpsFilter.minDistanceDeltaMeters) {
        addedDistance = delta;
      }
    }

    _lastLat = pos.latitude;
    _lastLng = pos.longitude;

    final newPoint = BreadcrumbPoint(
      runId: state.runId!,
      latitude: pos.latitude,
      longitude: pos.longitude,
      altitude: pos.altitude,
      accuracy: pos.accuracy,
      speedMetersPerSec: pos.speed,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
          pos.timestamp.millisecondsSinceEpoch),
    );

    // Compute rolling pace (last 10 seconds of movement)
    final newDistance = state.distanceMeters + addedDistance;
    double pace = state.currentPaceSecondsPerKm;
    if (pos.speed > 0.5) {
      pace = 1000.0 / pos.speed; // seconds per km
    }

    state = state.copyWith(
      status: TrackingStatus.running,
      distanceMeters: newDistance,
      currentPaceSecondsPerKm: pace,
      currentAccuracyMeters: pos.accuracy,
      breadcrumbs: [...state.breadcrumbs, newPoint],
      errorMessage: null,
    );

    // Persist to SQLite asynchronously via repository — do not await on the stream callback
    _gpsRepo.saveBreadcrumb(newPoint).catchError((Object e, StackTrace st) {
      AppCrashReporter.recordError(e, st, reason: 'sqlite_insert_error');
    });
  }

  void _cleanup() {
    _clockTimer?.cancel();
    _clockTimer = null;
    _positionSub?.cancel();
    _positionSub = null;
  }
}
