import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../components/create_report_dialog.dart';
import '../components/panel_header_actions.dart';
import '../components/report_detail_panel.dart';
import '../components/report_map_panel.dart';
import '../components/scroll_reveal.dart';
import '../components/web_panel_layout.dart';
import '../models/report_map_item.dart';
import '../pages/login_page.dart';
import '../pages/reports_page.dart';
import '../pages/volunteers_page.dart';
import '../services/report_map_service.dart';
import '../theme/app_palette.dart';
import '../utils/panel_responsive.dart';
import 'dashboard_page.dart';
import 'settings_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  ReportMapItem? _selected;
  bool _assigning = false;
  int _reloadSignal = 0;

  Future<void> _openCreateReportDialog() async {
    if (!_ensureSession()) return;
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CreateReportDialog(),
    );
    if (!mounted || created != true) return;
    setState(() => _reloadSignal++);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Ihbar basariyla olusturuldu.'),
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

  @override
  Widget build(BuildContext context) {
    return WebPanelLayout(
      revealScope: 'map',
      currentItem: WebMenuItem.map,
      title: 'PatiMap',
      onMenuSelected: (item) => _onMenuSelected(context, item),
      headerTrailing: PanelHeaderActions.authStream(
        context,
        onLogin: () => PanelHeaderActions.openLogin(context),
        onRegister: () => PanelHeaderActions.openRegister(context),
        onProfile: () => PanelHeaderActions.openProfile(context),
        onSettings: () => PanelHeaderActions.openSettings(context),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = PanelResponsive.isMobile(constraints.maxWidth);
          final mapHeight = mobile ? 320.0 : 640.0;

          final mapPanel = SizedBox(
            width: double.infinity,
            child: ReportMapPanel(
              height: mapHeight,
              title: 'Ihbar Haritasi',
              selectionId: _selected?.id,
              reloadSignal: _reloadSignal,
              onMarkerTap: (item) => setState(() => _selected = item),
              onDataLoaded: _syncSelectedWithLatestData,
            ),
          );

          final detailPanel = ReportDetailPanel(
            report: _selected,
            assigning: _assigning,
            onClose: () => setState(() => _selected = null),
            onAssign: _onAssignPressed,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScrollReveal(
                detectKey: const ValueKey<String>('map_page_actions'),
                child: Align(
                  alignment: mobile
                      ? Alignment.center
                      : Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _openCreateReportDialog,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Ihbar Olustur'),
                  ),
                ),
              ),
              SizedBox(height: mobile ? 10 : 12),
              ScrollReveal(
                detectKey: const ValueKey<String>('map_page_map_row'),
                child: mobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          mapPanel,
                          const SizedBox(height: 12),
                          detailPanel,
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: mapPanel),
                          const SizedBox(width: 14),
                          Expanded(flex: 5, child: detailPanel),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _syncSelectedWithLatestData(List<ReportMapItem> items) {
    final selected = _selected;
    if (selected == null) return;
    ReportMapItem? next;
    for (final item in items) {
      if (item.id == selected.id) {
        next = item;
        break;
      }
    }
    if (next != null && mounted && next != _selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_selected?.id != next?.id || _selected != next) {
          setState(() => _selected = next);
        }
      });
    }
  }

  Future<void> _onAssignPressed() async {
    final report = _selected;
    if (report == null) return;
    if (!_ensureSession()) return;

    setState(() => _assigning = true);
    try {
      final updated = await ReportMapService.assignVolunteerToReport(
        reportId: report.id,
      );
      if (!mounted) return;
      setState(() {
        _selected = updated;
        _reloadSignal++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Ihbar gonullu olarak ustlenildi.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(_messageForError(e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }


  String _messageForError(Object error) {
    if (error is AuthException) {
      final message = error.message.trim();
      if (message.isNotEmpty) return message;
    }
    return 'Islem su anda tamamlanamadi. Lutfen tekrar deneyin.';
  }

  bool _ensureSession() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Bu islem icin once giris yapmaniz gerekiyor.'),
      ),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
    );
    return false;
  }
}

