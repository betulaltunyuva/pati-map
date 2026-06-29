import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Görünürlük takibi: [VisibilityDetector] (viewport kesişimi ≈ Intersection Observer).
///
/// Flutter Web varsayılan olarak CanvasKit kullandığından DOM `.reveal` sınıfı yok;
/// geçiş süresi ve easing [web/scroll_reveal.css] ile aynı mantıkta tutulur.
class ScrollReveal extends StatefulWidget {
  const ScrollReveal({
    super.key,
    required this.detectKey,
    required this.child,
    this.visibleFractionThreshold = 0.05,
  });

  /// [VisibilityDetector] için benzersiz anahtar (ör. `ValueKey('dashboard_stats')`).
  final Key detectKey;
  final Widget child;

  /// Bu kesitten büyükse animasyon tetiklenir (bir kez).
  final double visibleFractionThreshold;

  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<ScrollReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curved;
  bool _triggered = false;

  static const Duration _duration = Duration(milliseconds: 600);
  static const double _dy = 24;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    _curved = CurvedAnimation(parent: _controller, curve: Curves.ease);
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onVisibility(VisibilityInfo info) {
    if (_triggered) return;
    if (info.visibleFraction > widget.visibleFractionThreshold) {
      _triggered = true;
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: widget.detectKey,
      onVisibilityChanged: _onVisibility,
      child: AnimatedBuilder(
        animation: _curved,
        builder: (context, child) {
          final v = _curved.value;
          return Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, _dy * (1 - v)),
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Uygulama açılışında [VisibilityDetector] güncelleme aralığını sınırla (performans).
void configureScrollRevealForPanel() {
  VisibilityDetectorController.instance.updateInterval =
      const Duration(milliseconds: 120);
}
