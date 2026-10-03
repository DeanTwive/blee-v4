import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/bouncy_pressable.dart';
import '../onboarding_notifier.dart';

/// Step 5 — Weekly rhythm commitment. Habit formation commitment hook.
class StepRhythm extends ConsumerWidget {
  const StepRhythm({super.key});

  static const _options = [
    (value: 2, label: '2×  week', sub: 'Easy starter rhythm'),
    (value: 3, label: '3×  week', sub: 'Solid consistency'),
    (value: 4, label: '4+× week', sub: 'Serious commitment'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingNotifierProvider).weeklyRhythmTarget;

    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'How often will\nyou run?',
            style: AppTypography.titleLarge.copyWith(
              fontSize: 34,
              height: 1.15,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Blee will protect your streak. Choose honestly.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),

          // Interactive 7-Day Rhythm Visualizer
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].asMap().entries.map((e) {
                final dayIdx = e.key;
                final dayLetter = e.value;
                // Active days mapping based on target
                final isRunDay = switch (selected) {
                  2 => dayIdx == 1 || dayIdx == 3, // Tue, Thu
                  3 => dayIdx == 1 || dayIdx == 3 || dayIdx == 5, // Tue, Thu, Sat
                  _ => dayIdx == 0 || dayIdx == 2 || dayIdx == 4 || dayIdx == 6, // Mon, Wed, Fri, Sun
                };
                return Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isRunDay
                            ? AppColors.primary
                            : AppColors.surfaceBase,
                        border: Border.all(
                          color: isRunDay ? AppColors.primary : AppColors.surfaceBorderLight,
                        ),
                        boxShadow: isRunDay
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                )
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        dayLetter,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isRunDay ? Colors.black : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          ..._options.map((opt) {
            final isSelected = selected == opt.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: BouncyPressable(
                onTap: () => ref
                    .read(onboardingNotifierProvider.notifier)
                    .setWeeklyRhythmTarget(opt.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: AppSpacing.paddingLg,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryMuted : AppColors.surfaceBase,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              blurRadius: 12,
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
                              opt.label,
                              style: AppTypography.titleMedium.copyWith(
                                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(opt.sub, style: AppTypography.bodyMedium),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary, size: 24),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, color: AppColors.success, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Blee Pro includes Grace Weeks — 2 automatic streak protection periods per quarter.',
                    style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
