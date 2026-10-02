import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../data/profile_repository.dart';
import '../domain/profile_entity.dart';
import '../domain/user_entity.dart';

// ─── Auth Repository Provider ─────────────────────────────────────────────────

final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  return FirebaseAuthRepository();
});

// ─── Profile Repository Provider ──────────────────────────────────────────────

final profileRepositoryProvider = Provider<IProfileRepository>((ref) {
  return SupabaseProfileRepository();
});

// ─── Auth State Stream Provider ───────────────────────────────────────────────

/// Streams the current Firebase auth user. Drives the GoRouter redirect guard.
final authStateProvider = StreamProvider<UserEntity?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// ─── Current Profile Provider ─────────────────────────────────────────────────

/// Streams the Supabase profile for the authenticated user.
/// Automatically ensures the profile exists on first sign-in.
final currentProfileProvider = StreamProvider<ProfileEntity?>((ref) {
  final authAsync = ref.watch(authStateProvider);
  return authAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      final repo = ref.watch(profileRepositoryProvider);
      // Ensure profile row exists (idempotent, no-op on subsequent calls)
      repo.ensureProfileExists(
        uid: user.id,
        displayName: user.displayName ?? '',
        email: user.email,
      );
      return repo.watchProfile(user.id);
    },
    loading: () => const Stream.empty(),
    error: (error, stackTrace) => const Stream.empty(),
  );
});

// ─── Auth Actions Notifier ────────────────────────────────────────────────────

class AuthNotifier extends Notifier<void> {
  @override
  void build() {}

  IAuthRepository get _auth => ref.read(authRepositoryProvider);

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _auth.signUpWithEmailAndPassword(
      email: email,
      password: password,
      displayName: displayName,
    );
  }

  Future<void> signInAnonymously() async {
    await _auth.signInAnonymously();
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, void>(AuthNotifier.new);
