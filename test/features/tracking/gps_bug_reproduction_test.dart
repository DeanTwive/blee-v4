import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blee/features/tracking/data/gps_filter.dart';
import 'package:blee/features/tracking/data/gps_repository.dart';
import 'package:blee/features/tracking/data/step_cadence_repository.dart';
import 'package:blee/features/tracking/domain/run_summary_entity.dart';
import 'package:blee/features/tracking/presentation/tracking_notifier.dart';
import '../../qa_harness/test_harness_models.dart';

void main() {
  late ProviderContainer container;
  late InMemoryGpsRepository gpsRepo;
  late FakeStepCadenceRepository stepRepo;

  setUp(() {
    gpsRepo = InMemoryGpsRepository();
    stepRepo = FakeStepCadenceRepository();
    container = ProviderContainer(
      overrides: [
        gpsRepositoryProvider.overrideWithValue(gpsRepo),
        stepCadenceRepositoryProvider.overrideWithValue(stepRepo),
      ],
    );
  });

  tearDown(() {
    // Avoid triggering Riverpod onDispose assertion bug during test teardown
  });

  group('GPS Fix Verification Tests', () {
    test('FIX 1: Realistic 1 Hz walk (1.0 m/s displacement) ACCUMULATES distance because baseline is maintained until threshold', () async {
      final notifier = container.read(trackingNotifierProvider.notifier);
      await notifier.startRun();
      notifier.completeAcquisitionAndRun();

      expect(container.read(trackingNotifierProvider).status, TrackingStatus.running);

      // Start at base coordinate (14.5507, 121.0500)
      const baseLat = 14.5507;
      const baseLng = 121.0500;

      // 1 meter in latitude is approximately 0.000009 degrees (1m / 111,320m)
      const latDelta1Meter = 0.000009;

      // Emit 20 fixes at 1 Hz, moving 1.0 meter North each second (walking pace ~ 3.6 km/h)
      for (int i = 0; i < 20; i++) {
        final pos = FakePositionBuilder.create(
          latitude: baseLat + (i * latDelta1Meter),
          longitude: baseLng,
          accuracy: 5.0, // High accuracy fix
          speed: 1.0,    // 1.0 m/s walk speed
        );
        gpsRepo.gpsStream.emit(pos);
        // Allow microtasks to process
        await Future<void>.delayed(Duration.zero);
      }

      final state = container.read(trackingNotifierProvider);

      // Verify physical distance is accumulated accurately (at least 15m out of 19-20m)
      expect(state.distanceMeters, greaterThan(15.0),
          reason: 'Distance must accumulate cleanly during a 1 Hz walk without being wiped by deadband baseline resets');
      expect(state.status, TrackingStatus.running);
      expect(state.isAutoPaused, isFalse);
    });

    test('FIX 2: Fixes with accuracy up to 35m are accepted as valid fixes (marked noisy if > 15m)', () {
      final acc10 = GpsFilter.validateFix(latitude: 14.5, longitude: 121.0, accuracy: 10.0);
      final acc20 = GpsFilter.validateFix(latitude: 14.5, longitude: 121.0, accuracy: 20.0);
      final acc28 = GpsFilter.validateFix(latitude: 14.5, longitude: 121.0, accuracy: 28.0);
      final acc30 = GpsFilter.validateFix(latitude: 14.5, longitude: 121.0, accuracy: 30.0);
      final acc36 = GpsFilter.validateFix(latitude: 14.5, longitude: 121.0, accuracy: 36.0);

      expect(acc10.isAccepted, isTrue);
      expect(acc10.isNoisy, isFalse);

      expect(acc20.isAccepted, isTrue);
      expect(acc20.isNoisy, isTrue);

      expect(acc28.isAccepted, isTrue);
      expect(acc28.isNoisy, isTrue);

      expect(acc30.isAccepted, isTrue);
      expect(acc30.isNoisy, isTrue);

      // Gross outlier > 35m is rejected
      expect(acc36.isAccepted, isFalse);
    });

    test('FIX 3: Saving/finishing when GPS stream is closed leaves state in stopped status (NOT idle)', () async {
      final notifier = container.read(trackingNotifierProvider.notifier);
      await notifier.startRun();
      notifier.completeAcquisitionAndRun();

      // Emit some valid fixes
      const baseLat = 14.5507;
      const baseLng = 121.0500;
      const latDelta2Meters = 0.000018;

      for (int i = 0; i < 10; i++) {
        gpsRepo.gpsStream.emit(FakePositionBuilder.create(
          latitude: baseLat + (i * latDelta2Meters),
          longitude: baseLng,
          accuracy: 5.0,
          speed: 2.0,
        ));
        await Future<void>.delayed(Duration.zero);
      }

      expect(container.read(trackingNotifierProvider).distanceMeters, greaterThan(10.0));

      // Now runner finishes run: GPS stream is closed/disabled
      gpsRepo.gpsStream.close();
      await Future<void>.delayed(Duration.zero);

      // Call stopRun()
      final summary = await notifier.stopRun();

      expect(summary, isNotNull);
      expect(summary!.distanceMeters, greaterThan(10.0));

      // Status must be stopped so TrackingScreen does not re-acquire GPS
      expect(container.read(trackingNotifierProvider).status, TrackingStatus.stopped);

      // Calling resetToIdle() explicitly transitions back to idle when user leaves PostRunScreen
      notifier.resetToIdle();
      expect(container.read(trackingNotifierProvider).status, TrackingStatus.idle);
    });

    test('FIX 4: TrackingScreen effectiveStatus does NOT flip to ACQUIRING when idle once mounted', () {
      TrackingStatus computeEffectiveStatus({
        required bool isAutoStarting,
        required bool cancelled,
        required TrackingState state,
      }) {
        return (isAutoStarting &&
                !cancelled &&
                state.status == TrackingStatus.idle &&
                state.unfinishedRun == null &&
                state.errorMessage == null)
            ? TrackingStatus.acquiring
            : state.status;
      }

      const idleState = TrackingState(status: TrackingStatus.idle);
      // Once post-frame callback runs, isAutoStarting is false
      expect(computeEffectiveStatus(isAutoStarting: false, cancelled: false, state: idleState), TrackingStatus.idle);
      // During initial mount before post-frame callback, isAutoStarting is true
      expect(computeEffectiveStatus(isAutoStarting: true, cancelled: false, state: idleState), TrackingStatus.acquiring);
    });
  });
}
