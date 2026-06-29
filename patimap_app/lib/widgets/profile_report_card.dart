import 'package:flutter/material.dart';

import '../report_pin.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../utils/report_ui_formatters.dart';

class ProfileReportCard extends StatelessWidget {
  const ProfileReportCard({
    super.key,
    required this.pin,
    this.onDetailResult,
  });

  final ReportPin pin;
  final ValueChanged<Object?>? onDetailResult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final result = await Navigator.of(context).pushNamed(
            AppRoutes.reportDetail,
            arguments: pin,
          );
          onDetailResult?.call(result);
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.pets_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        pin.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.heading,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _riskBadge(pin.displayRiskLevel),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _row(
                  context,
                  'Tür',
                  pin.animalTypeLabelTr,
                ),
                _row(
                  context,
                  'Durum',
                  pin.situationLabelTr,
                ),
                _row(
                  context,
                  'Aciliyet',
                  pin.urgencyLabelTr,
                ),
                _row(
                  context,
                  'Kayıt durumu',
                  reportRecordStatusLabelTr(pin.status),
                ),
                _row(
                  context,
                  'Tarih',
                  formatReportDate(pin.createdAt),
                ),
                _row(
                  context,
                  'Adres notu',
                  (pin.locationNote?.trim().isNotEmpty ?? false)
                      ? pin.locationNote!.trim()
                      : '—',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade900,
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _riskBadge(String level) {
    final (fg, bg) = switch (level) {
      'Yüksek Risk' => (const Color(0xFFB91C1C), const Color(0xFFFEE2E2)),
      'Orta Risk' => (const Color(0xFFB45309), const Color(0xFFFFEDD5)),
      'Düşük Risk' => (const Color(0xFF166534), const Color(0xFFDCFCE7)),
      _ => (const Color(0xFF475569), const Color(0xFFF1F5F9)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        level,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
