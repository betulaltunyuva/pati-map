import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/map_screen_style.dart';

class MobileHeader extends StatelessWidget {
  const MobileHeader({
    super.key,
    required this.title,
    required this.onProfileTap,
    this.onNotificationTap,
    this.mapScreenLayout = false,
  });

  final String title;
  final VoidCallback onProfileTap;
  final VoidCallback? onNotificationTap;

  /// Harita ana ekranında daha sakin tipografi ve hizalama.
  final bool mapScreenLayout;

  @override
  Widget build(BuildContext context) {
    final titleColor =
        mapScreenLayout ? MapScreenStyle.title : AppColors.heading;
    final iconColor =
        mapScreenLayout ? MapScreenStyle.accent : AppColors.primary;

    return Padding(
      padding: mapScreenLayout
          ? const EdgeInsets.fromLTRB(20, 6, 12, 10)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: mapScreenLayout
                  ? Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        height: 1.15,
                        color: titleColor,
                      )
                  : Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
            ),
          ),
          if (onNotificationTap != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: onNotificationTap,
              icon: Icon(
                Icons.notifications_outlined,
                size: 24,
                color: iconColor,
              ),
              style: IconButton.styleFrom(
                foregroundColor: iconColor,
              ),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: onProfileTap,
            icon: Icon(
              Icons.person_outline_rounded,
              size: 24,
              color: iconColor,
            ),
            style: IconButton.styleFrom(
              foregroundColor: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}
