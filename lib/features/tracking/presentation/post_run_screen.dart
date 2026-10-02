import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/geo_math.dart';
import '../domain/run_summary_entity.dart';
import '../../run_receipt/presentation/run_receipt_widget.dart';
import '../../run_receipt/presentation/run_receipt_notifier.dart';

class PostRunScreen extends ConsumerStatefulWidget {
  final RunSummaryEntity summary;
  const PostRunScreen({super.key, required this.summary});

  @override
  ConsumerState<PostRunScreen> createState() => _PostRunScreenState();
}

class _PostRunScreenState extends ConsumerState<PostRunScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  int _selectedRpe = 5;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onRpeChanged(int rpe) {
    HapticFeedback.selectionClick();
    setState(() => _selectedRpe = rpe);
  }

  Future<void> _shareReceipt() async {
    final finalSummary = widget.summary.copyWith(rpe: _selectedRpe);
    await ref.read(runReceiptNotifierProvider.notifier).shareReceipt(finalSummary);
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final receiptState = ref.watch(runReceiptNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
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
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text('Run Complete', style: AppTypography.titleMedium),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.go(Routes.home),
            child: const Text('Done'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Quick stats ────────────────────────────────────────────────
            _RunStatRow(summary: summary),
            const SizedBox(height: AppSpacing.xxl),

            // ── RPE Slider ─────────────────────────────────────────────────
            Text('How hard was that?', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              _rpeLabel(_selectedRpe),
              style: AppTypography.bodyMedium.copyWith(
                color: _rpeColor(_selectedRpe),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _RpeSlider(
              value: _selectedRpe,
              onChanged: _onRpeChanged,
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Run Receipt ────────────────────────────────────────────────
            Text('Your Run Receipt', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.md),
            FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: RunReceiptWidget(
                  summary: summary.copyWith(rpe: _selectedRpe),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Share button
            ElevatedButton.icon(
              icon: receiptState.isSharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : const Icon(Icons.share_rounded, size: 20),
              label: Text(receiptState.isSharing ? 'Preparing...' : 'SHARE RUN RECEIPT'),
              onPressed: receiptState.isSharing ? null : _shareReceipt,
            ),

            if (receiptState.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                receiptState.errorMessage!,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.danger),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: AppSpacing.massive),
          ],
        ),
      ),
    );
  }

  String _rpeLabel(int rpe) => switch (rpe) {
        1 || 2 => 'Very Easy — Recovery Walk',
        3 || 4 => 'Easy — Comfortable Pace',
        5 => 'Moderate — Controlled Effort',
        6 || 7 => 'Hard — Tempo Effort',
        8 || 9 => 'Very Hard — Threshold Push',
        10 => 'Maximum — All-Out Sprint',
        _ => '',
      };

  Color _rpeColor(int rpe) {
    if (rpe <= 3) return AppColors.success;
    if (rpe <= 6) return AppColors.warning;
    return AppColors.danger;
  }
}

// ── Run stats row ──────────────────────────────────────────────────────────────

class _RunStatRow extends StatelessWidget {
  final RunSummaryEntity summary;
  const _RunStatRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(
            value: summary.distanceKm.toStringAsFixed(2),
            unit: 'km',
            label: 'Distance',
          ),
          Container(width: 1, height: 40, color: AppColors.surfaceBorder),
          _Stat(
            value: GeoMath.formatDuration(summary.durationSeconds),
            unit: '',
            label: 'Duration',
          ),
          Container(width: 1, height: 40, color: AppColors.surfaceBorder),
          _Stat(
            value: GeoMath.formatPace(summary.avgPaceSecondsPerKm),
            unit: '/km',
            label: 'Avg Pace',
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  const _Stat({required this.value, required this.unit, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RichText(
          text: TextSpan(
            text: value,
            style: AppTypography.metricMedium,
            children: unit.isNotEmpty
                ? [
                    TextSpan(
                      text: ' $unit',
                      style: AppTypography.caption,
                    )
                  ]
                : null,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}

// ── RPE Slider ─────────────────────────────────────────────────────────────────

class _RpeSlider extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _RpeSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: _rpeColor(value),
            inactiveTrackColor: AppColors.surfaceBorder,
            thumbColor: _rpeColor(value),
            overlayColor: _rpeColor(value).withValues(alpha: 0.15),
            trackHeight: 6,
          ),
          child: Slider(
            min: 1,
            max: 10,
            divisions: 9,
            value: value.toDouble(),
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1', style: AppTypography.caption),
              Text('5', style: AppTypography.caption),
              Text('10', style: AppTypography.caption),
            ],
          ),
        ),
      ],
    );
  }

  Color _rpeColor(int rpe) {
    if (rpe <= 3) return AppColors.success;
    if (rpe <= 6) return AppColors.warning;
    return AppColors.danger;
  }
}
