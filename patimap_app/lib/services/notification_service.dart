import 'package:supabase_flutter/supabase_flutter.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.reportId,
    required this.title,
    required this.body,
    required this.isRead,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String reportId;
  final String title;
  final String body;
  final bool isRead;
  final DateTime? createdAt;

  factory AppNotification.fromRow(Map<String, dynamic> row) {
    final readRaw = row['is_read'];
    final isRead = readRaw == true ||
        readRaw?.toString().toLowerCase().trim() == 'true' ||
        readRaw?.toString().trim() == '1';

    return AppNotification(
      id: row['id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      reportId: row['report_id']?.toString() ?? '',
      title: row['title']?.toString() ?? 'Bildirim',
      body: row['body']?.toString() ?? '',
      isRead: isRead,
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
    );
  }
}

abstract final class NotificationService {
  static const String _tableName = 'notifications';
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<AppNotification>> fetchMyNotifications() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Oturum bulunamadı.');
    }

    final rows = await _client
        .from(_tableName)
        .select('id, user_id, report_id, title, body, is_read, created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final list = rows as List<dynamic>;
    return list
        .map((e) => AppNotification.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> markAsRead({
    required String notificationId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client
        .from(_tableName)
        .update({'is_read': true})
        .eq('id', _dbIdValue(notificationId))
        .eq('user_id', user.id);
  }

  static Future<void> createMessageNotification({
    required String receiverId,
    required String reportId,
    required String messageText,
    required String senderLabel,
  }) async {
    final bodyText = '$senderLabel yeni mesaj: $messageText';
    await _client.from(_tableName).insert({
      'user_id': receiverId,
      'report_id': _dbIdValue(reportId),
      'title': 'Yeni mesaj',
      'body': bodyText,
      'is_read': false,
    });
  }

  static Object _dbIdValue(String raw) {
    final v = raw.trim();
    final asInt = int.tryParse(v);
    if (asInt != null) return asInt;
    return v;
  }
}
