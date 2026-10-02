import 'package:flutter/foundation.dart';

/// Immutable state for the 7-step onboarding funnel.
@immutable
class OnboardingState {
  final int currentStep; // 0-indexed, 0..6
  final String firstName;
  final String tier; // 'pacer' | 'strider' | 'elite'
  final String motivation; // identity goal
  final int weeklyRhythmTarget; // 2 | 3 | 4
  final bool locationGranted;
  final bool notificationGranted;
  final bool isSubmitting;
  final String? errorMessage;

  const OnboardingState({
    this.currentStep = 0,
    this.firstName = '',
    this.tier = 'pacer',
    this.motivation = '',
    this.weeklyRhythmTarget = 3,
    this.locationGranted = false,
    this.notificationGranted = false,
    this.isSubmitting = false,
    this.errorMessage,
  });

  bool get canAdvance => switch (currentStep) {
        0 => true, // Manifesto — always can proceed
        1 => firstName.trim().isNotEmpty,
        2 => tier.isNotEmpty,
        3 => motivation.isNotEmpty,
        4 => weeklyRhythmTarget > 0,
        5 => true, // permissions — non-blocking
        6 => true, // declaration — always done
        _ => false,
      };

  OnboardingState copyWith({
    int? currentStep,
    String? firstName,
    String? tier,
    String? motivation,
    int? weeklyRhythmTarget,
    bool? locationGranted,
    bool? notificationGranted,
    bool? isSubmitting,
    String? errorMessage,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      firstName: firstName ?? this.firstName,
      tier: tier ?? this.tier,
      motivation: motivation ?? this.motivation,
      weeklyRhythmTarget: weeklyRhythmTarget ?? this.weeklyRhythmTarget,
      locationGranted: locationGranted ?? this.locationGranted,
      notificationGranted: notificationGranted ?? this.notificationGranted,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }
}
