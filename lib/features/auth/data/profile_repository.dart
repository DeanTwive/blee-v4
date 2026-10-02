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
  final SupabaseClient _supabase;

  SupabaseProfileRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  @override
  Future<Result<ProfileEntity?>> fetchProfile(String uid) async {
    try {
      final data = await _supabase
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

      await _supabase.from('profiles').upsert(
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
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
        'display_name': ?displayName,
        'tier': ?tier,
        'identity_goal': ?identityGoal,
        'weekly_rhythm_target': ?weeklyRhythmTarget,
        'onboarding_complete': ?onboardingComplete,
      };

      final updated = await _supabase
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
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((rows) => rows.isEmpty ? null : ProfileEntity.fromMap(rows.first));
  }
}
