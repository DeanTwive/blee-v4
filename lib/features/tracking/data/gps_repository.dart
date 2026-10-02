import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'local_run_db.dart';
import '../domain/run_summary_entity.dart';

abstract class IGpsRepository {
  Future<bool> checkPermission();
  Future<bool> requestPermission();
  Stream<Position> getPositionStream({LocationSettings? settings});
  Future<void> saveBreadcrumb(BreadcrumbPoint point);
  Future<List<BreadcrumbPoint>> getBreadcrumbs(String runId);
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
  Stream<Position> getPositionStream({LocationSettings? settings}) {
    return Geolocator.getPositionStream(
      locationSettings: settings ??
          const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 3,
          ),
    );
  }

  @override
  Future<void> saveBreadcrumb(BreadcrumbPoint point) {
    return _db.insertPoint(point);
  }

  @override
  Future<List<BreadcrumbPoint>> getBreadcrumbs(String runId) {
    return _db.getPointsForRun(runId);
  }

  @override
  Future<void> deleteBreadcrumbs(String runId) {
    return _db.deleteRun(runId);
  }
}

final gpsRepositoryProvider = Provider<IGpsRepository>((ref) {
  return GpsRepository();
});
