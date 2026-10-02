import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:blee/features/auth/data/auth_repository.dart';
import 'package:blee/features/auth/domain/user_entity.dart';

class InMemoryAuthRepository implements IAuthRepository {
  final _controller = StreamController<UserEntity?>.broadcast();
  UserEntity? _currentUser;

  @override
  Stream<UserEntity?> get authStateChanges => _controller.stream;

  @override
  UserEntity? get currentUser => _currentUser;

  @override
  Future<UserEntity> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (password.length < 6) {
      throw const AuthFailureException('Password must be at least 6 characters.');
    }
    final user = UserEntity(id: 'user_email_1', email: email);
    _currentUser = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<UserEntity> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (email.isEmpty) {
      throw const AuthFailureException('Email cannot be empty.');
    }
    final user = UserEntity(
      id: 'user_signup_1',
      email: email,
      displayName: displayName,
    );
    _currentUser = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<UserEntity> signInAnonymously() async {
    const user = UserEntity(id: 'user_anon_1', isAnonymous: true);
    _currentUser = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  group('AuthRepository State Transitions', () {
    late InMemoryAuthRepository authRepo;

    setUp(() {
      authRepo = InMemoryAuthRepository();
    });

    tearDown(() {
      authRepo.dispose();
    });

    test('Initial user is null', () {
      expect(authRepo.currentUser, isNull);
    });

    test('signInWithEmailAndPassword updates currentUser and emits user', () async {
      final streamFuture = expectLater(
        authRepo.authStateChanges,
        emits(predicate<UserEntity?>((u) => u?.email == 'runner@blee.app')),
      );

      final user = await authRepo.signInWithEmailAndPassword(
        email: 'runner@blee.app',
        password: 'password123',
      );

      expect(user.id, 'user_email_1');
      expect(user.email, 'runner@blee.app');
      expect(authRepo.currentUser, equals(user));
      await streamFuture;
    });

    test('signUpWithEmailAndPassword updates currentUser with displayName', () async {
      final user = await authRepo.signUpWithEmailAndPassword(
        email: 'coach@blee.app',
        password: 'password123',
        displayName: 'Coach Carlos',
      );

      expect(user.displayName, 'Coach Carlos');
      expect(authRepo.currentUser?.displayName, 'Coach Carlos');
    });

    test('signInAnonymously creates anonymous user', () async {
      final user = await authRepo.signInAnonymously();

      expect(user.isAnonymous, isTrue);
      expect(authRepo.currentUser?.isAnonymous, isTrue);
    });

    test('signOut clears currentUser and emits null', () async {
      await authRepo.signInAnonymously();
      expect(authRepo.currentUser, isNotNull);

      final streamFuture = expectLater(
        authRepo.authStateChanges,
        emits(isNull),
      );

      await authRepo.signOut();
      expect(authRepo.currentUser, isNull);
      await streamFuture;
    });

    test('throws AuthFailureException on weak password', () async {
      expect(
        () => authRepo.signInWithEmailAndPassword(
          email: 'test@blee.app',
          password: '123',
        ),
        throwsA(isA<AuthFailureException>()),
      );
    });
  });
}
