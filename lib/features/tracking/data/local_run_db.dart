import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/run_summary_entity.dart';

/// High-throughput SQLite storage for raw GPS breadcrumbs.
/// Optimised for < 3ms write latency per point.
/// Falls back to an in-memory store on Flutter Web (localhost).
class LocalRunDb {
  static const _dbName = 'blee_gps.db';
  static const _version = 1;
  static const _table = 'raw_breadcrumbs';

  final List<BreadcrumbPoint> _webStore = [];
  Database? _db;

  Future<Database> get _database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, _dbName);
    return openDatabase(
      path,
      version: _version,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            run_id TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            altitude REAL,
            accuracy REAL NOT NULL,
            speed REAL,
            timestamp INTEGER NOT NULL,
            is_synced INTEGER DEFAULT 0
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_run_ts ON $_table(run_id, timestamp)',
        );
      },
    );
  }

  /// Inserts a single breadcrumb. Average < 3ms.
  Future<void> insertPoint(BreadcrumbPoint point) async {
    if (kIsWeb) {
      _webStore.add(point);
      return;
    }
    final db = await _database;
    await db.insert(
      _table,
      {
        'run_id': point.runId,
        'latitude': point.latitude,
        'longitude': point.longitude,
        'altitude': point.altitude,
        'accuracy': point.accuracy,
        'speed': point.speedMetersPerSec,
        'timestamp': point.timestamp.millisecondsSinceEpoch,
        'is_synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Returns all breadcrumbs for a run, ordered by timestamp.
  Future<List<BreadcrumbPoint>> getPointsForRun(String runId) async {
    if (kIsWeb) {
      return _webStore
          .where((p) => p.runId == runId)
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
    final db = await _database;
    final rows = await db.query(
      _table,
      where: 'run_id = ?',
      whereArgs: [runId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(_rowToPoint).toList();
  }

  /// Marks all points for a run as synced to Supabase.
  Future<void> markRunSynced(String runId) async {
    if (kIsWeb) return;
    final db = await _database;
    await db.update(
      _table,
      {'is_synced': 1},
      where: 'run_id = ? AND is_synced = 0',
      whereArgs: [runId],
    );
  }

  /// Deletes synced runs older than 7 days to reclaim storage.
  Future<void> pruneOldSyncedRuns() async {
    if (kIsWeb) return;
    final db = await _database;
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 7))
        .millisecondsSinceEpoch;
    await db.delete(
      _table,
      where: 'is_synced = 1 AND timestamp < ?',
      whereArgs: [cutoff],
    );
  }

  /// Deletes all points for a run.
  Future<void> deleteRun(String runId) async {
    if (kIsWeb) {
      _webStore.removeWhere((p) => p.runId == runId);
      return;
    }
    final db = await _database;
    await db.delete(
      _table,
      where: 'run_id = ?',
      whereArgs: [runId],
    );
  }

  Future<void> close() async {
    if (kIsWeb) {
      _webStore.clear();
      return;
    }
    await _db?.close();
    _db = null;
  }

  BreadcrumbPoint _rowToPoint(Map<String, Object?> row) {
    return BreadcrumbPoint(
      runId: row['run_id'] as String,
      latitude: row['latitude'] as double,
      longitude: row['longitude'] as double,
      altitude: row['altitude'] as double?,
      accuracy: row['accuracy'] as double,
      speedMetersPerSec: row['speed'] as double?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
    );
  }
}
