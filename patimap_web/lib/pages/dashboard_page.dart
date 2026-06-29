import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
import '../utils/dashboard_report_metrics.dart';
import '../utils/map_marker_layout.dart';
import '../utils/panel_responsive.dart';
import 'map_page.dart';
import 'settings_page.dart';

/// Shared card shell: 20px radius, softer shadow; hover uses slightly deeper shadow.
BoxDecoration _dashboardCardDecoration({double radius = 20, bool elevated = false}) {
  return BoxDecoration(
    color: AppPalette.cardBackground,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppPalette.border),
    boxShadow: [
      BoxShadow(
        color: AppPalette.navy.withValues(alpha: elevated ? 0.085 : 0.042),
        blurRadius: elevated ? 28 : 20,
        offset: Offset(0, elevated ? 14 : 10),
      ),
    ],
  );
}

const TextStyle _dashboardSectionTitleStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w800,
  color: AppPalette.navy,
);

/// [ReportMapPanel._buildMap] ile ayni kaynak: geo filtre + haritadaki pin basina bir ihbar.
List<ReportMapItem> dashboardMapReportsFrom(List<ReportMapItem> reports) {
  final geoItems = reports.where((r) => r.hasGeoCoordinates).toList();
  return MapMarkerLayout.reportsOnMapPins(geoItems);
}

void _debugLogDashboardMapReports(List<ReportMapItem> dashboardMapReports) {
  final metrics = DashboardReportMetrics.fromReports(dashboardMapReports);
  final b = metrics.riskBuckets;
  final riskTotal = (b['high'] ?? 0) +
      (b['medium'] ?? 0) +
      (b['low'] ?? 0) +
      (b['unknown'] ?? 0);
  debugPrint('Marker listesi: $dashboardMapReports');
  debugPrint('Marker sayisi: ${dashboardMapReports.length}');
  debugPrint('Risk dagilimi toplam: $riskTotal');
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  ReportMapItem? _selected;
  bool _assigning = false;
  /// Dashboard sayilari ve kartlar icin tek ihbar listesi.
  List<ReportMapItem> _dashboardReports = const [];
  bool _reportsLoading = true;
  Object? _reportsError;

  /// Harita marker, baslik, risk ve haftalik ozet icin tek liste.
  List<ReportMapItem> get _dashboardMapReports =>
      dashboardMapReportsFrom(_dashboardReports);

  /// Harita, risk, haftalik ozet ve Genel Ozet: [_dashboardMapReports].
  DashboardReportMetrics get _mapMetrics =>
      DashboardReportMetrics.fromReports(_dashboardMapReports);

  @override
  void initState() {
    super.initState();
    _loadDashboardReports();
  }

  Future<void> _loadDashboardReports() async {
    setState(() {
      _reportsLoading = true;
      _reportsError = null;
    });
    try {
      final reports = await ReportMapService.fetchItems();
      if (!mounted) return;
      final mapReports = dashboardMapReportsFrom(reports);
      setState(() {
        _dashboardReports = reports;
        _reportsLoading = false;
      });
      _debugLogDashboardMapReports(mapReports);
      _syncSelectedWithLatestData(reports);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reportsError = e;
        _reportsLoading = false;
      });
    }
  }

  void _onMenuSelected(BuildContext context, WebMenuItem item) {
    switch (item) {
      case WebMenuItem.dashboard:
        break;
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
      setState(() => _selected = updated);
      await _loadDashboardReports();
      if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = PanelResponsive.useSidebar(width);
        final compact = PanelResponsive.isMobile(width);
        return WebPanelLayout(
          revealScope: 'dashboard',
          compactFooter: true,
          currentItem: WebMenuItem.dashboard,
          title: 'PatiMap',
          onMenuSelected: (item) => _onMenuSelected(context, item),
          headerTrailing: PanelHeaderActions.authStream(
            context,
            onLogin: () => PanelHeaderActions.openLogin(context),
            onRegister: () => PanelHeaderActions.openRegister(context),
            onProfile: () => PanelHeaderActions.openProfile(context),
            onSettings: () => PanelHeaderActions.openSettings(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScrollReveal(
                detectKey: const ValueKey<String>('dashboard_stats_block'),
                child: _StatsGrid(
                  isWide: wide,
                  compact: compact,
                  metrics: _mapMetrics,
                  loading: _reportsLoading,
                  onReload: _loadDashboardReports,
                ),
              ),
              SizedBox(height: compact ? 12 : 18),
              _DashboardMapAndActivityBlock(
                wide: wide,
                compact: compact,
                allReports: _dashboardReports,
                dashboardMapReports: _dashboardMapReports,
                mapMetrics: _mapMetrics,
                reportsLoading: _reportsLoading,
                reportsError: _reportsError,
                selected: _selected,
                assigning: _assigning,
                onReload: _loadDashboardReports,
                onMarkerTap: (item) => setState(() => _selected = item),
                onCloseDetail: () => setState(() => _selected = null),
                onAssign: _onAssignPressed,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Harita + detay üstte; Son Aktiviteler harita sütunuyla aynı genişlikte (wide).
class _DashboardMapAndActivityBlock extends StatelessWidget {
  const _DashboardMapAndActivityBlock({
    required this.wide,
    required this.compact,
    required this.allReports,
    required this.dashboardMapReports,
    required this.mapMetrics,
    required this.reportsLoading,
    required this.reportsError,
    required this.selected,
    required this.assigning,
    required this.onReload,
    required this.onMarkerTap,
    required this.onCloseDetail,
    required this.onAssign,
  });

  final bool wide;
  final bool compact;
  final List<ReportMapItem> allReports;
  final List<ReportMapItem> dashboardMapReports;
  final DashboardReportMetrics mapMetrics;
  final bool reportsLoading;
  final Object? reportsError;
  final ReportMapItem? selected;
  final bool assigning;
  final VoidCallback onReload;
  final ValueChanged<ReportMapItem> onMarkerTap;
  final VoidCallback onCloseDetail;
  final VoidCallback onAssign;

  String get _mapTitle {
    if (reportsLoading) return 'Harita Onizleme';
    if (mapMetrics.total == 0) return 'Harita Onizleme';
    return 'Harita Onizleme (${mapMetrics.total} ihbar)';
  }

  @override
  Widget build(BuildContext context) {
    final mapHeightWide = 460.0;
    final mapHeightNarrow = compact ? 300.0 : 360.0;

    if (wide) {
      final mapDetailRow = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: ReportMapPanel(
              height: mapHeightWide,
              title: _mapTitle,
              selectionId: selected?.id,
              items: dashboardMapReports,
              itemsLoading: reportsLoading,
              itemsError: reportsError,
              onReload: onReload,
              onMarkerTap: onMarkerTap,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ReportDetailPanel(
              report: selected,
              assigning: assigning,
              onClose: onCloseDetail,
              onAssign: onAssign,
              panelHeight: mapHeightWide,
              compactLayout: true,
            ),
          ),
        ],
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScrollReveal(
            detectKey: const ValueKey<String>('dashboard_map_detail'),
            child: mapDetailRow,
          ),
          const SizedBox(height: 14),
          ScrollReveal(
            detectKey: const ValueKey<String>('dashboard_insights'),
            child: _DashboardInsightRow(
              mapMetrics: mapMetrics,
              weeklyReports: dashboardMapReports,
              loading: reportsLoading,
              isWide: true,
            ),
          ),
          const SizedBox(height: 14),
          ScrollReveal(
            detectKey: const ValueKey<String>('dashboard_recent_activity'),
            child: _RecentActivityCard(
              reports: allReports,
              loading: reportsLoading,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScrollReveal(
          detectKey: const ValueKey<String>('dashboard_map_detail_narrow'),
          child: ReportMapPanel(
            height: mapHeightNarrow,
            title: _mapTitle,
            selectionId: selected?.id,
            items: dashboardMapReports,
            itemsLoading: reportsLoading,
            itemsError: reportsError,
            onReload: onReload,
            onMarkerTap: onMarkerTap,
          ),
        ),
        const SizedBox(height: 12),
        ScrollReveal(
          detectKey: const ValueKey<String>('dashboard_detail_narrow'),
          child: ReportDetailPanel(
            report: selected,
            assigning: assigning,
            onClose: onCloseDetail,
            onAssign: onAssign,
            compactLayout: true,
          ),
        ),
        const SizedBox(height: 12),
        ScrollReveal(
          detectKey: const ValueKey<String>('dashboard_insights_narrow'),
          child: _DashboardInsightRow(
            mapMetrics: mapMetrics,
            weeklyReports: dashboardMapReports,
            loading: reportsLoading,
            isWide: false,
          ),
        ),
        const SizedBox(height: 14),
        ScrollReveal(
          detectKey: const ValueKey<String>('dashboard_recent_narrow'),
          child: _RecentActivityCard(
            reports: allReports,
            loading: reportsLoading,
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.isWide,
    required this.compact,
    required this.metrics,
    required this.loading,
    required this.onReload,
  });

  final bool isWide;
  final bool compact;
  final DashboardReportMetrics metrics;
  final bool loading;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
        final cards = [
          _StatCard(
            title: 'Acik ihbar',
            subtitle: 'Aktif kayit',
            value: metrics.openCount,
            loading: loading,
            compact: compact,
            icon: Icons.folder_open_outlined,
          ),
          _StatCard(
            title: 'Acil ihbar',
            subtitle: 'Risk / aciliyet',
            value: metrics.urgentCount,
            loading: loading,
            compact: compact,
            icon: Icons.warning_amber_rounded,
          ),
          _StatCard(
            title: 'Cozulen ihbar',
            subtitle: 'Tamamlanan',
            value: metrics.resolvedCount,
            loading: loading,
            compact: compact,
            icon: Icons.check_circle_outline_rounded,
          ),
          _StatCard(
            title: 'Gonullu',
            subtitle: 'Ustlenen',
            value: metrics.volunteerCount,
            loading: loading,
            compact: compact,
            icon: Icons.groups_2_outlined,
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Genel Ozet', style: _dashboardSectionTitleStyle),
                const Spacer(),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppPalette.pageBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppPalette.border),
                  ),
                  child: IconButton(
                    onPressed: onReload,
                    tooltip: 'Istatistikleri yenile',
                    iconSize: 18,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ),
              ],
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cards.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWide ? 4 : 2,
                crossAxisSpacing: compact ? 8 : 14,
                mainAxisSpacing: compact ? 8 : 14,
                mainAxisExtent: isWide ? 178 : (compact ? 158 : 170),
              ),
              itemBuilder: (context, index) => cards[index],
            ),
          ],
        );
  }
}

class _StatCard extends StatefulWidget {
  const _StatCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.loading,
    required this.compact,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final int value;
  final bool loading;
  final bool compact;
  final IconData icon;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    const primary = AppPalette.primaryBlue;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(
          widget.compact ? 12 : 16,
          widget.compact ? 12 : 16,
          widget.compact ? 12 : 16,
          widget.compact ? 10 : 14,
        ),
        decoration: _dashboardCardDecoration(elevated: _hovered),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: _hovered ? 0.14 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primary.withValues(alpha: _hovered ? 0.22 : 0.14),
                    ),
                  ),
                  child: Icon(widget.icon, color: primary, size: 20),
                ),
                const Spacer(),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    color: AppPalette.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.loading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            else
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${widget.value}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.navy,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                height: 1.25,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Risk + haftalik ozet; mevcut [ReportMapService.fetchItems] verisinden turetilir.
class _DashboardInsightRow extends StatelessWidget {
  const _DashboardInsightRow({
    required this.mapMetrics,
    required this.weeklyReports,
    required this.loading,
    required this.isWide,
  });

  final DashboardReportMetrics mapMetrics;
  final List<ReportMapItem> weeklyReports;
  final bool loading;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
        if (isWide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _RiskDistributionCard(
                    metrics: mapMetrics,
                    loading: loading,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _WeeklyReportsCard(
                    reports: weeklyReports,
                    loading: loading,
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            _RiskDistributionCard(metrics: mapMetrics, loading: loading),
            const SizedBox(height: 12),
            _WeeklyReportsCard(reports: weeklyReports, loading: loading),
          ],
        );
  }
}

class _RiskDistributionCard extends StatelessWidget {
  const _RiskDistributionCard({
    required this.metrics,
    required this.loading,
  });

  final DashboardReportMetrics metrics;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final buckets = metrics.riskBuckets;
    final total = metrics.total;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: _dashboardCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Risk Dagilimi', style: _dashboardSectionTitleStyle),
              ),
              if (!loading && total > 0)
                Text(
                  '$total ihbar',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Toplam ${metrics.total} ihbar — risk / aciliyet',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          if (loading)
            const SizedBox(
              height: 88,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            )
          else if (total == 0)
            const Text(
              'Henuz ihbar verisi yok.',
              style: TextStyle(
                color: AppPalette.textMuted,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ...DashboardReportMetrics.riskOrder.map((key) {
              final count = buckets[key] ?? 0;
              final share = total == 0 ? 0.0 : count / total;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _InsightBarRow(
                  label: DashboardReportMetrics.riskLabelTr(key),
                  count: count,
                  share: share,
                  color: _riskColor(key),
                ),
              );
            }),
        ],
      ),
    );
  }

  static Color _riskColor(String key) {
    switch (key) {
      case 'high':
        return const Color(0xFFE11D48);
      case 'medium':
        return AppPalette.warning;
      case 'low':
        return AppPalette.success;
      default:
        return AppPalette.textMuted;
    }
  }
}

class _WeeklyReportsCard extends StatelessWidget {
  const _WeeklyReportsCard({
    required this.reports,
    required this.loading,
  });

  final List<ReportMapItem> reports;
  final bool loading;

  static const _dayLabels = ['Pzt', 'Sal', 'Car', 'Per', 'Cum', 'Cmt', 'Paz'];

  @override
  Widget build(BuildContext context) {
    final counts = _lastSevenDayCounts(reports);
    final max = counts.fold<int>(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: _dashboardCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Haftalik Ihbar Ozeti', style: _dashboardSectionTitleStyle),
          const SizedBox(height: 4),
          Text(
            'Son 7 gun',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          if (loading)
            const SizedBox(
              height: 88,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            )
          else
            SizedBox(
              height: 96,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final c = counts[i];
                  final h = max == 0 ? 8.0 : (c / max) * 72 + 8;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '$c',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOut,
                            height: h,
                            decoration: BoxDecoration(
                              color: AppPalette.primaryBlue
                                  .withValues(alpha: c > 0 ? 0.75 : 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _dayLabels[i],
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppPalette.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  static List<int> _lastSevenDayCounts(List<ReportMapItem> items) {
    if (items.isEmpty) return List<int>.filled(7, 0);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));
    final counts = List<int>.filled(7, 0);
    for (final item in items) {
      // Tarih yoksa bugune yaz (haritada ihbar varken grafik 0 kalmasin).
      final created = (item.createdAt ?? now).toLocal();
      final day = DateTime(created.year, created.month, created.day);
      if (day.isBefore(start)) continue;
      final index = day.difference(start).inDays;
      if (index >= 0 && index < 7) counts[index]++;
    }
    return counts;
  }
}

class _InsightBarRow extends StatelessWidget {
  const _InsightBarRow({
    required this.label,
    required this.count,
    required this.share,
    required this.color,
  });

  final String label;
  final int count;
  final double share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppPalette.navy,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: share.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: AppPalette.pageBackground,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            color: AppPalette.navy,
          ),
        ),
      ],
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({
    required this.reports,
    required this.loading,
  });

  final List<ReportMapItem> reports;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: _dashboardCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Son Aktiviteler', style: _dashboardSectionTitleStyle),
              const Spacer(),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppPalette.pageBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppPalette.border),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.timeline_rounded,
                  size: 18,
                  color: AppPalette.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              if (loading) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                );
              }

              final activities = _buildActivities(reports);
              if (activities.isEmpty) {
                return const Text(
                  'Gosterilecek guncel aktivite bulunamadi.',
                  style: TextStyle(
                    color: AppPalette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < activities.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: AppPalette.border.withValues(alpha: 0.85),
                      ),
                    _ActivityRow(
                      title: activities[i].title,
                      time: _timeAgoLabel(activities[i].at),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static List<_ActivityEntry> _buildActivities(List<ReportMapItem> items) {
    final out = <_ActivityEntry>[];
    for (final item in items) {
      if (item.createdAt != null) {
        final isUrgent = (item.urgency ?? '').toLowerCase().trim() == 'urgent';
        out.add(
          _ActivityEntry(
            title: isUrgent ? 'Acil ihbar isleme alindi' : 'Yeni ihbar olusturuldu',
            at: item.createdAt!,
          ),
        );
      }
      if (item.assignedAt != null) {
        out.add(
          _ActivityEntry(
            title: 'Ihbar gonullu tarafindan ustlenildi',
            at: item.assignedAt!,
          ),
        );
      }
      final status = (item.status ?? '').toUpperCase().trim();
      if ((status == 'RESOLVED' || status == 'CLOSED') && item.createdAt != null) {
        out.add(
          _ActivityEntry(
            title: 'Bir ihbar cozuldu',
            at: item.createdAt!,
          ),
        );
      }
    }
    out.sort((a, b) => b.at.compareTo(a.at));
    return out.take(4).toList();
  }

  static String _timeAgoLabel(DateTime time) {
    final now = DateTime.now().toUtc();
    final atUtc = time.toUtc();
    final diff = now.difference(atUtc);
    if (diff.inMinutes < 1) return 'simdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk once';
    if (diff.inHours < 24) return '${diff.inHours} saat once';
    return '${diff.inDays} gun once';
  }
}

class _ActivityEntry {
  const _ActivityEntry({required this.title, required this.at});

  final String title;
  final DateTime at;
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.title,
    required this.time,
  });

  final String title;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppPalette.primaryBlue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppPalette.navy,
                fontWeight: FontWeight.w600,
                height: 1.3,
                fontSize: 13.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            time,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
