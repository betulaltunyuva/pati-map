import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../components/panel_empty_state.dart';
import '../components/panel_header_actions.dart';
import '../components/scroll_reveal.dart';
import '../components/web_panel_layout.dart';
import '../services/profile_features_service.dart';
import '../theme/app_palette.dart';
import 'dashboard_page.dart';
import 'map_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';
import 'volunteers_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = true;
  String? _error;
  WebProfileSnapshot? _profile;
  int _createdCount = 0;
  int _assignedCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Profili gormek icin once giris yapin.';
      });
      return;
    }
    try {
      final results = await Future.wait<dynamic>([
        ProfileFeaturesService.loadSnapshot(),
        Supabase.instance.client.from('reports').select('id').eq('user_id', user.id),
        Supabase.instance.client
            .from('reports')
            .select('id')
            .eq('assigned_volunteer_id', user.id),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as WebProfileSnapshot;
        _createdCount = (results[1] as List<dynamic>).length;
        _assignedCount = (results[2] as List<dynamic>).length;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Profil verisi yuklenemedi.';
      });
      debugPrint('Web profile load error: $e');
    }
  }

  Future<void> _onSignOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _openAccountDialog() async {
    final profile = _profile;
    if (profile == null) return;
    final firstController = TextEditingController(text: profile.firstName ?? '');
    final lastController = TextEditingController(text: profile.lastName ?? '');
    final formKey = GlobalKey<FormState>();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Hesap Bilgileri'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: firstController,
                    decoration: const InputDecoration(labelText: 'Ad'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Ad zorunludur' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: lastController,
                    decoration: const InputDecoration(labelText: 'Soyad'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Soyad zorunludur' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: profile.email,
                    enabled: false,
                    decoration: const InputDecoration(labelText: 'E-posta'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Iptal'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final valid = formKey.currentState?.validate() ?? false;
                      if (!valid) return;
                      setLocalState(() => saving = true);
                      try {
                        await ProfileFeaturesService.updateName(
                          firstName: firstController.text,
                          lastName: lastController.text,
                        );
                        if (!mounted || !context.mounted) return;
                        Navigator.of(context).pop();
                        await _load();
                        if (!mounted || !context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text('Hesap bilgileri guncellendi.'),
                          ),
                        );
                      } catch (e) {
                        if (!mounted || !context.mounted) return;
                        setLocalState(() => saving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text(_messageForError(e)),
                          ),
                        );
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    firstController.dispose();
    lastController.dispose();
  }

  Future<void> _openNotificationsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          child: SizedBox(
            width: 760,
            height: 540,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _NotificationsPanel(onOpenChat: _openChatDialog),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openChatDialog(String reportId) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          child: SizedBox(
            width: 760,
            height: 560,
            child: _ChatPanel(
              reportId: reportId,
              inputController: controller,
            ),
          ),
        );
      },
    );
    controller.dispose();
  }

  Future<void> _openReportListDialog({
    required bool created,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final rows = await Supabase.instance.client
        .from('reports')
        .select('id, description, status, created_at')
        .eq(created ? 'user_id' : 'assigned_volunteer_id', user.id)
        .order('created_at', ascending: false)
        .limit(50);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(created ? 'Ihbarlarim' : 'Ustlendiklerim'),
        content: SizedBox(
          width: 560,
          child: rows.isEmpty
              ? const Text('Kayit bulunamadi.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = Map<String, dynamic>.from(rows[index] as Map);
                    return ListTile(
                      title: Text(
                        item['description']?.toString() ?? 'Ihbar',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Durum: ${item['status'] ?? '-'}',
                      ),
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _openChatDialog(item['id']?.toString() ?? '');
                        },
                        child: const Text('Mesajlar'),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _onMenuSelected(BuildContext context, WebMenuItem item) {
    switch (item) {
      case WebMenuItem.dashboard:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const DashboardPage()),
        );
        return;
      case WebMenuItem.map:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const MapPage()),
        );
        return;
      case WebMenuItem.reports:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ReportsPage()),
        );
        return;
      case WebMenuItem.volunteers:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NearbyVetsPage()),
        );
        return;
      case WebMenuItem.settings:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
        );
        return;
    }
  }

  String _messageForError(Object error) {
    if (error is AuthException) {
      final message = error.message.trim();
      if (message.isNotEmpty) return message;
    }
    if (error is PostgrestException) {
      final message = error.message.trim();
      if (message.isNotEmpty) return message;
    }
    return 'Islem tamamlanamadi. Lutfen tekrar deneyin.';
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return WebPanelLayout(
      revealScope: 'profile',
      currentItem: WebMenuItem.settings,
      title: 'PatiMap',
      onMenuSelected: (item) => _onMenuSelected(context, item),
      headerTrailing: PanelHeaderActions.authStream(
        context,
        onLogin: () => PanelHeaderActions.openLogin(context),
        onRegister: () => PanelHeaderActions.openRegister(context),
        onProfile: () {},
        onSettings: () => PanelHeaderActions.openSettings(context),
      ),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: PanelListSkeleton(itemCount: 2),
            )
          : _error != null
              ? PanelErrorState(message: _error!)
              : profile == null
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ScrollReveal(
                          detectKey: const ValueKey<String>('profile_intro'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Profil',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppPalette.navy,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Hesabiniz ve aktiviteleriniz',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ScrollReveal(
                          detectKey: const ValueKey<String>('profile_hero'),
                          child: _ProfileHero(
                            name: profile.displayName,
                            email: profile.email,
                            role: profile.roleLabel ?? 'Gonullu Kullanici',
                            avatarUrl: profile.avatarUrl,
                            createdCount: _createdCount,
                            assignedCount: _assignedCount,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ScrollReveal(
                          detectKey: const ValueKey<String>('profile_actions'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Hizli Islemler',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppPalette.navy,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _ActionCard(
                          icon: Icons.person_outline,
                          title: 'Hesap Bilgileri',
                          subtitle: 'Ad, soyad ve profil bilgilerini guncelle',
                          onTap: _openAccountDialog,
                        ),
                        _ActionCard(
                          icon: Icons.folder_open_outlined,
                          title: 'Ihbarlarim',
                          subtitle: 'Olusturdugunuz ihbarlari goruntule',
                          onTap: () => _openReportListDialog(created: true),
                        ),
                        _ActionCard(
                          icon: Icons.volunteer_activism_outlined,
                          title: 'Ustlendiklerim',
                          subtitle: 'Gonullu oldugunuz ihbarlari goruntule',
                          onTap: () => _openReportListDialog(created: false),
                        ),
                        _ActionCard(
                          icon: Icons.notifications_outlined,
                          title: 'Bildirimler ve Mesajlar',
                          subtitle: 'Ihbar sahibi ve gonullu mesajlasmalarini ac',
                          onTap: _openNotificationsDialog,
                        ),
                        _ActionCard(
                          icon: Icons.settings_outlined,
                          title: 'Ayarlar',
                          subtitle: 'Uygulama ayarlari yakinda eklenecek',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                behavior: SnackBarBehavior.floating,
                                content: Text('Ayarlar yakinda eklenecek.'),
                              ),
                            );
                          },
                        ),
                        _ActionCard(
                          icon: Icons.help_outline,
                          title: 'Yardim',
                          subtitle: 'Destek icin yonetim ekibiyle iletisime gecin',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                behavior: SnackBarBehavior.floating,
                                content: Text(
                                  'Destek kanali yakinda burada olacak.',
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _onSignOut,
                                icon: const Icon(Icons.logout_rounded),
                                label: const Text('Cikis Yap'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppPalette.error,
                                  side: const BorderSide(color: AppPalette.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.email,
    required this.role,
    required this.avatarUrl,
    required this.createdCount,
    required this.assignedCount,
  });

  final String name;
  final String email;
  final String role;
  final String? avatarUrl;
  final int createdCount;
  final int assignedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppPalette.primaryBlue.withValues(alpha: 0.12),
            backgroundImage: (avatarUrl != null && avatarUrl!.trim().isNotEmpty)
                ? NetworkImage(avatarUrl!.trim())
                : null,
            child: (avatarUrl == null || avatarUrl!.trim().isEmpty)
                ? const Icon(
                    Icons.person_outline_rounded,
                    color: AppPalette.primaryBlue,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  role,
                  style: const TextStyle(
                    color: AppPalette.primaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _CounterCard(label: 'Olusturdugum', value: createdCount),
          const SizedBox(width: 8),
          _CounterCard(label: 'Ustlendigim', value: assignedCount),
        ],
      ),
    );
  }
}

class _CounterCard extends StatelessWidget {
  const _CounterCard({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppPalette.pageBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppPalette.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppPalette.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppPalette.primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 18, color: AppPalette.primaryBlue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppPalette.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppPalette.navy,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationsPanel extends StatefulWidget {
  const _NotificationsPanel({
    required this.onOpenChat,
  });

  final Future<void> Function(String reportId) onOpenChat;

  @override
  State<_NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<_NotificationsPanel> {
  bool _loading = true;
  String? _error;
  List<WebNotificationItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ProfileFeaturesService.fetchMyNotifications();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd.$mm $hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: AppPalette.error),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('Henuz bildirim yok.'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bildirimler',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppPalette.navy,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: _items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = _items[index];
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    await ProfileFeaturesService.markNotificationRead(item.id);
                    if (!mounted) return;
                    await widget.onOpenChat(item.reportId);
                    if (!mounted) return;
                    _load();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: item.isRead ? AppPalette.border : AppPalette.primaryBlue,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          item.isRead
                              ? Icons.notifications_none_rounded
                              : Icons.notifications_active_rounded,
                          color:
                              item.isRead ? Colors.grey.shade500 : AppPalette.primaryBlue,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  color: AppPalette.navy,
                                  fontWeight:
                                      item.isRead ? FontWeight.w700 : FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.body,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatDate(item.createdAt),
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChatPanel extends StatefulWidget {
  const _ChatPanel({
    required this.reportId,
    required this.inputController,
  });

  final String reportId;
  final TextEditingController inputController;

  @override
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel> {
  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<WebReportMessage> _messages = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ProfileFeaturesService.fetchMessages(widget.reportId);
      if (!mounted) return;
      setState(() {
        _messages = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _send() async {
    final text = widget.inputController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ProfileFeaturesService.sendMessage(
        reportId: widget.reportId,
        messageText: text,
      );
      widget.inputController.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Mesajlar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.navy,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppPalette.error),
                        ),
                      )
                    : _messages.isEmpty
                        ? const Center(child: Text('Bu ihbar icin mesaj yok.'))
                        : ListView.builder(
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final item = _messages[index];
                              final mine = userId != null && item.senderId == userId;
                              return Align(
                                alignment: mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  constraints: const BoxConstraints(maxWidth: 460),
                                  decoration: BoxDecoration(
                                    color: mine
                                        ? AppPalette.primaryBlue
                                        : AppPalette.pageBackground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: mine
                                          ? AppPalette.primaryBlue
                                          : AppPalette.border,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.message,
                                        style: TextStyle(
                                          color: mine ? Colors.white : AppPalette.navy,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDate(item.createdAt),
                                        style: TextStyle(
                                          color: mine
                                              ? Colors.white70
                                              : Colors.grey.shade600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.inputController,
                  maxLines: 2,
                  minLines: 1,
                  decoration: const InputDecoration(
                    hintText: 'Mesajinizi yazin...',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Gonder'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
