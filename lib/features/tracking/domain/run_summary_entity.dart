import 'package:flutter/foundation.dart';

/// Immutable domain entity for a completed run breadcrumb point.
@immutable
class BreadcrumbPoint {
  final String runId;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double accuracy;
  final double? speedMetersPerSec;
  final DateTime timestamp;

  const BreadcrumbPoint({
    required this.runId,
    required this.latitude,
    required this.longitude,
    this.altitude,
    required this.accuracy,
    this.speedMetersPerSec,
    required this.timestamp,
  });
}

/// Immutable domain entity for a completed run summary.
@immutable
class RunSummaryEntity {
  final String runId;
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceMeters;
  final int durationSeconds;
  final double avgPaceSecondsPerKm;
  final double? peakKmPaceSecondsPerKm;
  final int? peakKmIndex;
  final int? rpe;
  final List<BreadcrumbPoint> breadcrumbs;

  const RunSummaryEntity({
    required this.runId,
    required this.startedAt,
    required this.endedAt,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.avgPaceSecondsPerKm,
    this.peakKmPaceSecondsPerKm,
    this.peakKmIndex,
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
      avgPaceSecondsPerKm: avgPaceSecondsPerKm,
      peakKmPaceSecondsPerKm: peakKmPaceSecondsPerKm,
      peakKmIndex: peakKmIndex,
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
  final double distanceMeters;
  final int elapsedSeconds;
  final double currentPaceSecondsPerKm;
  final double? currentAccuracyMeters;
  final List<BreadcrumbPoint> breadcrumbs;
  final String? errorMessage;

  const TrackingState({
    this.status = TrackingStatus.idle,
    this.runId,
    this.distanceMeters = 0,
    this.elapsedSeconds = 0,
    this.currentPaceSecondsPerKm = 0,
    this.currentAccuracyMeters,
    this.breadcrumbs = const [],
    this.errorMessage,
  });

  double get distanceKm => distanceMeters / 1000;
  bool get isActive => status == TrackingStatus.running || status == TrackingStatus.paused;

  TrackingState copyWith({
    TrackingStatus? status,
    String? runId,
    double? distanceMeters,
    int? elapsedSeconds,
    double? currentPaceSecondsPerKm,
    double? currentAccuracyMeters,
    List<BreadcrumbPoint>? breadcrumbs,
    String? errorMessage,
  }) {
    return TrackingState(
      status: status ?? this.status,
      runId: runId ?? this.runId,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      currentPaceSecondsPerKm: currentPaceSecondsPerKm ?? this.currentPaceSecondsPerKm,
      currentAccuracyMeters: currentAccuracyMeters ?? this.currentAccuracyMeters,
      breadcrumbs: breadcrumbs ?? this.breadcrumbs,
      errorMessage: errorMessage,
    );
  }
}
