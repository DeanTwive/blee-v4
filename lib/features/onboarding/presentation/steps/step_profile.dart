import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../onboarding_notifier.dart';

/// Step 2 — First name entry.
class StepProfile extends ConsumerStatefulWidget {
  const StepProfile({super.key});

  @override
  ConsumerState<StepProfile> createState() => _StepProfileState();
}

class _StepProfileState extends ConsumerState<StepProfile> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(onboardingNotifierProvider).firstName;
    _nameController = TextEditingController(text: initial);
    _nameController.addListener(() {
      ref.read(onboardingNotifierProvider.notifier).setFirstName(_nameController.text);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'What should we\ncall you?',
            style: AppTypography.titleLarge.copyWith(
              fontSize: 34,
              height: 1.15,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Live Runner Identity Preview Avatar Badge
          Center(
            child: AnimatedBuilder(
              animation: _nameController,
              builder: (context, _) {
                final text = _nameController.text.trim();
                final initial = text.isNotEmpty ? text[0].toUpperCase() : '⚡';
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                    border: Border.all(
                      color: text.isNotEmpty ? AppColors.primary : AppColors.surfaceBorder,
                      width: 1.5,
                    ),
                    boxShadow: text.isNotEmpty
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text.isNotEmpty ? text : 'Your Runner Name',
                            style: AppTypography.titleMedium.copyWith(
                              color: text.isNotEmpty
                                  ? AppColors.textPrimary
                                  : AppColors.textTertiary,
                            ),
                          ),
                          Text(
                            'Blee Runner · BGC Cluster',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          TextFormField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: AppTypography.titleLarge,
            decoration: const InputDecoration(
              hintText: 'e.g. Marco, Katrina...',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: AppColors.primaryMuted,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Your first name will appear on your Run Receipts.',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.primary),
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
