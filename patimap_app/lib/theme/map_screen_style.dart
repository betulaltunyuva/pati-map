import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Görsel sabitler: yalnızca harita ana ekranı (Home) için.
/// İş mantığına dokunulmaz; renk ve ölçü tutarlılığı için merkezi referans.
abstract final class MapScreenStyle {
  MapScreenStyle._();

  static const Color scaffoldBackground = AppColors.scaffoldBackground;
  /// light_all + hafif kontrast sonrası kenar uyumu için biraz daha tok nötr gri.
  static const Color mapCanvasBackground = Color(0xFFEBEBEB);

  /// light_all raster katmanına uygulanan hafif kontrast (URL aynı kalır).
  /// Renk uzayı 0–1; marker katmanı bu filtrenin dışında kalır.
  static const List<double> tileLayerContrastMatrix = <double>[
    1.07, 0, 0, 0, -0.028,
    0, 1.07, 0, 0, -0.028,
    0, 0, 1.07, 0, -0.028,
    0, 0, 0, 1, 0,
  ];

  /// Uygulama primary ile aynı — harita CTA ve ölçüler burada kalır.
  static const Color accent = AppColors.primary;
  static const Color accentLight = AppColors.primaryLight;
  static const Color title = AppColors.heading;
  static const Color subtitleMuted = Color(0xFF5B6777);

  static const Color navBarBackground = AppColors.cardBackground;
  static const Color navSelected = accent;
  static const Color navUnselected = Color(0xFF7A8695);

  static const double mapRadius = 22;
  static const double mapHorizontalPadding = 18;
  static const double mapCardElevationBlur = 22;
  static const double mapCardElevationY = 10;
  static const double mapCardElevationAlpha = 0.06;

  static const double markerSize = 28;
  static const double mapInset = 10;

  static const double primaryCtaHeight = 52;
  static const double primaryCtaRadius = 22;

  static const Color userLocationRing = AppColors.primaryLight;
}
