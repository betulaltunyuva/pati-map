import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../components/panel_empty_state.dart';
import '../components/panel_header_actions.dart';
import '../components/scroll_reveal.dart';
import '../components/web_panel_layout.dart';
import '../theme/app_palette.dart';
import 'dashboard_page.dart';
import 'map_page.dart';
import 'settings_page.dart';
import 'volunteers_page.dart';
import '../utils/panel_responsive.dart';
import '../utils/risk_analyzer.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _loading = true;
  String? _error;
  String? _processingReportId;
  final Map<String, String> _resolvedLocationById = <String, String>{};

  List<_ReportRow> _all = const [];
  String _statusFilter = 'all';
  String _urgencyFilter = 'all';
  String _animalFilter = 'all';
  String _riskFilter = 'all';
  String _search = '';

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
      final rows = await Supabase.instance.client
          .from('reports')
          .select(
            'id, animal_type, custom_animal_type, status, urgency, latitude, longitude, '
            'location_note, description, photo_url, created_at, report_status, '
            'custom_report_status, assigned_volunteer_id, user_id, risk_level, ai_score',
          )
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _all = (rows as List<dynamic>)
            .map((e) => _ReportRow.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        _loading = false;
      });
      _resolveLocationLabels(_all);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _messageForError(e);
      });
      debugPrint('ReportsPage load error: $e');
    }
  }

  Future<void> _resolveLocationLabels(List<_ReportRow> rows) async {
    for (final row in rows) {
      if (_resolvedLocationById.containsKey(row.id)) continue;
      if (row.latitude == null || row.longitude == null) continue;
      final label = await _reverseLocationToCityDistrict(
        latitude: row.latitude!,
        longitude: row.longitude!,
      );
      if (!mounted) return;
      if (label == null) continue;
      setState(() {
        _resolvedLocationById[row.id] = label;
      });
    }
  }

  Future<String?> _reverseLocationToCityDistrict({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'format': 'jsonv2',
        'zoom': '18',
        'addressdetails': '1',
      });
      final response = await http.get(
        uri,
        headers: const {'Accept': 'application/json'},
      );
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final rawAddress = decoded['address'];
      if (rawAddress is! Map) return null;
      final address = Map<String, dynamic>.from(rawAddress);

      final city = _firstAddressValue(address, const [
        'city',
        'town',
        'state',
        'province',
      ]);
      final district = _firstAddressValue(address, const [
        'neighbourhood',
        'suburb',
        'quarter',
        'village',
      ]);
      if (city == null && district == null) return null;
      if (city != null && district != null) return '$city / $district';
      return city ?? district;
    } catch (_) {
      return null;
    }
  }

  String? _firstAddressValue(Map<String, dynamic> address, List<String> keys) {
    for (final key in keys) {
      final value = address[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  Future<void> _updateStatus(_ReportRow row) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Durum guncellemek icin once giris yapmalisiniz.'),
        ),
      );
      return;
    }
    final next = await showDialog<String>(
      context: context,
      builder: (context) {
        var current = row.statusRaw;
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            title: const Text('Durumu Guncelle'),
            content: DropdownButtonFormField<String>(
              initialValue: current,
              items: const [
                DropdownMenuItem(value: 'OPEN', child: Text('Acik')),
                DropdownMenuItem(value: 'ASSIGNED', child: Text('Ustlenildi')),
                DropdownMenuItem(value: 'RESOLVED', child: Text('Cozuldu')),
                DropdownMenuItem(value: 'CLOSED', child: Text('Kapali')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setLocalState(() => current = value);
                }
              },
              decoration: const InputDecoration(labelText: 'Durum'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Iptal'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(current),
                child: const Text('Kaydet'),
              ),
            ],
          ),
        );
      },
    );
    if (next == null || next == row.statusRaw) return;

    setState(() => _processingReportId = row.id);
    try {
      await Supabase.instance.client
          .from('reports')
          .update({'status': next})
          .eq('id', _dbIdValue(row.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Ihbar durumu guncellendi.'),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(_messageForError(e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _processingReportId = null);
    }
  }

  Future<void> _deleteReport(_ReportRow row) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Ihbar silmek icin once giris yapmalisiniz.'),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ihbari Sil'),
        content: const Text('Bu ihbari silmek istediginize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgec'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _processingReportId = row.id);
    try {
      await Supabase.instance.client
          .from('reports')
          .delete()
          .eq('id', _dbIdValue(row.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Ihbar silindi.'),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(_messageForError(e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _processingReportId = null);
    }
  }

  void _showDetail(_ReportRow row) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780, maxHeight: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ihbar Detayi',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.navy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Olusturma: ${row.createdLabel}',
                            style: const TextStyle(
                              color: AppPalette.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppPalette.pageBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppPalette.border),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        iconSize: 18,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (row.photoUrl != null && row.photoUrl!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      row.photoUrl!,
                      height: 240,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _metaChip('Tur: ${row.animalTypeLabel}'),
                    _metaChip('Durum: ${row.statusLabel}'),
                    _metaChip('Aciliyet: ${row.urgencyLabel}'),
                    _metaChip(row.isMine ? 'Sahiplik: Bana ait' : 'Sahiplik: Topluluk'),
                  ],
                ),
                const SizedBox(height: 14),
                _kv('Konum', _locationLabelFor(row)),
                _kv(
                  'Adres tarifi',
                  row.addressDescriptionLabel,
                ),
                _kv(
                  'Aciklama',
                  row.description?.trim().isNotEmpty == true ? row.description! : '—',
                ),
                const SizedBox(height: 6),
                _AiEmergencyAssistantCard(reportId: row.id),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metaChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppPalette.pageBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppPalette.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppPalette.navy,
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: AppPalette.pageBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppPalette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              k,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppPalette.navy,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              v,
              style: const TextStyle(
                color: AppPalette.navy,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_ReportRow> get _filtered {
    return _all.where((r) {
      if (_statusFilter != 'all' && r.statusRaw != _statusFilter) return false;
      if (_urgencyFilter != 'all' && r.urgencyRaw != _urgencyFilter) return false;
      if (_animalFilter != 'all' && r.animalTypeRaw != _animalFilter) return false;
      if (_riskFilter != 'all') {
        final risk = r.displayRiskLevel;
        final mapped = switch (_riskFilter) {
          'high' => 'Yüksek Risk',
          'medium' => 'Orta Risk',
          'low' => 'Düşük Risk',
          'unknown' => 'Belirlenmedi',
          _ => '',
        };
        if (risk != mapped) return false;
      }
      if (_search.trim().isNotEmpty) {
        final q = _search.trim().toLowerCase();
        final text =
            '${r.animalTypeLabel} ${r.statusLabel} ${r.urgencyLabel} ${r.locationLabel} '
            '${r.description ?? ''} ${r.displayRiskLevel}'
                .toLowerCase();
        if (!text.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Set<String> get _statusOptions => {'all', ..._all.map((e) => e.statusRaw)};
  Set<String> get _urgencyOptions => {'all', ..._all.map((e) => e.urgencyRaw)};
  Set<String> get _animalOptions => {'all', ..._all.map((e) => e.animalTypeRaw)};

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
    final rows = _filtered;
    return WebPanelLayout(
      revealScope: 'reports',
      currentItem: WebMenuItem.reports,
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
            detectKey: const ValueKey<String>('reports_page_intro'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ihbarlar',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tum ihbarlar burada listelenir, filtrelenir ve yonetilir.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ScrollReveal(
            detectKey: const ValueKey<String>('reports_page_filters'),
            child: _FilterBar(
              statusValue: _statusFilter,
              urgencyValue: _urgencyFilter,
              animalValue: _animalFilter,
              riskValue: _riskFilter,
              statusOptions: _statusOptions.toList()..sort(),
              urgencyOptions: _urgencyOptions.toList()..sort(),
              animalOptions: _animalOptions.toList()..sort(),
              riskOptions: const ['all', 'high', 'medium', 'low', 'unknown'],
              onStatusChanged: (v) => setState(() => _statusFilter = v),
              onUrgencyChanged: (v) => setState(() => _urgencyFilter = v),
              onAnimalChanged: (v) => setState(() => _animalFilter = v),
              onRiskChanged: (v) => setState(() => _riskFilter = v),
              onSearchChanged: (v) => setState(() => _search = v),
              onRefresh: _load,
            ),
          ),
          const SizedBox(height: 14),
          ScrollReveal(
            detectKey: const ValueKey<String>('reports_page_body'),
            child: _loading
                ? const PanelListSkeleton(itemCount: 4)
                : _error != null
                    ? PanelErrorState(message: _error!)
                    : rows.isEmpty
                        ? PanelEmptyState(
                            icon: Icons.inbox_outlined,
                            title: _all.isEmpty
                                ? 'Henuz ihbar bulunmuyor.'
                                : 'Filtreye uygun ihbar bulunamadi.',
                            subtitle: _all.isEmpty
                                ? 'Yeni bir ihbar olusturuldugunda burada listelenecek.'
                                : 'Filtreleri degistirerek tekrar deneyin.',
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: rows.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final row = rows[index];
                              return _ReportCard(
                                row: row,
                                locationLabel: _locationLabelFor(row),
                                busy: _processingReportId == row.id,
                                onDetail: () => _showDetail(row),
                                onUpdate: () => _updateStatus(row),
                                onDelete: () => _deleteReport(row),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  String _locationLabelFor(_ReportRow row) {
    final resolved = _resolvedLocationById[row.id];
    if (resolved != null && resolved.trim().isNotEmpty) return resolved;
    return row.locationLabel;
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.statusValue,
    required this.urgencyValue,
    required this.animalValue,
    required this.riskValue,
    required this.statusOptions,
    required this.urgencyOptions,
    required this.animalOptions,
    required this.riskOptions,
    required this.onStatusChanged,
    required this.onUrgencyChanged,
    required this.onAnimalChanged,
    required this.onRiskChanged,
    required this.onSearchChanged,
    required this.onRefresh,
  });

  final String statusValue;
  final String urgencyValue;
  final String animalValue;
  final String riskValue;
  final List<String> statusOptions;
  final List<String> urgencyOptions;
  final List<String> animalOptions;
  final List<String> riskOptions;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onUrgencyChanged;
  final ValueChanged<String> onAnimalChanged;
  final ValueChanged<String> onRiskChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = PanelResponsive.isMobile(constraints.maxWidth);
        final fieldWidth = mobile ? constraints.maxWidth : 170.0;
        final searchWidth = mobile ? constraints.maxWidth : 260.0;

        return Container(
      padding: EdgeInsets.all(mobile ? 10 : 14),
      decoration: BoxDecoration(
        color: AppPalette.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.border),
      ),
      child: Wrap(
        spacing: mobile ? 8 : 10,
        runSpacing: mobile ? 8 : 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: fieldWidth,
            child: _dropdown(
              value: statusValue,
              label: 'Durum',
              items: statusOptions,
              labelForItem: _statusLabel,
              onChanged: onStatusChanged,
            ),
          ),
          SizedBox(
            width: fieldWidth,
            child: _dropdown(
              value: urgencyValue,
              label: 'Aciliyet',
              items: urgencyOptions,
              labelForItem: _urgencyLabel,
              onChanged: onUrgencyChanged,
            ),
          ),
          SizedBox(
            width: fieldWidth,
            child: _dropdown(
              value: animalValue,
              label: 'Hayvan turu',
              items: animalOptions,
              labelForItem: _animalLabel,
              onChanged: onAnimalChanged,
            ),
          ),
          SizedBox(
            width: fieldWidth,
            child: _dropdown(
              value: riskValue,
              label: 'Risk Seviyesi',
              items: riskOptions,
              labelForItem: _riskFilterLabel,
              onChanged: onRiskChanged,
            ),
          ),
          SizedBox(
            width: searchWidth,
            child: TextField(
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Ara: aciklama, konum, tur...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: onRefresh,
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.primaryBlue,
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Yenile'),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _dropdown({
    required String value,
    required String label,
    required List<String> items,
    required String Function(String) labelForItem,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((e) => DropdownMenuItem<String>(value: e, child: Text(labelForItem(e))))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _AiEmergencyAssistantCard extends StatefulWidget {
  const _AiEmergencyAssistantCard({required this.reportId});

  final String reportId;

  @override
  State<_AiEmergencyAssistantCard> createState() => _AiEmergencyAssistantCardState();
}

class _AiEmergencyAssistantCardState extends State<_AiEmergencyAssistantCard> {
  static const List<_AssistantQuestion> _questions = [
    _AssistantQuestion(
      id: 'can_move',
      text: 'Hayvan hareket edebiliyor mu?',
      scoreOnNo: 25,
    ),
    _AssistantQuestion(
      id: 'bleeding',
      text: 'Kanama veya acik yara var mi?',
      scoreOnYes: 30,
    ),
    _AssistantQuestion(
      id: 'traffic',
      text: 'Trafik kazasi suphesi var mi?',
      scoreOnYes: 30,
    ),
    _AssistantQuestion(
      id: 'faint',
      text: 'Hayvan cok halsiz veya baygin gorunuyor mu?',
      scoreOnYes: 25,
    ),
    _AssistantQuestion(
      id: 'cannot_eat',
      text: 'Yemek veya su tuketebiliyor mu?',
      scoreOnNo: 15,
    ),
    _AssistantQuestion(
      id: 'danger_zone',
      text: 'Yakininda tehlikeli bir alan var mi?',
      scoreOnYes: 15,
    ),
  ];

  final Map<String, _AnswerOption> _answers = {};
  _AssistantResult? _result;

  @override
  Widget build(BuildContext context) {
    final hasAllAnswers = _answers.length == _questions.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE4EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppPalette.primaryBlue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.psychology_alt_rounded,
                  size: 15,
                  color: AppPalette.primaryBlue,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Acil Durum Değerlendirme Asistanı',
                  style: TextStyle(
                    color: AppPalette.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final q in _questions) ...[
            _questionRow(q),
            const SizedBox(height: 8),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: hasAllAnswers ? _runAnalysis : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.primaryBlue,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: const Text('Analiz Et'),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 10),
            _resultCard(_result!),
          ],
        ],
      ),
    );
  }

  Widget _questionRow(_AssistantQuestion q) {
    final value = _answers[q.id];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          q.text,
          style: const TextStyle(
            color: AppPalette.navy,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            _answerChip(q.id, _AnswerOption.yes, 'Evet', value == _AnswerOption.yes),
            _answerChip(q.id, _AnswerOption.no, 'Hayir', value == _AnswerOption.no),
            _answerChip(
              q.id,
              _AnswerOption.unknown,
              'Emin degilim',
              value == _AnswerOption.unknown,
            ),
          ],
        ),
      ],
    );
  }

  Widget _answerChip(
    String questionId,
    _AnswerOption option,
    String label,
    bool selected,
  ) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _answers[questionId] = option),
      selectedColor: AppPalette.primaryBlue.withValues(alpha: 0.16),
      side: BorderSide(
        color: selected ? AppPalette.primaryBlue : AppPalette.border,
      ),
      labelStyle: TextStyle(
        color: selected ? AppPalette.primaryBlue : AppPalette.navy,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }

  void _runAnalysis() {
    var score = 0;
    for (final q in _questions) {
      final answer = _answers[q.id];
      if (answer == _AnswerOption.yes) score += q.scoreOnYes;
      if (answer == _AnswerOption.no) score += q.scoreOnNo;
    }

    final risk = switch (score) {
      >= 70 => 'Yüksek Risk',
      >= 35 => 'Orta Risk',
      _ => 'Düşük Risk',
    };

    final (summary, suggestion) = switch (risk) {
      'Yüksek Risk' => (
        'Hayvanin hayati riski olabilir.',
        'Bu durum acil müdahale gerektirebilir. Hayvana güvenli mesafeden yaklaşın, mümkünse bulunduğu alanı güvenli hale getirin ve en yakın veterinerle iletişime geçin.',
      ),
      'Orta Risk' => (
        'Durum orta seviyede riskli gorunuyor.',
        'Hayvanın durumu takip edilmelidir. Su ve güvenli alan sağlanabilir, durum kötüleşirse veteriner desteği alınmalıdır.',
      ),
      _ => (
        'Acil risk dusuk seviyede gorunuyor.',
        'Durum şu an düşük riskli görünüyor. Hayvan gözlemlenmeli ve ihtiyaç varsa destek sağlanmalıdır.',
      ),
    };

    setState(() {
      _result = _AssistantResult(
        riskLevel: risk,
        score: score,
        summary: summary,
        suggestion: suggestion,
      );
    });
  }

  Widget _resultCard(_AssistantResult result) {
    final (border, bg) = switch (result.riskLevel) {
      'Yüksek Risk' => (const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
      'Orta Risk' => (const Color(0xFFEA580C), const Color(0xFFFFF7ED)),
      _ => (const Color(0xFF16A34A), const Color(0xFFF0FDF4)),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${result.riskLevel} • ${result.score} / 140',
            style: TextStyle(
              color: border,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            result.summary,
            style: const TextStyle(
              color: AppPalette.navy,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            result.suggestion,
            style: const TextStyle(
              color: AppPalette.navy,
              fontWeight: FontWeight.w500,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantQuestion {
  const _AssistantQuestion({
    required this.id,
    required this.text,
    this.scoreOnYes = 0,
    this.scoreOnNo = 0,
  });

  final String id;
  final String text;
  final int scoreOnYes;
  final int scoreOnNo;
}

class _AssistantResult {
  const _AssistantResult({
    required this.riskLevel,
    required this.score,
    required this.summary,
    required this.suggestion,
  });

  final String riskLevel;
  final int score;
  final String summary;
  final String suggestion;
}

enum _AnswerOption { yes, no, unknown }

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.row,
    required this.locationLabel,
    required this.busy,
    required this.onDetail,
    required this.onUpdate,
    required this.onDelete,
  });

  final _ReportRow row;
  final String locationLabel;
  final bool busy;
  final VoidCallback onDetail;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final compact = PanelResponsive.isMobile(PanelResponsive.ofWidth(context));
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppPalette.cardBackground,
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        border: Border.all(color: AppPalette.border),
        boxShadow: [
          BoxShadow(
            color: AppPalette.navy.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PhotoThumb(url: row.photoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _riskChip(row.displayRiskLevel),
                    _chip('Tur: ${row.animalTypeLabel}'),
                    _chip('Durum: ${row.statusLabel}'),
                    _chip('Aciliyet: ${row.urgencyLabel}'),
                    _chip('Tarih: ${row.createdLabel}'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Konum: $locationLabel',
            style: const TextStyle(
              color: AppPalette.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            row.description?.trim().isNotEmpty == true ? row.description! : 'Aciklama yok.',
            style: TextStyle(
              color: Colors.grey.shade800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          _aiAnalysisPanel(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : onDetail,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Detay Gor'),
              ),
              FilledButton.icon(
                onPressed: busy ? null : onUpdate,
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.primaryBlue,
                ),
                icon: const Icon(Icons.sync_alt_rounded, size: 18),
                label: const Text('Durumu Guncelle'),
              ),
              FilledButton.icon(
                onPressed: busy ? null : onDelete,
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.error,
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Sil'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppPalette.pageBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppPalette.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppPalette.navy,
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
      ),
    );
  }

  Widget _riskChip(String? riskLevel) {
    final label = (riskLevel == null || riskLevel.trim().isEmpty)
        ? 'Belirlenmedi'
        : riskLevel.trim();
    final (bg, border, text) = switch (label) {
      'Yüksek Risk' => (
        const Color(0xFFFEE2E2),
        const Color(0xFFFCA5A5),
        const Color(0xFFB91C1C),
      ),
      'Orta Risk' => (
        const Color(0xFFFFEDD5),
        const Color(0xFFFDBA74),
        const Color(0xFFC2410C),
      ),
      'Düşük Risk' => (
        const Color(0xFFDCFCE7),
        const Color(0xFF86EFAC),
        const Color(0xFF15803D),
      ),
      _ => (
        const Color(0xFFF1F5F9),
        const Color(0xFFCBD5E1),
        const Color(0xFF475569),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    );
  }

  Widget _aiAnalysisPanel() {
    final risk = row.displayRiskLevel;
    final score = row.displayAiScore;
    final message = switch (risk) {
      'Yüksek Risk' => 'Bu ihbar acil müdahale gerektirebilir.',
      'Orta Risk' => 'Bu ihbar takip edilmesi gereken bir durum olabilir.',
      'Düşük Risk' => 'Bu ihbar düşük öncelikli olarak değerlendirildi.',
      _ => 'Bu ihbar için henüz risk değerlendirmesi bulunmuyor.',
    };

    final (accent, bg) = switch (risk) {
      'Yüksek Risk' => (const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
      'Orta Risk' => (const Color(0xFFEA580C), const Color(0xFFFFF7ED)),
      'Düşük Risk' => (const Color(0xFF16A34A), const Color(0xFFF0FDF4)),
      _ => (const Color(0xFF64748B), const Color(0xFFF8FAFC)),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_rounded, size: 14, color: accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Risk Değerlendirmesi',
                  style: TextStyle(
                    color: AppPalette.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Risk Seviyesi: $risk',
                  style: const TextStyle(
                    color: AppPalette.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Risk Skoru: $score / 100',
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                    height: 1.25,
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

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 92,
        height: 72,
        color: AppPalette.pageBackground,
        child: (url != null && url!.trim().isNotEmpty)
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.image_not_supported_outlined,
                  color: AppPalette.textMuted,
                ),
              )
            : const Icon(Icons.image_outlined, color: AppPalette.textMuted),
      ),
    );
  }
}

class _ReportRow {
  const _ReportRow({
    required this.id,
    required this.ownerUserId,
    required this.isMine,
    required this.animalTypeRaw,
    required this.customAnimalType,
    required this.statusRaw,
    required this.urgencyRaw,
    required this.latitude,
    required this.longitude,
    required this.locationNote,
    required this.description,
    required this.photoUrl,
    required this.createdAt,
    required this.riskLevel,
    required this.aiScore,
  });

  final String id;
  final String ownerUserId;
  final bool isMine;
  final String animalTypeRaw;
  final String? customAnimalType;
  final String statusRaw;
  final String urgencyRaw;
  final double? latitude;
  final double? longitude;
  final String? locationNote;
  final String? description;
  final String? photoUrl;
  final DateTime? createdAt;
  final String? riskLevel;
  final int? aiScore;

  factory _ReportRow.fromMap(Map<String, dynamic> map) {
    final ownerId = map['user_id']?.toString().trim() ?? '';
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    return _ReportRow(
      id: map['id']?.toString() ?? '',
      ownerUserId: ownerId,
      isMine: currentUserId != null && _isOwner(ownerId, currentUserId),
      animalTypeRaw: (map['animal_type']?.toString().trim().toLowerCase().isNotEmpty ?? false)
          ? map['animal_type'].toString().trim().toLowerCase()
          : 'other',
      customAnimalType: _trimOrNull(map['custom_animal_type']),
      statusRaw: (_trimOrNull(map['status']) ?? 'OPEN').toUpperCase(),
      urgencyRaw: (_trimOrNull(map['urgency']) ?? 'normal').toLowerCase(),
      latitude: _toDouble(map['latitude']),
      longitude: _toDouble(map['longitude']),
      locationNote: _trimOrNull(map['location_note']),
      description: _trimOrNull(map['description']),
      photoUrl: _trimOrNull(map['photo_url']),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      riskLevel: _trimOrNull(map['risk_level']),
      aiScore: _toInt(map['ai_score']),
    );
  }

  String get animalTypeLabel => _animalLabel(animalTypeRaw, customAnimalType);
  String get statusLabel => _statusLabel(statusRaw);
  String get urgencyLabel => _urgencyLabel(urgencyRaw);
  String get displayRiskLevel {
    if (riskLevel != null && riskLevel!.trim().isNotEmpty) {
      return riskLevel!.trim();
    }
    final text = description?.trim() ?? '';
    if (text.isEmpty) return 'Belirlenmedi';
    return analyzeReportRisk(text).riskLevel;
  }
  int get displayAiScore {
    if (aiScore != null) return aiScore!;
    final text = description?.trim() ?? '';
    if (text.isEmpty) return 0;
    return analyzeReportRisk(text).aiScore;
  }

  String get locationLabel {
    final parsed = _parseLocationParts(locationNote);
    final locationText = parsed.$1;
    if (locationText != null && locationText.isNotEmpty) return locationText;
    if (latitude == null || longitude == null) return '—';
    return '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}';
  }

  String get addressDescriptionLabel {
    final parsed = _parseLocationParts(locationNote);
    final descriptionText = parsed.$2;
    if (descriptionText != null && descriptionText.isNotEmpty) return descriptionText;
    return '—';
  }

  String get createdLabel {
    if (createdAt == null) return '—';
    final local = createdAt!.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yyyy = local.year.toString();
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd.$mm.$yyyy $hh:$min';
  }
}

(String?, String?) _parseLocationParts(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return (null, null);
  const separator = ' - ';
  final idx = text.indexOf(separator);
  if (idx <= 0) return (text, null);
  final location = text.substring(0, idx).trim();
  final description = text.substring(idx + separator.length).trim();
  return (
    location.isEmpty ? null : location,
    description.isEmpty ? null : description,
  );
}

bool _isOwner(String ownerUserId, String currentUserId) {
  return ownerUserId.trim().toLowerCase() == currentUserId.trim().toLowerCase();
}

String _statusLabel(String raw) {
  if (raw.toLowerCase() == 'all') return 'Tumu';
  switch (raw.toUpperCase()) {
    case 'OPEN':
      return 'Acik';
    case 'ASSIGNED':
      return 'Ustlenildi';
    case 'RESOLVED':
      return 'Cozuldu';
    case 'CLOSED':
      return 'Kapali';
    default:
      return raw;
  }
}

String _urgencyLabel(String raw) {
  if (raw.toLowerCase() == 'all') return 'Tumu';
  switch (raw.toLowerCase()) {
    case 'urgent':
      return 'Yuksek';
    case 'normal':
      return 'Orta';
    case 'low':
      return 'Dusuk';
    default:
      return raw;
  }
}

String _riskFilterLabel(String raw) {
  switch (raw) {
    case 'all':
      return 'Tümü';
    case 'high':
      return 'Yüksek Risk';
    case 'medium':
      return 'Orta Risk';
    case 'low':
      return 'Düşük Risk';
    case 'unknown':
      return 'Belirlenmedi';
    default:
      return raw;
  }
}

String _animalLabel(String raw, [String? custom]) {
  if (raw.toLowerCase() == 'all') return 'Tumu';
  if (raw == 'other' && custom != null && custom.isNotEmpty) return custom;
  switch (raw) {
    case 'cat':
      return 'Kedi';
    case 'dog':
      return 'Kopek';
    case 'bird':
      return 'Kus';
    case 'other':
      return 'Diger';
    default:
      return custom?.isNotEmpty == true ? custom! : raw;
  }
}

Object _dbIdValue(String raw) {
  final v = raw.trim();
  final asInt = int.tryParse(v);
  if (asInt != null) return asInt;
  return v;
}

String? _trimOrNull(Object? value) {
  final v = value?.toString().trim();
  if (v == null || v.isEmpty) return null;
  return v;
}

double? _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

int? _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String _messageForError(Object error) {
  if (error is AuthException) {
    final m = error.message.trim();
    if (m.isNotEmpty) return m;
  }
  if (error is PostgrestException) {
    final m = error.message.trim();
    if (m.isNotEmpty) return m;
  }
  return 'Islem su an tamamlanamadi. Lutfen tekrar deneyin.';
}
