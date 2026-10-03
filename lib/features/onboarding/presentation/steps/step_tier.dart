import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/bouncy_pressable.dart';
import '../onboarding_notifier.dart';

/// Step 3 — Running tier self-declaration. SDT: Autonomy.
class StepTier extends ConsumerWidget {
  const StepTier({super.key});

  static const _tiers = [
    (
      id: 'pacer',
      label: 'PACER',
      pace: '> 6:30 min/km',
      description: 'Running to build consistency and enjoy the journey.',
      color: AppColors.electricCobalt,
    ),
    (
      id: 'strider',
      label: 'STRIDER',
      pace: '5:00 – 6:30 min/km',
      description: 'Training with purpose. Pushing personal benchmarks.',
      color: AppColors.primary,
    ),
    (
      id: 'elite',
      label: 'ELITE',
      pace: '< 5:00 min/km',
      description: 'Racing-focused. Every second counts.',
      color: AppColors.safetyOrange,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTier = ref.watch(onboardingNotifierProvider).tier;

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Which runner\nare you today?',
            style: AppTypography.titleLarge.copyWith(
              fontSize: 34,
              height: 1.15,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'This can always change. Pick honestly, not aspirationally.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          ..._tiers.map(
            (tier) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _TierCard(
                id: tier.id,
                label: tier.label,
                pace: tier.pace,
                description: tier.description,
                accentColor: tier.color,
                isSelected: selectedTier == tier.id,
                onTap: () => ref
                    .read(onboardingNotifierProvider.notifier)
                    .setTier(tier.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final String id;
  final String label;
  final String pace;
  final String description;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _TierCard({
    required this.id,
    required this.label,
    required this.pace,
    required this.description,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BouncyPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: AppSpacing.paddingLg,
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.12)
              : AppColors.surfaceBase,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isSelected ? accentColor : AppColors.surfaceBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.titleMedium.copyWith(
                      color: isSelected ? accentColor : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    pace,
                    style: AppTypography.bodyMedium.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(description, style: AppTypography.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? accentColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? accentColor : AppColors.surfaceBorderLight,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.black)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
