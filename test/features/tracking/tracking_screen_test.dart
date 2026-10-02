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
            home: const TrackingScreen(),
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

      await tester.pumpAndSettle();

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

      await tester.pumpAndSettle();

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

      await tester.pumpAndSettle();

      expect(find.text('Location permission denied. Please enable it in Settings.'), findsOneWidget);
    });
  });
}
