import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';

/// Step 1 — The Blee Manifesto. Identity anchoring.
class StepManifesto extends StatelessWidget {
  const StepManifesto({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: const Text(
              '🐝 BLEE',
              style: TextStyle(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text(
            'We don\'t run\nfor numbers.',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -1.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'We run for who we become.',
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _ManifestoPoint(
            icon: Icons.groups_rounded,
            title: 'Community, not competition.',
            body: 'Your pace doesn\'t define your belonging here.',
          ),
          const SizedBox(height: AppSpacing.lg),
          _ManifestoPoint(
            icon: Icons.loop_rounded,
            title: 'Consistency, not PRs.',
            body: 'The rhythm you build outlasts any personal record.',
          ),
          const SizedBox(height: AppSpacing.lg),
          _ManifestoPoint(
            icon: Icons.place_rounded,
            title: 'Local, always.',
            body: 'BGC, Manila. Your streets. Your tribe.',
          ),
        ],
      ),
    );
  }
}

class _ManifestoPoint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _ManifestoPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryMuted,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.titleMedium.copyWith(fontSize: 15)),
              const SizedBox(height: AppSpacing.xxs),
              Text(body, style: AppTypography.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
