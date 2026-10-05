import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:blee/features/tracking/data/gps_repository.dart';
import 'package:blee/features/tracking/data/step_cadence_repository.dart';
import 'package:blee/features/tracking/domain/run_summary_entity.dart';

/// Helper to build test Positions deterministically.
class FakePositionBuilder {
  static Position create({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
    double accuracy = 5.0,
    double? altitude = 25.0,
    double speed = 3.33,
    double heading = 0.0,
  }) {
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp ?? DateTime.now(),
      accuracy: accuracy,
      altitude: altitude ?? 0.0,
      altitudeAccuracy: 1.0,
      heading: heading,
      headingAccuracy: 1.0,
      speed: speed,
      speedAccuracy: 0.1,
    );
  }
}

/// Controllable stream of GPS fixes.
class FakeGpsStream {
  final _controller = StreamController<Position>.broadcast();

  Stream<Position> get stream => _controller.stream;

  void emit(Position pos) {
    _controller.add(pos);
  }

  void emitError(Object error) {
    _controller.addError(error);
  }

  void close() {
    _controller.close();
  }
}

/// Controllable Step Cadence Repository.
class FakeStepCadenceRepository extends StepCadenceRepository {
  final _stepController = StreamController<StepData>.broadcast();
  bool permissionGranted = true;
  bool isTracking = false;
  int currentSteps = 0;
  double currentCadence = 0.0;
  bool isBuffered = false;

  @override
  Stream<StepData> get stepStream => _stepController.stream;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<void> startTracking() async {
    isTracking = true;
  }

  @override
  void stopTracking() {
    isTracking = false;
  }

  void emitSteps({required int steps, double cadence = 175.0, bool buffered = false}) {
    currentSteps = steps;
    currentCadence = cadence;
    isBuffered = buffered;
    _stepController.add(StepData(
      totalRunSteps: steps,
      currentCadenceSpm: cadence,
      isBuffered: buffered,
    ));
  }

  @override
  StepData checkCadenceHeartbeat({required bool isMoving}) {
    return StepData(
      totalRunSteps: currentSteps,
      currentCadenceSpm: isMoving ? currentCadence : 0.0,
      isBuffered: isBuffered,
    );
  }

  @override
  void dispose() {
    _stepController.close();
    super.dispose();
  }
}

/// In-Memory implementation of IGpsRepository for testing.
class InMemoryGpsRepository implements IGpsRepository {
  final FakeGpsStream gpsStream = FakeGpsStream();
  bool permissionGranted = true;
  bool throwOnBatchSave = false;
  bool throwOnUpdateRun = false;
  bool throwOnGetUnfinished = false;

  final Map<String, Map<String, dynamic>> runs = {};
  final List<BreadcrumbPoint> rawTelemetry = [];
  final List<RunEvent> events = [];

  Position? latestPosition;

  @override
  Future<bool> checkPermission() async => permissionGranted;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<Position?> getCurrentPosition() async => latestPosition;

  @override
  Stream<Position> getPositionStream({LocationSettings? settings}) => gpsStream.stream;

  @override
  Future<void> saveBreadcrumb(BreadcrumbPoint point) async {
    if (throwOnBatchSave) throw Exception('SQLite write error: disk full / lock');
    rawTelemetry.add(point);
  }

  @override
  Future<void> saveBreadcrumbBatch(List<BreadcrumbPoint> points) async {
    if (throwOnBatchSave) throw Exception('SQLite batch insert failed: disk full / lock');
    rawTelemetry.addAll(points);
  }

  @override
  Future<void> logEvent(RunEvent event) async {
    events.add(event);
  }

  @override
  Future<void> updateRunRecord({
    required String runId,
    required String status,
    required DateTime startedAt,
    DateTime? endedAt,
    int elapsedMs = 0,
    int movingMs = 0,
    double distanceMeters = 0.0,
    int totalSteps = 0,
  }) async {
    if (throwOnUpdateRun) throw Exception('Database error on updateRunRecord');
    runs[runId] = {
      'id': runId,
      'status': status,
      'started_at': startedAt.millisecondsSinceEpoch,
      'ended_at': endedAt?.millisecondsSinceEpoch,
      'elapsed_ms': elapsedMs,
      'moving_ms': movingMs,
      'distance_meters': distanceMeters,
      'total_steps': totalSteps,
    };
  }

  @override
  Future<Map<String, dynamic>?> getUnfinishedRun() async {
    if (throwOnGetUnfinished) throw Exception('Database error on getUnfinishedRun');
    for (final run in runs.values) {
      if (run['status'] == 'running' || run['status'] == 'interrupted') {
        return run;
      }
    }
    return null;
  }

  @override
  Future<List<BreadcrumbPoint>> getBreadcrumbs(String runId) async {
    return rawTelemetry
        .where((p) => p.runId == runId && !p.isRejected)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  @override
  Future<List<RunEvent>> getEvents(String runId) async {
    return events.where((e) => e.runId == runId).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  @override
  Future<void> deleteBreadcrumbs(String runId) async {
    rawTelemetry.removeWhere((p) => p.runId == runId);
    events.removeWhere((e) => e.runId == runId);
    runs.remove(runId);
  }
}

/// Scenario status enum
enum ScenarioStatus { pass, fail, notRun }

/// Result of executing a scenario
class ScenarioResult {
  final String id;
  final String category;
  final String title;
  final ScenarioStatus status;
  final String expected;
  final String actual;
  final String? rootCause;
  final String? fileAndLine;
  final String? proposedFix;

  const ScenarioResult({
    required this.id,
    required this.category,
    required this.title,
    required this.status,
    required this.expected,
    required this.actual,
    this.rootCause,
    this.fileAndLine,
    this.proposedFix,
  });

  bool get passed => status == ScenarioStatus.pass;
}

/// Scenario definition
class ScenarioDefinition {
  final String id;
  final String category;
  final String title;
  final String description;
  final Future<ScenarioResult> Function() run;

  const ScenarioDefinition({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.run,
  });
}
