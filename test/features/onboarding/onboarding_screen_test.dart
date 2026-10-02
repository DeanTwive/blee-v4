import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blee/core/theme/app_theme.dart';
import 'package:blee/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  group('OnboardingScreen Widget Tests', () {
    testWidgets('Renders Step 1 (Manifesto) with opening statement', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const OnboardingScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('🐝 BLEE'), findsOneWidget);
      expect(find.text("We don't run\nfor numbers."), findsOneWidget);
      expect(find.text('CONTINUE'), findsOneWidget);
    });

    testWidgets('Navigates from Step 1 to Step 2 on CTA tap and handles back navigation', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const OnboardingScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Next on Step 1
      final continueButton = find.text('CONTINUE');
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // Back button appears
      final backButton = find.byIcon(Icons.arrow_back_rounded);
      expect(backButton, findsOneWidget);

      // Tap back button
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Returns to Step 1
      expect(find.text("We don't run\nfor numbers."), findsOneWidget);
    });
  });
}
