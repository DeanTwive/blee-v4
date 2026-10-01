import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blee/core/theme/app_theme.dart';
import 'package:blee/features/auth/data/auth_repository.dart';
import 'package:blee/features/auth/domain/user_entity.dart';
import 'package:blee/features/auth/presentation/auth_gate.dart';

class MockAuthRepository implements IAuthRepository {
  final _controller = StreamController<UserEntity?>.broadcast();
  UserEntity? _user;

  @override
  Stream<UserEntity?> get authStateChanges => _controller.stream;

  @override
  UserEntity? get currentUser => _user;

  void emitUser(UserEntity? user) {
    _user = user;
    _controller.add(user);
  }

  @override
  Future<UserEntity> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final user = UserEntity(id: 'mock-1', email: email);
    emitUser(user);
    return user;
  }

  @override
  Future<UserEntity> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final user = UserEntity(id: 'mock-1', email: email, displayName: displayName);
    emitUser(user);
    return user;
  }

  @override
  Future<UserEntity> signInAnonymously() async {
    const user = UserEntity(id: 'mock-anon', isAnonymous: true);
    emitUser(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    emitUser(null);
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  group('Blee App Tests', () {
    late MockAuthRepository mockAuthRepository;

    setUp(() {
      mockAuthRepository = MockAuthRepository();
    });

    tearDown(() {
      mockAuthRepository.dispose();
    });

    testWidgets('Renders LoginScreen when user is unauthenticated', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: AuthGate(authRepository: mockAuthRepository),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('🐝 BLEE'), findsOneWidget);
      expect(find.text('Welcome Back.'), findsOneWidget);
      expect(find.text('CONTINUE AS GUEST RUNNER'), findsOneWidget);
    });

    testWidgets('Renders HomeScreen when user is authenticated', (tester) async {
      mockAuthRepository.emitUser(
        const UserEntity(
          id: 'runner-123',
          email: 'runner@blee.app',
          displayName: 'Coach Carlos',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: AuthGate(authRepository: mockAuthRepository),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Run Community'), findsOneWidget);
      expect(find.text('Coach Carlos'), findsOneWidget);
      expect(find.text('START RUN'), findsOneWidget);
      expect(find.text('BGC Saturday Sunrise Run'), findsOneWidget);
    });
  });
}
