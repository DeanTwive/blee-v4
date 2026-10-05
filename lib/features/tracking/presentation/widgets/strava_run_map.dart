import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/run_summary_entity.dart';

/// Strava-style Dark Mode Route Map for live tracking and post-run summaries.
class StravaRunMap extends StatefulWidget {
  final List<BreadcrumbPoint> breadcrumbs;
  final double? currentLatitude;
  final double? currentLongitude;
  final bool isInteractive;
  final bool showLivePuck;
  final Color? routeColor;
  final VoidCallback? onRecenter;

  const StravaRunMap({
    super.key,
    required this.breadcrumbs,
    this.currentLatitude,
    this.currentLongitude,
    this.isInteractive = true,
    this.showLivePuck = true,
    this.routeColor,
    this.onRecenter,
  });

  @override
  State<StravaRunMap> createState() => _StravaRunMapState();
}

class _StravaRunMapState extends State<StravaRunMap> with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _pulseController;

  // Default fallback location (Manila / Bonifacio Global City running track)
  static const LatLng _defaultCenter = LatLng(14.5507, 121.0494);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.showLivePuck) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(StravaRunMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When live tracking, follow the runner smoothly
    if (widget.showLivePuck && widget.currentLatitude != null && widget.currentLongitude != null) {
      if (widget.currentLatitude != oldWidget.currentLatitude ||
          widget.currentLongitude != oldWidget.currentLongitude) {
        try {
          _mapController.move(
            LatLng(widget.currentLatitude!, widget.currentLongitude!),
            _mapController.camera.zoom,
          );
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  LatLng get _currentCenter {
    if (widget.currentLatitude != null && widget.currentLongitude != null) {
      return LatLng(widget.currentLatitude!, widget.currentLongitude!);
    }
    if (widget.breadcrumbs.isNotEmpty) {
      final valid = widget.breadcrumbs.where((p) => !p.isRejected).toList();
      if (valid.isNotEmpty) {
        final last = valid.last;
        return LatLng(last.latitude, last.longitude);
      }
    }
    return _defaultCenter;
  }

  List<LatLng> get _polylinePoints {
    return widget.breadcrumbs
        .where((p) => !p.isRejected)
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
  }

  void _recenter() {
    final center = _currentCenter;
    _mapController.move(center, 16.5);
    widget.onRecenter?.call();
  }

  void _fitRoute() {
    final points = _polylinePoints;
    if (points.length >= 2) {
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(40),
        ),
      );
    } else {
      _recenter();
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = _polylinePoints;
    final currentPos = _currentCenter;
    final hasRoute = points.length >= 2;
    final effectiveColor = widget.routeColor ?? AppColors.primary;
    final LatLngBounds? bounds = hasRoute ? LatLngBounds.fromPoints(points) : null;

    return Stack(
      children: [
        // ── Map Canvas ─────────────────────────────────────────────────────────
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: currentPos,
            initialZoom: hasRoute ? 16.0 : 15.0,
            initialCameraFit: (!widget.showLivePuck && bounds != null)
                ? CameraFit.bounds(
                    bounds: bounds,
                    padding: const EdgeInsets.all(36),
                  )
                : null,
            interactionOptions: InteractionOptions(
              flags: widget.isInteractive ? InteractiveFlag.all : InteractiveFlag.none,
            ),
          ),
          children: [
            // Dark Mode Basemap (Clean OpenStreetMap tiles inverted to sleek dark theme, no watermarks)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.blee.blee',
              maxZoom: 19,
              tileBuilder: (context, tileWidget, tile) {
                return ColorFiltered(
                  colorFilter: const ColorFilter.matrix(<double>[
                    -0.22, 0, 0, 0, 68,
                    0, -0.22, 0, 0, 68,
                    0, 0, -0.22, 0, 82,
                    0, 0, 0, 1, 0,
                  ]),
                  child: tileWidget,
                );
              },
            ),

            // Live Route Polyline (Strava 3-Tier Athletic Glow)
            if (hasRoute) ...[
              // 1. Wide outer ambient halo
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    strokeWidth: 10.0,
                    color: effectiveColor.withValues(alpha: 0.28),
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ],
              ),
              // 2. High-intensity inner neon aura
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    strokeWidth: 6.5,
                    color: effectiveColor.withValues(alpha: 0.65),
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ],
              ),
              // 3. Ultra-sharp solid core polyline
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    strokeWidth: 4.0,
                    color: effectiveColor,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ],
              ),
            ],

            // Map Markers: Start Flag, Finish Flag & Live Pulsing Puck
            MarkerLayer(
              markers: [
                // 1. Start Marker (Green Flag/Dot)
                if (hasRoute)
                  Marker(
                    point: points.first,
                    width: 32,
                    height: 32,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 18,
                        ),
                      ),
                    ),
                  ),

                // 2. Finish Marker (Shown when stopped/summary, placed at points.last)
                if (!widget.showLivePuck && hasRoute && points.length > 2)
                  Marker(
                    point: points.last,
                    width: 32,
                    height: 32,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3366),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF3366).withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.flag_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),

                // 3. Current Location Live Pulsing Puck (when running)
                if (widget.showLivePuck)
                  Marker(
                    point: currentPos,
                    width: 44,
                    height: 44,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final pulseScale = 1.0 + (_pulseController.value * 0.35);
                        final pulseAlpha = 0.5 * (1.0 - _pulseController.value);
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer pulsing aura
                            Transform.scale(
                              scale: pulseScale,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: effectiveColor.withValues(alpha: pulseAlpha),
                                ),
                              ),
                            ),
                            // Inner high-visibility runner puck
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: effectiveColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),

        // ── Map Vignette Subtle Gradients ──────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 50,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 50,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Floating Action Buttons (Recenter & Fit Route) ─────────────────────
        if (widget.isInteractive)
          Positioned(
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasRoute) ...[
                  _MapActionButton(
                    icon: Icons.fit_screen_rounded,
                    tooltip: 'Fit Route',
                    onTap: _fitRoute,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                _MapActionButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Recenter',
                  onTap: _recenter,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MapActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MapActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated.withValues(alpha: 0.92),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surfaceBorderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
