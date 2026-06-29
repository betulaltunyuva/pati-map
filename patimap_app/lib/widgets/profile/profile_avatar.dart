import 'package:flutter/material.dart';

import '../../constants/app_assets.dart';
import '../../theme/app_colors.dart';

/// Kullanıcı profil görseli (URL) veya baş harf fallback.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.letter,
    this.avatarUrl,
    this.radius = 44,
    this.showRing = true,
  });

  final String letter;
  final String? avatarUrl;
  final double radius;
  final bool showRing;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final hasImage = url != null && url.isNotEmpty;
    final imageUrl = url ?? '';

    final inner = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryContainer,
      backgroundImage: hasImage ? NetworkImage(imageUrl) : null,
      child: hasImage
          ? null
          : ClipOval(
              child: Image.asset(
                AppAssets.logoPng,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Text(
                  letter.isEmpty ? '?' : letter.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: radius * 0.72,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    height: 1,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
    );

    if (!showRing) return inner;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.45),
            AppColors.primaryLight.withValues(alpha: 0.35),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(2.5),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: inner,
      ),
    );
  }
}
