import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/report_map_item.dart';
import '../theme/app_palette.dart';

BoxDecoration _detailPanelDecoration() {
  return BoxDecoration(
    color: AppPalette.cardBackground,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppPalette.border),
    boxShadow: [
      BoxShadow(
        color: AppPalette.navy.withValues(alpha: 0.042),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

class ReportDetailPanel extends StatelessWidget {
  const ReportDetailPanel({
    super.key,
    required this.report,
    required this.assigning,
    required this.onAssign,
    required this.onClose,
    this.panelHeight,
    this.compactLayout = false,
  });

  final ReportMapItem? report;
  final bool assigning;
  final VoidCallback onAssign;
  final VoidCallback onClose;

  /// Dashboard’da harita yuksekligiyle hizalamak icin (ornegin 540).
  final double? panelHeight;

  /// Dashboard: daha sıkı yerlesim ve 2 kolonlu ozet alanlari.
  final bool compactLayout;

  @override
  Widget build(BuildContext context) {
    if (report == null) {
      return _buildEmpty();
    }
    return _buildFilled(report!);
  }

  Widget _buildEmpty() {
    final body = Container(
      clipBehavior: Clip.antiAlias,
      decoration: panelHeight != null
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppPalette.border),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppPalette.cardBackground,
                  AppPalette.primaryBlue.withValues(alpha: 0.06),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.navy.withValues(alpha: 0.042),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            )
          : _detailPanelDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: AppPalette.primaryBlue.withValues(alpha: 0.55),
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(20),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppPalette.navy.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.touch_app_outlined,
                      size: 32,
                      color: AppPalette.primaryBlue.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppPalette.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Secim bekleniyor',
                      style: TextStyle(
                        color: AppPalette.primaryBlue,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Ihbar detayi',
                    style: TextStyle(
                      color: AppPalette.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Haritada bir marker secin. Baslik, aciliyet, konum ve aciklama bu alanda gorunecek.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      fontSize: 13.2,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: const [
                      _EmptyHintChip(icon: Icons.touch_app_outlined, label: 'Marker sec'),
                      _EmptyHintChip(icon: Icons.info_outline_rounded, label: 'Detaylari oku'),
                      _EmptyHintChip(icon: Icons.groups_outlined, label: 'Ustlen'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (panelHeight != null) {
      return SizedBox(height: panelHeight, child: body);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: body,
    );
  }

  Widget _buildFilled(ReportMapItem selected) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isMine = selected.userId != null && selected.userId == currentUserId;
    final ownershipLabel = isMine ? 'Bana ait ihbar' : 'Topluluk ihbari';

    final urgency = (selected.urgency ?? '').toLowerCase().trim();
    final urgencyColor = urgency == 'urgent'
        ? const Color(0xFFE11D48)
        : urgency == 'low'
            ? AppPalette.textMuted
            : AppPalette.warning;

    final content = Container(
      clipBehavior: Clip.antiAlias,
      decoration: _detailPanelDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: AppPalette.primaryBlue.withValues(alpha: 0.65),
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(20),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          selected.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.navy,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppPalette.pageBackground,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppPalette.border),
                        ),
                        child: IconButton(
                          tooltip: 'Paneli kapat',
                          onPressed: onClose,
                          iconSize: 18,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusChip(
                        label: selected.urgencyLabelTr,
                        color: urgencyColor,
                        icon: Icons.flag_outlined,
                      ),
                      _StatusChip(
                        label: selected.isAssigned ? 'Ustlenildi' : 'Acik',
                        color: selected.isAssigned ? AppPalette.success : AppPalette.primaryBlue,
                        icon: selected.isAssigned ? Icons.verified_outlined : Icons.circle_outlined,
                      ),
                      _StatusChip(
                        label: ownershipLabel,
                        color: AppPalette.textMuted,
                        icon: Icons.person_outline_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (selected.photoUrl != null && selected.photoUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(compactLayout ? 12 : 14),
                      child: SizedBox(
                        height: compactLayout ? 118 : 180,
                        width: double.infinity,
                        child: Image.network(
                          selected.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  if (selected.photoUrl != null && selected.photoUrl!.isNotEmpty)
                    SizedBox(height: compactLayout ? 10 : 12),
                  if (compactLayout)
                    _buildCompactDetailGrid(selected, ownershipLabel)
                  else ...[
                    _detailRow('Tur', selected.animalTypeLabelTr),
                    _detailRow('Durum', selected.situationLabelTr),
                    _detailRow('Aciliyet', selected.urgencyLabelTr),
                    _detailRow(
                      'Kayit durumu',
                      selected.isAssigned
                          ? 'Ustlenildi'
                          : (selected.status ?? 'OPEN'),
                    ),
                    _detailRow(
                      'Konum',
                      '${selected.latitude.toStringAsFixed(5)}, ${selected.longitude.toStringAsFixed(5)}',
                    ),
                    _detailRow(
                      'Adres tarifi',
                      selected.locationNote?.trim().isNotEmpty == true
                          ? selected.locationNote!.trim()
                          : '—',
                    ),
                    _detailRow('Olusturulma', _formatDate(selected.createdAt)),
                    _detailRow('Sahiplik', ownershipLabel),
                    _detailRow(
                      'Ustlenen',
                      selected.assignedVolunteerId?.trim().isNotEmpty == true
                          ? selected.assignedVolunteerId!
                          : '—',
                    ),
                  ],
                  SizedBox(height: compactLayout ? 8 : 6),
                  Text(
                    'Aciklama',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppPalette.navy,
                      fontSize: compactLayout ? 12.5 : 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selected.description?.trim().isNotEmpty == true
                        ? selected.description!.trim()
                        : '—',
                    maxLines: compactLayout ? 3 : null,
                    overflow: compactLayout ? TextOverflow.ellipsis : null,
                    style: TextStyle(
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: AppPalette.navy,
                      fontSize: compactLayout ? 12.5 : 14,
                    ),
                  ),
                  SizedBox(height: compactLayout ? 10 : 12),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: (selected.isAssigned || assigning) ? null : onAssign,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: selected.isAssigned
                            ? Colors.grey.shade300
                            : AppPalette.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        selected.isAssigned
                            ? 'Bu ihbar ustlenildi'
                            : (assigning ? 'Ustleniliyor...' : 'Gonullu Olarak Ustlen'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (panelHeight != null) {
      return SizedBox(height: panelHeight, child: content);
    }
    return content;
  }

  static String _riskLabelForReport(ReportMapItem report) {
    final risk = report.riskLevel?.trim();
    if (risk != null && risk.isNotEmpty) return risk;
    switch ((report.urgency ?? '').toLowerCase().trim()) {
      case 'urgent':
        return 'Yuksek';
      case 'low':
        return 'Dusuk';
      case 'normal':
        return 'Orta';
      default:
        return 'Belirsiz';
    }
  }

  Widget _buildCompactDetailGrid(ReportMapItem selected, String ownershipLabel) {
    final cells = <({String label, String value})>[
      (label: 'Tur', value: selected.animalTypeLabelTr),
      (label: 'Durum', value: selected.situationLabelTr),
      (label: 'Aciliyet', value: selected.urgencyLabelTr),
      (
        label: 'Risk',
        value: _riskLabelForReport(selected),
      ),
      (
        label: 'Kayit',
        value: selected.isAssigned ? 'Ustlenildi' : (selected.status ?? 'OPEN'),
      ),
      (label: 'Sahiplik', value: ownershipLabel),
      (label: 'Olusturulma', value: _formatDate(selected.createdAt)),
      (
        label: 'Konum',
        value:
            '${selected.latitude.toStringAsFixed(4)}, ${selected.longitude.toStringAsFixed(4)}',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cells
              .map(
                (cell) => SizedBox(
                  width: (constraints.maxWidth - 8) / 2,
                  child: _compactDetailCell(cell.label, cell.value),
                ),
              )
              .toList(),
        );
      },
    );
  }

  static Widget _compactDetailCell(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppPalette.pageBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppPalette.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppPalette.navy,
              fontSize: 12.5,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(
                color: AppPalette.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppPalette.navy,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yyyy = local.year.toString();
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd.$mm.$yyyy $hh:$min';
  }
}

class _EmptyHintChip extends StatelessWidget {
  const _EmptyHintChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppPalette.primaryBlue),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppPalette.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
