import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

final stepCadenceRepositoryProvider = Provider<StepCadenceRepository>((ref) {
  final repo = StepCadenceRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

class StepData {
  final int totalRunSteps;
  final double currentCadenceSpm;
  final bool isBuffered;

  const StepData({
    required this.totalRunSteps,
    required this.currentCadenceSpm,
    this.isBuffered = false,
  });
}

/// Robust step & cadence telemetry repository.
/// Manages hardware step counting, S0 baseline offsets, reboot wrap-around,
/// and deep-doze buffering.
class StepCadenceRepository {
  StreamSubscription<StepCount>? _stepSub;
  StreamController<StepData>? _stepDataController;

  // Baseline and accumulation
  int? _initialHardwareSteps;
  int _lastHardwareSteps = 0;
  int _accumulatedStepsPriorToReset = 0;

  // Cadence calculation rolling window
  final List<({int steps, DateTime timestamp})> _stepHistory = [];
  DateTime? _lastStepEventTime;
  double _lastKnownCadence = 0.0;

  Stream<StepData> get stepStream {
    _stepDataController ??= StreamController<StepData>.broadcast();
    return _stepDataController!.stream;
  }

  /// Requests Activity Recognition permission.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    final status = await Permission.activityRecognition.request();
    return status.isGranted;
  }

  /// Starts listening to the hardware step counter.
  Future<void> startTracking() async {
    _cleanup();
    _stepDataController = StreamController<StepData>.broadcast();
    _initialHardwareSteps = null;
    _lastHardwareSteps = 0;
    _accumulatedStepsPriorToReset = 0;
    _stepHistory.clear();
    _lastKnownCadence = 0.0;
    _lastStepEventTime = null;

    if (kIsWeb) return;

    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) return;

      _stepSub = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: (err) {
          debugPrint('StepCadenceRepository pedometer error: $err');
        },
      );
    } catch (e) {
      debugPrint('StepCadenceRepository initialization failed: $e');
    }
  }

  void _onStepCount(StepCount event) {
    final now = DateTime.now();
    final currentSteps = event.steps;

    // 1. Establish S0 Baseline on first event
    if (_initialHardwareSteps == null) {
      _initialHardwareSteps = currentSteps;
      _lastHardwareSteps = currentSteps;
      _lastStepEventTime = now;
      _stepHistory.add((steps: currentSteps, timestamp: now));
      _stepDataController?.add(
        const StepData(totalRunSteps: 0, currentCadenceSpm: 0.0),
      );
      return;
    }

    // 2. Hardware Reboot / Wrap-Around Guard
    if (currentSteps < _lastHardwareSteps) {
      // The device rebooted or step counter wrapped around
      _accumulatedStepsPriorToReset += (_lastHardwareSteps - _initialHardwareSteps!);
      _initialHardwareSteps = currentSteps;
      _lastHardwareSteps = currentSteps;
    }

    _lastHardwareSteps = currentSteps;
    _lastStepEventTime = now;

    // 3. Compute net run steps
    final runSteps = _accumulatedStepsPriorToReset + (currentSteps - _initialHardwareSteps!);

    // 4. Rolling Cadence (SPM) over a 10-second window
    _stepHistory.add((steps: currentSteps, timestamp: now));
    _stepHistory.removeWhere((entry) => now.difference(entry.timestamp).inSeconds > 10);

    double cadence = 0.0;
    if (_stepHistory.length >= 2) {
      final dtSeconds = now.difference(_stepHistory.first.timestamp).inMilliseconds / 1000.0;
      final dSteps = _stepHistory.last.steps - _stepHistory.first.steps;
      if (dtSeconds > 1.0 && dSteps >= 0) {
        cadence = (dSteps / dtSeconds) * 60.0;
      }
    }

    _lastKnownCadence = cadence;

    _stepDataController?.add(
      StepData(
        totalRunSteps: runSteps,
        currentCadenceSpm: cadence,
        isBuffered: false,
      ),
    );
  }

  /// Called periodically by the tracker timer to check for deep-doze batching delays.
  StepData checkCadenceHeartbeat({required bool isMoving}) {
    final now = DateTime.now();
    final timeSinceLastEvent = _lastStepEventTime == null
        ? 999
        : now.difference(_lastStepEventTime!).inSeconds;

    final currentTotal = _initialHardwareSteps == null
        ? 0
        : _accumulatedStepsPriorToReset + (_lastHardwareSteps - _initialHardwareSteps!);

    // If moving at speed, but sensor hasn't fired in > 12s, buffer the last known cadence
    if (isMoving && timeSinceLastEvent > 12 && _lastKnownCadence > 0) {
      return StepData(
        totalRunSteps: currentTotal,
        currentCadenceSpm: _lastKnownCadence,
        isBuffered: true,
      );
    }

    // If stopped / stationary, clamp cadence to zero
    if (!isMoving) {
      _lastKnownCadence = 0.0;
      return StepData(
        totalRunSteps: currentTotal,
        currentCadenceSpm: 0.0,
        isBuffered: false,
      );
    }

    return StepData(
      totalRunSteps: currentTotal,
      currentCadenceSpm: _lastKnownCadence,
      isBuffered: false,
    );
  }

  void stopTracking() {
    _cleanup();
  }

  void dispose() {
    _cleanup();
    _stepDataController?.close();
  }

  void _cleanup() {
    _stepSub?.cancel();
    _stepSub = null;
  }
}
