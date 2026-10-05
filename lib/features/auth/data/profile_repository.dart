import '../../../core/utils/crash_reporter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/profile_entity.dart';
import '../../../core/utils/result.dart';

abstract interface class IProfileRepository {
  /// Fetches the profile for [uid]. Returns null if not yet created.
  Future<Result<ProfileEntity?>> fetchProfile(String uid);

  /// Creates a default profile if one doesn't exist. Returns the profile.
  Future<Result<ProfileEntity>> ensureProfileExists({
    required String uid,
    required String displayName,
    String? email,
  });

  /// Updates profile fields. Only non-null fields are sent to Supabase.
  Future<Result<ProfileEntity>> updateProfile({
    required String uid,
    String? displayName,
    String? tier,
    String? identityGoal,
    int? weeklyRhythmTarget,
    bool? onboardingComplete,
  });

  /// Streams real-time profile updates from Supabase.
  Stream<ProfileEntity?> watchProfile(String uid);
}

class SupabaseProfileRepository implements IProfileRepository {
  SupabaseClient? _supabase;

  SupabaseProfileRepository({SupabaseClient? client}) : _supabase = client;

  SupabaseClient? get _client {
    if (_supabase != null) return _supabase;
    try {
      _supabase = Supabase.instance.client;
      return _supabase;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Result<ProfileEntity?>> fetchProfile(String uid) async {
    final client = _client;
    if (client == null) {
      return const Failure('Cloud database is not initialized.');
    }
    try {
      final data = await client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (data == null) return const Success(null);
      return Success(ProfileEntity.fromMap(data));
    } catch (e, st) {
      AppCrashReporter.recordError(e, st, reason: 'fetchProfile');
      return Failure('Failed to fetch profile: ${e.toString()}', raw: e);
    }
  }

  @override
  Future<Result<ProfileEntity>> ensureProfileExists({
    required String uid,
    required String displayName,
    String? email,
  }) async {
    final client = _client;
    if (client == null) {
      return const Failure('Cloud database is not initialized.');
    }
    try {
      // Check existence first — avoids a redundant upsert on every sign-in.
      final existing = await fetchProfile(uid);
      if (existing is Success<ProfileEntity?> && existing.value != null) {
        return Success(existing.value!);
      }

      final username = '${uid.substring(0, 8).toLowerCase()}runner';
      final newProfile = ProfileEntity(
        id: uid,
        displayName: displayName.isNotEmpty ? displayName : 'Runner',
        username: username,
        email: email,
        createdAt: DateTime.now(),
      );

      await client.from('profiles').upsert(
        newProfile.toMap(),
        onConflict: 'id', // idempotent
      );

      return Success(newProfile);
    } catch (e, st) {
      AppCrashReporter.recordError(e, st, reason: 'ensureProfileExists');
      return Failure('Failed to create profile: ${e.toString()}', raw: e);
    }
  }

  @override
  Future<Result<ProfileEntity>> updateProfile({
    required String uid,
    String? displayName,
    String? tier,
    String? identityGoal,
    int? weeklyRhythmTarget,
    bool? onboardingComplete,
  }) async {
    final client = _client;
    if (client == null) {
      return const Failure('Cloud database is not initialized.');
    }
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
        'display_name': ?displayName,
        'tier': ?tier,
        'identity_goal': ?identityGoal,
        'weekly_rhythm_target': ?weeklyRhythmTarget,
        'onboarding_complete': ?onboardingComplete,
      };

      final updated = await client
          .from('profiles')
          .update(updates)
          .eq('id', uid)
          .select()
          .single();

      return Success(ProfileEntity.fromMap(updated));
    } catch (e, st) {
      AppCrashReporter.recordError(e, st, reason: 'updateProfile');
      return Failure('Failed to update profile: ${e.toString()}', raw: e);
    }
  }

  @override
  Stream<ProfileEntity?> watchProfile(String uid) {
    final client = _client;
    if (client == null) {
      return const Stream.empty();
    }
    return client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((rows) => rows.isEmpty ? null : ProfileEntity.fromMap(rows.first));
  }
}
