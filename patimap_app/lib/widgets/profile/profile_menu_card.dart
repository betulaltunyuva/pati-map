import 'package:flutter/material.dart';

import 'profile_menu_tile.dart';
import 'profile_ui_tokens.dart';

class ProfileMenuCard extends StatelessWidget {
  const ProfileMenuCard({
    super.key,
    required this.onAccount,
    required this.onMyReports,
    required this.onAssigned,
    required this.onSettings,
    required this.onHelp,
  });

  final VoidCallback onAccount;
  final VoidCallback onMyReports;
  final VoidCallback onAssigned;
  final VoidCallback onSettings;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: ProfileUiTokens.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProfileMenuTile(
            icon: Icons.badge_outlined,
            title: 'Hesap Bilgileri',
            subtitle: 'Kişisel bilgilerinizi görüntüleyin ve düzenleyin',
            onTap: onAccount,
          ),
          ProfileMenuTile(
            icon: Icons.post_add_rounded,
            title: 'Oluşturduğum İhbarlar',
            subtitle: 'Paylaştığınız ihbarların tamamını listeleyin',
            onTap: onMyReports,
          ),
          ProfileMenuTile(
            icon: Icons.volunteer_activism_outlined,
            title: 'Üstlendiğim İhbarlar',
            subtitle: 'Gönüllü destek verdiğiniz kayıtlar',
            onTap: onAssigned,
          ),
          ProfileMenuTile(
            icon: Icons.settings_outlined,
            title: 'Ayarlar',
            subtitle: 'Uygulama tercihleri ve hesap yönetimi',
            onTap: onSettings,
          ),
          ProfileMenuTile(
            icon: Icons.help_outline_rounded,
            title: 'Yardım / Destek',
            subtitle: 'Sıkça sorulanlar ve iletişim',
            onTap: onHelp,
            showDividerBelow: false,
          ),
        ],
      ),
    );
  }
}
