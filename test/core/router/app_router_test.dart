import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blee/core/router/app_router.dart';
import 'package:blee/features/auth/domain/user_entity.dart';
import 'package:blee/features/auth/domain/profile_entity.dart';
import 'package:blee/features/auth/presentation/auth_providers.dart';

void main() {
  group('AppRouter Null-Safety Tests', () {
    const user = UserEntity(
      id: 'test-user',
      email: 'test@twive.com',
      displayName: 'Test Runner',
    );

    final profile = ProfileEntity(
      id: 'test-user',
      displayName: 'Test Runner',
      username: 'testrunner',
      tier: 'pacer',
      onboardingComplete: true,
      weeklyRhythmTarget: 3,
      createdAt: DateTime.now(),
    );

    testWidgets('Accessing /post-run with null extra does not throw TypeError and renders safely', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(user)),
            currentProfileProvider.overrideWith((ref) => Stream.value(profile)),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              final router = ref.watch(appRouterProvider);
              return MaterialApp.router(
                routerConfig: router,
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      final element = tester.element(find.byType(MaterialApp));
      final container = ProviderScope.containerOf(element);
      final router = container.read(appRouterProvider);

      // Should not throw 'TypeError: null: type Null is not a subtype of type RunSummaryEntity'
      expect(() => router.go(Routes.postRun), returnsNormally);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Accessing /activity-detail with null extra does not throw TypeError and renders safely', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(user)),
            currentProfileProvider.overrideWith((ref) => Stream.value(profile)),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              final router = ref.watch(appRouterProvider);
              return MaterialApp.router(
                routerConfig: router,
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      final element = tester.element(find.byType(MaterialApp));
      final container = ProviderScope.containerOf(element);
      final router = container.read(appRouterProvider);

      // Should not throw
      expect(() => router.go(Routes.activityDetail), returnsNormally);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
