import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'profile_ui_tokens.dart';

class ProfileMotivationFooter extends StatelessWidget {
  const ProfileMotivationFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(ProfileUiTokens.cardRadius),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.favorite_rounded,
            color: AppColors.primary.withValues(alpha: 0.85),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sokak hayvanları için yaptığınız her destek çok değerli.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.heading.withValues(alpha: 0.92),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
