import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/geo_math.dart';
import '../../../core/widgets/bouncy_pressable.dart';
import '../domain/run_summary_entity.dart';
import 'tracking_notifier.dart';

class TrackingScreen extends ConsumerWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trackingNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      body: SafeArea(
        child: switch (state.status) {
          TrackingStatus.idle => _IdleView(
              errorMessage: state.errorMessage,
              onStart: () => ref.read(trackingNotifierProvider.notifier).startRun(),
              onSimulate: () => ref.read(trackingNotifierProvider.notifier).startDemoRun(),
            ),
          TrackingStatus.acquiring => const _AcquiringView(),
          TrackingStatus.running || TrackingStatus.paused => _RunningHud(state: state),
          TrackingStatus.stopped => const _StoppedView(),
        },
      ),
    );
  }
}

// ── Idle State ─────────────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  final String? errorMessage;
  final VoidCallback onStart;
  final VoidCallback? onSimulate;
  const _IdleView({this.errorMessage, required this.onStart, this.onSimulate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (errorMessage != null) ...[
            _ErrorBanner(message: errorMessage!),
            const SizedBox(height: AppSpacing.lg),
          ],
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryMuted,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text('🐝', style: TextStyle(fontSize: 48)),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text(
            'Ready to Run',
            style: AppTypography.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 16),
              const SizedBox(width: AppSpacing.xxs),
              const Text(
                'BGC, Manila',
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          BouncyPressable(
            onTap: onStart,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded, size: 28),
              label: const Text('START RUN'),
              onPressed: onStart,
            ),
          ),
          if (onSimulate != null) ...[
            const SizedBox(height: AppSpacing.sm),
            BouncyPressable(
              onTap: onSimulate,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                ),
                icon: const Icon(Icons.fast_forward_rounded, size: 18, color: AppColors.primary),
                label: const Text(
                  'SIMULATE RUN (BGC 5K DEMO)',
                  style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700),
                ),
                onPressed: onSimulate,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }
}

// ── Acquiring GPS Signal ───────────────────────────────────────────────────────

class _AcquiringView extends ConsumerStatefulWidget {
  const _AcquiringView();

  @override
  ConsumerState<_AcquiringView> createState() => _AcquiringViewState();
}

class _AcquiringViewState extends ConsumerState<_AcquiringView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulse,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: const Icon(
                Icons.gps_fixed_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text('Acquiring GPS Signal', style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Move outdoors for best accuracy',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextButton.icon(
            icon: const Icon(Icons.fast_forward_rounded, size: 18, color: AppColors.primary),
            label: const Text(
              'Taking too long indoors? Simulate Run',
              style: TextStyle(color: AppColors.primary, fontSize: 13),
            ),
            onPressed: () =>
                ref.read(trackingNotifierProvider.notifier).startDemoRun(),
          ),
        ],
      ),
    );
  }
}

// ── Live Run HUD ───────────────────────────────────────────────────────────────

class _RunningHud extends ConsumerWidget {
  final TrackingState state;
  const _RunningHud({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPaused = state.status == TrackingStatus.paused;
    final distanceKm = state.distanceKm.toStringAsFixed(2);
    final duration = GeoMath.formatDuration(state.elapsedSeconds);
    final pace = GeoMath.formatPace(state.currentPaceSecondsPerKm);
    final accuracy = state.currentAccuracyMeters;

    return Column(
      children: [
        // Accuracy warning banner
        if (accuracy != null && accuracy > 15)
          _AccuracyBanner(accuracyMeters: accuracy),

        // Error banner
        if (state.errorMessage != null)
          _ErrorBanner(message: state.errorMessage!),

        if (isPaused)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pause_circle_filled_rounded,
                      color: AppColors.warning, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'RUN PAUSED',
                    style: AppTypography.badge.copyWith(
                      color: AppColors.warning,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

        const Spacer(),

        // ── Main metrics ──────────────────────────────────────────────────
        Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            children: [
              // Distance (primary hero metric)
              RepaintBoundary(
                child: Column(
                  children: [
                    Text(
                      distanceKm,
                      style: AppTypography.metricLarge.copyWith(fontSize: 72),
                    ),
                    Text(
                      'KILOMETERS',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Secondary metrics row
              RepaintBoundary(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _MetricColumn(value: duration, label: 'DURATION'),
                    Container(width: 1, height: 40, color: AppColors.surfaceBorder),
                    _MetricColumn(value: pace, label: 'PACE /KM'),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // ── Controls ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Pause / Resume
              _CircleButton(
                icon: isPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                color: AppColors.surfaceElevated,
                iconColor: AppColors.primary,
                size: 64,
                onTap: isPaused
                    ? () => ref
                        .read(trackingNotifierProvider.notifier)
                        .resumeRun()
                    : () => ref
                        .read(trackingNotifierProvider.notifier)
                        .pauseRun(),
              ),
              // Hold-to-stop
              _HoldToStopButton(
                onStopped: () async {
                  final summary = await ref
                      .read(trackingNotifierProvider.notifier)
                      .stopRun();
                  if (context.mounted && summary != null) {
                    context.pushReplacement(Routes.postRun, extra: summary);
                  } else if (context.mounted) {
                    context.go(Routes.home);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricColumn extends StatelessWidget {
  final String value;
  final String label;
  const _MetricColumn({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTypography.metricMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final double size;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BouncyPressable(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: AppColors.surfaceBorderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: size * 0.45),
      ),
    );
  }
}

/// Hold-to-stop button with 2-second countdown circular indicator.
class _HoldToStopButton extends StatefulWidget {
  final VoidCallback onStopped;
  const _HoldToStopButton({required this.onStopped});

  @override
  State<_HoldToStopButton> createState() => _HoldToStopButtonState();
}

class _HoldToStopButtonState extends State<_HoldToStopButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onStopped();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _controller.forward(),
      onLongPressEnd: (_) => _controller.reverse(),
      onLongPressCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: _controller.value,
                strokeWidth: 4,
                backgroundColor: AppColors.surfaceBorder,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.danger),
              ),
            ),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceElevated,
              ),
              child: Icon(
                Icons.stop_rounded,
                color: _controller.value > 0 ? AppColors.danger : AppColors.textSecondary,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Banners ────────────────────────────────────────────────────────────────────

class _AccuracyBanner extends StatelessWidget {
  final double accuracyMeters;
  const _AccuracyBanner({required this.accuracyMeters});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      color: AppColors.warning.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.gps_not_fixed_rounded,
              color: AppColors.warning, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Weak signal (±${accuracyMeters.toStringAsFixed(0)}m) — move to open sky',
            style: AppTypography.caption.copyWith(color: AppColors.warning),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      color: AppColors.danger.withValues(alpha: 0.15),
      child: Text(
        message,
        style: AppTypography.caption.copyWith(color: AppColors.danger),
      ),
    );
  }
}

class _StoppedView extends StatelessWidget {
  const _StoppedView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }
}
