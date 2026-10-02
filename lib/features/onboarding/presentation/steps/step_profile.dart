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
          const SizedBox(height: AppSpacing.xs),
          Text(
            'This is how the community will know you.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xxl),
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
