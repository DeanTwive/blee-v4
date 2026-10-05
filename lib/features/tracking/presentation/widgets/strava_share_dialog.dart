import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/geo_math.dart';
import '../../../../core/utils/local_file_saver.dart';
import '../../domain/run_summary_entity.dart';
import 'strava_run_map.dart';

enum ShareOverlayStyle { minimalSticker, lowerBanner, gradientCard }
enum ShareBackgroundSource { photo, routeMap, darkMinimal }

/// Strava-style Graphic Share Studio Dialog.
/// Allows athletes to composite their running metrics (as a floating PNG sticker/overlay)
/// on top of their activity photo, route map, or dark theme canvas.
class StravaShareDialog extends StatefulWidget {
  final RunSummaryEntity run;
  final String runnerName;
  final Uint8List? initialImageBytes;

  const StravaShareDialog({
    super.key,
    required this.run,
    required this.runnerName,
    this.initialImageBytes,
  });

  static Future<void> show(
    BuildContext context, {
    required RunSummaryEntity run,
    required String runnerName,
    Uint8List? initialImageBytes,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => StravaShareDialog(
        run: run,
        runnerName: runnerName,
        initialImageBytes: initialImageBytes ?? run.imageBytes,
      ),
    );
  }

  @override
  State<StravaShareDialog> createState() => _StravaShareDialogState();
}

class _StravaShareDialogState extends State<StravaShareDialog> {
  final ScreenshotController _screenshotController = ScreenshotController();
  final ImagePicker _picker = ImagePicker();

  late ShareBackgroundSource _bgSource;
  ShareOverlayStyle _overlayStyle = ShareOverlayStyle.minimalSticker;
  Uint8List? _customPhotoBytes;
  bool _isSavingLocal = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _customPhotoBytes = widget.initialImageBytes ?? widget.run.imageBytes;
    _bgSource = _customPhotoBytes != null
        ? ShareBackgroundSource.photo
        : ShareBackgroundSource.routeMap;
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
          _customPhotoBytes = bytes;
          _bgSource = ShareBackgroundSource.photo;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load image: $e')),
        );
      }
    }
  }

  Future<void> _saveToLocal() async {
    setState(() => _isSavingLocal = true);
    try {
      final Uint8List? imageBytes = await _screenshotController.capture(
        pixelRatio: 3.0,
      );

      if (imageBytes == null) {
        throw Exception('Failed to generate image capture.');
      }

      final fileName = 'blee_run_${widget.run.runId.substring(0, 8)}.png';
      final result = await saveImageBytesLocally(
        bytes: imageBytes,
        fileName: fileName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceElevated,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              side: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    kIsWeb ? 'Graphic downloaded to your device!' : 'Saved to: $result',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceElevated,
            content: Text('Failed to save image: $e', style: const TextStyle(color: AppColors.danger)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingLocal = false);
      }
    }
  }

  Future<void> _exportAndShare() async {
    setState(() => _isExporting = true);
    try {
      final Uint8List? imageBytes = await _screenshotController.capture(
        pixelRatio: 3.0,
      );

      if (imageBytes == null) {
        throw Exception('Failed to generate image capture.');
      }

      final run = widget.run;
      final distStr = run.distanceKm > 0.01 ? '${run.distanceKm.toStringAsFixed(2)} km' : '0.00 km';
      final paceStr = run.distanceKm > 0.01 ? '${GeoMath.formatPace(run.avgPaceSecondsPerKm)} /km' : '--:--';
      final timeStr = GeoMath.formatDuration(run.durationSeconds);

      final shareText = '🏃 ${run.displayTitle} with Blee!\n'
          '📏 $distStr · ⏱ $timeStr · ⚡ $paceStr\n'
          '🐝 The Running Community That Moves You. blee.app';

      final xFile = XFile.fromData(
        imageBytes,
        name: 'blee_${run.runId.substring(0, 8)}.png',
        mimeType: 'image/png',
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: shareText,
        ),
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: AppColors.surfaceBackground,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Dialog Header ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: const Text(
                          'BLEE SHARE',
                          style: TextStyle(
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Text(
                        'Share Graphic',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.surfaceBorder, height: 1),

            // ── Scrollable Studio Controls & Canvas ───────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    // The Capture Canvas (Aspect Ratio 1:1 Square)
                    Screenshot(
                      controller: _screenshotController,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // 1. Background Layer (Photo, Map, or Dark Canvas)
                              _buildBackgroundLayer(),

                              // 2. Stats Overlay Sticker (Placed ABOVE the image)
                              _buildStatsOverlay(),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // ── Background Selector Controls ──────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _FilterChipButton(
                            icon: Icons.photo_library_rounded,
                            label: 'Photo',
                            isSelected: _bgSource == ShareBackgroundSource.photo,
                            onTap: () {
                              if (_customPhotoBytes == null) {
                                _pickPhoto(ImageSource.gallery);
                              } else {
                                setState(() => _bgSource = ShareBackgroundSource.photo);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: _FilterChipButton(
                            icon: Icons.map_rounded,
                            label: 'Map',
                            isSelected: _bgSource == ShareBackgroundSource.routeMap,
                            onTap: () => setState(() => _bgSource = ShareBackgroundSource.routeMap),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: _FilterChipButton(
                            icon: Icons.dark_mode_rounded,
                            label: 'Dark',
                            isSelected: _bgSource == ShareBackgroundSource.darkMinimal,
                            onTap: () => setState(() => _bgSource = ShareBackgroundSource.darkMinimal),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xs),

                    // Photo Action Strip (if photo mode active)
                    if (_bgSource == ShareBackgroundSource.photo) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                            label: Text(_customPhotoBytes != null ? 'Change Photo' : 'Select Photo'),
                            onPressed: () => _pickPhoto(ImageSource.gallery),
                          ),
                          if (!kIsWeb) ...[
                            const SizedBox(width: 8),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.camera_alt_rounded, size: 16),
                              label: const Text('Camera'),
                              onPressed: () => _pickPhoto(ImageSource.camera),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],

                    // ── Overlay Style Presets ─────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _OverlayStyleTab(
                            title: 'Sticker',
                            isSelected: _overlayStyle == ShareOverlayStyle.minimalSticker,
                            onTap: () => setState(() => _overlayStyle = ShareOverlayStyle.minimalSticker),
                          ),
                          _OverlayStyleTab(
                            title: 'Banner',
                            isSelected: _overlayStyle == ShareOverlayStyle.lowerBanner,
                            onTap: () => setState(() => _overlayStyle = ShareOverlayStyle.lowerBanner),
                          ),
                          _OverlayStyleTab(
                            title: 'Card',
                            isSelected: _overlayStyle == ShareOverlayStyle.gradientCard,
                            onTap: () => setState(() => _overlayStyle = ShareOverlayStyle.gradientCard),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Dialog Bottom Actions (Save Image to Local & Share) ───────────
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  // 1. SAVE TO LOCAL (Prominent Primary Action)
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                        elevation: 3,
                      ),
                      icon: _isSavingLocal
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                            )
                          : const Icon(Icons.download_rounded, size: 20),
                      label: Text(
                        _isSavingLocal ? 'SAVING...' : 'SAVE IMAGE',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8),
                      ),
                      onPressed: (_isSavingLocal || _isExporting) ? null : _saveToLocal,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // 2. SHARE VIA SYSTEM SHEET
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        backgroundColor: AppColors.surfaceElevated,
                        side: const BorderSide(color: AppColors.surfaceBorderLight),
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          : const Icon(Icons.share_rounded, size: 18),
                      label: Text(
                        _isExporting ? 'SHARING...' : 'SHARE',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
                      ),
                      onPressed: (_isSavingLocal || _isExporting) ? null : _exportAndShare,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Background Layer Builder ────────────────────────────────────────────────
  Widget _buildBackgroundLayer() {
    switch (_bgSource) {
      case ShareBackgroundSource.photo:
        if (_customPhotoBytes != null) {
          return Image.memory(
            _customPhotoBytes!,
            fit: BoxFit.cover,
          );
        }
        return Container(
          color: const Color(0xFF1E232E),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 40),
                const SizedBox(height: 8),
                Text(
                  'Tap below to select photo',
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        );

      case ShareBackgroundSource.routeMap:
        return StravaRunMap(
          breadcrumbs: widget.run.effectiveBreadcrumbs,
          isInteractive: false,
          showLivePuck: false,
          routeColor: AppColors.primary,
        );

      case ShareBackgroundSource.darkMinimal:
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1B202B), Color(0xFF0F1218)],
            ),
          ),
        );
    }
  }

  // ── Stats Overlay Sticker Builder (Above the image) ──────────────────────────
  Widget _buildStatsOverlay() {
    final run = widget.run;
    final hasValidDistance = run.distanceKm > 0.01;
    final distStr = hasValidDistance ? run.distanceKm.toStringAsFixed(2) : '0.00';
    final paceStr = hasValidDistance ? GeoMath.formatPace(run.avgPaceSecondsPerKm) : '--:--';
    final timeStr = GeoMath.formatDuration(run.durationSeconds);
    final title = run.displayTitle;
    const effectiveAccent = AppColors.primary;

    switch (_overlayStyle) {
      // 1. Strava Minimal Transparent Sticker (Floating directly on image/map)
      case ShareOverlayStyle.minimalSticker:
        return Stack(
          children: [
            // Vignette gradient for high-contrast legibility over maps and photos
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  stops: const [0.0, 0.40, 1.0],
                ),
              ),
            ),

            // Top Header: Blee Badge & Runner Pill
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: effectiveAccent,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      boxShadow: [
                        BoxShadow(
                          color: effectiveAccent.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      '🐝 BLEE',
                      style: TextStyle(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      border: Border.all(color: Colors.white24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_run_rounded, color: effectiveAccent, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          widget.runnerName.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Floating Stats (Clean Strava Typography with drop shadows)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 10, offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _StickerMetric(value: distStr, unit: 'km', label: 'DISTANCE', highlightColor: effectiveAccent, fontSize: 18)),
                      Expanded(child: _StickerMetric(value: paceStr, unit: hasValidDistance ? '/km' : '', label: 'PACE', highlightColor: effectiveAccent, fontSize: 18)),
                      Expanded(child: _StickerMetric(value: timeStr, unit: '', label: 'TIME', highlightColor: effectiveAccent, fontSize: 18)),
                      if (run.elevationGainMeters > 0)
                        Expanded(child: _StickerMetric(value: '+${run.elevationGainMeters.round()}', unit: 'm', label: 'ELEV', highlightColor: effectiveAccent, fontSize: 18)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );

      // 2. Lower Frosted Glass Banner Overlay
      case ShareOverlayStyle.lowerBanner:
        return Stack(
          children: [
            // Top Left Blee Logo & Athlete Pill
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: effectiveAccent,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: const Text(
                      '🐝 BLEE',
                      style: TextStyle(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_run_rounded, size: 12, color: effectiveAccent),
                        const SizedBox(width: 4),
                        Text(
                          widget.runnerName.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Frosted Card Banner
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F131C).withValues(alpha: 0.88),
                      border: Border(
                        top: BorderSide(color: effectiveAccent.withValues(alpha: 0.6), width: 2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _StickerMetric(value: distStr, unit: 'km', label: 'DISTANCE', highlightColor: effectiveAccent, fontSize: 17)),
                            Container(width: 1, height: 28, color: Colors.white24),
                            Expanded(child: _StickerMetric(value: paceStr, unit: hasValidDistance ? '/km' : '', label: 'AVG PACE', highlightColor: effectiveAccent, fontSize: 17)),
                            Container(width: 1, height: 28, color: Colors.white24),
                            Expanded(child: _StickerMetric(value: timeStr, unit: '', label: 'DURATION', highlightColor: effectiveAccent, fontSize: 17)),
                            if (run.elevationGainMeters > 0) ...[
                              Container(width: 1, height: 28, color: Colors.white24),
                              Expanded(child: _StickerMetric(value: '+${run.elevationGainMeters.round()}', unit: 'm', label: 'ELEV', highlightColor: effectiveAccent, fontSize: 17)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );

      // 3. Floating Modern Card Overlay
      case ShareOverlayStyle.gradientCard:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F131C).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(color: effectiveAccent.withValues(alpha: 0.45), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.65),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('🐝', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Text(
                                'BLEE TRACKER',
                                style: TextStyle(
                                  color: effectiveAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.directions_run_rounded, size: 12, color: effectiveAccent),
                                const SizedBox(width: 4),
                                Text(
                                  widget.runnerName.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 1.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              effectiveAccent.withValues(alpha: 0.6),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _StickerMetric(value: distStr, unit: 'km', label: 'DISTANCE', highlightColor: effectiveAccent, fontSize: 18)),
                          Expanded(child: _StickerMetric(value: paceStr, unit: hasValidDistance ? '/km' : '', label: 'PACE', highlightColor: effectiveAccent, fontSize: 18)),
                          Expanded(child: _StickerMetric(value: timeStr, unit: '', label: 'TIME', highlightColor: effectiveAccent, fontSize: 18)),
                          if (run.elevationGainMeters > 0)
                            Expanded(child: _StickerMetric(value: '+${run.elevationGainMeters.round()}', unit: 'm', label: 'ELEV', highlightColor: effectiveAccent, fontSize: 18)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
    }
  }
}

class _StickerMetric extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  final Color? highlightColor;
  final double fontSize;

  const _StickerMetric({
    required this.value,
    required this.unit,
    required this.label,
    this.highlightColor,
    this.fontSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final accent = highlightColor ?? AppColors.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  shadows: const [
                    Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 2)),
                  ],
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: TextStyle(
                    color: accent,
                    fontSize: (fontSize * 0.58).clamp(10.0, 14.0),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}


class _FilterChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayStyleTab extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _OverlayStyleTab({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textTertiary,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
