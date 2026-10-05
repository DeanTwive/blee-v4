import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../domain/user_entity.dart';

abstract interface class IAuthRepository {
  Stream<UserEntity?> get authStateChanges;
  UserEntity? get currentUser;
  Future<UserEntity> signInWithEmailAndPassword({
    required String email,
    required String password,
  });
  Future<UserEntity> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  });
  Future<UserEntity> signInAnonymously();
  Future<void> signOut();
}

class FirebaseAuthRepository implements IAuthRepository {
  fb.FirebaseAuth? _firebaseAuth;

  FirebaseAuthRepository({fb.FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth;

  fb.FirebaseAuth? get _auth {
    if (_firebaseAuth != null) return _firebaseAuth;
    try {
      _firebaseAuth = fb.FirebaseAuth.instance;
      return _firebaseAuth;
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<UserEntity?> get authStateChanges {
    final auth = _auth;
    if (auth == null) {
      return Stream.value(null);
    }
    return auth.authStateChanges().map(
          (user) => user != null ? _mapFirebaseUser(user) : null,
        );
  }

  @override
  UserEntity? get currentUser {
    final user = _auth?.currentUser;
    return user != null ? _mapFirebaseUser(user) : null;
  }

  @override
  Future<UserEntity> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final auth = _auth;
    if (auth == null) {
      throw const AuthFailureException('Authentication service is unavailable.');
    }
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthFailureException('Failed to retrieve user after sign-in.');
      }
      return _mapFirebaseUser(user);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthFailureException(_mapFirebaseError(e.code));
    } catch (e) {
      throw AuthFailureException(e.toString());
    }
  }

  @override
  Future<UserEntity> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final auth = _auth;
    if (auth == null) {
      throw const AuthFailureException('Authentication service is unavailable.');
    }
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthFailureException('Failed to create user account.');
      }
      if (displayName != null && displayName.isNotEmpty) {
        await user.updateDisplayName(displayName);
        await user.reload();
      }
      return _mapFirebaseUser(auth.currentUser ?? user);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthFailureException(_mapFirebaseError(e.code));
    } catch (e) {
      throw AuthFailureException(e.toString());
    }
  }

  @override
  Future<UserEntity> signInAnonymously() async {
    final auth = _auth;
    if (auth == null) {
      throw const AuthFailureException('Authentication service is unavailable.');
    }
    try {
      final credential = await auth.signInAnonymously();
      final user = credential.user;
      if (user == null) {
        throw const AuthFailureException('Anonymous sign-in failed.');
      }
      return _mapFirebaseUser(user);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthFailureException(_mapFirebaseError(e.code));
    } catch (e) {
      throw AuthFailureException(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    await _auth?.signOut();
  }

  UserEntity _mapFirebaseUser(fb.User user) {
    return UserEntity(
      id: user.uid,
      email: user.email,
      displayName: user.displayName,
      isAnonymous: user.isAnonymous,
    );
  }

  String _mapFirebaseError(String code) {
    return switch (code) {
      'user-not-found' => 'No runner account found with this email.',
      'wrong-password' => 'Incorrect password. Please try again.',
      'email-already-in-use' => 'An account already exists with this email.',
      'invalid-email' => 'Please enter a valid email address.',
      'weak-password' => 'Password is too weak. Please use at least 6 characters.',
      'network-request-failed' => 'Network error. Please check your connection.',
      'too-many-requests' => 'Too many attempts. Please try again in a few minutes.',
      _ => 'Authentication failed ($code). Please try again.',
    };
  }
}

class AuthFailureException implements Exception {
  final String message;
  const AuthFailureException(this.message);

  @override
  String toString() => message;
}
