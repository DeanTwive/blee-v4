import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../../tracking/domain/run_summary_entity.dart';

/// Normalized 2D vector coordinates for drawing route silhouettes on canvas.
class NormalizedRoute {
  final List<Offset> points;
  final Rect bounds;
  final double width;
  final double height;

  const NormalizedRoute({
    required this.points,
    required this.bounds,
    required this.width,
    required this.height,
  });

  bool get isEmpty => points.isEmpty;
  bool get hasPath => points.length >= 2;
}

/// Service for generating run receipt vector assets and measuring export performance.
class ReceiptGeneratorService {
  /// Normalizes geographic breadcrumbs into 2D canvas coordinates fitting [width] x [height].
  /// Preserves the real-world aspect ratio of the runner's path.
  static NormalizedRoute normalizeRoute(
    List<BreadcrumbPoint> breadcrumbs, {
    double width = 300.0,
    double height = 160.0,
    double padding = 20.0,
  }) {
    if (breadcrumbs.isEmpty) {
      return NormalizedRoute(
        points: const [],
        bounds: Rect.fromLTWH(0, 0, width, height),
        width: width,
        height: height,
      );
    }

    if (breadcrumbs.length == 1) {
      final center = Offset(width / 2, height / 2);
      return NormalizedRoute(
        points: [center],
        bounds: Rect.fromLTWH(0, 0, width, height),
        width: width,
        height: height,
      );
    }

    double minLat = breadcrumbs.first.latitude;
    double maxLat = breadcrumbs.first.latitude;
    double minLng = breadcrumbs.first.longitude;
    double maxLng = breadcrumbs.first.longitude;

    for (final p in breadcrumbs) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final dLat = maxLat - minLat;
    final dLng = maxLng - minLng;

    final availableWidth = width - (padding * 2);
    final availableHeight = height - (padding * 2);

    if (dLat == 0 && dLng == 0) {
      final center = Offset(width / 2, height / 2);
      return NormalizedRoute(
        points: List.filled(breadcrumbs.length, center),
        bounds: Rect.fromLTWH(0, 0, width, height),
        width: width,
        height: height,
      );
    }

    // Latitude maps to Y (inverted: higher latitude = top = smaller Y)
    // Longitude maps to X (higher longitude = right = larger X)
    // Scale while preserving aspect ratio
    final scaleX = dLng > 0 ? availableWidth / dLng : double.infinity;
    final scaleY = dLat > 0 ? availableHeight / dLat : double.infinity;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final contentWidth = dLng * scale;
    final contentHeight = dLat * scale;
    final offsetX = padding + (availableWidth - contentWidth) / 2;
    final offsetY = padding + (availableHeight - contentHeight) / 2;

    final normalizedPoints = <Offset>[];
    for (final p in breadcrumbs) {
      final x = offsetX + (p.longitude - minLng) * scale;
      final y = offsetY + (maxLat - p.latitude) * scale; // invert Y
      normalizedPoints.add(Offset(x, y));
    }

    return NormalizedRoute(
      points: normalizedPoints,
      bounds: Rect.fromLTWH(0, 0, width, height),
      width: width,
      height: height,
    );
  }

  /// Offloads route normalization to a background isolate for datasets with many points.
  static Future<NormalizedRoute> normalizeRouteAsync(
    List<BreadcrumbPoint> breadcrumbs, {
    double width = 300.0,
    double height = 160.0,
    double padding = 20.0,
  }) async {
    if (breadcrumbs.length < 50) {
      return normalizeRoute(
        breadcrumbs,
        width: width,
        height: height,
        padding: padding,
      );
    }

    return compute(_normalizeRouteEntry, {
      'points': breadcrumbs,
      'width': width,
      'height': height,
      'padding': padding,
    });
  }

  static NormalizedRoute _normalizeRouteEntry(Map<String, dynamic> params) {
    final points = params['points'] as List<BreadcrumbPoint>;
    final width = params['width'] as double;
    final height = params['height'] as double;
    final padding = params['padding'] as double;
    return normalizeRoute(points, width: width, height: height, padding: padding);
  }
}
