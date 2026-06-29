import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/map_screen_style.dart';

class PatiMapPrimaryButton extends StatelessWidget {
  const PatiMapPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.mapScreenAppearance = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Harita ekranında yumuşak yeşil ve daha premium gölge.
  final bool mapScreenAppearance;

  @override
  Widget build(BuildContext context) {
    final height = mapScreenAppearance
        ? MapScreenStyle.primaryCtaHeight
        : 56.0;
    final radius = mapScreenAppearance
        ? MapScreenStyle.primaryCtaRadius
        : 18.0;

    final baseGreen = AppColors.primary;
    final pressedGreen = AppColors.primaryLight;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: baseGreen.withValues(
              alpha: mapScreenAppearance ? 0.24 : 0.2,
            ),
            blurRadius: mapScreenAppearance ? 20 : 12,
            offset: Offset(0, mapScreenAppearance ? 6 : 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(
            Size(double.infinity, height),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return baseGreen.withValues(alpha: 0.45);
            }
            if (states.contains(WidgetState.pressed)) {
              return pressedGreen;
            }
            return baseGreen;
          }),
          foregroundColor:
              const WidgetStatePropertyAll(Color(0xFFFFFFFF)),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          surfaceTintColor:
              const WidgetStatePropertyAll(Colors.transparent),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.transparent;
            }
            return baseGreen.withValues(alpha: 0.12);
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: mapScreenAppearance ? 16.5 : 17,
            fontWeight: FontWeight.w800,
            letterSpacing: mapScreenAppearance ? 0.15 : 0,
            height: 1.1,
            color: const Color(0xFFFFFFFF),
            shadows: mapScreenAppearance
                ? const [
                    Shadow(
                      color: Color(0x33000000),
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}
