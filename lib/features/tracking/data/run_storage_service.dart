import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/run_summary_entity.dart';

/// Robust offline-first storage and Cloud Firestore synchronization service for completed runs.
///
/// Dual-tier persistence strategy:
/// 1. Local Storage (SharedPreferences): Guaranteed immediate persistence across browser
///    reloads (F5) and native app kills. Runs survive even with zero network connectivity.
/// 2. Cloud Firestore ('runs' collection): Pushes run entities to the cloud when online.
///    If the internet is unavailable or Firestore errors out, runs stay safely stored locally
///    in a pending sync queue and automatically sync once connectivity returns.
class RunStorageService {
  static const String _localRunsKey = 'blee_local_runs_v1';
  static const String _pendingSyncKey = 'blee_pending_sync_run_ids_v1';

  final FirebaseFirestore? _firestore;

  RunStorageService({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore? get _effectiveFirestore {
    if (_firestore != null) return _firestore;
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseFirestore.instance;
      }
    } catch (e) {
      debugPrint('[RunStorageService] Firebase not initialized: $e');
    }
    return null;
  }

  // ─── Local Storage Tier (SharedPreferences) ────────────────────────────────

  /// Loads all locally persisted runs. Fast, synchronous read from disk/cache.
  Future<List<RunSummaryEntity>> loadLocalRuns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stringList = prefs.getStringList(_localRunsKey) ?? [];
      final List<RunSummaryEntity> runs = [];

      for (final rawJson in stringList) {
        try {
          final map = jsonDecode(rawJson) as Map<String, dynamic>;
          runs.add(RunSummaryEntity.fromMap(map));
        } catch (e) {
          debugPrint('[RunStorageService] Corrupted local run entry ignored: $e');
        }
      }

      // Sort newest runs first
      runs.sort((a, b) => b.endedAt.compareTo(a.endedAt));
      return runs;
    } catch (e) {
      debugPrint('[RunStorageService] Error reading local runs: $e');
      return [];
    }
  }

  /// Saves a run into local persistent storage. Replaces existing run if runId matches.
  Future<void> saveRunLocally(
    RunSummaryEntity run, {
    bool markAsPending = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stringList = prefs.getStringList(_localRunsKey) ?? [];

      // Decode and filter out any previous version of this runId
      final updatedMaps = <Map<String, dynamic>>[];
      for (final raw in stringList) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          final id = (map['runId'] as String?) ?? (map['run_id'] as String?);
          if (id != run.runId) {
            updatedMaps.add(map);
          }
        } catch (_) {}
      }

      // Add the new / updated run at the beginning
      updatedMaps.insert(0, run.toMap(includeImageBytes: true));

      // Serialize back
      final updatedStrings = updatedMaps.map((m) => jsonEncode(m)).toList();
      await prefs.setStringList(_localRunsKey, updatedStrings);

      if (markAsPending) {
        final pendingIds = (prefs.getStringList(_pendingSyncKey) ?? []).toSet();
        pendingIds.add(run.runId);
        await prefs.setStringList(_pendingSyncKey, pendingIds.toList());
      }
    } catch (e) {
      debugPrint('[RunStorageService] Failed to save run locally: $e');
    }
  }

  /// Removes a run from the local persistent storage and pending queue.
  Future<void> deleteRunLocally(String runId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stringList = prefs.getStringList(_localRunsKey) ?? [];
      final filtered = stringList.where((raw) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          final id = (map['runId'] as String?) ?? (map['run_id'] as String?);
          return id != runId;
        } catch (_) {
          return true;
        }
      }).toList();

      await prefs.setStringList(_localRunsKey, filtered);

      final pendingIds = (prefs.getStringList(_pendingSyncKey) ?? []).toSet();
      pendingIds.remove(runId);
      await prefs.setStringList(_pendingSyncKey, pendingIds.toList());
    } catch (e) {
      debugPrint('[RunStorageService] Failed to delete run locally: $e');
    }
  }

  /// Marks a run as successfully synced to the cloud.
  Future<void> markRunSyncedLocally(String runId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingIds = (prefs.getStringList(_pendingSyncKey) ?? []).toSet();
      if (pendingIds.remove(runId)) {
        await prefs.setStringList(_pendingSyncKey, pendingIds.toList());
      }
    } catch (e) {
      debugPrint('[RunStorageService] Failed to mark run as synced: $e');
    }
  }

  /// Returns list of run IDs that are currently waiting for cloud sync.
  Future<List<String>> getPendingSyncRunIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_pendingSyncKey) ?? [];
    } catch (_) {
      return [];
    }
  }

  // ─── Cloud Firestore Tier ('runs' collection) ──────────────────────────────

  /// Pushes a run to Cloud Firestore. Returns `true` if successful, `false` if offline or error.
  Future<bool> syncRunToFirestore(
    RunSummaryEntity run, {
    String? userId,
  }) async {
    final firestore = _effectiveFirestore;
    if (firestore == null) {
      debugPrint('[RunStorageService] Firestore unavailable. Run ${run.runId} remains in local queue.');
      return false;
    }

    try {
      final data = {
        ...run.toMap(includeImageBytes: false),
        'userId': (userId != null && userId.trim().isNotEmpty) ? userId.trim() : 'anonymous',
        'updatedAt': FieldValue.serverTimestamp(),
        'source': 'blee_tracker',
      };

      await firestore
          .collection('runs')
          .doc(run.runId)
          .set(data, SetOptions(merge: true))
          .timeout(const Duration(seconds: 8));

      // Successfully saved in Firestore! Clear from pending queue
      await markRunSyncedLocally(run.runId);
      debugPrint('[RunStorageService] Successfully synced run ${run.runId} to Firestore.');
      return true;
    } catch (e) {
      debugPrint('[RunStorageService] Firestore write failed (${run.runId}): $e. Preserving in local storage.');
      return false;
    }
  }

  /// Fetches saved runs from Firestore for a given user.
  /// Also stores fetched runs locally so they are accessible offline.
  Future<List<RunSummaryEntity>> fetchUserRunsFromFirestore({String? userId}) async {
    final firestore = _effectiveFirestore;
    if (firestore == null) return [];

    try {
      Query<Map<String, dynamic>> query = firestore.collection('runs');
      if (userId != null && userId.isNotEmpty && userId != 'anonymous') {
        query = query.where('userId', isEqualTo: userId);
      }

      final snapshot = await query.limit(50).get().timeout(const Duration(seconds: 10));
      final List<RunSummaryEntity> fetchedRuns = [];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final run = RunSummaryEntity.fromMap(data);
          fetchedRuns.add(run);
          // Cache locally as synced
          await saveRunLocally(run, markAsPending: false);
        } catch (e) {
          debugPrint('[RunStorageService] Failed to parse Firestore doc ${doc.id}: $e');
        }
      }

      fetchedRuns.sort((a, b) => b.endedAt.compareTo(a.endedAt));
      return fetchedRuns;
    } catch (e) {
      debugPrint('[RunStorageService] Failed to fetch runs from Firestore: $e');
      return [];
    }
  }

  /// Attempts to upload all pending runs to Firestore.
  /// Call this when the app starts or when network connectivity is restored.
  Future<int> syncPendingRuns({String? userId}) async {
    final pendingIds = await getPendingSyncRunIds();
    if (pendingIds.isEmpty) return 0;

    final localRuns = await loadLocalRuns();
    final runMap = {for (final r in localRuns) r.runId: r};

    int syncedCount = 0;
    for (final id in pendingIds) {
      final run = runMap[id];
      if (run != null) {
        final ok = await syncRunToFirestore(run, userId: userId);
        if (ok) syncedCount++;
      }
    }
    return syncedCount;
  }

  /// Deletes a run from Firestore.
  Future<void> deleteRunFromFirestore(String runId) async {
    final firestore = _effectiveFirestore;
    if (firestore == null) return;
    try {
      await firestore.collection('runs').doc(runId).delete();
    } catch (e) {
      debugPrint('[RunStorageService] Failed to delete run $runId from Firestore: $e');
    }
  }

  // ─── Dual-Tier Unified Save Method ─────────────────────────────────────────

  /// Dual-tier save:
  /// 1. Immediately writes to local persistent storage (SharedPreferences) so the run
  ///    survives browser refresh (F5) or offline closure.
  /// 2. Asynchronously attempts to upload to Cloud Firestore.
  /// Returns `true` if synced to Firestore, `false` if stored locally offline.
  Future<bool> saveRun(
    RunSummaryEntity run, {
    String? userId,
  }) async {
    // Step 1: Always save locally first with pending status
    await saveRunLocally(run, markAsPending: true);

    // Step 2: Attempt cloud sync
    final isSynced = await syncRunToFirestore(run, userId: userId);
    return isSynced;
  }
}

/// Global provider for the RunStorageService
final runStorageServiceProvider = Provider<RunStorageService>((ref) {
  return RunStorageService();
});
