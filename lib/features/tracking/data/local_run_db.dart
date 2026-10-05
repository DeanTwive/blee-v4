import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/run_summary_entity.dart';

/// High-throughput SQLite storage for raw telemetry and state events.
/// Implements ACID batch transactions and recovery querying.
/// Falls back to in-memory collections on Flutter Web.
class LocalRunDb {
  static const _dbName = 'blee_gps_v2.db';
  static const _version = 2;

  static const _runsTable = 'runs';
  static const _telemetryTable = 'raw_telemetry';
  static const _eventsTable = 'run_events';

  final List<BreadcrumbPoint> _webTelemetryStore = [];
  final List<RunEvent> _webEventStore = [];
  final Map<String, Map<String, dynamic>> _webRunStore = {};
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
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createTables(db);
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    // 1. Master Run Record
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_runsTable (
        id TEXT PRIMARY KEY,
        status TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        elapsed_ms INTEGER NOT NULL DEFAULT 0,
        moving_ms INTEGER NOT NULL DEFAULT 0,
        distance_meters REAL NOT NULL DEFAULT 0,
        total_steps INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 2. Raw Telemetry Replay Journal
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_telemetryTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        run_id TEXT NOT NULL,
        epoch_id INTEGER NOT NULL DEFAULT 0,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL,
        accuracy REAL NOT NULL,
        doppler_speed REAL,
        hardware_steps INTEGER,
        monotonic_ms INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        is_rejected INTEGER NOT NULL DEFAULT 0,
        rejection_reason TEXT,
        FOREIGN KEY(run_id) REFERENCES $_runsTable(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_telemetry_run ON $_telemetryTable(run_id, timestamp)',
    );

    // 3. Run Event Journal
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_eventsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        run_id TEXT NOT NULL,
        epoch_id INTEGER NOT NULL DEFAULT 0,
        event_type TEXT NOT NULL,
        monotonic_ms INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        extra_json TEXT,
        FOREIGN KEY(run_id) REFERENCES $_runsTable(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_events_run ON $_eventsTable(run_id, timestamp)',
    );
  }

  /// Inserts a batch of telemetry points in a single atomic transaction.
  Future<void> insertTelemetryBatch(List<BreadcrumbPoint> points) async {
    if (points.isEmpty) return;
    if (kIsWeb) {
      _webTelemetryStore.addAll(points);
      return;
    }
    final db = await _database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final p in points) {
        batch.insert(_telemetryTable, p.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    });
  }

  /// Inserts a single breadcrumb point.
  Future<void> insertPoint(BreadcrumbPoint point) async {
    await insertTelemetryBatch([point]);
  }

  /// Logs a run event (pause, resume, split, etc.).
  Future<void> logEvent(RunEvent event) async {
    if (kIsWeb) {
      _webEventStore.add(event);
      return;
    }
    final db = await _database;
    await db.insert(_eventsTable, event.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Creates or updates the master run state row.
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
    final values = {
      'id': runId,
      'status': status,
      'started_at': startedAt.millisecondsSinceEpoch,
      'ended_at': endedAt?.millisecondsSinceEpoch,
      'elapsed_ms': elapsedMs,
      'moving_ms': movingMs,
      'distance_meters': distanceMeters,
      'total_steps': totalSteps,
    };

    if (kIsWeb) {
      _webRunStore[runId] = values;
      return;
    }

    final db = await _database;
    await db.insert(
      _runsTable,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Cold-Boot Recovery: Checks if there is an interrupted run.
  Future<Map<String, dynamic>?> getUnfinishedRun() async {
    if (kIsWeb) {
      for (final row in _webRunStore.values) {
        if (row['status'] == 'running' || row['status'] == 'paused') {
          return row;
        }
      }
      return null;
    }
    final db = await _database;
    final rows = await db.query(
      _runsTable,
      where: 'status = ? OR status = ?',
      whereArgs: ['running', 'paused'],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// Returns all raw telemetry points for a given run, ordered by timestamp.
  Future<List<BreadcrumbPoint>> getPointsForRun(String runId) async {
    if (kIsWeb) {
      return _webTelemetryStore
          .where((p) => p.runId == runId && !p.isRejected)
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
    final db = await _database;
    final rows = await db.query(
      _telemetryTable,
      where: 'run_id = ? AND is_rejected = 0',
      whereArgs: [runId],
      orderBy: 'timestamp ASC',
    );
    return rows.map((r) => BreadcrumbPoint.fromMap(r)).toList();
  }

  /// Returns all events for a run.
  Future<List<RunEvent>> getEventsForRun(String runId) async {
    if (kIsWeb) {
      return _webEventStore.where((e) => e.runId == runId).toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
    final db = await _database;
    final rows = await db.query(
      _eventsTable,
      where: 'run_id = ?',
      whereArgs: [runId],
      orderBy: 'timestamp ASC',
    );
    return rows.map((r) => RunEvent.fromMap(r)).toList();
  }

  /// Deletes all data for a run.
  Future<void> deleteRun(String runId) async {
    if (kIsWeb) {
      _webTelemetryStore.removeWhere((p) => p.runId == runId);
      _webEventStore.removeWhere((e) => e.runId == runId);
      _webRunStore.remove(runId);
      return;
    }
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete(_runsTable, where: 'id = ?', whereArgs: [runId]);
      await txn.delete(_telemetryTable, where: 'run_id = ?', whereArgs: [runId]);
      await txn.delete(_eventsTable, where: 'run_id = ?', whereArgs: [runId]);
    });
  }

  Future<void> close() async {
    if (kIsWeb) {
      _webTelemetryStore.clear();
      _webEventStore.clear();
      _webRunStore.clear();
      return;
    }
    await _db?.close();
    _db = null;
  }
}
