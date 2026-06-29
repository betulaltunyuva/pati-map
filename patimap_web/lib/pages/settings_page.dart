import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../components/panel_header_actions.dart';
import '../components/panel_empty_state.dart';
import '../components/password_text_field.dart';
import '../components/scroll_reveal.dart';
import '../components/web_panel_layout.dart';
import '../services/auth_password_service.dart';
import '../theme/app_palette.dart';
import '../utils/panel_responsive.dart';
import '../utils/password_rules.dart';
import 'dashboard_page.dart';
import 'map_page.dart';
import 'reports_page.dart';
import 'volunteers_page.dart';

enum SettingsFocusSection { notifications, security }

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.focusSection});

  final SettingsFocusSection? focusSection;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _notificationsSectionKey = GlobalKey();
  final _securitySectionKey = GlobalKey();
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _newPassAgainController = TextEditingController();

  bool _loading = true;
  bool _savingPassword = false;
  bool _darkMode = false;
  bool _compactCards = false;
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _twoFactorEnabled = false;
  bool _locationVisibility = true;
  String _language = 'Turkce';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _scrollToFocusSection() {
    final targetKey = switch (widget.focusSection) {
      SettingsFocusSection.notifications => _notificationsSectionKey,
      SettingsFocusSection.security => _securitySectionKey,
      null => null,
    };
    final targetContext = targetKey?.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  @override
  void dispose() {
    _currentPassController.dispose();
    _newPassController.dispose();
    _newPassAgainController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    // TODO: load from user settings table when backend is ready.
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    setState(() => _loading = false);
    if (widget.focusSection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFocusSection());
    }
  }

  void _showSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Bilgiler güncellendi'),
      ),
    );
  }

  void _showError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Bir hata oluştu'),
      ),
    );
  }

  Future<void> _savePreferences() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;
      _showSuccess();
    } catch (_) {
      if (!mounted) return;
      _showError();
    }
  }

  Future<void> _updatePassword() async {
    final matchError = PasswordRules.validateMatch(
      _newPassController.text,
      _newPassAgainController.text,
    );
    if (matchError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(matchError),
        ),
      );
      return;
    }

    setState(() => _savingPassword = true);
    try {
      await AuthPasswordService.changePasswordForCurrentUser(
        currentPassword: _currentPassController.text,
        newPassword: _newPassController.text,
        confirmPassword: _newPassAgainController.text,
      );
      if (!mounted) return;
      _currentPassController.clear();
      _newPassController.clear();
      _newPassAgainController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Sifreniz basariyla guncellendi.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(AuthPasswordService.messageForError(e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      _showSuccess();
    } catch (_) {
      if (!mounted) return;
      _showError();
    }
  }

  Future<void> _deleteAccount() async {
    // TODO: connect delete-account API endpoint securely.
    _showError();
  }

  void _onMenuSelected(BuildContext context, WebMenuItem item) {
    switch (item) {
      case WebMenuItem.dashboard:
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const DashboardPage()));
        return;
      case WebMenuItem.reports:
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const ReportsPage()));
        return;
      case WebMenuItem.map:
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const MapPage()));
        return;
      case WebMenuItem.volunteers:
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const NearbyVetsPage()));
        return;
      case WebMenuItem.settings:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebPanelLayout(
      revealScope: 'settings',
      currentItem: WebMenuItem.settings,
      title: 'PatiMap',
      onMenuSelected: (item) => _onMenuSelected(context, item),
      headerTrailing: PanelHeaderActions.authStream(
        context,
        onLogin: () => PanelHeaderActions.openLogin(context),
        onRegister: () => PanelHeaderActions.openRegister(context),
        onProfile: () => PanelHeaderActions.openProfile(context),
        onSettings: () {},
      ),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: PanelListSkeleton(itemCount: 2),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1080;
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ScrollReveal(
                        detectKey: const ValueKey<String>('settings_intro'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ayarlar',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppPalette.navy,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Profil duzenleme disindaki uygulama ayarlarini yonetin.',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ScrollReveal(
                                detectKey: const ValueKey<String>(
                                  'settings_col_left',
                                ),
                                child: Column(
                                  children: [
                                    _SectionCard(
                                      title: 'Uygulama Ayarlari',
                                      child: _buildApplicationSection(),
                                    ),
                                    const SizedBox(height: 14),
                                    _SectionCard(
                                      key: _notificationsSectionKey,
                                      title: 'Bildirim Ayarlari',
                                      child: _buildNotificationSection(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: ScrollReveal(
                                detectKey: const ValueKey<String>(
                                  'settings_col_right',
                                ),
                                child: Column(
                                  children: [
                                    _SectionCard(
                                      key: _securitySectionKey,
                                      title: 'Gizlilik ve Guvenlik',
                                      child: _buildSecuritySection(),
                                    ),
                                    const SizedBox(height: 14),
                                    _SectionCard(
                                      title: 'Hesap',
                                      child: _buildAccountSection(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        ScrollReveal(
                          detectKey: const ValueKey<String>(
                            'settings_section_app',
                          ),
                          child: _SectionCard(
                            title: 'Uygulama Ayarlari',
                            child: _buildApplicationSection(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ScrollReveal(
                          detectKey: const ValueKey<String>(
                            'settings_section_notifications',
                          ),
                          child: _SectionCard(
                            key: _notificationsSectionKey,
                            title: 'Bildirim Ayarlari',
                            child: _buildNotificationSection(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ScrollReveal(
                          detectKey: const ValueKey<String>(
                            'settings_section_security',
                          ),
                          child: _SectionCard(
                            key: _securitySectionKey,
                            title: 'Gizlilik ve Guvenlik',
                            child: _buildSecuritySection(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ScrollReveal(
                          detectKey: const ValueKey<String>(
                            'settings_section_account',
                          ),
                          child: _SectionCard(
                            title: 'Hesap',
                            child: _buildAccountSection(),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildApplicationSection() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _language,
          decoration: const InputDecoration(labelText: 'Dil'),
          items: const [
            DropdownMenuItem(value: 'Turkce', child: Text('Turkce')),
            DropdownMenuItem(value: 'English', child: Text('English')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _language = value);
            _savePreferences();
          },
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Dark Tema'),
          subtitle: const Text(
            'Koyu tema gorunumu',
            style: TextStyle(color: AppPalette.textMuted),
          ),
          value: _darkMode,
          onChanged: (v) {
            setState(() => _darkMode = v);
            _savePreferences();
          },
        ),
        const Divider(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Kompakt Kart Gorunumu'),
          subtitle: const Text(
            'Daha sıkı kart araliklari',
            style: TextStyle(color: AppPalette.textMuted),
          ),
          value: _compactCards,
          onChanged: (v) {
            setState(() => _compactCards = v);
            _savePreferences();
          },
        ),
      ],
    );
  }

  Widget _buildNotificationSection() {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Bildirimler'),
          subtitle: const Text(
            'Uygulama ici bildirimleri ac / kapat',
            style: TextStyle(color: AppPalette.textMuted),
          ),
          value: _notificationsEnabled,
          onChanged: (v) {
            setState(() => _notificationsEnabled = v);
            _savePreferences();
          },
        ),
        const Divider(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('E-posta Bildirimleri'),
          subtitle: const Text(
            'Onemli guncellemeler e-posta ile gelsin',
            style: TextStyle(color: AppPalette.textMuted),
          ),
          value: _emailNotifications,
          onChanged: (v) {
            setState(() => _emailNotifications = v);
            _savePreferences();
          },
        ),
      ],
    );
  }

  Widget _buildSecuritySection() {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Iki Asamali Dogrulama (2FA)'),
          subtitle: const Text(
            'Hesap guvenligi icin ekstra koruma',
            style: TextStyle(color: AppPalette.textMuted),
          ),
          value: _twoFactorEnabled,
          onChanged: (v) {
            setState(() => _twoFactorEnabled = v);
            _savePreferences();
          },
        ),
        const Divider(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Konum Gorunurlugu'),
          subtitle: const Text(
            'Konum bazli ozelliklerde gorunurluk izni',
            style: TextStyle(color: AppPalette.textMuted),
          ),
          value: _locationVisibility,
          onChanged: (v) {
            setState(() => _locationVisibility = v);
            _savePreferences();
          },
        ),
        const SizedBox(height: 10),
        PasswordTextField(
          controller: _currentPassController,
          labelText: 'Mevcut Sifre',
        ),
        const SizedBox(height: 12),
        PasswordTextField(
          controller: _newPassController,
          labelText: 'Yeni Sifre',
        ),
        const SizedBox(height: 12),
        PasswordTextField(
          controller: _newPassAgainController,
          labelText: 'Yeni Sifre Tekrar',
        ),
        const SizedBox(height: 8),
        ...PasswordRules.hintLines.map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              line,
              style: const TextStyle(
                color: AppPalette.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _savingPassword ? null : _updatePassword,
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.primaryBlue,
            ),
            child: _savingPassword
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Sifreyi Guncelle'),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _signOut,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Cikis Yap'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _deleteAccount,
          icon: const Icon(Icons.delete_forever_rounded),
          style: FilledButton.styleFrom(
            backgroundColor: AppPalette.error,
            foregroundColor: Colors.white,
          ),
          label: const Text('Hesabi Sil'),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final compact = PanelResponsive.isMobile(PanelResponsive.ofWidth(context));
    return Container(
      key: key,
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppPalette.border),
        boxShadow: [
          BoxShadow(
            color: AppPalette.navy.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppPalette.navy,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
