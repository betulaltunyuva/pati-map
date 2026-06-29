import 'package:flutter/material.dart';

/// Profil ekranı ortak görsel sabitleri.
abstract final class ProfileUiTokens {
  static const double cardRadius = 18;
  static const double sectionGap = 16;
  static const EdgeInsets pagePadding =
      EdgeInsets.fromLTRB(20, 14, 20, 28);

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];

  static BoxDecoration cardDecoration({Color? color}) {
    return BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(cardRadius),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: cardShadow,
    );
  }
}
