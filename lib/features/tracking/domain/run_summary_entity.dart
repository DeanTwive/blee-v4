import 'package:flutter/foundation.dart';

/// Immutable domain entity for a recorded raw telemetry breadcrumb point.
@immutable
class BreadcrumbPoint {
  final String runId;
  final int epochId;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double accuracy;
  final double? speedMetersPerSec;
  final double? dopplerSpeed;
  final int? hardwareSteps;
  final int? monotonicMs;
  final DateTime timestamp;
  final bool isRejected;
  final String? rejectionReason;

  const BreadcrumbPoint({
    required this.runId,
    this.epochId = 0,
    required this.latitude,
    required this.longitude,
    this.altitude,
    required this.accuracy,
    this.speedMetersPerSec,
    this.dopplerSpeed,
    this.hardwareSteps,
    this.monotonicMs,
    required this.timestamp,
    this.isRejected = false,
    this.rejectionReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'run_id': runId,
      'epoch_id': epochId,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'doppler_speed': dopplerSpeed ?? speedMetersPerSec,
      'hardware_steps': hardwareSteps,
      'monotonic_ms': monotonicMs ?? 0,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'is_rejected': isRejected ? 1 : 0,
      'rejection_reason': rejectionReason,
    };
  }

  factory BreadcrumbPoint.fromMap(Map<String, dynamic> map) {
    return BreadcrumbPoint(
      runId: map['run_id'] as String,
      epochId: (map['epoch_id'] as int?) ?? 0,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      altitude: (map['altitude'] as num?)?.toDouble(),
      accuracy: (map['accuracy'] as num).toDouble(),
      speedMetersPerSec: (map['doppler_speed'] as num?)?.toDouble(),
      dopplerSpeed: (map['doppler_speed'] as num?)?.toDouble(),
      hardwareSteps: map['hardware_steps'] as int?,
      monotonicMs: map['monotonic_ms'] as int?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      isRejected: (map['is_rejected'] as int? ?? 0) == 1,
      rejectionReason: map['rejection_reason'] as String?,
    );
  }
}

/// Immutable record of a state transition or telemetry event.
@immutable
class RunEvent {
  final String runId;
  final int epochId;
  final String eventType; // 'manual_pause', 'manual_resume', 'auto_pause', 'auto_resume', 'split', 'paused_gap'
  final int monotonicMs;
  final DateTime timestamp;
  final String? extraJson;

  const RunEvent({
    required this.runId,
    required this.epochId,
    required this.eventType,
    required this.monotonicMs,
    required this.timestamp,
    this.extraJson,
  });

  Map<String, dynamic> toMap() {
    return {
      'run_id': runId,
      'epoch_id': epochId,
      'event_type': eventType,
      'monotonic_ms': monotonicMs,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'extra_json': extraJson,
    };
  }

  factory RunEvent.fromMap(Map<String, dynamic> map) {
    return RunEvent(
      runId: map['run_id'] as String,
      epochId: (map['epoch_id'] as int?) ?? 0,
      eventType: map['event_type'] as String,
      monotonicMs: (map['monotonic_ms'] as int?) ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      extraJson: map['extra_json'] as String?,
    );
  }
}

/// 1 km / 1 mile auto-split checkpoint record.
@immutable
class RunSplit {
  final int kilometer;
  final int splitDurationSeconds;
  final double averagePaceSecondsPerKm;
  final double? gapSecondsPerKm;
  final double elevationChangeMeters;
  final double? averageCadenceSpm;

  const RunSplit({
    required this.kilometer,
    required this.splitDurationSeconds,
    required this.averagePaceSecondsPerKm,
    this.gapSecondsPerKm,
    required this.elevationChangeMeters,
    this.averageCadenceSpm,
  });

  int get splitIndex => kilometer;
  double get paceSecondsPerKm => averagePaceSecondsPerKm;
  double get elevationDeltaMeters => elevationChangeMeters;

  Map<String, dynamic> toMap() {
    return {
      'kilometer': kilometer,
      'split_duration_seconds': splitDurationSeconds,
      'avg_pace_seconds_per_km': averagePaceSecondsPerKm,
      'gap_seconds_per_km': gapSecondsPerKm,
      'elevation_change_meters': elevationChangeMeters,
      'avg_cadence_spm': averageCadenceSpm,
    };
  }

  factory RunSplit.fromMap(Map<String, dynamic> map) {
    return RunSplit(
      kilometer: map['kilometer'] as int,
      splitDurationSeconds: map['split_duration_seconds'] as int,
      averagePaceSecondsPerKm: (map['avg_pace_seconds_per_km'] as num).toDouble(),
      gapSecondsPerKm: (map['gap_seconds_per_km'] as num?)?.toDouble(),
      elevationChangeMeters: (map['elevation_change_meters'] as num).toDouble(),
      averageCadenceSpm: (map['avg_cadence_spm'] as num?)?.toDouble(),
    );
  }
}

/// Immutable domain entity for a completed run summary.
@immutable
class RunSummaryEntity {
  final String runId;
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceMeters;
  final int durationSeconds;
  final int movingSeconds;
  final double avgPaceSecondsPerKm;
  final double? peakKmPaceSecondsPerKm;
  final int? peakKmIndex;
  final double elevationGainMeters;
  final double elevationLossMeters;
  final int totalSteps;
  final double avgCadenceSpm;
  final double avgStepLengthMeters;
  final double estimatedCalories;
  final List<RunSplit> splits;
  final int? rpe;
  final List<BreadcrumbPoint> breadcrumbs;

  const RunSummaryEntity({
    required this.runId,
    required this.startedAt,
    required this.endedAt,
    required this.distanceMeters,
    required this.durationSeconds,
    this.movingSeconds = 0,
    required this.avgPaceSecondsPerKm,
    this.peakKmPaceSecondsPerKm,
    this.peakKmIndex,
    this.elevationGainMeters = 0.0,
    this.elevationLossMeters = 0.0,
    this.totalSteps = 0,
    this.avgCadenceSpm = 0.0,
    this.avgStepLengthMeters = 0.0,
    this.estimatedCalories = 0.0,
    this.splits = const [],
    this.rpe,
    required this.breadcrumbs,
  });

  double get distanceKm => distanceMeters / 1000.0;

  RunSummaryEntity copyWith({int? rpe}) {
    return RunSummaryEntity(
      runId: runId,
      startedAt: startedAt,
      endedAt: endedAt,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      movingSeconds: movingSeconds,
      avgPaceSecondsPerKm: avgPaceSecondsPerKm,
      peakKmPaceSecondsPerKm: peakKmPaceSecondsPerKm,
      peakKmIndex: peakKmIndex,
      elevationGainMeters: elevationGainMeters,
      elevationLossMeters: elevationLossMeters,
      totalSteps: totalSteps,
      avgCadenceSpm: avgCadenceSpm,
      avgStepLengthMeters: avgStepLengthMeters,
      estimatedCalories: estimatedCalories,
      splits: splits,
      rpe: rpe ?? this.rpe,
      breadcrumbs: breadcrumbs,
    );
  }
}

/// Live in-run tracking state.
enum TrackingStatus { idle, acquiring, running, paused, stopped }

@immutable
class TrackingState {
  final TrackingStatus status;
  final String? runId;
  final int epochId;

  // Distances & Durations
  final double distanceMeters;
  final int elapsedSeconds;
  final int movingSeconds;

  // Pacing & Splits
  final double currentPaceSecondsPerKm;
  final double averagePaceSecondsPerKm;
  final double currentGapSecondsPerKm;
  final List<RunSplit> splits;

  // Kinematics & Health
  final int totalSteps;
  final double currentCadenceSpm;
  final double averageCadenceSpm;
  final double estimatedStepLengthMeters;
  final double estimatedCalories;
  final bool isStepBuffered;

  // Topography
  final double? currentAltitude;
  final double elevationGainMeters;
  final double elevationLossMeters;

  // Quality & Controls
  final double? currentAccuracyMeters;
  final String gpsConfidence; // 'High', 'Medium', 'Poor'
  final bool isAutoPaused;
  final List<BreadcrumbPoint> breadcrumbs;
  final String? errorMessage;
  final Map<String, dynamic>? unfinishedRun;

  const TrackingState({
    this.status = TrackingStatus.idle,
    this.runId,
    this.epochId = 0,
    this.distanceMeters = 0,
    this.elapsedSeconds = 0,
    this.movingSeconds = 0,
    this.currentPaceSecondsPerKm = 0,
    this.averagePaceSecondsPerKm = 0,
    this.currentGapSecondsPerKm = 0,
    this.splits = const [],
    this.totalSteps = 0,
    this.currentCadenceSpm = 0,
    this.averageCadenceSpm = 0,
    this.estimatedStepLengthMeters = 0,
    this.estimatedCalories = 0,
    this.isStepBuffered = false,
    this.currentAltitude,
    this.elevationGainMeters = 0,
    this.elevationLossMeters = 0,
    this.currentAccuracyMeters,
    this.gpsConfidence = 'High',
    this.isAutoPaused = false,
    this.breadcrumbs = const [],
    this.errorMessage,
    this.unfinishedRun,
  });

  double get distanceKm => distanceMeters / 1000;
  bool get isActive => status == TrackingStatus.running || status == TrackingStatus.paused;

  TrackingState copyWith({
    TrackingStatus? status,
    String? runId,
    int? epochId,
    double? distanceMeters,
    int? elapsedSeconds,
    int? movingSeconds,
    double? currentPaceSecondsPerKm,
    double? averagePaceSecondsPerKm,
    double? currentGapSecondsPerKm,
    List<RunSplit>? splits,
    int? totalSteps,
    double? currentCadenceSpm,
    double? averageCadenceSpm,
    double? estimatedStepLengthMeters,
    double? estimatedCalories,
    bool? isStepBuffered,
    double? currentAltitude,
    double? elevationGainMeters,
    double? elevationLossMeters,
    double? currentAccuracyMeters,
    String? gpsConfidence,
    bool? isAutoPaused,
    List<BreadcrumbPoint>? breadcrumbs,
    String? errorMessage,
    Map<String, dynamic>? unfinishedRun,
    bool clearUnfinishedRun = false,
  }) {
    return TrackingState(
      status: status ?? this.status,
      runId: runId ?? this.runId,
      epochId: epochId ?? this.epochId,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      movingSeconds: movingSeconds ?? this.movingSeconds,
      currentPaceSecondsPerKm: currentPaceSecondsPerKm ?? this.currentPaceSecondsPerKm,
      averagePaceSecondsPerKm: averagePaceSecondsPerKm ?? this.averagePaceSecondsPerKm,
      currentGapSecondsPerKm: currentGapSecondsPerKm ?? this.currentGapSecondsPerKm,
      splits: splits ?? this.splits,
      totalSteps: totalSteps ?? this.totalSteps,
      currentCadenceSpm: currentCadenceSpm ?? this.currentCadenceSpm,
      averageCadenceSpm: averageCadenceSpm ?? this.averageCadenceSpm,
      estimatedStepLengthMeters: estimatedStepLengthMeters ?? this.estimatedStepLengthMeters,
      estimatedCalories: estimatedCalories ?? this.estimatedCalories,
      isStepBuffered: isStepBuffered ?? this.isStepBuffered,
      currentAltitude: currentAltitude ?? this.currentAltitude,
      elevationGainMeters: elevationGainMeters ?? this.elevationGainMeters,
      elevationLossMeters: elevationLossMeters ?? this.elevationLossMeters,
      currentAccuracyMeters: currentAccuracyMeters ?? this.currentAccuracyMeters,
      gpsConfidence: gpsConfidence ?? this.gpsConfidence,
      isAutoPaused: isAutoPaused ?? this.isAutoPaused,
      breadcrumbs: breadcrumbs ?? this.breadcrumbs,
      errorMessage: errorMessage,
      unfinishedRun: clearUnfinishedRun ? null : (unfinishedRun ?? this.unfinishedRun),
    );
  }
}
