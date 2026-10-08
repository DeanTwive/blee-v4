import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'local_run_db.dart';
import '../domain/run_summary_entity.dart';

abstract class IGpsRepository {
  Future<bool> checkPermission();
  Future<bool> requestPermission();
  Future<Position?> getCurrentPosition();
  Stream<Position> getPositionStream({LocationSettings? settings});
  Future<void> saveBreadcrumb(BreadcrumbPoint point);
  Future<void> saveBreadcrumbBatch(List<BreadcrumbPoint> points);
  Future<void> logEvent(RunEvent event);
  Future<void> updateRunRecord({
    required String runId,
    required String status,
    required DateTime startedAt,
    DateTime? endedAt,
    int elapsedMs = 0,
    int movingMs = 0,
    double distanceMeters = 0.0,
    int totalSteps = 0,
  });
  Future<Map<String, dynamic>?> getUnfinishedRun();
  Future<List<BreadcrumbPoint>> getBreadcrumbs(String runId);
  Future<List<RunEvent>> getEvents(String runId);
  Future<void> deleteBreadcrumbs(String runId);
}

class GpsRepository implements IGpsRepository {
  final LocalRunDb _db;

  GpsRepository({LocalRunDb? db}) : _db = db ?? LocalRunDb();

  @override
  Future<bool> checkPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  @override
  Future<bool> requestPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  @override
  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: kIsWeb
            ? const LocationSettings(accuracy: LocationAccuracy.high)
            : const LocationSettings(accuracy: LocationAccuracy.bestForNavigation),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? settings}) {
    return Geolocator.getPositionStream(
      locationSettings: settings ??
          (kIsWeb
              ? const LocationSettings(
                  accuracy: LocationAccuracy.high,
                  distanceFilter: 0,
                )
              : defaultTargetPlatform == TargetPlatform.android
                  ? AndroidSettings(
                      accuracy: LocationAccuracy.bestForNavigation,
                      distanceFilter: 0,
                      intervalDuration: const Duration(seconds: 1),
                      foregroundNotificationConfig: const ForegroundNotificationConfig(
                        notificationTitle: 'Blee Running Tracker',
                        notificationText: 'Tracking your run in the background',
                        enableWakeLock: true,
                      ),
                    )
                  : const LocationSettings(
                      accuracy: LocationAccuracy.bestForNavigation,
                      distanceFilter: 0,
                    )),
    );
  }

  @override
  Future<void> saveBreadcrumb(BreadcrumbPoint point) {
    return _db.insertPoint(point);
  }

  @override
  Future<void> saveBreadcrumbBatch(List<BreadcrumbPoint> points) {
    return _db.insertTelemetryBatch(points);
  }

  @override
  Future<void> logEvent(RunEvent event) {
    return _db.logEvent(event);
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
  }) {
    return _db.updateRunRecord(
      runId: runId,
      status: status,
      startedAt: startedAt,
      endedAt: endedAt,
      elapsedMs: elapsedMs,
      movingMs: movingMs,
      distanceMeters: distanceMeters,
      totalSteps: totalSteps,
    );
  }

  @override
  Future<Map<String, dynamic>?> getUnfinishedRun() {
    return _db.getUnfinishedRun();
  }

  @override
  Future<List<BreadcrumbPoint>> getBreadcrumbs(String runId) {
    return _db.getPointsForRun(runId);
  }

  @override
  Future<List<RunEvent>> getEvents(String runId) {
    return _db.getEventsForRun(runId);
  }

  @override
  Future<void> deleteBreadcrumbs(String runId) {
    return _db.deleteRun(runId);
  }
}

final gpsRepositoryProvider = Provider<IGpsRepository>((ref) {
  return GpsRepository();
});
