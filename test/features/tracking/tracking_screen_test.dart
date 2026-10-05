import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blee/core/theme/app_theme.dart';
import 'package:blee/features/tracking/domain/run_summary_entity.dart';
import 'package:blee/features/tracking/presentation/tracking_notifier.dart';
import 'package:blee/features/tracking/presentation/tracking_screen.dart';

class FakeTrackingNotifier extends TrackingNotifier {
  final TrackingState initialState;
  FakeTrackingNotifier(this.initialState);

  @override
  TrackingState build() => initialState;
}

void main() {
  group('TrackingScreen Widget Tests - UI States', () {
    testWidgets('Renders Idle State with Ready to Run and Start Run button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingNotifierProvider.overrideWith(
              () => FakeTrackingNotifier(const TrackingState(status: TrackingStatus.idle)),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const TrackingScreen(autoStart: false),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Ready to Run'), findsOneWidget);
      expect(find.text('START RUN'), findsOneWidget);
      expect(find.text('BGC, Manila'), findsOneWidget);
    });

    testWidgets('Renders Acquiring State with pulsing signal indicator', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingNotifierProvider.overrideWith(
              () => FakeTrackingNotifier(const TrackingState(status: TrackingStatus.acquiring)),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const TrackingScreen(),
          ),
        ),
      );

      // Pump single frame
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Acquiring GPS Signal'), findsOneWidget);
      expect(find.text('Move outdoors for best accuracy'), findsOneWidget);
    });

    testWidgets('Renders Running HUD with metrics and controls', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingNotifierProvider.overrideWith(
              () => FakeTrackingNotifier(
                const TrackingState(
                  status: TrackingStatus.running,
                  distanceMeters: 3200,
                  elapsedSeconds: 960,
                  currentPaceSecondsPerKm: 300,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const TrackingScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('KILOMETERS'), findsOneWidget);
      expect(find.text('3.20'), findsOneWidget);
      expect(find.text('16:00'), findsOneWidget); // 960s = 16:00
      expect(find.text('PACE /KM'), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('Renders Paused State with resume control', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingNotifierProvider.overrideWith(
              () => FakeTrackingNotifier(
                const TrackingState(
                  status: TrackingStatus.paused,
                  distanceMeters: 5000,
                  elapsedSeconds: 1500,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const TrackingScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('Renders Idle State with error banner when error message is present', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingNotifierProvider.overrideWith(
              () => FakeTrackingNotifier(
                const TrackingState(
                  status: TrackingStatus.idle,
                  errorMessage: 'Location permission denied. Please enable it in Settings.',
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const TrackingScreen(),
          ),
        ),
      );

      expect(find.text('Location permission denied. Please enable it in Settings.'), findsOneWidget);
    });

    testWidgets('Tapping stop displays Finish Run sheet with DISCARD RUN button and confirmation dialog', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingNotifierProvider.overrideWith(
              () => FakeTrackingNotifier(
                const TrackingState(
                  status: TrackingStatus.paused,
                  distanceMeters: 500,
                  elapsedSeconds: 60,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const TrackingScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap stop button in paused state
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pumpAndSettle();

      // Bottom sheet should be visible with Finish, Resume, and Discard options
      expect(find.text('Finish Run?'), findsOneWidget);
      expect(find.text('FINISH & SAVE RUN'), findsOneWidget);
      expect(find.text('RESUME RUN'), findsOneWidget);
      expect(find.text('DISCARD RUN'), findsOneWidget);

      // Tap Discard Run
      await tester.tap(find.text('DISCARD RUN'));
      await tester.pumpAndSettle();

      // Discard confirmation dialog should be displayed
      expect(find.text('Discard Run?'), findsOneWidget);
      expect(find.text('KEEP RUNNING'), findsOneWidget);
      expect(find.text('DISCARD'), findsOneWidget);
    });
  });
}
