import 'dart:async';
import '../../../core/utils/crash_reporter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../tracking/domain/run_summary_entity.dart';
import '../data/cloudflare_r2_repository.dart';

// ── State ──────────────────────────────────────────────────────────────────────

class RunReceiptState {
  final bool isSharing;
  final String? errorMessage;
  final int? lastExportDurationMs;

  const RunReceiptState({
    this.isSharing = false,
    this.errorMessage,
    this.lastExportDurationMs,
  });

  RunReceiptState copyWith({
    bool? isSharing,
    String? errorMessage,
    int? lastExportDurationMs,
  }) {
    return RunReceiptState(
      isSharing: isSharing ?? this.isSharing,
      errorMessage: errorMessage,
      lastExportDurationMs: lastExportDurationMs ?? this.lastExportDurationMs,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────────

class RunReceiptNotifier extends Notifier<RunReceiptState> {
  final _screenshotController = ScreenshotController();
  ScreenshotController get screenshotController => _screenshotController;

  ICloudflareR2Repository get _r2Repo => ref.read(cloudflareR2RepositoryProvider);

  @override
  RunReceiptState build() => const RunReceiptState();

  /// Captures the receipt widget as PNG and shares it via native share sheet.
  /// Also triggers an asynchronous, non-blocking upload to Cloudflare R2 / Supabase Storage.
  Future<void> shareReceipt(RunSummaryEntity summary) async {
    state = state.copyWith(isSharing: true, errorMessage: null);
    final stopwatch = Stopwatch()..start();

    try {
      final Uint8List? imageBytes =
          await _screenshotController.capture(pixelRatio: 3.0);
      stopwatch.stop();

      final elapsedMs = stopwatch.elapsedMilliseconds;
      if (kDebugMode && elapsedMs > 400) {
        debugPrint('[RunReceipt] Export took ${elapsedMs}ms (> 400ms target)');
      }

      if (imageBytes == null) {
        throw Exception('Screenshot capture returned null');
      }

      state = state.copyWith(lastExportDurationMs: elapsedMs);

      // Trigger asynchronous, non-blocking upload to Cloudflare R2 / storage
      final userId = ref.read(authStateProvider).value?.id ?? 'anonymous';
      unawaited(
        _r2Repo.uploadReceiptImage(
          userId: userId,
          runId: summary.runId,
          imageBytes: imageBytes,
        ),
      );

      final xFile = XFile.fromData(
        imageBytes,
        name: 'blee_run_${summary.runId.substring(0, 8)}.png',
        mimeType: 'image/png',
      );

      final profile = ref.read(currentProfileProvider).value;
      final name = profile?.displayName ?? 'a Blee Runner';
      final distanceKm = summary.distanceKm.toStringAsFixed(2);

      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: '🐝 $name just ran ${distanceKm}km in BGC, Manila — powered by Blee. '
              'Identity > Telemetry. blee.app',
        ),
      );

      state = state.copyWith(isSharing: false);
    } catch (e, st) {
      AppCrashReporter.recordError(e, st, reason: 'shareReceipt');
      state = state.copyWith(
        isSharing: false,
        errorMessage: 'Failed to share. Please try again.',
      );
    }
  }
}

final runReceiptNotifierProvider =
    NotifierProvider<RunReceiptNotifier, RunReceiptState>(RunReceiptNotifier.new);
