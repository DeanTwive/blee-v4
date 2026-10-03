import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blee/features/home/domain/clubs_provider.dart';
import 'package:blee/features/home/domain/community_events_provider.dart';
import 'package:blee/features/tracking/domain/run_history_provider.dart';
import 'package:blee/features/tracking/domain/run_summary_entity.dart';
import 'package:blee/features/tracking/domain/tracking_preferences_provider.dart';

void main() {
  group('RunHistoryNotifier Tests', () {
    test('Initializes with seed run and computes mileage correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(runHistoryNotifierProvider);
      expect(state.runs.length, 1);
      expect(state.runs.first.distanceKm, 5.2);
      expect(state.weeklyDistanceKm, 5.2);
      expect(state.totalDistanceKm, 5.2);
      expect(state.weeklyRunsCount, 1);
    });

    test('addRun updates mileage and run counts reactively', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final now = DateTime.now();
      final newRun = RunSummaryEntity(
        runId: 'test_run_2',
        startedAt: now.subtract(const Duration(minutes: 30)),
        endedAt: now,
        distanceMeters: 4800,
        durationSeconds: 1500,
        avgPaceSecondsPerKm: 312,
        peakKmPaceSecondsPerKm: 290,
        peakKmIndex: 3,
        rpe: 8,
        breadcrumbs: const [],
      );

      container.read(runHistoryNotifierProvider.notifier).addRun(newRun);

      final state = container.read(runHistoryNotifierProvider);
      expect(state.runs.length, 2);
      expect(state.runs.first.runId, 'test_run_2');
      expect(state.weeklyDistanceKm, 10.0); // 5.2 + 4.8
      expect(state.weeklyRunsCount, 2);
    });
  });

  group('CommunityEventsNotifier Tests', () {
    test('toggleRsvp increments and decrements attendee count correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialEvents = container.read(communityEventsProvider);
      final event = initialEvents.first;
      expect(event.isRsvp, false);
      expect(event.attendeesCount, 42);

      // Toggle RSVP on
      container.read(communityEventsProvider.notifier).toggleRsvp(event.id);
      final updatedEvents = container.read(communityEventsProvider);
      final updatedEvent = updatedEvents.first;
      expect(updatedEvent.isRsvp, true);
      expect(updatedEvent.attendeesCount, 43);

      // Toggle RSVP off
      container.read(communityEventsProvider.notifier).toggleRsvp(event.id);
      final reUpdated = container.read(communityEventsProvider).first;
      expect(reUpdated.isRsvp, false);
      expect(reUpdated.attendeesCount, 42);
    });
  });

  group('ClubsNotifier Tests', () {
    test('toggleJoin toggles membership and member count', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialClubs = container.read(clubsProvider);
      final club = initialClubs.first;
      final initialCount = club.members;
      expect(club.isJoined, false);

      // Join club
      container.read(clubsProvider.notifier).toggleJoin(club.id);
      var updated = container.read(clubsProvider).first;
      expect(updated.isJoined, true);
      expect(updated.members, initialCount + 1);

      // Leave club
      container.read(clubsProvider.notifier).toggleJoin(club.id);
      updated = container.read(clubsProvider).first;
      expect(updated.isJoined, false);
      expect(updated.members, initialCount);
    });
  });

  group('TrackingPreferencesNotifier Tests', () {
    test('toggles autoPause and liveBeacon', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = container.read(trackingPreferencesProvider);
      expect(initial.autoPauseEnabled, true);
      expect(initial.liveBeaconEnabled, false);

      container.read(trackingPreferencesProvider.notifier).toggleAutoPause(false);
      expect(container.read(trackingPreferencesProvider).autoPauseEnabled, false);

      container.read(trackingPreferencesProvider.notifier).toggleLiveBeacon(true);
      expect(container.read(trackingPreferencesProvider).liveBeaconEnabled, true);
    });
  });
}
