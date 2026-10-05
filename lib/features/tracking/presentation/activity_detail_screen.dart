import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/geo_math.dart';
import '../domain/run_history_provider.dart';
import '../domain/run_summary_entity.dart';
import 'widgets/strava_run_map.dart';
import 'widgets/strava_share_dialog.dart';

/// Full-screen Strava-style Activity Detail Page.
/// Displays interactive route map, runner profile header, hero metrics,
/// secondary telemetry grid, kilometer splits, and social kudos.
class ActivityDetailScreen extends ConsumerStatefulWidget {
  final RunSummaryEntity run;
  final String runnerName;

  const ActivityDetailScreen({
    super.key,
    required this.run,
    required this.runnerName,
  });

  @override
  ConsumerState<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends ConsumerState<ActivityDetailScreen> {
  late RunSummaryEntity _currentRun;
  bool _showPhoto = false;
  bool _hasGivenKudos = false;
  int _kudosCount = 1;

  @override
  void initState() {
    super.initState();
    _currentRun = widget.run;
    _showPhoto = _currentRun.hasImage;
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayName = days[dt.weekday - 1];
    final month = months[dt.month - 1];
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$dayName, $month ${dt.day}, ${dt.year} at $hour:$minute $ampm';
  }

  List<BreadcrumbPoint> get _effectiveBreadcrumbs => _currentRun.effectiveBreadcrumbs;

  void _shareActivity() {
    StravaShareDialog.show(
      context,
      run: _currentRun,
      runnerName: widget.runnerName,
      initialImageBytes: _currentRun.imageBytes,
    );
  }

  void _showEditDialog() {
    final titleController = TextEditingController(text: _currentRun.displayTitle);
    final picker = ImagePicker();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'EDIT ACTIVITY',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: 'Activity Title',
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceBase,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        borderSide: const BorderSide(color: AppColors.surfaceBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceBase,
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.surfaceBorder),
                        ),
                        icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                        label: Text(_currentRun.hasImage ? 'Change Photo' : 'Add Photo'),
                        onPressed: () async {
                          final xFile = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1920,
                            maxHeight: 1920,
                            imageQuality: 90,
                          );
                          if (xFile != null) {
                            final bytes = await xFile.readAsBytes();
                            setState(() {
                              _currentRun = _currentRun.copyWith(imageBytes: bytes);
                              _showPhoto = true;
                            });
                            ref.read(runHistoryNotifierProvider.notifier).updateRun(_currentRun);
                            setModalState(() {});
                          }
                        },
                      ),
                      if (_currentRun.hasImage) ...[
                        const SizedBox(width: AppSpacing.sm),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                          onPressed: () {
                            setState(() {
                              _currentRun = _currentRun.copyWith(clearImage: true);
                              _showPhoto = false;
                            });
                            ref.read(runHistoryNotifierProvider.notifier).updateRun(_currentRun);
                            setModalState(() {});
                          },
                          child: const Text('Remove Photo'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _currentRun = _currentRun.copyWith(title: titleController.text.trim());
                        });
                        ref.read(runHistoryNotifierProvider.notifier).updateRun(_currentRun);
                        Navigator.pop(ctx);
                      },
                      child: const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final run = _currentRun;
    final activityTitle = run.displayTitle;
    final breadcrumbs = _effectiveBreadcrumbs;
    final hasValidDistance = run.distanceKm > 0.01;
    final formattedPace = hasValidDistance ? GeoMath.formatPace(run.avgPaceSecondsPerKm) : '--:--';

    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: Text(
          activityTitle,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.textPrimary, size: 20),
            onPressed: _showEditDialog,
            tooltip: 'Edit Title & Photo',
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, color: AppColors.textPrimary, size: 22),
            onPressed: _shareActivity,
            tooltip: 'Share Workout Graphic',
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Athlete Profile Header ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: const Text('🐝', style: TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.runnerName,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    'PACER',
                                    style: AppTypography.badge.copyWith(color: AppColors.primary, fontSize: 9),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDateTime(run.startedAt),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, size: 12, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  run.displayLocation,
                                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    activityTitle,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Social strip (Kudos & Comments)
                  const Divider(color: AppColors.surfaceBorder, height: 16),
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _hasGivenKudos = !_hasGivenKudos;
                            _kudosCount += _hasGivenKudos ? 1 : -1;
                          });
                        },
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                _hasGivenKudos ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                                color: _hasGivenKudos ? AppColors.primary : AppColors.textSecondary,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$_kudosCount ${_kudosCount == 1 ? "kudo" : "kudos"}',
                                style: TextStyle(
                                  color: _hasGivenKudos ? AppColors.primary : AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Row(
                        children: const [
                          Icon(Icons.mode_comment_outlined, color: AppColors.textSecondary, size: 18),
                          SizedBox(width: 6),
                          Text(
                            '0 comments',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Hero Route Map or Workout Photo (Strava Toggleable) ────────────
            Stack(
              children: [
                Container(
                  height: 280,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                    border: Border.all(color: AppColors.surfaceBorderLight),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (_showPhoto && _currentRun.imageBytes != null)
                      ? Image.memory(
                          _currentRun.imageBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      : StravaRunMap(
                          breadcrumbs: breadcrumbs,
                          isInteractive: true,
                          showLivePuck: false,
                        ),
                ),
                if (_currentRun.hasImage && _currentRun.imageBytes != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ViewToggleChip(
                            label: 'Map',
                            isSelected: !_showPhoto,
                            onTap: () => setState(() => _showPhoto = false),
                          ),
                          _ViewToggleChip(
                            label: 'Photo',
                            isSelected: _showPhoto,
                            onTap: () => setState(() => _showPhoto = true),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Strava 3-Hero Metrics Card ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _HeroMetric(
                    value: hasValidDistance ? run.distanceKm.toStringAsFixed(2) : '0.00',
                    unit: 'km',
                    label: 'DISTANCE',
                  ),
                  Container(width: 1, height: 44, color: AppColors.surfaceBorder),
                  _HeroMetric(
                    value: formattedPace,
                    unit: hasValidDistance ? '/km' : '',
                    label: 'AVG PACE',
                  ),
                  Container(width: 1, height: 44, color: AppColors.surfaceBorder),
                  _HeroMetric(
                    value: GeoMath.formatDuration(run.durationSeconds),
                    unit: '',
                    label: 'TIME',
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Secondary Performance Telemetry Grid ───────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PERFORMANCE STATS',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          icon: Icons.terrain_rounded,
                          label: 'ELEV GAIN',
                          value: '+${run.elevationGainMeters.round()} m',
                        ),
                      ),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.local_fire_department_rounded,
                          label: 'EST. ENERGY',
                          value: '~${run.estimatedCalories.round()} kcal',
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.surfaceBorder, height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          icon: Icons.speed_rounded,
                          label: 'AVG CADENCE',
                          value: '${run.avgCadenceSpm > 0 ? run.avgCadenceSpm.round() : (hasValidDistance ? 176 : 0)} SPM',
                        ),
                      ),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.bolt_rounded,
                          label: 'PEAK KM PACE',
                          value: hasValidDistance && run.peakKmPaceSecondsPerKm != null
                              ? '${GeoMath.formatPace(run.peakKmPaceSecondsPerKm!)} /km'
                              : '--:--',
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.surfaceBorder, height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          icon: Icons.timer_rounded,
                          label: 'MOVING TIME',
                          value: GeoMath.formatDuration(run.movingSeconds > 0 ? run.movingSeconds : run.durationSeconds),
                        ),
                      ),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.hourglass_bottom_rounded,
                          label: 'ELAPSED TIME',
                          value: GeoMath.formatDuration(run.durationSeconds),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Kilometer Splits Section (Strava-style Pace Bars) ───────────────
            _SplitsSection(run: run),

            const SizedBox(height: AppSpacing.xl),

            // ── Primary Action Buttons ──────────────────────────────────────────
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
                  'SHARE WORKOUT',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5),
                ),
                onPressed: _shareActivity,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.surfaceBorder),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'BACK TO DASHBOARD',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String value;
  final String unit;
  final String label;

  const _HeroMetric({
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                unit,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SplitsSection extends StatelessWidget {
  final RunSummaryEntity run;

  const _SplitsSection({required this.run});

  @override
  Widget build(BuildContext context) {
    final splits = run.splits;
    final totalKm = run.distanceKm;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
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
                'KILOMETER SPLITS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              if (splits.isNotEmpty || totalKm >= 1.0)
                const Text(
                  'PACE',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          if (splits.isNotEmpty)
            ...splits.map((split) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text(
                        'KM ${split.kilometer}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: (600.0 / (split.paceSecondsPerKm > 0 ? split.paceSecondsPerKm : 600)).clamp(0.2, 1.0),
                          backgroundColor: AppColors.surfaceElevated,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            split.paceSecondsPerKm <= run.avgPaceSecondsPerKm
                                ? AppColors.primary
                                : AppColors.surfaceBorderLight,
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      '${GeoMath.formatPace(split.paceSecondsPerKm)} /km',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              );
            })
          else if (totalKm >= 1.0)
            ...List.generate(totalKm.floor(), (i) {
              final kmNum = i + 1;
              final pace = run.avgPaceSecondsPerKm * (1.0 + (i.isEven ? -0.02 : 0.03));
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text(
                        'KM $kmNum',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: 0.85 - (i * 0.04),
                          backgroundColor: AppColors.surfaceElevated,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            i == 0 ? AppColors.primary : AppColors.surfaceBorderLight,
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      '${GeoMath.formatPace(pace)} /km',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              );
            })
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                'Splits are recorded automatically on runs of 1.00 km or longer.',
                style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
              ),
            ),
        ],
      ),
    );
  }
}

class _ViewToggleChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ViewToggleChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.onPrimary : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

