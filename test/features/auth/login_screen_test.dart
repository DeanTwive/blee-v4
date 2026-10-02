import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blee/core/theme/app_theme.dart';
import 'package:blee/features/auth/presentation/login_screen.dart';

void main() {
  group('LoginScreen Widget Tests', () {
    testWidgets('Renders all sign-in options, inputs, and branding', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('🐝 BLEE'), findsOneWidget);
      expect(find.text('Welcome Back.'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('SIGN IN'), findsOneWidget);
      expect(find.text('CONTINUE AS GUEST RUNNER'), findsOneWidget);
    });

    testWidgets('Toggles between Sign In and Sign Up mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap toggle to switch to sign up
      final toggleFinder = find.text('New to Blee? Create an account');
      expect(toggleFinder, findsOneWidget);
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(find.text('Join the Hive.'), findsOneWidget);
      expect(find.text('Runner Name'), findsOneWidget);
      expect(find.text('CREATE RUNNER ACCOUNT'), findsOneWidget);
    });

    testWidgets('Validates empty email and password submission', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final submitBtn = find.text('SIGN IN');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter an email'), findsOneWidget);
      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    });
  });
}
