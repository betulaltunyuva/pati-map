import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../report_pin.dart';
import '../services/report_service.dart';
import '../theme/app_colors.dart';
import '../utils/risk_analyzer.dart';

class ReportDetailPage extends StatefulWidget {
  const ReportDetailPage({
    super.key,
    required this.pin,
    this.autoOpenChat = false,
  });

  final ReportPin pin;
  final bool autoOpenChat;

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();

}

class _ReportDetailPageState extends State<ReportDetailPage> {
  late ReportPin _pin = widget.pin;
  bool _assigning = false;
  bool _deleting = false;
  bool _chatAutoOpened = false;
  String? _locationText;
  bool _resolvingLocation = false;

  @override
  void initState() {
    super.initState();
    _resolveLocationText();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoOpenChatIfNeeded());
  }

  Future<void> _resolveLocationText() async {
    setState(() => _resolvingLocation = true);
    try {
      await setLocaleIdentifier('tr_TR');
      final places = await placemarkFromCoordinates(
        _pin.latitude,
        _pin.longitude,
      );
      final first = places.isNotEmpty ? places.first : null;
      if (!mounted) return;
      setState(() => _locationText = _formatPlacemark(first));
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationText = null);
    } finally {
      if (mounted) setState(() => _resolvingLocation = false);
    }
  }

  String? _formatPlacemark(Placemark? p) {
    if (p == null) return null;
    final parts = <String>[
      if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality!.trim(),
      if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
      if ((p.street ?? '').trim().isNotEmpty) p.street!.trim(),
      if ((p.thoroughfare ?? '').trim().isNotEmpty) p.thoroughfare!.trim(),
      if ((p.name ?? '').trim().isNotEmpty) p.name!.trim(),
      if ((p.subAdministrativeArea ?? '').trim().isNotEmpty)
        p.subAdministrativeArea!.trim(),
      if ((p.administrativeArea ?? '').trim().isNotEmpty)
        p.administrativeArea!.trim(),
      if ((p.country ?? '').trim().isNotEmpty) p.country!.trim(),
    ];
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yyyy = local.year.toString();
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd.$mm.$yyyy $hh:$min';
  }

  Future<void> _onVolunteerAssignPressed() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      setState(() => _assigning = true);
      final updated = await ReportService.assignVolunteerToReport(
        reportId: _pin.id,
      );

      if (!mounted) return;
      setState(() => _pin = updated);

      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: const Text('İhbar gönüllü olarak üstlenildi'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(ReportService.messageForError(e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  Future<void> _onDeletePressed() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('İhbarı sil'),
          content: const Text('Bu ihbarı silmek istediğine emin misin?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      setState(() => _deleting = true);
      await ReportService.deleteOwnReport(reportId: _pin.id);
      if (!mounted) return;
      Navigator.of(context).pop({
        'deleted': true,
        'id': _pin.id,
      });
    } catch (e, st) {
      debugPrint('Report delete error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(ReportService.messageForError(e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _openMessagePanel({
    required String ownerId,
    required String assignedVolunteerId,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReportMessageSheet(
        reportId: _pin.id,
        ownerId: ownerId,
        assignedVolunteerId: assignedVolunteerId,
      ),
    );
  }

  bool _canCurrentUserOpenChat() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final ownerId = _pin.userId;
    final assignedVolunteerId = _pin.assignedVolunteerId;
    if (currentUserId == null || ownerId == null || assignedVolunteerId == null) {
      return false;
    }
    return currentUserId == ownerId || currentUserId == assignedVolunteerId;
  }

  Future<void> _autoOpenChatIfNeeded() async {
    if (!widget.autoOpenChat || _chatAutoOpened) return;
    if (!_canCurrentUserOpenChat()) return;
    final ownerId = _pin.userId;
    final assignedVolunteerId = _pin.assignedVolunteerId;
    if (ownerId == null || assignedVolunteerId == null) return;
    _chatAutoOpened = true;
    await _openMessagePanel(
      ownerId: ownerId,
      assignedVolunteerId: assignedVolunteerId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isMine = _pin.userId != null && _pin.userId == currentUserId;
    final ownershipLabel = isMine ? 'Bana ait ihbar' : 'Topluluk ihbarı';
    final ownerId = _pin.userId;
    final assignedVolunteerId = _pin.assignedVolunteerId;
    final canOpenChat = currentUserId != null &&
        ownerId != null &&
        assignedVolunteerId != null &&
        (currentUserId == ownerId || currentUserId == assignedVolunteerId);

    final isAlreadyAssigned = _pin.isAssigned;
    final assignedVolunteerLabel = _pin.assignedVolunteerId == null
        ? null
        : (_pin.assignedVolunteerId == currentUserId
            ? 'Siz'
            : 'Gönüllü (${_pin.assignedVolunteerId!.substring(0, math.min(8, _pin.assignedVolunteerId!.length))})');

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(_pin),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.heading,
        title: const Text(
          'İhbar Detayı',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _pin.color.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.pets_rounded, color: _pin.color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _pin.title.trim().isEmpty ? 'İhbar' : _pin.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.heading,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_pin.photoUrl != null && _pin.photoUrl!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            height: 190,
                            child: Image.network(
                              _pin.photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox.shrink(),
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  color: Colors.grey.shade100,
                                  alignment: Alignment.center,
                                  child: const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    _detailRow('Tür', _pin.animalTypeLabelTr),
                    _detailRow('Durum', _pin.situationLabelTr),
                    _detailRow('Aciliyet', _pin.urgencyLabelTr),
                    _detailRow('Risk Seviyesi', _pin.displayRiskLevel),
                    _detailRow('Risk Skoru', '%${_pin.displayAiScore}'),
                    _statusRow(
                      label: 'Kayıt durumu',
                      status: _pin.status,
                      isAssigned: isAlreadyAssigned,
                    ),
                    _detailRow(
                      'Harita adresi',
                      _resolvingLocation
                          ? 'Adres çözümleniyor...'
                          : (_locationText ??
                              '${_pin.latitude.toStringAsFixed(5)}, ${_pin.longitude.toStringAsFixed(5)}'),
                    ),
                    _detailRow(
                      'Adres tarifi',
                      (_pin.locationNote?.trim().isNotEmpty ?? false)
                          ? _pin.locationNote!.trim()
                          : '—',
                    ),
                    _detailRow('Oluşturulma', _formatDate(_pin.createdAt)),
                    _detailRow('Sahiplik', ownershipLabel),
                    if (isAlreadyAssigned && assignedVolunteerLabel != null)
                      _detailRow('Üstlenen', assignedVolunteerLabel),
                    const SizedBox(height: 12),
                    Text(
                      'Açıklama',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.heading,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _pin.description.trim().isEmpty ? '—' : _pin.description.trim(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade800,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _AiEmergencyAssistantCard(
                      description: _pin.description,
                      initialRiskLevel: _pin.displayRiskLevel,
                      initialAiScore: _pin.displayAiScore,
                    ),
                  ],
                ),
              ),
              if (!isMine) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.successSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.volunteer_activism_outlined,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Gönüllü olarak üstlenme',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.heading,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: (isAlreadyAssigned || _assigning)
                              ? null
                              : _onVolunteerAssignPressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isAlreadyAssigned
                                ? Colors.grey.shade300
                                : AppColors.primary,
                            foregroundColor: const Color(0xFFFFFFFF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            isAlreadyAssigned
                                ? 'Bu ihbar üstlenildi'
                                : (_assigning ? 'Üstleniliyor…' : 'Gönüllü Olarak Üstlen'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (canOpenChat) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => _openMessagePanel(
                      ownerId: ownerId,
                      assignedVolunteerId: assignedVolunteerId,
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('Mesaj Gönder'),
                  ),
                ),
              ],
              if (isMine) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _deleting ? null : _onDeletePressed,
                    icon: _deleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline_rounded),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    label: Text(_deleting ? 'Siliniyor…' : 'İhbarı Sil'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow({
    required String label,
    required String status,
    required bool isAssigned,
  }) {
    final pillBg = isAssigned
        ? AppColors.primary.withValues(alpha: 0.12)
        : Colors.grey.shade100;
    final pillBorder = isAssigned
        ? AppColors.primary.withValues(alpha: 0.35)
        : Colors.grey.shade300;
    final pillText = isAssigned ? 'Üstlenildi' : status.toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: pillBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: pillBorder),
              ),
              child: Text(
                pillText,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isAssigned ? AppColors.heading : Colors.grey.shade800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _AssistantAnswer { yes, no, unsure }

class _AiEmergencyAssistantResult {
  const _AiEmergencyAssistantResult({
    required this.level,
    required this.score,
    required this.summary,
    required this.action,
  });

  final String level;
  final int score;
  final String summary;
  final String action;
}

class _AiEmergencyAssistantCard extends StatefulWidget {
  const _AiEmergencyAssistantCard({
    required this.description,
    required this.initialRiskLevel,
    required this.initialAiScore,
  });

  final String description;
  final String initialRiskLevel;
  final int initialAiScore;

  @override
  State<_AiEmergencyAssistantCard> createState() => _AiEmergencyAssistantCardState();
}

class _AiEmergencyAssistantCardState extends State<_AiEmergencyAssistantCard> {
  final Map<int, _AssistantAnswer> _answers = <int, _AssistantAnswer>{};
  bool _analyzing = false;
  _AiEmergencyAssistantResult? _result;

  static const _questions = <String>[
    'Hayvan hareket edebiliyor mu?',
    'Kanama veya acik yara var mi?',
    'Trafik kazasi suphesi var mi?',
    'Hayvan cok halsiz veya baygin gorunuyor mu?',
    'Yemek veya su tuketebiliyor mu?',
    'Yakininda tehlikeli bir alan var mi?',
  ];

  void _runAnalysis() async {
    setState(() => _analyzing = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));

    var score = 0;
    for (final answer in _answers.values) {
      if (answer == _AssistantAnswer.unsure) {
        score += 5;
      }
    }
    if (_answers[0] == _AssistantAnswer.no) score += 25;
    if (_answers[1] == _AssistantAnswer.yes) score += 30;
    if (_answers[2] == _AssistantAnswer.yes) score += 30;
    if (_answers[3] == _AssistantAnswer.yes) score += 25;
    if (_answers[4] == _AssistantAnswer.no) score += 15;
    if (_answers[5] == _AssistantAnswer.yes) score += 15;

    final result = switch (score) {
      >= 70 => _AiEmergencyAssistantResult(
          level: 'Yüksek Risk',
          score: score,
          summary: 'Bu durum acil müdahale gerektirebilir.',
          action:
              'Hayvana güvenli mesafeden yaklaşın, bulunduğu alanı güvenli hale getirin ve en yakın veterinerle iletişime geçin.',
        ),
      >= 35 => _AiEmergencyAssistantResult(
          level: 'Orta Risk',
          score: score,
          summary: 'Bu ihbar takip edilmesi gereken bir durum olabilir.',
          action:
              'Hayvanın durumu takip edilmelidir. Su ve güvenli alan sağlanabilir, durum kötüleşirse veteriner desteği alınmalıdır.',
        ),
      _ => _AiEmergencyAssistantResult(
          level: 'Düşük Risk',
          score: score,
          summary: 'Durum şu an düşük riskli görünüyor.',
          action:
              'Hayvan gözlemlenmeli ve ihtiyaç varsa destek sağlanmalıdır.',
        ),
    };

    if (!mounted) return;
    setState(() {
      _result = result;
      _analyzing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final baseAnalysis = analyzeReportRisk(widget.description);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.smart_toy_outlined,
                  size: 18,
                  color: Color(0xFF4338CA),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Acil Durum Değerlendirme Asistanı',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.heading,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Risk Seviyesi: ${widget.initialRiskLevel}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w600,
                ),
          ),
          Text(
            'Risk Skoru: %${widget.initialAiScore == 0 ? baseAnalysis.aiScore : widget.initialAiScore}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade700,
                ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _questions.length; i++) ...[
            Text(
              _questions[i],
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.heading,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _answerChip(i, _AssistantAnswer.yes, 'Evet'),
                _answerChip(i, _AssistantAnswer.no, 'Hayır'),
                _answerChip(i, _AssistantAnswer.unsure, 'Emin değilim'),
              ],
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: _analyzing ? null : _runAnalysis,
              child: _analyzing
                  ? const Text('Durum değerlendiriliyor...')
                  : const Text('Analiz Et'),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            _buildResultCard(_result!),
          ],
        ],
      ),
    );
  }

  Widget _answerChip(int q, _AssistantAnswer answer, String label) {
    final selected = _answers[q] == answer;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _answers[q] = answer),
    );
  }

  Widget _buildResultCard(_AiEmergencyAssistantResult result) {
    final (bg, border, textColor) = switch (result.level) {
      'Yüksek Risk' => (
          const Color(0xFFFEF2F2),
          const Color(0xFFFECACA),
          const Color(0xFFB91C1C),
        ),
      'Orta Risk' => (
          const Color(0xFFFFF7ED),
          const Color(0xFFFED7AA),
          const Color(0xFFB45309),
        ),
      'Düşük Risk' => (
          const Color(0xFFF0FDF4),
          const Color(0xFFBBF7D0),
          const Color(0xFF166534),
        ),
      _ => (
          const Color(0xFFF8FAFC),
          const Color(0xFFE2E8F0),
          const Color(0xFF334155),
        ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Risk Seviyesi: ${result.level}',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Risk Skoru: %${result.score}',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(result.summary),
          const SizedBox(height: 6),
          Text(
            result.action,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _ReportMessageSheet extends StatefulWidget {
  const _ReportMessageSheet({
    required this.reportId,
    required this.ownerId,
    required this.assignedVolunteerId,
  });

  final String reportId;
  final String ownerId;
  final String assignedVolunteerId;

  @override
  State<_ReportMessageSheet> createState() => _ReportMessageSheetState();
}

class _ReportMessageSheetState extends State<_ReportMessageSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<ReportMessage> _messages = const [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$hh:$min';
  }

  Future<void> _loadMessages() async {
    try {
      final list = await ReportService.fetchReportMessages(
        reportId: widget.reportId,
      );
      if (!mounted) return;
      setState(() {
        _messages = list;
        _loading = false;
        _error = null;
      });
      _jumpToBottom();
    } catch (e, st) {
      debugPrint('Report messages load error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ReportService.messageForError(e);
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    final receiverId = currentUserId == widget.ownerId
        ? widget.assignedVolunteerId
        : widget.ownerId;

    try {
      setState(() => _sending = true);
      await ReportService.sendReportMessage(
        reportId: widget.reportId,
        receiverId: receiverId,
        message: text,
        senderLabel: currentUserId == widget.ownerId
            ? 'İhbar sahibinden'
            : 'Gönüllüden',
      );
      _controller.clear();
      await _loadMessages();
    } catch (e, st) {
      debugPrint('Report message send error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(ReportService.messageForError(e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Mesajlaşma',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.heading,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : _messages.isEmpty
                            ? const Center(
                                child: Text('Henüz mesaj yok. İlk mesajı gönderin.'),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                                itemCount: _messages.length,
                                itemBuilder: (context, index) {
                                  final item = _messages[index];
                                  final isMe = item.senderId == currentUserId;
                                  return Align(
                                    alignment: isMe
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      constraints: const BoxConstraints(maxWidth: 290),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? AppColors.primary.withValues(alpha: 0.12)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.message,
                                            style: TextStyle(
                                              color: Colors.grey.shade900,
                                              height: 1.3,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatDate(item.createdAt),
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Mesajınızı yazın',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 44,
                      child: FilledButton(
                        onPressed: _sending ? null : _send,
                        child: _sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
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
  }
}
