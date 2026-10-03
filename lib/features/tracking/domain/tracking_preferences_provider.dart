import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrackingPreferences {
  final bool autoPauseEnabled;
  final bool liveBeaconEnabled;
  final double autoPauseThresholdMetersPerSec;

  const TrackingPreferences({
    this.autoPauseEnabled = true,
    this.liveBeaconEnabled = false,
    this.autoPauseThresholdMetersPerSec = 0.8,
  });

  TrackingPreferences copyWith({
    bool? autoPauseEnabled,
    bool? liveBeaconEnabled,
    double? autoPauseThresholdMetersPerSec,
  }) {
    return TrackingPreferences(
      autoPauseEnabled: autoPauseEnabled ?? this.autoPauseEnabled,
      liveBeaconEnabled: liveBeaconEnabled ?? this.liveBeaconEnabled,
      autoPauseThresholdMetersPerSec:
          autoPauseThresholdMetersPerSec ?? this.autoPauseThresholdMetersPerSec,
    );
  }
}

class TrackingPreferencesNotifier extends Notifier<TrackingPreferences> {
  @override
  TrackingPreferences build() => const TrackingPreferences();

  void toggleAutoPause(bool enabled) {
    state = state.copyWith(autoPauseEnabled: enabled);
  }

  void toggleLiveBeacon(bool enabled) {
    state = state.copyWith(liveBeaconEnabled: enabled);
  }
}

final trackingPreferencesProvider =
    NotifierProvider<TrackingPreferencesNotifier, TrackingPreferences>(
  TrackingPreferencesNotifier.new,
);
