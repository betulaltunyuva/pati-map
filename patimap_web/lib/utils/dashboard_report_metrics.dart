import '../models/report_map_item.dart';

/// Dashboard’daki sayisal alanlar icin kaynak: verilen [reports] listesi.
class DashboardReportMetrics {
  const DashboardReportMetrics({
    required this.reports,
    required this.openCount,
    required this.urgentCount,
    required this.resolvedCount,
    required this.volunteerCount,
    required this.riskBuckets,
  });

  final List<ReportMapItem> reports;
  final int openCount;
  final int urgentCount;
  final int resolvedCount;
  final int volunteerCount;
  final Map<String, int> riskBuckets;

  int get total => reports.length;

  /// Haritada marker olarak gosterilen ihbarlar (gercek enlem/boylam).
  static List<ReportMapItem> visibleOnMap(List<ReportMapItem> reports) =>
      reports.where((r) => r.hasGeoCoordinates).toList(growable: false);

  factory DashboardReportMetrics.fromReports(List<ReportMapItem> reports) {
    var open = 0;
    var urgent = 0;
    var resolved = 0;
    final buckets = <String, int>{
      'high': 0,
      'medium': 0,
      'low': 0,
      'unknown': 0,
    };

    var volunteer = 0;
    for (final report in reports) {
      final status = (report.status ?? 'OPEN').toUpperCase().trim();
      if (_isOpenStatus(status)) open++;

      if (_isUrgentReport(report)) urgent++;

      if (_isResolvedStatus(status)) resolved++;

      if (_hasAssignedVolunteer(report)) volunteer++;

      final bucket = _riskBucketKey(report);
      buckets[bucket] = (buckets[bucket] ?? 0) + 1;
    }

    return DashboardReportMetrics(
      reports: reports,
      openCount: open,
      urgentCount: urgent,
      resolvedCount: resolved,
      volunteerCount: volunteer,
      riskBuckets: buckets,
    );
  }

  static bool _isOpenStatus(String status) =>
      status == 'OPEN' || status == 'ACIK';

  static bool _isResolvedStatus(String status) =>
      status == 'RESOLVED' ||
      status == 'CLOSED' ||
      status == 'SOLVED' ||
      status == 'COMPLETED' ||
      status == 'TAMAMLANDI' ||
      status == 'COZULDU' ||
      status == 'ÇÖZÜLDÜ';

  static bool _hasAssignedVolunteer(ReportMapItem report) {
    final id = report.assignedVolunteerId?.trim();
    return id != null && id.isNotEmpty;
  }

  static bool _isUrgentReport(ReportMapItem report) {
    if (_riskBucketKey(report) == 'high') return true;
    final u = (report.urgency ?? '').toLowerCase().trim();
    return u == 'urgent' ||
        u == 'high' ||
        u.contains('acil') ||
        u.contains('yuksek') ||
        u.contains('yüksek');
  }

  /// risk_level varsa onu kullan; yoksa aciliyetten turet.
  static String _riskBucketKey(ReportMapItem report) {
    final risk = report.riskLevel?.toLowerCase().trim();
    if (risk != null && risk.isNotEmpty) {
      if (risk == 'high' ||
          risk == 'urgent' ||
          risk.contains('yuksek') ||
          risk.contains('yüksek')) {
        return 'high';
      }
      if (risk == 'low' || risk.contains('dusuk') || risk.contains('düşük')) {
        return 'low';
      }
      if (risk == 'medium' ||
          risk == 'normal' ||
          risk.contains('orta')) {
        return 'medium';
      }
      if (risk.contains('belir') || risk == 'unknown') {
        return 'unknown';
      }
    }

    switch ((report.urgency ?? '').toLowerCase().trim()) {
      case 'urgent':
        return 'high';
      case 'low':
        return 'low';
      case 'normal':
        return 'medium';
      default:
        return 'unknown';
    }
  }

  static String riskLabelTr(String key) {
    switch (key) {
      case 'high':
        return 'Yuksek';
      case 'medium':
        return 'Orta';
      case 'low':
        return 'Dusuk';
      default:
        return 'Belirsiz';
    }
  }

  static const riskOrder = ['high', 'medium', 'low', 'unknown'];
}
