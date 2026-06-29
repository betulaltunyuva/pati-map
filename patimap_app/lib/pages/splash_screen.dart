import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../routes/app_routes.dart';

/// Harita dekoru + çift dalga; logo `patimaplogoseffaf.png`, yuvarlak blur glow, ızgara yok.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 6), _goNext);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  static const Color _ink = Color(0xFF1C1C1E);
  static const Color _brand = Color(0xFF2F6FE4);
  /// Açık gri-mavi (iOS secondary benzeri, slogan).
  static const Color _muted = Color(0xFF8A96A8);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Görsel 1 ile aynı ölçü
    final logoSize = size.width * 0.35;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFF5F7FA),
                    Color(0xFFEAF1FF),
                  ],
                ),
              ),
            ),
            const _RouteDecorations(),
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TransparentLogoWithGlow(
                      size: logoSize,
                      child: Image.asset(
                        AppAssets.splashLogoTransparentPng,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    const SizedBox(height: 26),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.85,
                          height: 1.12,
                          fontFamily: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.fontFamily,
                        ),
                        children: const [
                          TextSpan(
                            text: 'Pati',
                            style: TextStyle(color: _ink),
                          ),
                          TextSpan(
                            text: 'Map',
                            style: TextStyle(color: _brand),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Evcil dostların için\nharita ve topluluk',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _muted,
                        fontSize: 13.5,
                        height: 1.58,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.12,
                        fontFamily:
                            Theme.of(context).textTheme.bodyMedium?.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: _DoubleBottomWave(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yuvarlak, yumuşak glow — `BoxShadow` dikdörtgeni yok; blur + radial gradient.
class _TransparentLogoWithGlow extends StatelessWidget {
  const _TransparentLogoWithGlow({
    required this.size,
    required this.child,
  });

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final glowDiameter = size * 0.92;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              width: glowDiameter,
              height: glowDiameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF5B8DEF).withValues(alpha: 0.22),
                    const Color(0xFF2F6FE4).withValues(alpha: 0.10),
                    const Color(0xFF2F6FE4).withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.42, 1.0],
                ),
              ),
            ),
          ),
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: size * 0.42,
              height: size * 0.42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF14253D).withValues(alpha: 0.05),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _RouteDecorations extends StatelessWidget {
  const _RouteDecorations();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return IgnorePointer(
          child: Stack(
            children: [
              _pin(Offset(w * 0.11, h * 0.19), w * 0.085),
              _pin(Offset(w * 0.78, h * 0.27), w * 0.072),
              _pin(Offset(w * 0.74, h * 0.76), w * 0.062),
              _paw(Offset(w * 0.14, h * 0.72), w * 0.055),
              _paw(Offset(w * 0.84, h * 0.62), w * 0.048),
              _paw(Offset(w * 0.86, h * 0.16), w * 0.042),
              _dashedRoute(
                top: h * 0.36,
                left: w * 0.14,
                right: w * 0.18,
              ),
              _dashedRoute(
                top: h * 0.68,
                left: w * 0.18,
                right: w * 0.20,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dashedRoute({
    required double top,
    required double left,
    required double right,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: Container(
        height: 2,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF2F6FE4).withValues(alpha: 0.0),
              const Color(0xFF2F6FE4).withValues(alpha: 0.17),
              const Color(0xFF2F6FE4).withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pin(Offset offset, double iconSize) {
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: Icon(
        Icons.location_on_rounded,
        size: iconSize.clamp(22, 36),
        color: const Color(0xFF2F6FE4).withValues(alpha: 0.48),
      ),
    );
  }

  Widget _paw(Offset offset, double iconSize) {
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: Icon(
        Icons.pets_rounded,
        size: iconSize.clamp(16, 26),
        color: const Color(0xFF2F6FE4).withValues(alpha: 0.17),
      ),
    );
  }
}

class _DoubleBottomWave extends StatelessWidget {
  const _DoubleBottomWave();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      width: double.infinity,
      child: CustomPaint(
        painter: _DoubleWavePainter(),
      ),
    );
  }
}

class _DoubleWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final waveBack = Paint()..color = const Color(0xFFDFEAFE);
    final waveFront = Paint()
      ..color = const Color(0xFF2F6FE4).withValues(alpha: 0.82);

    final back = Path()
      ..moveTo(0, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.2,
        size.height * 0.35,
        size.width * 0.42,
        size.height * 0.56,
      )
      ..quadraticBezierTo(
        size.width * 0.73,
        size.height * 0.78,
        size.width,
        size.height * 0.52,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(back, waveBack);

    final front = Path()
      ..moveTo(0, size.height * 0.67)
      ..quadraticBezierTo(
        size.width * 0.23,
        size.height * 0.50,
        size.width * 0.46,
        size.height * 0.72,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.98,
        size.width,
        size.height * 0.66,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(front, waveFront);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
