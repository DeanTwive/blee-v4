import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../onboarding_notifier.dart';

/// Step 7 — Identity Declaration Card. Peak-End Rule: the memorable ending.
class StepDeclaration extends ConsumerWidget {
  const StepDeclaration({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingNotifierProvider);
    final name = state.firstName.isNotEmpty ? state.firstName : 'Runner';
    final tierLabel = switch (state.tier) {
      'strider' => 'STRIDER',
      'elite' => 'ELITE',
      _ => 'PACER',
    };
    final tierColor = switch (state.tier) {
      'strider' => AppColors.primary,
      'elite' => AppColors.safetyOrange,
      _ => AppColors.electricCobalt,
    };

    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          Text(
            'You\'re ready.',
            style: AppTypography.titleLarge.copyWith(
              fontSize: 32,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tap the button below to claim your identity.',
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Identity Card
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, scale, child) => Transform.scale(
              scale: scale,
              child: child,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.surfaceElevated,
                    tierColor.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                border: Border.all(color: tierColor.withValues(alpha: 0.4), width: 2),
              ),
              child: Column(
                children: [
                  const Text('🐝', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'I am a Blee Runner',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: tierColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      tierLabel,
                      style: AppTypography.badge.copyWith(
                        color: tierColor,
                        fontSize: 13,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'BGC, Manila · ${DateTime.now().year}',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Identity > Telemetry · blee.app',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
