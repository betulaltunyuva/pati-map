import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'profile_ui_tokens.dart';

class ProfileStatBoxesRow extends StatelessWidget {
  const ProfileStatBoxesRow({
    super.key,
    required this.createdCount,
    required this.assignedCount,
  });

  final int createdCount;
  final int assignedCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            value: '$createdCount',
            title: 'Oluşturduğum ihbar',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBox(
            value: '$assignedCount',
            title: 'Üstlendiğim ihbar',
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.value,
    required this.title,
  });

  final String value;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: ProfileUiTokens.cardDecoration().copyWith(
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              height: 1,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
