import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/geo_math.dart';
import '../../../core/widgets/bouncy_pressable.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/run_summary_entity.dart';
import '../domain/run_history_provider.dart';
import '../../run_receipt/presentation/run_receipt_widget.dart';
import '../../run_receipt/presentation/run_receipt_notifier.dart';
import 'tracking_notifier.dart';
import 'widgets/strava_run_map.dart';
import 'widgets/strava_share_dialog.dart';

class PostRunScreen extends ConsumerStatefulWidget {
  final RunSummaryEntity summary;
  const PostRunScreen({super.key, required this.summary});

  @override
  ConsumerState<PostRunScreen> createState() => _PostRunScreenState();
}

class _PostRunScreenState extends ConsumerState<PostRunScreen> {
  late final TextEditingController _titleController;
  final ImagePicker _picker = ImagePicker();
  Uint8List? _photoBytes;
  int _selectedRpe = 5;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.summary.displayTitle);
    _photoBytes = widget.summary.imageBytes;
    _selectedRpe = widget.summary.rpe ?? 5;

    // Auto-save completed run to the runner's history and dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _saveCurrentRun();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  RunSummaryEntity get _currentSummary => widget.summary.copyWith(
        rpe: _selectedRpe,
        title: _titleController.text.trim(),
        imageBytes: _photoBytes,
      );

  void _saveCurrentRun() {
    ref.read(runHistoryNotifierProvider.notifier).addRun(_currentSummary);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final xFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );
      if (xFile != null) {
        final bytes = await xFile.readAsBytes();
        setState(() {
          _photoBytes = bytes;
        });
        _saveCurrentRun();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load image: $e')),
        );
      }
    }
  }

  void _removePhoto() {
    setState(() {
      _photoBytes = null;
    });
    ref.read(runHistoryNotifierProvider.notifier).addRun(
          widget.summary.copyWith(
            rpe: _selectedRpe,
            title: _titleController.text.trim(),
            clearImage: true,
          ),
        );
  }

  void _onRpeChanged(int rpe) {
    HapticFeedback.selectionClick();
    setState(() => _selectedRpe = rpe);
    _saveCurrentRun();
  }

  void _openStravaShare() {
    _saveCurrentRun();
    final runnerName = ref.read(currentProfileProvider).value?.displayName ?? 'Runner';
    StravaShareDialog.show(
      context,
      run: _currentSummary,
      runnerName: runnerName,
      initialImageBytes: _photoBytes,
    );
  }

  Future<void> _shareReceipt() async {
    final finalSummary = _currentSummary;
    await ref.read(runReceiptNotifierProvider.notifier).shareReceipt(finalSummary);
  }

  void _confirmDiscard(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        title: const Text(
          'Discard Activity?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'Are you sure you want to discard this run? It will be permanently removed and not saved to your profile.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text(
              'KEEP ACTIVITY',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              ref.read(runHistoryNotifierProvider.notifier).removeRun(widget.summary.runId);
              ref.read(trackingNotifierProvider.notifier).resetToIdle();
              context.go(Routes.home);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Activity discarded'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
            ),
            child: const Text(
              'DISCARD',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
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
            onPressed: () => _confirmDiscard(context),
            child: const Text(
              'Discard',
              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(trackingNotifierProvider.notifier).resetToIdle();
              context.go(Routes.home);
            },
            child: const Text('Done'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Strava Activity Title Input ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ACTIVITY TITLE',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Morning 5K at Track 30th',
                      hintStyle: TextStyle(color: AppColors.textTertiary.withValues(alpha: 0.6)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      border: InputBorder.none,
                      suffixIcon: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 18),
                    ),
                    onChanged: (_) => _saveCurrentRun(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Strava Photo Attachment Card ─────────────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'PHOTOS & MEMORIES',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      if (_photoBytes != null)
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: _removePhoto,
                          child: const Text('Remove', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  if (_photoBytes != null) ...[
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          child: Image.memory(
                            _photoBytes!,
                            height: 190,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black.withValues(alpha: 0.75),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.photo_library_rounded, size: 14),
                            label: const Text('Change', style: TextStyle(fontSize: 12)),
                            onPressed: () => _pickPhoto(ImageSource.gallery),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    InkWell(
                      onTap: () => _pickPhoto(ImageSource.gallery),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBase,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(
                            color: AppColors.surfaceBorderLight,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 22),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Add Photo to Workout',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Your photo will appear behind your stats graphic',
                                    style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Strava Route Map ──────────────────────────────────────────
            if (summary.breadcrumbs.isNotEmpty) ...[
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: AppColors.surfaceBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: StravaRunMap(
                  breadcrumbs: summary.breadcrumbs,
                  isInteractive: true,
                  showLivePuck: false,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ── Quick stats ────────────────────────────────────────────────
            _RunStatRow(summary: summary),
            if (summary.splits.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _SplitsBreakdownCard(splits: summary.splits),
            ],
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

            // ── Primary Action: Strava Graphic Share ─────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  elevation: 4,
                ),
                icon: const Icon(Icons.share_rounded, size: 20),
                label: const Text(
                  'SHARE WORKOUT GRAPHIC',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.8),
                ),
                onPressed: _openStravaShare,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Secondary Action: Save & Done ────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.surfaceBorder),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                onPressed: () {
                  _saveCurrentRun();
                  ref.read(trackingNotifierProvider.notifier).resetToIdle();
                  context.go(Routes.home);
                },
                child: const Text(
                  'SAVE & GO TO DASHBOARD',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                onPressed: () => _confirmDiscard(context),
                label: const Text(
                  'DISCARD ACTIVITY',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Collapsible Receipt Export (Optional) ────────────────────────
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'View Novelty Run Receipt',
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
                children: [
                  RunReceiptWidget(
                    summary: _currentSummary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  BouncyPressable(
                    onTap: receiptState.isSharing ? null : _shareReceipt,
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.receipt_long_rounded, size: 18),
                        label: Text(receiptState.isSharing ? 'Preparing...' : 'SHARE RECEIPT IMAGE'),
                        onPressed: receiptState.isSharing ? null : _shareReceipt,
                      ),
                    ),
                  ),
                ],
              ),
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
    final hasSecondary = summary.elevationGainMeters > 0 ||
        summary.totalSteps > 0 ||
        summary.estimatedCalories > 0;

    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.specularHighlight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
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
          if (hasSecondary) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(color: AppColors.surfaceBorder, height: 1),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(
                  value: '+${summary.elevationGainMeters.toStringAsFixed(0)}',
                  unit: 'm',
                  label: 'Elevation',
                ),
                Container(width: 1, height: 36, color: AppColors.surfaceBorder),
                _Stat(
                  value: summary.totalSteps > 0 ? '${summary.totalSteps}' : '--',
                  unit: '',
                  label: summary.avgCadenceSpm > 0
                      ? 'Steps (${summary.avgCadenceSpm.toStringAsFixed(0)} spm)'
                      : 'Steps',
                ),
                Container(width: 1, height: 36, color: AppColors.surfaceBorder),
                _Stat(
                  value: summary.estimatedCalories > 0
                      ? summary.estimatedCalories.toStringAsFixed(0)
                      : '--',
                  unit: 'kcal',
                  label: 'Calories',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SplitsBreakdownCard extends StatelessWidget {
  final List<RunSplit> splits;
  const _SplitsBreakdownCard({required this.splits});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'KILOMETER SPLITS',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Minetti GAP',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Table(
            columnWidths: const {
              0: FixedColumnWidth(36),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(2),
            },
            children: [
              const TableRow(
                children: [
                  Text('KM', style: AppTypography.caption),
                  Text('PACE', style: AppTypography.caption),
                  Text('GAP', style: AppTypography.caption),
                  Text('ELEV', style: AppTypography.caption, textAlign: TextAlign.right),
                ],
              ),
              ...splits.map((s) {
                final elevSign = s.elevationDeltaMeters >= 0 ? '+' : '';
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        '${s.splitIndex}',
                        style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        GeoMath.formatPace(s.paceSecondsPerKm),
                        style: AppTypography.bodyMedium,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        GeoMath.formatPace(s.gapSecondsPerKm ?? s.paceSecondsPerKm),
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        '$elevSign${s.elevationDeltaMeters.toStringAsFixed(0)}m',
                        style: AppTypography.bodyMedium.copyWith(
                          color: s.elevationDeltaMeters >= 0 ? AppColors.warning : AppColors.success,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                );
              }),
            ],
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
