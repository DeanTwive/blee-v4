import 'dart:async';
import 'dart:math' as math;
import '../../../core/utils/crash_reporter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../data/gps_filter.dart';
import '../data/gps_repository.dart';
import '../data/step_cadence_repository.dart';
import '../domain/run_summary_entity.dart';

final trackingNotifierProvider =
    NotifierProvider<TrackingNotifier, TrackingState>(TrackingNotifier.new);

class TrackingNotifier extends Notifier<TrackingState> {
  // Streams & Timers
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<StepData>? _stepSub;
  Timer? _oneSecondTimer;
  Timer? _demoTimer;

  // Monotonic time tracking
  final Stopwatch _monotonicStopwatch = Stopwatch();
  int _movingMs = 0;
  int _lastMovingTickMs = 0;
  late final int _epochId;

  // Telemetry smoothing & auto-pause state
  double _smoothedSpeedMps = 0.0;
  int _consecutiveSlowSeconds = 0;
  bool _isAutoPaused = false;

  // Distance & coordinate memory
  double? _lastValidLat;
  double? _lastValidLng;
  final List<double> _recentAltitudes = [];
  final List<({double distance, double altitude})> _distanceAltitudeHistory = [];

  // Elevation Anchor Hysteresis state
  double? _anchorAltitude;
  double _cumulativeGainMeters = 0.0;
  double _cumulativeLossMeters = 0.0;

  // Rolling Pace Window (last 10 seconds of distance)
  final List<({double distance, int timestampMs})> _rollingPaceWindow = [];

  // Splits tracking
  double _lastSplitDistanceMeters = 0.0;
  int _lastSplitMovingMs = 0;
  double _lastSplitAltitude = 0.0;
  final List<RunSplit> _splits = [];

  // Batch checkpointing buffer
  final List<BreadcrumbPoint> _pendingTelemetryBatch = [];

  // Kinematics & Energy
  double _cumulativeCalories = 0.0;
  int _totalSteps = 0;
  double _currentCadenceSpm = 0.0;
  double _avgCadenceSpm = 0.0;
  double _estimatedStepLengthM = 0.0;
  bool _isStepBuffered = false;

  // Synthetic demo variables
  int _demoStep = 0;

  IGpsRepository get _gpsRepo => ref.read(gpsRepositoryProvider);
  StepCadenceRepository get _stepRepo => ref.read(stepCadenceRepositoryProvider);

  @override
  TrackingState build() {
    _epochId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    ref.onDispose(_cleanup);
    Future.microtask(() => checkUnfinishedRun());
    return const TrackingState();
  }

  // ── Cold-Boot Recovery ───────────────────────────────────────────────────────

  Future<void> checkUnfinishedRun() async {
    try {
      final unfinished = await _gpsRepo.getUnfinishedRun();
      if (unfinished != null && state.status == TrackingStatus.idle) {
        state = state.copyWith(unfinishedRun: unfinished);
      }
    } catch (_) {
      // Silently handle database lock/init race conditions on startup
    }
  }

  /// Cold-Boot Recovery: Finalizes and converts an interrupted run into a RunSummaryEntity.
  Future<RunSummaryEntity?> recoverAndFinishRun(String runId) async {
    final points = await _gpsRepo.getBreadcrumbs(runId);
    final unfinished = await _gpsRepo.getUnfinishedRun();
    final distanceMeters = (unfinished?['distance_meters'] as num?)?.toDouble() ?? 0.0;
    final movingMs = (unfinished?['moving_ms'] as int?) ?? 0;
    final elapsedMs = (unfinished?['elapsed_ms'] as int?) ?? movingMs;
    final steps = (unfinished?['total_steps'] as int?) ?? 0;
    final startedAtEpoch = (unfinished?['started_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch;
    final startedAt = DateTime.fromMillisecondsSinceEpoch(startedAtEpoch);
    final endedAt = DateTime.now();

    final movingSec = movingMs ~/ 1000;
    final elapsedSec = elapsedMs ~/ 1000;

    await _gpsRepo.updateRunRecord(
      runId: runId,
      status: 'completed',
      startedAt: startedAt,
      endedAt: endedAt,
      elapsedMs: elapsedMs,
      movingMs: movingMs,
      distanceMeters: distanceMeters,
      totalSteps: steps,
    );

    state = state.copyWith(clearUnfinishedRun: true);

    // Recompute elevation gain from breadcrumbs using 2.0m hysteresis
    double gain = 0.0;
    double loss = 0.0;
    if (points.length >= 2) {
      double anchor = points.first.altitude ?? 0.0;
      for (final p in points) {
        if (p.altitude == null) continue;
        final (g, l, newAnchor) = GpsFilter.calculateAnchorElevationGain(
          anchorAltitude: anchor,
          currentAltitude: p.altitude!,
          hysteresisThresholdMeters: 2.0,
        );
        gain += g;
        loss += l;
        anchor = newAnchor;
      }
    }

    final peakResult = points.length >= 2
        ? await compute(GpsFilter.findPeakKm, points)
        : null;

    final avgPace = movingSec > 0 && distanceMeters > 0
        ? (movingSec / (distanceMeters / 1000.0))
        : 330.0;

    return RunSummaryEntity(
      runId: runId,
      startedAt: startedAt,
      endedAt: endedAt,
      distanceMeters: distanceMeters,
      durationSeconds: elapsedSec > 0 ? elapsedSec : movingSec,
      movingSeconds: movingSec,
      avgPaceSecondsPerKm: avgPace,
      peakKmPaceSecondsPerKm: peakResult?.paceSecondsPerKm ?? (avgPace * 0.95),
      peakKmIndex: peakResult?.peakKmIndex ?? 1,
      elevationGainMeters: gain,
      elevationLossMeters: loss,
      totalSteps: steps,
      avgCadenceSpm: movingSec > 0 ? (steps / (movingSec / 60.0)) : 0.0,
      avgStepLengthMeters: steps > 0 ? (distanceMeters / steps) : 0.0,
      estimatedCalories: GpsFilter.calculateAcsmKcalBurnPerSecond(
        speedMps: movingSec > 0 ? (distanceMeters / movingSec) : 0.0,
        gradientFraction: 0.0,
        runnerWeightKg: 70.0,
      ) * movingSec,
      splits: const [],
      breadcrumbs: points,
    );
  }

  /// Cold-Boot Recovery: Resumes tracking an interrupted run seamlessly.
  Future<void> resumeInterruptedRun(String runId) async {
    final points = await _gpsRepo.getBreadcrumbs(runId);
    final unfinished = await _gpsRepo.getUnfinishedRun();
    final distanceMeters = (unfinished?['distance_meters'] as num?)?.toDouble() ?? 0.0;
    final movingMs = (unfinished?['moving_ms'] as int?) ?? 0;
    final elapsedMs = (unfinished?['elapsed_ms'] as int?) ?? movingMs;
    final steps = (unfinished?['total_steps'] as int?) ?? 0;

    _resetTelemetryVariables();
    _movingMs = movingMs;
    _totalSteps = steps;

    // Recovery Gap Rule: Discontinuous straight-line jump across crash is strictly omitted from distance
    _lastValidLat = null;
    _lastValidLng = null;
    if (points.isNotEmpty) {
      _anchorAltitude = points.last.altitude;
    }

    _epochId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _monotonicStopwatch.start();
    _startOneSecondTimer();
    _startStepTracking();
    _startPositionStream();

    state = TrackingState(
      status: TrackingStatus.running,
      runId: runId,
      epochId: _epochId,
      distanceMeters: distanceMeters,
      elapsedSeconds: elapsedMs ~/ 1000,
      movingSeconds: movingMs ~/ 1000,
      totalSteps: steps,
      breadcrumbs: points,
    );

    await _gpsRepo.logEvent(RunEvent(
      runId: runId,
      epochId: _epochId,
      eventType: 'paused_gap',
      monotonicMs: _monotonicStopwatch.elapsedMilliseconds,
      timestamp: DateTime.now(),
      extraJson: '{"resumed_from_crash": true, "suppressed_gap_distance": true}',
    ));
  }

  /// Discards the interrupted run and purges its stored telemetry.
  Future<void> discardUnfinishedRun(String runId) async {
    await _gpsRepo.deleteBreadcrumbs(runId);
    state = state.copyWith(clearUnfinishedRun: true);
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> startRun() async {
    if (state.isActive) return;

    final runId = const Uuid().v4();
    state = TrackingState(
      status: TrackingStatus.acquiring,
      runId: runId,
      epochId: _epochId,
    );

    final permission = await _gpsRepo.requestPermission();
    if (!permission) {
      state = state.copyWith(
        status: TrackingStatus.idle,
        errorMessage: 'Location permission denied. Please enable it in Settings.',
      );
      return;
    }

    _resetTelemetryVariables();
    _monotonicStopwatch.start();
    _startOneSecondTimer();
    _startStepTracking();
    _startPositionStream();

    await _gpsRepo.updateRunRecord(
      runId: runId,
      status: 'running',
      startedAt: DateTime.now(),
      elapsedMs: 0,
      movingMs: 0,
      distanceMeters: 0,
      totalSteps: 0,
    );

    await _gpsRepo.logEvent(RunEvent(
      runId: runId,
      epochId: _epochId,
      eventType: 'start',
      monotonicMs: _monotonicStopwatch.elapsedMilliseconds,
      timestamp: DateTime.now(),
    ));
  }

  void pauseRun() {
    if (state.status != TrackingStatus.running) return;
    _positionSub?.pause();
    _isAutoPaused = false;

    state = state.copyWith(status: TrackingStatus.paused, isAutoPaused: false);

    _gpsRepo.logEvent(RunEvent(
      runId: state.runId!,
      epochId: _epochId,
      eventType: 'manual_pause',
      monotonicMs: _monotonicStopwatch.elapsedMilliseconds,
      timestamp: DateTime.now(),
    ));

    _flushBatch();
  }

  void resumeRun() {
    if (state.status != TrackingStatus.paused) return;
    _positionSub?.resume();
    _isAutoPaused = false;
    _lastMovingTickMs = _monotonicStopwatch.elapsedMilliseconds;

    state = state.copyWith(status: TrackingStatus.running, isAutoPaused: false);

    _gpsRepo.logEvent(RunEvent(
      runId: state.runId!,
      epochId: _epochId,
      eventType: 'manual_resume',
      monotonicMs: _monotonicStopwatch.elapsedMilliseconds,
      timestamp: DateTime.now(),
    ));
  }

  Future<RunSummaryEntity?> stopRun() async {
    if (!state.isActive) return null;

    final runId = state.runId!;
    final breadcrumbs = List<BreadcrumbPoint>.from(state.breadcrumbs);
    final distanceM = state.distanceMeters;
    final movingSec = state.movingSeconds > 0 ? state.movingSeconds : state.elapsedSeconds;
    final elapsedSec = state.elapsedSeconds;

    _cleanup();
    _flushBatch();

    state = const TrackingState(status: TrackingStatus.stopped);

    await _gpsRepo.updateRunRecord(
      runId: runId,
      status: 'completed',
      startedAt: breadcrumbs.isNotEmpty ? breadcrumbs.first.timestamp : DateTime.now(),
      endedAt: DateTime.now(),
      elapsedMs: elapsedSec * 1000,
      movingMs: movingSec * 1000,
      distanceMeters: distanceM,
      totalSteps: _totalSteps,
    );

    if (breadcrumbs.length < 2 && distanceM <= 0) return null;

    final peakResult = await compute(GpsFilter.findPeakKm, breadcrumbs);
    final avgPace = movingSec > 0 && distanceM > 0
        ? (movingSec / (distanceM / 1000.0))
        : 330.0;

    return RunSummaryEntity(
      runId: runId,
      startedAt: breadcrumbs.isNotEmpty ? breadcrumbs.first.timestamp : DateTime.now(),
      endedAt: DateTime.now(),
      distanceMeters: distanceM,
      durationSeconds: elapsedSec,
      movingSeconds: movingSec,
      avgPaceSecondsPerKm: avgPace,
      peakKmPaceSecondsPerKm: peakResult?.paceSecondsPerKm ?? (avgPace * 0.95),
      peakKmIndex: peakResult?.peakKmIndex ?? 1,
      elevationGainMeters: _cumulativeGainMeters,
      elevationLossMeters: _cumulativeLossMeters,
      totalSteps: _totalSteps,
      avgCadenceSpm: _avgCadenceSpm,
      avgStepLengthMeters: _estimatedStepLengthM,
      estimatedCalories: _cumulativeCalories,
      splits: _splits,
      breadcrumbs: breadcrumbs,
    );
  }

  /// Starts a synthetic demo run simulating realistic cadence, hills, and splits.
  Future<void> startDemoRun() async {
    if (state.isActive) return;
    _cleanup();

    final runId = const Uuid().v4();
    _resetTelemetryVariables();
    _monotonicStopwatch.start();

    state = TrackingState(
      status: TrackingStatus.running,
      runId: runId,
      epochId: _epochId,
      currentAccuracyMeters: 3.5,
      gpsConfidence: 'High',
    );

    const baseLat = 14.5507;
    const baseLng = 121.0500;
    const baseAlt = 25.0;
    _anchorAltitude = baseAlt;
    _demoStep = 0;

    _startOneSecondTimer();

    _demoTimer?.cancel();
    _demoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.status != TrackingStatus.running) return;
      _demoStep++;

      final stepAngle = _demoStep * 0.08;
      final lat = baseLat + (0.0018 * math.sin(stepAngle));
      final lng = baseLng + (0.0018 * math.cos(stepAngle));
      // Simulate gentle rolling hills: 25m to 45m elevation
      final alt = baseAlt + (10.0 * math.sin(_demoStep * 0.03));
      final newDist = state.distanceMeters + 3.33; // ~12 km/h (5:00 /km pace)
      _smoothedSpeedMps = 3.33;

      _totalSteps += 3; // ~180 SPM
      _currentCadenceSpm = 178.0;
      _avgCadenceSpm = 176.0;
      _estimatedStepLengthM = 1.12;

      _handleAltitude(alt, 3.33);

      final point = BreadcrumbPoint(
        runId: runId,
        epochId: _epochId,
        latitude: lat,
        longitude: lng,
        altitude: alt,
        accuracy: 3.2,
        dopplerSpeed: 3.33,
        hardwareSteps: _totalSteps,
        monotonicMs: _monotonicStopwatch.elapsedMilliseconds,
        timestamp: DateTime.now(),
      );

      _pendingTelemetryBatch.add(point);
      if (_pendingTelemetryBatch.length >= 10) {
        _flushBatch();
      }

      final livePace = 300.0; // 5:00 min/km
      final gap = GpsFilter.calculateMinettiGap(
        actualPaceSecondsPerKm: livePace,
        gradientFraction: 0.04,
      );

      // Accumulate Calories
      _cumulativeCalories += GpsFilter.calculateAcsmKcalBurnPerSecond(
        speedMps: 3.33,
        gradientFraction: 0.04,
        runnerWeightKg: 70.0,
      );

      // Split check
      _checkSplit(newDist, alt);

      state = state.copyWith(
        distanceMeters: newDist,
        currentPaceSecondsPerKm: livePace,
        currentGapSecondsPerKm: gap,
        elevationGainMeters: _cumulativeGainMeters,
        elevationLossMeters: _cumulativeLossMeters,
        totalSteps: _totalSteps,
        currentCadenceSpm: _currentCadenceSpm,
        averageCadenceSpm: _avgCadenceSpm,
        estimatedStepLengthMeters: _estimatedStepLengthM,
        estimatedCalories: _cumulativeCalories,
        breadcrumbs: [...state.breadcrumbs, point],
      );
    });
  }

  // ── Private Pipeline & Sensor Handlers ─────────────────────────────────────

  void _startPositionStream() {
    _positionSub = _gpsRepo.getPositionStream().listen(
      _onPosition,
      onError: (Object e, StackTrace st) {
        AppCrashReporter.recordError(e, st, reason: 'gps_stream_error');
        state = state.copyWith(
          errorMessage: 'GPS signal lost. Reconnecting...',
          gpsConfidence: 'Poor',
        );
      },
    );
  }

  void _startStepTracking() {
    _stepRepo.startTracking();
    _stepSub = _stepRepo.stepStream.listen((stepData) {
      _totalSteps = stepData.totalRunSteps;
      _currentCadenceSpm = stepData.currentCadenceSpm;
      _isStepBuffered = stepData.isBuffered;

      if (_totalSteps > 50 && state.distanceMeters > 100.0) {
        _estimatedStepLengthM = state.distanceMeters / _totalSteps;
      }
      if (state.movingSeconds > 0) {
        _avgCadenceSpm = (_totalSteps / (state.movingSeconds / 60.0)).clamp(0.0, 240.0);
      }
    });
  }

  void _startOneSecondTimer() {
    _oneSecondTimer?.cancel();
    _oneSecondTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.isActive) return;

      final nowMonotonicMs = _monotonicStopwatch.elapsedMilliseconds;
      final elapsedSec = nowMonotonicMs ~/ 1000;

      // Moving Time Integration
      final isMoving = !_isAutoPaused && state.status == TrackingStatus.running;
      if (isMoving) {
        final dtMs = nowMonotonicMs - _lastMovingTickMs;
        if (dtMs > 0 && dtMs < 2000) {
          _movingMs += dtMs;
        }
      }
      _lastMovingTickMs = nowMonotonicMs;

      // Check cadence heartbeat for deep-doze buffering
      final heartbeat = _stepRepo.checkCadenceHeartbeat(isMoving: isMoving);
      _totalSteps = heartbeat.totalRunSteps;
      _currentCadenceSpm = heartbeat.currentCadenceSpm;
      _isStepBuffered = heartbeat.isBuffered;

      // Update average pace
      final movingSec = _movingMs ~/ 1000;
      final avgPace = (movingSec > 0 && state.distanceMeters > 10)
          ? (movingSec / (state.distanceMeters / 1000.0))
          : 0.0;

      state = state.copyWith(
        elapsedSeconds: elapsedSec,
        movingSeconds: movingSec,
        averagePaceSecondsPerKm: avgPace,
        totalSteps: _totalSteps,
        currentCadenceSpm: _currentCadenceSpm,
        averageCadenceSpm: _avgCadenceSpm,
        estimatedStepLengthMeters: _estimatedStepLengthM,
        isStepBuffered: _isStepBuffered,
      );
    });
  }

  void _onPosition(Position pos) {
    final nowMonotonicMs = _monotonicStopwatch.elapsedMilliseconds;

    // 1. Adaptive Accuracy Gate
    final validation = GpsFilter.validateFix(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracy: pos.accuracy,
      speedMetersPerSec: pos.speed > 0 ? pos.speed : null,
    );

    if (!validation.isAccepted) {
      // Discarded point: Log to SQLite journal as rejected
      final rejectedPoint = BreadcrumbPoint(
        runId: state.runId!,
        epochId: _epochId,
        latitude: pos.latitude,
        longitude: pos.longitude,
        altitude: pos.altitude,
        accuracy: pos.accuracy,
        dopplerSpeed: pos.speed,
        hardwareSteps: _totalSteps,
        monotonicMs: nowMonotonicMs,
        timestamp: DateTime.now(),
        isRejected: true,
        rejectionReason: validation.rejectionReason,
      );
      _pendingTelemetryBatch.add(rejectedPoint);

      state = state.copyWith(
        currentAccuracyMeters: pos.accuracy,
        gpsConfidence: 'Poor',
      );
      return;
    }

    final gpsConfidence = validation.isNoisy ? 'Medium' : 'High';

    // 2. Doppler Speed 1-Pole Low-Pass Filter
    final rawSpeed = pos.speed >= 0 ? pos.speed : 0.0;
    _smoothedSpeedMps = GpsFilter.filterDopplerSpeed(rawSpeed, _smoothedSpeedMps);

    // 3. Asymmetric Auto-Pause Hysteresis
    _evaluateAutoPause(_smoothedSpeedMps, nowMonotonicMs);

    // 4. Distance & Coordinate Accumulation
    double addedDist = 0.0;
    if (_lastValidLat != null && _lastValidLng != null) {
      final delta = GpsFilter.haversineDistance(
        _lastValidLat!,
        _lastValidLng!,
        pos.latitude,
        pos.longitude,
      );

      // Only accumulate distance if moving and passes delta threshold
      if (!_isAutoPaused && state.status == TrackingStatus.running && delta >= GpsFilter.minDistanceDeltaMeters) {
        addedDist = delta;
      }
    }

    _lastValidLat = pos.latitude;
    _lastValidLng = pos.longitude;

    // 5. Continuous Altitude & 2.0m Anchor Hysteresis
    _handleAltitude(pos.altitude, addedDist);

    final newDistance = state.distanceMeters + addedDist;

    // 6. Rolling 10s Live Pace Window
    _rollingPaceWindow.add((distance: addedDist, timestampMs: nowMonotonicMs));
    _rollingPaceWindow.removeWhere((w) => nowMonotonicMs - w.timestampMs > 10000);

    double rollingDist = 0.0;
    for (final w in _rollingPaceWindow) {
      rollingDist += w.distance;
    }
    final livePaceSec = (rollingDist > 2.0 && !_isAutoPaused)
        ? (10.0 / (rollingDist / 1000.0))
        : 0.0;

    // 7. 40m Windowed Grade & Minetti GAP
    final gradient = _calculate40mWindowGradient(newDistance, pos.altitude);
    final gapPace = (newDistance >= GpsFilter.minGapDistanceWarmupMeters && livePaceSec > 0)
        ? GpsFilter.calculateMinettiGap(
            actualPaceSecondsPerKm: livePaceSec,
            gradientFraction: gradient,
          )
        : livePaceSec;

    // 8. Dual-Speed ACSM Metabolic Calorie Calculation
    if (!_isAutoPaused && state.status == TrackingStatus.running) {
      _cumulativeCalories += GpsFilter.calculateAcsmKcalBurnPerSecond(
        speedMps: _smoothedSpeedMps,
        gradientFraction: gradient,
        runnerWeightKg: 70.0,
      );
    }

    // 9. 1 km Auto-Split Check
    _checkSplit(newDistance, pos.altitude);

    final newPoint = BreadcrumbPoint(
      runId: state.runId!,
      epochId: _epochId,
      latitude: pos.latitude,
      longitude: pos.longitude,
      altitude: pos.altitude,
      accuracy: pos.accuracy,
      speedMetersPerSec: pos.speed,
      dopplerSpeed: _smoothedSpeedMps,
      hardwareSteps: _totalSteps,
      monotonicMs: nowMonotonicMs,
      timestamp: DateTime.now(),
      isRejected: false,
    );

    _pendingTelemetryBatch.add(newPoint);
    if (_pendingTelemetryBatch.length >= 10) {
      _flushBatch();
    }

    state = state.copyWith(
      status: _isAutoPaused ? TrackingStatus.paused : TrackingStatus.running,
      distanceMeters: newDistance,
      currentPaceSecondsPerKm: livePaceSec,
      currentGapSecondsPerKm: gapPace,
      currentAltitude: pos.altitude,
      elevationGainMeters: _cumulativeGainMeters,
      elevationLossMeters: _cumulativeLossMeters,
      currentAccuracyMeters: pos.accuracy,
      gpsConfidence: gpsConfidence,
      isAutoPaused: _isAutoPaused,
      estimatedCalories: _cumulativeCalories,
      splits: _splits,
      breadcrumbs: [...state.breadcrumbs, newPoint],
      errorMessage: null,
    );
  }

  void _evaluateAutoPause(double speedMps, int monotonicMs) {
    if (speedMps < GpsFilter.autoPauseThresholdMps) {
      _consecutiveSlowSeconds++;
      if (_consecutiveSlowSeconds >= GpsFilter.autoPauseSustainedSeconds && !_isAutoPaused) {
        _isAutoPaused = true;
        _gpsRepo.logEvent(RunEvent(
          runId: state.runId!,
          epochId: _epochId,
          eventType: 'auto_pause',
          monotonicMs: monotonicMs,
          timestamp: DateTime.now(),
        ));
      }
    } else if (speedMps >= GpsFilter.autoResumeThresholdMps) {
      _consecutiveSlowSeconds = 0;
      if (_isAutoPaused) {
        _isAutoPaused = false;
        _lastMovingTickMs = monotonicMs;
        _gpsRepo.logEvent(RunEvent(
          runId: state.runId!,
          epochId: _epochId,
          eventType: 'auto_resume',
          monotonicMs: monotonicMs,
          timestamp: DateTime.now(),
        ));
      }
    }
  }

  void _handleAltitude(double rawAltitude, double distanceDelta) {
    _recentAltitudes.add(rawAltitude);
    if (_recentAltitudes.length > 5) {
      _recentAltitudes.removeAt(0);
    }
    final smoothedAlt = GpsFilter.medianFilter(_recentAltitudes);

    _distanceAltitudeHistory.add((
      distance: state.distanceMeters + distanceDelta,
      altitude: smoothedAlt,
    ));
    if (_distanceAltitudeHistory.length > 100) {
      _distanceAltitudeHistory.removeAt(0);
    }

    // Anchor-Point Hysteresis (+-2.0m)
    _anchorAltitude ??= smoothedAlt;
    final dH = smoothedAlt - _anchorAltitude!;

    if (dH >= GpsFilter.elevationAnchorHysteresisMeters) {
      _cumulativeGainMeters += dH;
      _anchorAltitude = smoothedAlt;
    } else if (dH <= -GpsFilter.elevationAnchorHysteresisMeters) {
      _cumulativeLossMeters += dH.abs();
      _anchorAltitude = smoothedAlt;
    }
  }

  double _calculate40mWindowGradient(double currentDistance, double currentAltitude) {
    if (_distanceAltitudeHistory.isEmpty) return 0.0;

    final targetDist = currentDistance - GpsFilter.gapWindowDistanceMeters;
    final baseline = _distanceAltitudeHistory.lastWhere(
      (entry) => entry.distance <= targetDist,
      orElse: () => _distanceAltitudeHistory.first,
    );

    final dDist = currentDistance - baseline.distance;
    if (dDist < 10.0) return 0.0;

    final dAlt = currentAltitude - baseline.altitude;
    return dAlt / dDist;
  }

  void _checkSplit(double currentDistanceMeters, double currentAltitude) {
    final nextKmTarget = (_splits.length + 1) * 1000.0;
    if (currentDistanceMeters >= nextKmTarget) {
      final splitDistance = currentDistanceMeters - _lastSplitDistanceMeters;
      final splitDurationMs = _movingMs - _lastSplitMovingMs;
      final splitSec = (splitDurationMs / 1000.0).round();
      final paceSecPerKm = splitSec / (splitDistance / 1000.0);
      final elevDelta = currentAltitude - _lastSplitAltitude;
      final splitGradient = splitDistance > 0 ? (elevDelta / splitDistance) : 0.0;
      final splitGap = GpsFilter.calculateMinettiGap(
        actualPaceSecondsPerKm: paceSecPerKm,
        gradientFraction: splitGradient,
      );

      final split = RunSplit(
        kilometer: _splits.length + 1,
        splitDurationSeconds: splitSec,
        averagePaceSecondsPerKm: paceSecPerKm,
        gapSecondsPerKm: splitGap,
        elevationChangeMeters: elevDelta,
        averageCadenceSpm: _currentCadenceSpm > 0 ? _currentCadenceSpm : null,
      );

      _splits.add(split);
      _lastSplitDistanceMeters = currentDistanceMeters;
      _lastSplitMovingMs = _movingMs;
      _lastSplitAltitude = currentAltitude;

      _gpsRepo.logEvent(RunEvent(
        runId: state.runId!,
        epochId: _epochId,
        eventType: 'split',
        monotonicMs: _monotonicStopwatch.elapsedMilliseconds,
        timestamp: DateTime.now(),
        extraJson: '{"km": ${_splits.length}, "pace": $paceSecPerKm}',
      ));
    }
  }

  void _flushBatch() {
    if (_pendingTelemetryBatch.isEmpty) return;
    final batchToSave = List<BreadcrumbPoint>.from(_pendingTelemetryBatch);
    _pendingTelemetryBatch.clear();

    _gpsRepo.saveBreadcrumbBatch(batchToSave).catchError((Object e, StackTrace st) {
      AppCrashReporter.recordError(e, st, reason: 'sqlite_batch_insert_error');
    });

    _gpsRepo.updateRunRecord(
      runId: state.runId!,
      status: state.status.name,
      startedAt: state.breadcrumbs.isNotEmpty ? state.breadcrumbs.first.timestamp : DateTime.now(),
      elapsedMs: _monotonicStopwatch.elapsedMilliseconds,
      movingMs: _movingMs,
      distanceMeters: state.distanceMeters,
      totalSteps: _totalSteps,
    );
  }

  void _resetTelemetryVariables() {
    _monotonicStopwatch.reset();
    _movingMs = 0;
    _lastMovingTickMs = 0;
    _smoothedSpeedMps = 0.0;
    _consecutiveSlowSeconds = 0;
    _isAutoPaused = false;
    _lastValidLat = null;
    _lastValidLng = null;
    _anchorAltitude = null;
    _cumulativeGainMeters = 0.0;
    _cumulativeLossMeters = 0.0;
    _recentAltitudes.clear();
    _distanceAltitudeHistory.clear();
    _rollingPaceWindow.clear();
    _splits.clear();
    _lastSplitDistanceMeters = 0.0;
    _lastSplitMovingMs = 0;
    _lastSplitAltitude = 0.0;
    _pendingTelemetryBatch.clear();
    _cumulativeCalories = 0.0;
    _totalSteps = 0;
    _currentCadenceSpm = 0.0;
    _avgCadenceSpm = 0.0;
    _estimatedStepLengthM = 0.0;
    _isStepBuffered = false;
  }

  void _cleanup() {
    _monotonicStopwatch.stop();
    _oneSecondTimer?.cancel();
    _oneSecondTimer = null;
    _demoTimer?.cancel();
    _demoTimer = null;
    _positionSub?.cancel();
    _positionSub = null;
    _stepSub?.cancel();
    _stepSub = null;
    _stepRepo.stopTracking();
  }
}
