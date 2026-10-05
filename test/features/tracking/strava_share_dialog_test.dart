import 'package:blee/features/tracking/domain/run_summary_entity.dart';
import 'package:blee/features/tracking/presentation/widgets/strava_share_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sampleRun = RunSummaryEntity(
    runId: 'test-run-1234',
    distanceMeters: 5200.0,
    durationSeconds: 1695,
    avgPaceSecondsPerKm: 326.0,
    startedAt: DateTime(2026, 10, 6, 6, 30),
    endedAt: DateTime(2026, 10, 6, 7, 0),
    title: 'Night Run',
    breadcrumbs: const [],
  );

  testWidgets('StravaShareDialog renders Blee theme, Save Image button, and excludes orange route selector', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StravaShareDialog(
            run: sampleRun,
            runnerName: 'war',
          ),
        ),
      ),
    );
    await tester.pump();

    // 1. Header shows BLEE SHARE (not Strava Share)
    expect(find.text('BLEE SHARE'), findsOneWidget);
    expect(find.text('STRAVA SHARE'), findsNothing);

    // 2. Action buttons: SAVE IMAGE and SHARE are present
    expect(find.text('SAVE IMAGE'), findsOneWidget);
    expect(find.text('SHARE'), findsOneWidget);

    // 3. The ROUTE LINE row and Strava Orange are completely removed
    expect(find.text('ROUTE LINE: '), findsNothing);
    expect(find.text('Strava Orange'), findsNothing);
    expect(find.text('Neon Lime'), findsNothing);

    // 4. Mode selector tabs work
    expect(find.text('Sticker'), findsOneWidget);
    expect(find.text('Banner'), findsOneWidget);
    expect(find.text('Card'), findsOneWidget);

    await tester.tap(find.text('Card'));
    await tester.pump();
    expect(find.text('BLEE TRACKER'), findsOneWidget);

    await tester.tap(find.text('Banner'));
    await tester.pump();
    expect(find.text('AVG PACE'), findsOneWidget);
  });
}
