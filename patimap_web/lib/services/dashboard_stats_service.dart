import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dashboard_stats.dart';
import 'report_map_service.dart';

class DashboardStatsService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<DashboardStats> fetchStats() async {
    // Dashboard kartları ile harita marker'larının aynı veri kümesini kullanması
    // için ihbar tarafını tek kaynaktan (ReportMapService) hesaplıyoruz.
    final items = await ReportMapService.fetchItems();
    final volunteerCount = await _safeCount(_countVolunteers, 'volunteer count');

    return DashboardStats(
      openReports: items.where((e) => _statusOf(e.status) == 'OPEN').length,
      urgentReports: items
          .where(
            (e) =>
                _urgencyOf(e.urgency) == 'urgent' &&
                _statusOf(e.status) != 'CLOSED',
          )
          .length,
      resolvedReports: items.where((e) => _statusOf(e.status) == 'CLOSED').length,
      volunteerCount: volunteerCount,
    );
  }

  static Future<int> _safeCount(
    Future<int> Function() loader,
    String label,
  ) async {
    try {
      return await loader();
    } catch (error) {
      debugPrint('DashboardStatsService $label error: $error');
      return 0;
    }
  }

  static Future<int> _countVolunteers() async {
    try {
      final roleRows = await _client
          .from('profiles')
          .select('id')
          .or('role.ilike.%Gönüllü%,role.ilike.%gonullu%,role.ilike.%volunteer%');
      final count = roleRows.length;
      if (count > 0) return count;
    } catch (error) {
      debugPrint('DashboardStatsService role based volunteer count failed: $error');
    }

    final fallback = await _client
        .from('profiles')
        .select('id');
    return fallback.length;
  }

  static String _statusOf(String? status) =>
      status?.toUpperCase().trim().isNotEmpty == true
      ? status!.toUpperCase().trim()
      : 'OPEN';

  static String _urgencyOf(String? urgency) => urgency?.toLowerCase().trim() ?? '';
}
