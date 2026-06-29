import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/login_page.dart';
import '../pages/settings_page.dart';
import 'create_report_dialog.dart';
import 'footer_info_dialog.dart';
import 'web_panel_layout.dart';

Future<void> handlePanelFooterLink(
  BuildContext context,
  String label, {
  required ValueChanged<WebMenuItem> onMenuSelected,
}) async {
  switch (label) {
    case 'İhbar Oluştur':
      await _openCreateReportDialog(context);
      return;
    case 'Yakın Veterinerler':
      onMenuSelected(WebMenuItem.volunteers);
      return;
    case 'Harita':
      onMenuSelected(WebMenuItem.map);
      return;
    case 'Bildirimler':
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const SettingsPage(
            focusSection: SettingsFocusSection.notifications,
          ),
        ),
      );
      return;
    case 'Güvenlik':
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const SettingsPage(
            focusSection: SettingsFocusSection.security,
          ),
        ),
      );
      return;
    default:
      FooterInfoContent.showForLabel(context, label);
  }
}

Future<void> _openCreateReportDialog(BuildContext context) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Bu islem icin once giris yapmaniz gerekiyor.'),
      ),
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
    );
    return;
  }

  final created = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const CreateReportDialog(),
  );
  if (!context.mounted || created != true) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text('Ihbar basariyla olusturuldu.'),
    ),
  );
}
