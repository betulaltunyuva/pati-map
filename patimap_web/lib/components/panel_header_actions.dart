import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/login_page.dart';
import '../pages/profile_page.dart';
import '../pages/register_page.dart';
import '../pages/settings_page.dart';
import '../theme/app_palette.dart';
import '../utils/panel_responsive.dart';

class _HeaderNotification {
  const _HeaderNotification({
    required this.title,
    required this.subtitle,
    this.unread = false,
  });

  final String title;
  final String subtitle;
  final bool unread;
}

const _sampleNotifications = [
  _HeaderNotification(
    title: 'Yeni ihbar olusturuldu',
    subtitle: 'Az once — haritada goruntulenebilir',
    unread: true,
  ),
  _HeaderNotification(
    title: 'Acil ihbar isleme alindi',
    subtitle: '15 dk once — risk: yuksek',
    unread: true,
  ),
  _HeaderNotification(
    title: 'Gonullu bir ihbar ustendi',
    subtitle: '1 saat once — durum: atandi',
    unread: false,
  ),
];

class PanelHeaderActions extends StatelessWidget {
  const PanelHeaderActions({
    super.key,
    this.userEmail,
    required this.onLogin,
    required this.onRegister,
    required this.onProfile,
    required this.onSettings,
  });

  final String? userEmail;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback onProfile;
  final VoidCallback onSettings;

  static Widget authStream(
    BuildContext context, {
    required VoidCallback onLogin,
    required VoidCallback onRegister,
    required VoidCallback onProfile,
    required VoidCallback onSettings,
  }) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final auth = Supabase.instance.client.auth;
        final user = snapshot.data?.session?.user ?? auth.currentUser;
        return PanelHeaderActions(
          userEmail: user?.email,
          onLogin: onLogin,
          onRegister: onRegister,
          onProfile: onProfile,
          onSettings: onSettings,
        );
      },
    );
  }

  static void openLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
    );
  }

  static void openRegister(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RegisterPage()),
    );
  }

  static void openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProfilePage()),
    );
  }

  static void openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
    );
  }

  static Future<void> signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  bool get _isLoggedIn => userEmail != null;

  @override
  Widget build(BuildContext context) {
    final width = PanelResponsive.ofWidth(context);
    final narrow = PanelResponsive.isNarrow(width);
    final compactStyle = _compactButtonStyle(narrow);

    if (!_isLoggedIn) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            onPressed: onRegister,
            style: compactStyle.outlined,
            child: Text(
              'Kayit Ol',
              style: TextStyle(fontSize: narrow ? 11.5 : 14),
            ),
          ),
          SizedBox(width: narrow ? 4 : 8),
          FilledButton(
            onPressed: onLogin,
            style: compactStyle.filled.copyWith(
              backgroundColor: const WidgetStatePropertyAll(
                AppPalette.primaryBlue,
              ),
              foregroundColor: const WidgetStatePropertyAll(Colors.white),
            ),
            child: Text(
              'Giris Yap',
              style: TextStyle(fontSize: narrow ? 11.5 : 14),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NotificationMenuButton(compact: narrow),
        SizedBox(width: narrow ? 4 : 8),
        _ProfileMenuButton(
          compact: narrow,
          onProfile: onProfile,
          onSettings: onSettings,
          onSignOut: () => signOut(context),
        ),
      ],
    );
  }
}

class _CompactButtonStyle {
  const _CompactButtonStyle({required this.outlined, required this.filled});

  final ButtonStyle outlined;
  final ButtonStyle filled;
}

_CompactButtonStyle _compactButtonStyle(bool narrow) {
  final pad = narrow
      ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
      : const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  return _CompactButtonStyle(
    outlined: OutlinedButton.styleFrom(
      padding: pad,
      minimumSize: Size(narrow ? 0 : 64, narrow ? 30 : 40),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    filled: FilledButton.styleFrom(
      padding: pad,
      minimumSize: Size(narrow ? 0 : 64, narrow ? 30 : 40),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
}

class _NotificationMenuButton extends StatelessWidget {
  const _NotificationMenuButton({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    const hasUnread = true;
    return MenuAnchor(
      alignmentOffset: const Offset(-180, 10),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(AppPalette.cardBackground),
        elevation: const WidgetStatePropertyAll(14),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        minimumSize: const WidgetStatePropertyAll(Size(300, 0)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppPalette.border),
          ),
        ),
      ),
      builder: (context, controller, child) {
        return _HeaderIconButton(
          tooltip: 'Bildirimler',
          showBadge: hasUnread,
          compact: compact,
          icon: Icons.notifications_outlined,
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
        );
      },
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Bildirimler',
                style: TextStyle(
                  color: AppPalette.navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              ..._sampleNotifications.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _NotificationTile(item: item),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final _HeaderNotification item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: item.unread
            ? AppPalette.primaryBlue.withValues(alpha: 0.06)
            : AppPalette.pageBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.unread
              ? AppPalette.primaryBlue.withValues(alpha: 0.18)
              : AppPalette.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.unread
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            size: 18,
            color: item.unread ? AppPalette.primaryBlue : AppPalette.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: AppPalette.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontWeight: FontWeight.w500,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (item.unread)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                color: AppPalette.primaryBlue,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileMenuButton extends StatelessWidget {
  const _ProfileMenuButton({
    required this.onProfile,
    required this.onSettings,
    required this.onSignOut,
    this.compact = false,
  });

  final VoidCallback onProfile;
  final VoidCallback onSettings;
  final VoidCallback onSignOut;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(-120, 10),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(AppPalette.cardBackground),
        elevation: const WidgetStatePropertyAll(14),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
        minimumSize: const WidgetStatePropertyAll(Size(190, 0)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppPalette.border),
          ),
        ),
      ),
      builder: (context, controller, child) {
        return _HeaderIconButton(
          tooltip: 'Profil menusu',
          filled: true,
          compact: compact,
          icon: Icons.person_outline_rounded,
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
        );
      },
      menuChildren: [
        _ProfileMenuItem(
          icon: Icons.person_outline_rounded,
          label: 'Profilim',
          onTap: onProfile,
        ),
        _ProfileMenuItem(
          icon: Icons.settings_outlined,
          label: 'Ayarlar',
          onTap: onSettings,
        ),
        const Divider(height: 8),
        _ProfileMenuItem(
          icon: Icons.logout_rounded,
          label: 'Cikis Yap',
          onTap: onSignOut,
          danger: true,
        ),
      ],
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppPalette.error : AppPalette.navy;
    return MenuItemButton(
      onPressed: onTap,
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        overlayColor: WidgetStatePropertyAll(
          (danger ? AppPalette.error : AppPalette.primaryBlue)
              .withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.showBadge = false,
    this.filled = false,
    this.compact = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool showBadge;
  final bool filled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 36.0 : 42.0;
    final iconSize = compact ? 18.0 : 20.0;
    final button = filled
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.primaryBlue,
              foregroundColor: Colors.white,
              minimumSize: Size(size, size),
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            child: Icon(icon, size: iconSize),
          )
        : IconButton(
            onPressed: onPressed,
            style: IconButton.styleFrom(
              backgroundColor: AppPalette.primaryBlue.withValues(alpha: 0.1),
              foregroundColor: AppPalette.primaryBlue,
              minimumSize: Size(size, size),
              shape: const CircleBorder(),
            ),
            icon: Icon(icon, size: iconSize),
          );

    Widget child = button;
    if (showBadge) {
      child = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            right: filled ? 8 : 10,
            top: filled ? 8 : 10,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: AppPalette.primaryBlue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ],
      );
    }

    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}
