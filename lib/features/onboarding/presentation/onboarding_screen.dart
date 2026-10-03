import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/bouncy_pressable.dart';
import 'onboarding_notifier.dart';
import 'steps/step_manifesto.dart';
import 'steps/step_profile.dart';
import 'steps/step_tier.dart';
import 'steps/step_motivation.dart';
import 'steps/step_rhythm.dart';
import 'steps/step_permissions.dart';
import 'steps/step_declaration.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _handleNext() async {
    final notifier = ref.read(onboardingNotifierProvider.notifier);
    final state = ref.read(onboardingNotifierProvider);

    if (state.currentStep == 6) {
      // Final step — complete onboarding
      HapticFeedback.heavyImpact();
      await notifier.completeOnboarding();
      return;
    }

    notifier.nextStep();
    _goToPage(state.currentStep + 1);
  }

  void _handleBack() {
    final notifier = ref.read(onboardingNotifierProvider.notifier);
    final state = ref.read(onboardingNotifierProvider);
    if (state.currentStep > 0) {
      notifier.previousStep();
      _goToPage(state.currentStep - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingNotifierProvider);

    return PopScope(
      canPop: false, // Prevent accidental back
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // ── Progress bar + back button ────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    if (state.currentStep > 0)
                      GestureDetector(
                        onTap: _handleBack,
                        child: const Padding(
                          padding: EdgeInsets.only(right: AppSpacing.sm),
                          child: Icon(Icons.arrow_back_rounded,
                              color: AppColors.textSecondary, size: 22),
                        ),
                      ),
                    Expanded(
                      child: Row(
                        children: List.generate(7, (index) {
                          final isCurrent = index == state.currentStep;
                          final isReached = index <= state.currentStep;
                          return Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                                color: isReached
                                    ? AppColors.primary
                                    : AppColors.surfaceBorder,
                                boxShadow: isCurrent
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.6),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${state.currentStep + 1} / 7',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Step pages ────────────────────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(), // nav via buttons only
                  children: const [
                    StepManifesto(),
                    StepProfile(),
                    StepTier(),
                    StepMotivation(),
                    StepRhythm(),
                    StepPermissions(),
                    StepDeclaration(),
                  ],
                ),
              ),

              // ── CTA button ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(
                          state.errorMessage!,
                          style:
                              AppTypography.bodyMedium.copyWith(color: AppColors.danger),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    BouncyPressable(
                      onTap: (!state.canAdvance || state.isSubmitting)
                          ? null
                          : _handleNext,
                      child: ElevatedButton(
                        onPressed: (!state.canAdvance || state.isSubmitting)
                            ? null
                            : _handleNext,
                        child: state.isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.onPrimary,
                                ),
                              )
                            : Text(
                                state.currentStep == 6 ? "I'M A BLEE RUNNER" : 'CONTINUE',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
