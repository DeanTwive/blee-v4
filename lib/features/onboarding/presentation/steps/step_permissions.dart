import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../onboarding_notifier.dart';

/// Step 6 — Permission Primer (location + notifications).
/// Shown BEFORE the OS dialog to explain WHY — improves grant rate.
class StepPermissions extends ConsumerWidget {
  const StepPermissions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingNotifierProvider);

    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Two quick\npermissions.',
            style: AppTypography.titleLarge.copyWith(
              fontSize: 34,
              height: 1.15,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Blee needs these to keep your GPS running and notify you before group runs.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xxl),

          _PermissionCard(
            icon: Icons.location_on_rounded,
            iconColor: AppColors.safetyOrange,
            title: 'Background Location',
            description:
                'Lets Blee track your run even when your screen is off — '
                'critical for accurate distance, route, and pace calculations.',
            isGranted: state.locationGranted,
            badge: 'REQUIRED',
          ),
          const SizedBox(height: AppSpacing.md),
          _PermissionCard(
            icon: Icons.notifications_rounded,
            iconColor: AppColors.electricCobalt,
            title: 'Notifications',
            description:
                'Receive reminders 2 hours before group runs and '
                'encouragement when you hit a Blee Rhythm milestone.',
            isGranted: state.notificationGranted,
            badge: 'RECOMMENDED',
          ),

          const SizedBox(height: AppSpacing.xl),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.safetyOrange,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget),
            ),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
            label: const Text('GRANT PERMISSIONS'),
            onPressed: () => ref
                .read(onboardingNotifierProvider.notifier)
                .requestPermissions(),
          ),

          if (state.locationGranted && state.notificationGranted)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 18),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'All permissions granted!',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.success,
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

class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool isGranted;
  final String badge;

  const _PermissionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isGranted ? AppColors.success : AppColors.surfaceBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: AppTypography.titleMedium.copyWith(fontSize: 15)),
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs, vertical: 2),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      child: Text(
                        badge,
                        style: AppTypography.badge.copyWith(
                          color: iconColor,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(description, style: AppTypography.bodyMedium),
                if (isGranted) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const Icon(Icons.check_rounded,
                          color: AppColors.success, size: 14),
                      const SizedBox(width: AppSpacing.xxs),
                      Text('Granted',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.success)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
