import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blee/core/theme/app_theme.dart';
import 'package:blee/features/auth/data/auth_repository.dart';
import 'package:blee/features/auth/domain/user_entity.dart';
import 'package:blee/features/auth/domain/profile_entity.dart';
import 'package:blee/features/auth/presentation/auth_providers.dart';
import 'package:blee/features/auth/presentation/login_screen.dart';
import 'package:blee/features/home/presentation/home_screen.dart';

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

    testWidgets('Renders LoginScreen with branding and guest option', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepository),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('🐝 BLEE'), findsOneWidget);
      expect(find.text('Welcome Back.'), findsOneWidget);
      expect(find.text('CONTINUE AS GUEST RUNNER'), findsOneWidget);
    });

    testWidgets('Renders HomeScreen with runner stats and Start Run CTA', (tester) async {
      const user = UserEntity(
        id: 'runner-123',
        email: 'runner@blee.app',
        displayName: 'Coach Carlos',
      );
      final profile = ProfileEntity(
        id: 'runner-123',
        displayName: 'Coach Carlos',
        username: 'coachcarlos',
        tier: 'strider',
        weeklyRhythmTarget: 3,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepository),
            authStateProvider.overrideWith((ref) => Stream.value(user)),
            currentProfileProvider.overrideWith((ref) => Stream.value(profile)),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Coach Carlos'), findsOneWidget);
      expect(find.text('START RUN'), findsOneWidget);
      expect(find.text('STRIDER'), findsOneWidget);
      expect(find.text('Weekly Rhythm'), findsOneWidget);
    });
  });
}
