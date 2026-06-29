import 'package:flutter/material.dart';

/// Merkezi renk paleti — harita "İhbar Oluştur" yeşili ana vurgu olarak kullanılır.
abstract final class AppColors {
  AppColors._();

  /// PatiMap mavi paleti
  static const Color primary = Color(0xFF2D67BC);
  static const Color primaryLight = Color(0xFF4B82D1);
  static const Color primaryDark = Color(0xFF243446);
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Başlık ve güçlü metin vurgusu
  static const Color heading = Color(0xFF243446);

  /// Yüzey / kart / border tonları
  static const Color primaryContainer = Color(0xFFEAF2FF);
  static const Color onPrimaryContainer = Color(0xFF243446);
  static const Color primaryContainerMuted = Color(0xFFDDE8FA);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);

  /// Durum renkleri
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF97316);
  static const Color error = Color(0xFFEF4444);
  static const Color successSurface = Color(0xFFEAFBF0);

  static const Color scaffoldBackground = Color(0xFFF8FAFC);
}
