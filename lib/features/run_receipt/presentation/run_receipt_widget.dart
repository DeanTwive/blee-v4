import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screenshot/screenshot.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/geo_math.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../tracking/domain/run_summary_entity.dart';
import '../domain/receipt_generator_service.dart';
import 'run_receipt_notifier.dart';

/// The shareable Run Receipt card — rendered both on-screen and captured for sharing.
class RunReceiptWidget extends ConsumerWidget {
  final RunSummaryEntity summary;
  const RunReceiptWidget({super.key, required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final controller = ref.read(runReceiptNotifierProvider.notifier).screenshotController;
    final tierColor = switch (profile?.tier ?? 'pacer') {
      'strider' => AppColors.primary,
      'elite' => AppColors.safetyOrange,
      _ => AppColors.electricCobalt,
    };

    return Screenshot(
      controller: controller,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E232E),
              Color(0xFF14171E),
              Color(0xFF0F1116),
            ],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            _ReceiptHeader(
              profile: profile,
              tierColor: tierColor,
              summary: summary,
            ),

            // ── Route Mini-Map Silhouette (Vector, no raster) ────────────────
            _RouteSilhouette(
              breadcrumbs: summary.breadcrumbs,
              accentColor: tierColor,
            ),

            // ── Distance Hero ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                children: [
                  Text(
                    summary.distanceKm.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -3,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    'KILOMETERS',
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),

            // ── Separator ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Row(
                children: [
                  Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.12))),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Text(
                      '🐝',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.12))),
                ],
              ),
            ),

            // ── Stats grid ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.xl,
              ),
              child: Row(
                children: [
                  _ReceiptStat(
                    value: GeoMath.formatDuration(summary.durationSeconds),
                    label: 'DURATION',
                  ),
                  _ReceiptDivider(),
                  _ReceiptStat(
                    value: GeoMath.formatPace(summary.avgPaceSecondsPerKm),
                    label: 'AVG PACE',
                  ),
                  _ReceiptDivider(),
                  if (summary.peakKmPaceSecondsPerKm != null)
                    _ReceiptStat(
                      value: GeoMath.formatPace(summary.peakKmPaceSecondsPerKm!),
                      label: 'PEAK KM',
                      valueColor: tierColor,
                    )
                  else
                    _ReceiptStat(
                      value: summary.rpe != null ? '${summary.rpe} / 10' : '--',
                      label: 'RPE EFFORT',
                    ),
                ],
              ),
            ),

            // ── Footer ────────────────────────────────────────────────────────
            _ReceiptFooter(summary: summary, tierColor: tierColor),
          ],
        ),
      ),
    );
  }
}

class _ReceiptHeader extends StatelessWidget {
  final dynamic profile;
  final Color tierColor;
  final RunSummaryEntity summary;

  const _ReceiptHeader({
    required this.profile,
    required this.tierColor,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMM d · h:mm a').format(summary.startedAt);
    final name = profile?.displayName ?? 'Runner';
    final tierLabel = profile?.tierLabel ?? 'PACER';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '🐝 BLEE',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tierColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        tierLabel,
                        style: TextStyle(
                          color: tierColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  dateStr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
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

class _RouteSilhouette extends StatelessWidget {
  final List<BreadcrumbPoint> breadcrumbs;
  final Color accentColor;

  const _RouteSilhouette({
    required this.breadcrumbs,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xs,
      ),
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: CustomPaint(
          painter: RouteSilhouettePainter(
            breadcrumbs: breadcrumbs,
            strokeColor: accentColor,
          ),
        ),
      ),
    );
  }
}

/// CustomPainter that renders a vector polyline silhouette of the run route.
class RouteSilhouettePainter extends CustomPainter {
  final List<BreadcrumbPoint> breadcrumbs;
  final Color strokeColor;

  RouteSilhouettePainter({
    required this.breadcrumbs,
    required this.strokeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (breadcrumbs.isEmpty) {
      _paintEmptyState(canvas, size);
      return;
    }

    final normalized = ReceiptGeneratorService.normalizeRoute(
      breadcrumbs,
      width: size.width,
      height: size.height,
      padding: 16.0,
    );

    if (!normalized.hasPath) {
      if (normalized.points.isNotEmpty) {
        final p = normalized.points.first;
        final paint = Paint()
          ..color = strokeColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p, 4, paint);
      }
      return;
    }

    // Glowing path underlay
    final glowPaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.25)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Sharp main route path
    final pathPaint = Paint()
      ..color = strokeColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final first = normalized.points.first;
    path.moveTo(first.dx, first.dy);

    for (int i = 1; i < normalized.points.length; i++) {
      final pt = normalized.points[i];
      path.lineTo(pt.dx, pt.dy);
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, pathPaint);

    // Draw Start point (Green dot)
    final startPaint = Paint()
      ..color = const Color(0xFF00E676)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(first, 3.5, startPaint);

    // Draw Finish point (Safety Orange / White dot with ring)
    final last = normalized.points.last;
    final finishPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final finishRing = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(last, 4.0, finishPaint);
    canvas.drawCircle(last, 5.5, finishRing);
  }

  void _paintEmptyState(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, 12, paint);
  }

  @override
  bool shouldRepaint(covariant RouteSilhouettePainter oldDelegate) {
    return oldDelegate.breadcrumbs != breadcrumbs ||
        oldDelegate.strokeColor != strokeColor;
  }
}

class _ReceiptStat extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;

  const _ReceiptStat({
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: valueColor ?? Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.4),
              letterSpacing: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ReceiptDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withValues(alpha: 0.12),
    );
  }
}

class _ReceiptFooter extends StatelessWidget {
  final RunSummaryEntity summary;
  final Color tierColor;

  const _ReceiptFooter({required this.summary, required this.tierColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppSpacing.radiusXl),
          bottomRight: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on_rounded, color: tierColor, size: 14),
                  const SizedBox(width: AppSpacing.xxs),
                  Text(
                    'BGC, Manila',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Text(
                'blee.app · Identity > Telemetry',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _ReceiptBarcode(runId: summary.runId),
        ],
      ),
    );
  }
}

/// Simulated receipt barcode graphic representing the cryptographic run verification hash.
class _ReceiptBarcode extends StatelessWidget {
  final String runId;
  const _ReceiptBarcode({required this.runId});

  @override
  Widget build(BuildContext context) {
    final cleanId = runId.replaceAll('-', '');
    final bars = <Widget>[];

    for (int i = 0; i < 40; i++) {
      final charCode = i < cleanId.length ? cleanId.codeUnitAt(i) : i * 7;
      final width = (charCode % 3) + 1.2;
      bars.add(
        Container(
          width: width,
          height: 18,
          margin: const EdgeInsets.symmetric(horizontal: 1.0),
          color: Colors.white.withValues(alpha: (charCode % 2 == 0) ? 0.4 : 0.15),
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: bars,
        ),
        const SizedBox(height: 3),
        Text(
          'RUN ID: ${runId.substring(0, 8).toUpperCase()}',
          style: TextStyle(
            fontSize: 8,
            letterSpacing: 2,
            fontFamily: 'monospace',
            color: Colors.white.withValues(alpha: 0.25),
          ),
        ),
      ],
    );
  }
}
