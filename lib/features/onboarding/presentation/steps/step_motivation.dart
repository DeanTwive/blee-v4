import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/bouncy_pressable.dart';
import '../onboarding_notifier.dart';

/// Step 4 — Motivation anchor (identity goal). SDT: Relatedness + Competence.
class StepMotivation extends ConsumerWidget {
  const StepMotivation({super.key});

  static const _motivations = [
    (id: 'mental_clarity', emoji: '🧘', label: 'Mental Clarity', sub: 'Running clears my head'),
    (id: 'health', emoji: '💪', label: 'Health & Longevity', sub: 'Building a body that lasts'),
    (id: 'marathon_prep', emoji: '🏅', label: 'Race / Marathon Prep', sub: 'Training with a goal race in mind'),
    (id: 'community', emoji: '🤝', label: 'Community', sub: 'Running is more fun with people'),
    (id: 'weight_loss', emoji: '🔥', label: 'Weight & Energy', sub: 'Feel lighter and more energised'),
    (id: 'habit', emoji: '🔁', label: 'Build a Habit', sub: 'Making running part of who I am'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingNotifierProvider).motivation;

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Why do you run?',
            style: AppTypography.titleLarge.copyWith(
              fontSize: 34,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your honest answer shapes your Blee experience.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.25,
            children: _motivations.map((m) {
              final isSelected = selected == m.id;
              return BouncyPressable(
                onTap: () => ref
                    .read(onboardingNotifierProvider.notifier)
                    .setMotivation(m.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: AppSpacing.paddingMd,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryMuted
                        : AppColors.surfaceBase,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surfaceBorder,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        m.label,
                        style: AppTypography.caption.copyWith(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        m.sub,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
