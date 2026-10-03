import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Elite micro-interaction widget: delivers tactile physical spring compression
/// and subtle haptics on press down, elevating UI feel to Apple/Nike standards.
class BouncyPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double shrinkScale;
  final Duration duration;
  final bool enableHaptics;

  const BouncyPressable({
    super.key,
    required this.child,
    this.onTap,
    this.shrinkScale = 0.96,
    this.duration = const Duration(milliseconds: 140),
    this.enableHaptics = true,
  });

  @override
  State<BouncyPressable> createState() => _BouncyPressableState();
}

class _BouncyPressableState extends State<BouncyPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: widget.duration,
      value: 1.0,
      lowerBound: widget.shrinkScale,
      upperBound: 1.0,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInQuad,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap == null) return;
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    _controller.reverse();
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap == null) return;
    _controller.forward();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    if (widget.onTap == null) return;
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
