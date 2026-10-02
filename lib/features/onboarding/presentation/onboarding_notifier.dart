import '../../../core/utils/crash_reporter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../domain/onboarding_state.dart';
import '../../../core/utils/result.dart';
import '../../auth/presentation/auth_providers.dart';

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  void setFirstName(String name) =>
      state = state.copyWith(firstName: name);

  void setTier(String tier) =>
      state = state.copyWith(tier: tier);

  void setMotivation(String motivation) =>
      state = state.copyWith(motivation: motivation);

  void setWeeklyRhythmTarget(int target) =>
      state = state.copyWith(weeklyRhythmTarget: target);

  void nextStep() {
    if (state.currentStep < 6) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  Future<void> requestPermissions() async {
    try {
      final locationStatus = await Permission.locationWhenInUse.request();
      final notifStatus = await Permission.notification.request();

      // Request always-on location if basic was granted
      if (locationStatus.isGranted) {
        await Permission.locationAlways.request();
      }

      state = state.copyWith(
        locationGranted: locationStatus.isGranted,
        notificationGranted: notifStatus.isGranted,
      );
    } catch (e, st) {
      AppCrashReporter.recordError(e, st, reason: 'requestPermissions');
    }
  }

  /// Persists the onboarding data to Supabase and marks completion.
  Future<void> completeOnboarding() async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('No authenticated user');

      final profileRepo = ref.read(profileRepositoryProvider);
      final result = await profileRepo.updateProfile(
        uid: user.id,
        displayName: state.firstName,
        tier: state.tier,
        identityGoal: state.motivation,
        weeklyRhythmTarget: state.weeklyRhythmTarget,
        onboardingComplete: true,
      );

      if (result.isFailure) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: result.errorOrThrow,
        );
      }
      // Router will navigate to /home automatically via currentProfileProvider
    } catch (e, st) {
      AppCrashReporter.recordError(e, st, reason: 'completeOnboarding');
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to save profile. Please try again.',
      );
    }
  }
}

final onboardingNotifierProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(OnboardingNotifier.new);
