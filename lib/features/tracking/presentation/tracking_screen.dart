import 'package:flutter/foundation.dart';
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
import 'widgets/strava_run_map.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  final bool autoStart;
  const TrackingScreen({super.key, this.autoStart = true});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _cancelled) return;
        final state = ref.read(trackingNotifierProvider);
        if (state.status == TrackingStatus.idle &&
            state.unfinishedRun == null &&
            state.errorMessage == null) {
          ref.read(trackingNotifierProvider.notifier).startRun();
        }
      });
    }
  }

  void _handleCancel() {
    setState(() => _cancelled = true);
    ref.read(trackingNotifierProvider.notifier).cancelAcquisition();
    if (context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trackingNotifierProvider);

    // If autoStart is active, user has not cancelled, and there is no error or unfinished run,
    // display _AcquiringView immediately so user never sees _IdleView.
    final effectiveStatus = (widget.autoStart &&
            !_cancelled &&
            state.status == TrackingStatus.idle &&
            state.unfinishedRun == null &&
            state.errorMessage == null)
        ? TrackingStatus.acquiring
        : state.status;

    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      body: SafeArea(
        child: switch (effectiveStatus) {
          TrackingStatus.idle || TrackingStatus.stopped => _IdleView(
              errorMessage: state.errorMessage,
              unfinishedRun: state.unfinishedRun,
              onStart: () {
                setState(() => _cancelled = false);
                ref.read(trackingNotifierProvider.notifier).startRun();
              },
              onSimulate: () => ref.read(trackingNotifierProvider.notifier).startDemoRun(),
              onResumeUnfinished: (runId) => ref.read(trackingNotifierProvider.notifier).resumeInterruptedRun(runId),
              onSaveUnfinished: (runId) async {
                final summary = await ref.read(trackingNotifierProvider.notifier).recoverAndFinishRun(runId);
                if (summary != null && context.mounted) {
                  context.push(Routes.postRun, extra: summary);
                }
              },
              onDiscardUnfinished: (runId) => ref.read(trackingNotifierProvider.notifier).discardUnfinishedRun(runId),
            ),
          TrackingStatus.acquiring => _AcquiringView(onCancel: _handleCancel),
          TrackingStatus.running || TrackingStatus.paused => _RunningHud(state: state),
        },
      ),
    );
  }
}

// ── Idle State ─────────────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  final String? errorMessage;
  final Map<String, dynamic>? unfinishedRun;
  final VoidCallback onStart;
  final VoidCallback? onSimulate;
  final ValueChanged<String>? onResumeUnfinished;
  final ValueChanged<String>? onSaveUnfinished;
  final ValueChanged<String>? onDiscardUnfinished;

  const _IdleView({
    this.errorMessage,
    this.unfinishedRun,
    required this.onStart,
    this.onSimulate,
    this.onResumeUnfinished,
    this.onSaveUnfinished,
    this.onDiscardUnfinished,
  });

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
          if (unfinishedRun != null) ...[
            _InterruptedRunCard(
              runData: unfinishedRun!,
              onResume: () => onResumeUnfinished?.call(unfinishedRun!['id'] as String),
              onSave: () => onSaveUnfinished?.call(unfinishedRun!['id'] as String),
              onDiscard: () => onDiscardUnfinished?.call(unfinishedRun!['id'] as String),
            ),
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
                  'SIMULATE RUN (BGC 5K TELEMETRY DEMO)',
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
  final VoidCallback? onCancel;
  const _AcquiringView({this.onCancel});

  @override
  ConsumerState<_AcquiringView> createState() => _AcquiringViewState();
}

class _AcquiringViewState extends ConsumerState<_AcquiringView>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;
  late final AnimationController _countdownController;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Short loading window (~1.5s) to calibrate and lock GPS
    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _progress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _countdownController, curve: Curves.easeInOut),
    );

    _countdownController.forward().then((_) {
      if (mounted) {
        ref.read(trackingNotifierProvider.notifier).completeAcquisitionAndRun();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'GPS CALIBRATION',
                    style: AppTypography.badge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Concentric Glowing Radar / GPS Lock Target
            Stack(
              alignment: Alignment.center,
              children: [
                ScaleTransition(
                  scale: _pulse,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.06),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                ScaleTransition(
                  scale: _pulse,
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceElevated,
                    border: Border.all(color: AppColors.primary, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.gps_fixed_rounded,
                    color: AppColors.primary,
                    size: 36,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            const Text(
              'Acquiring GPS Signal',
              style: AppTypography.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),

            // Animated Countdown / Calibration Progress Bar
            AnimatedBuilder(
              animation: _progress,
              builder: (context, _) {
                final pct = (_progress.value * 100).toInt();
                return Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      child: SizedBox(
                        width: 200,
                        height: 6,
                        child: LinearProgressIndicator(
                          value: _progress.value,
                          backgroundColor: AppColors.surfaceBorder,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      pct < 100
                          ? 'Starting telemetry ($pct%)'
                          : 'Lock acquired! Launching...',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),

            Text(
              kIsWeb
                  ? 'Desktop browsers use Wi-Fi location (no satellite GPS)'
                  : 'Move outdoors for best accuracy',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),

            if (kIsWeb) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.fast_forward_rounded, size: 16, color: AppColors.primary),
                label: const Text(
                  'Simulate 5K Run (Instant Test)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: () => ref.read(trackingNotifierProvider.notifier).startDemoRun(),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            TextButton(
              onPressed: widget.onCancel ?? () {
                ref.read(trackingNotifierProvider.notifier).cancelAcquisition();
                if (context.canPop()) {
                  context.pop();
                }
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Live Run HUD (3-Tier Architecture) ─────────────────────────────────────────

class _RunningHud extends ConsumerStatefulWidget {
  final TrackingState state;
  const _RunningHud({required this.state});

  @override
  ConsumerState<_RunningHud> createState() => _RunningHudState();
}

class _RunningHudState extends ConsumerState<_RunningHud> {
  final PageController _pageController = PageController();
  int _currentCardIndex = 0;
  bool _showMap = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isPaused = state.status == TrackingStatus.paused;
    final distanceKm = state.distanceKm.toStringAsFixed(2);
    final movingDuration = GeoMath.formatDuration(
        state.movingSeconds > 0 ? state.movingSeconds : state.elapsedSeconds);
    final pace = GeoMath.formatPace(state.currentPaceSecondsPerKm);
    final accuracy = state.currentAccuracyMeters;

    // ── Strava Live Map Mode ──────────────────────────────────────────
    if (_showMap) {
      return Stack(
        children: [
          // Full-screen Strava route map
          Positioned.fill(
            child: StravaRunMap(
              breadcrumbs: state.breadcrumbs,
              currentLatitude: state.currentLatitude,
              currentLongitude: state.currentLongitude,
              isInteractive: true,
              showLivePuck: true,
            ),
          ),

          // Floating Top Stats Bar
          Positioned(
            top: AppSpacing.sm,
            left: AppSpacing.md,
            right: AppSpacing.md,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceBackground.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.surfaceBorderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MiniStat(label: 'KM', value: distanceKm),
                  Container(width: 1, height: 26, color: AppColors.surfaceBorder),
                  _MiniStat(label: 'PACE', value: pace),
                  Container(width: 1, height: 26, color: AppColors.surfaceBorder),
                  _MiniStat(label: 'TIME', value: movingDuration),
                  // Back to stats toggle
                  InkWell(
                    onTap: () => setState(() => _showMap = false),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bar_chart_rounded, size: 14, color: Colors.black),
                          SizedBox(width: 4),
                          Text(
                            'STATS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Bottom Controls
          Positioned(
            bottom: AppSpacing.lg,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceBackground.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(color: AppColors.surfaceBorderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CircleButton(
                    icon: isPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    color: AppColors.surfaceElevated,
                    iconColor: AppColors.primary,
                    size: 64,
                    onTap: isPaused
                        ? () => ref.read(trackingNotifierProvider.notifier).resumeRun()
                        : () => ref.read(trackingNotifierProvider.notifier).pauseRun(),
                  ),
                  _HoldToStopButton(
                    isPaused: isPaused,
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
                    onDiscard: () async {
                      await ref
                          .read(trackingNotifierProvider.notifier)
                          .discardCurrentRun();
                      if (context.mounted) {
                        context.go(Routes.home);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Run discarded'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // ── Primary Hero Metrics Mode ─────────────────────────────────────
    return Column(
      children: [
        // ── Top Bar: Quality & Badges ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // GPS Confidence Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                decoration: BoxDecoration(
                  color: state.gpsConfidence == 'High'
                      ? AppColors.primaryMuted
                      : AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                    color: state.gpsConfidence == 'High'
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : AppColors.warning.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: state.gpsConfidence == 'High'
                          ? AppColors.primary
                          : AppColors.warning,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      'GPS: ${state.gpsConfidence}',
                      style: AppTypography.caption.copyWith(
                        color: state.gpsConfidence == 'High'
                            ? AppColors.primary
                            : AppColors.warning,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              // Badges & Strava Map Switcher
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.isAutoPaused) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.pause_circle_filled_rounded,
                              color: AppColors.warning, size: 12),
                          const SizedBox(width: AppSpacing.xxs),
                          Text(
                            'AUTO-PAUSED',
                            style: AppTypography.badge.copyWith(
                              color: AppColors.warning,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ] else if (isPaused) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      child: Text(
                        'MANUAL PAUSE',
                        style: AppTypography.badge.copyWith(
                          color: AppColors.warning,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],

                  // Strava Segmented Mode Switcher (STATS / LIVE MAP)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HudModeTab(
                          label: 'STATS',
                          icon: Icons.bar_chart_rounded,
                          isSelected: !_showMap,
                          onTap: () => setState(() => _showMap = false),
                        ),
                        _HudModeTab(
                          label: 'MAP',
                          icon: Icons.map_rounded,
                          isSelected: _showMap,
                          onTap: () => setState(() => _showMap = true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Accuracy warning banner if weak
        if (accuracy != null && accuracy > 15)
          _AccuracyBanner(accuracyMeters: accuracy),

        if (state.errorMessage != null)
          _ErrorBanner(message: state.errorMessage!),

        const Spacer(),

        // ── TIER 1: Primary Hero Metrics ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              // Distance (Primary 72pt Hero)
              RepaintBoundary(
                child: Column(
                  children: [
                    Text(
                      distanceKm,
                      style: AppTypography.metricLarge.copyWith(fontSize: 72, height: 1.0),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
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
              const SizedBox(height: AppSpacing.md),

              // Secondary Row: Live Pace & Moving Time
              RepaintBoundary(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _MetricColumn(value: pace, label: 'PACE /KM'),
                    Container(width: 1, height: 38, color: AppColors.surfaceBorder),
                    _MetricColumn(value: movingDuration, label: 'MOVING TIME'),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xs),

        // ── LIVE ROUTE MINI-MAP PREVIEW (Strava Style) ────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
          child: InkWell(
            onTap: () => setState(() => _showMap = true),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.surfaceBorderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: StravaRunMap(
                        breadcrumbs: state.breadcrumbs,
                        currentLatitude: state.currentLatitude,
                        currentLongitude: state.currentLongitude,
                        isInteractive: false,
                        showLivePuck: false,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.route_rounded, color: AppColors.primary, size: 11),
                          SizedBox(width: 4),
                          Text(
                            'LIVE GPS ROUTE',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fullscreen_rounded, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'EXPAND MAP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const Spacer(),

        // ── TIER 2: Swipeable Horizon Cards ───────────────────────────────────
        SizedBox(
          height: 90,
          child: PageView(
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _currentCardIndex = idx),
            children: [
              // Card 1: Kinematics (Cadence & Steps)
              _SwipeCard(
                children: [
                  _SubMetric(
                    label: 'CADENCE',
                    value: '${state.currentCadenceSpm.round()} SPM',
                    subtitle: state.isStepBuffered ? '(buffered)' : null,
                  ),
                  _SubMetric(
                    label: 'EST. STEP',
                    value: state.estimatedStepLengthMeters > 0
                        ? '${state.estimatedStepLengthMeters.toStringAsFixed(2)} m'
                        : '--',
                  ),
                  _SubMetric(
                    label: 'STEPS',
                    value: '${state.totalSteps}',
                  ),
                ],
              ),

              // Card 2: Topography (Elevation & GAP)
              _SwipeCard(
                children: [
                  _SubMetric(
                    label: 'ELEV GAIN',
                    value: '+${state.elevationGainMeters.round()} m',
                  ),
                  _SubMetric(
                    label: 'GAP (MINETTI)',
                    value: state.currentGapSecondsPerKm > 0
                        ? GeoMath.formatPace(state.currentGapSecondsPerKm)
                        : '--:--',
                  ),
                  _SubMetric(
                    label: 'ALTITUDE',
                    value: state.currentAltitude != null
                        ? '${state.currentAltitude!.round()} m'
                        : '--',
                  ),
                ],
              ),

              // Card 3: Energy & Splits
              _SwipeCard(
                children: [
                  _SubMetric(
                    label: 'ENERGY (EST)',
                    value: '~${state.estimatedCalories.round()} kcal',
                  ),
                  _SubMetric(
                    label: 'AVG PACE',
                    value: GeoMath.formatPace(state.averagePaceSecondsPerKm),
                  ),
                  _SubMetric(
                    label: 'SPLITS',
                    value: '${state.splits.length} km',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),

        // Dots indicator for Swipeable Cards
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (idx) {
            final isSelected = idx == _currentCardIndex;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isSelected ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                color: isSelected
                    ? AppColors.primary
                    : AppColors.surfaceBorder,
              ),
            );
          }),
        ),

        const Spacer(),

        // ── Controls: Pause / Resume & Hold to Finish ─────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Pause / Resume Button
              _CircleButton(
                icon: isPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                color: AppColors.surfaceElevated,
                iconColor: AppColors.primary,
                size: 64,
                onTap: isPaused
                    ? () => ref.read(trackingNotifierProvider.notifier).resumeRun()
                    : () => ref.read(trackingNotifierProvider.notifier).pauseRun(),
              ),

              // Hold-to-stop / Finish Button
              _HoldToStopButton(
                isPaused: isPaused,
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
                onDiscard: () async {
                  await ref
                      .read(trackingNotifierProvider.notifier)
                      .discardCurrentRun();
                  if (context.mounted) {
                    context.go(Routes.home);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Run discarded'),
                        duration: Duration(seconds: 2),
                      ),
                    );
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

class _SwipeCard extends StatelessWidget {
  final List<Widget> children;
  const _SwipeCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.surfaceBase,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: children,
        ),
      ),
    );
  }
}

class _SubMetric extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  const _SubMetric({required this.label, required this.value, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: const TextStyle(fontSize: 9, color: AppColors.warning),
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
        Text(label, style: AppTypography.caption.copyWith(letterSpacing: 1)),
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

/// Hold-to-stop or Tap-to-Finish button.
/// When paused: single tap immediately completes and saves the run.
/// When active: hold for 1.2s to stop, or single tap opens quick finish modal.
class _HoldToStopButton extends StatefulWidget {
  final bool isPaused;
  final VoidCallback onStopped;
  final VoidCallback? onDiscard;

  const _HoldToStopButton({
    required this.isPaused,
    required this.onStopped,
    this.onDiscard,
  });

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
      duration: const Duration(milliseconds: 1200),
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

  void _showFinishConfirmationDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Finish Run?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Save your route, cadence, and splits to your activity feed.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                widget.onStopped();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
              child: const Text(
                'FINISH & SAVE RUN',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.surfaceBorder),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
              child: const Text(
                'RESUME RUN',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _showDiscardConfirmationDialog(context);
              },
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
              label: const Text(
                'DISCARD RUN',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ),
      ),
    );
  }

  void _showDiscardConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        title: const Text(
          'Discard Run?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'Are you sure you want to discard this run? All telemetry and GPS route data for this session will be permanently deleted.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text(
              'KEEP RUNNING',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              widget.onDiscard?.call();
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
    if (widget.isPaused) {
      return BouncyPressable(
        onTap: () => _showFinishConfirmationDialog(context),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.danger,
            boxShadow: [
              BoxShadow(
                color: AppColors.danger.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.stop_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showFinishConfirmationDialog(context),
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

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
      ],
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
            'Weak signal (±${accuracyMeters.toStringAsFixed(0)}m) — tall buildings nearby',
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

class _InterruptedRunCard extends StatelessWidget {
  final Map<String, dynamic> runData;
  final VoidCallback onResume;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  const _InterruptedRunCard({
    required this.runData,
    required this.onResume,
    required this.onSave,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final distKm = ((runData['distance_meters'] as num?)?.toDouble() ?? 0.0) / 1000.0;
    final movingSec = ((runData['moving_ms'] as int?) ?? 0) ~/ 1000;

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_toggle_off_rounded, color: AppColors.warning, size: 20),
              const SizedBox(width: AppSpacing.xs),
              const Expanded(
                child: Text(
                  'Interrupted Run Detected',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textTertiary, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Discard',
                onPressed: onDiscard,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${distKm.toStringAsFixed(2)} km · ${GeoMath.formatDuration(movingSec)} · Preserved in SQLite',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: onResume,
                  child: const Text('RESUME RUN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: onSave,
                  child: const Text('FINISH & SAVE', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 11)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HudModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _HudModeTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.black : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isSelected ? Colors.black : AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

