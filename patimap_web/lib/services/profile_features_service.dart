import 'package:supabase_flutter/supabase_flutter.dart';

class WebProfileSnapshot {
  const WebProfileSnapshot({
    required this.displayName,
    required this.email,
    this.firstName,
    this.lastName,
    this.roleLabel,
    this.avatarUrl,
  });

  final String displayName;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? roleLabel;
  final String? avatarUrl;
}

class WebNotificationItem {
  const WebNotificationItem({
    required this.id,
    required this.reportId,
    required this.title,
    required this.body,
    required this.isRead,
    this.createdAt,
  });

  final String id;
  final String reportId;
  final String title;
  final String body;
  final bool isRead;
  final DateTime? createdAt;

  factory WebNotificationItem.fromRow(Map<String, dynamic> row) {
    final readRaw = row['is_read'];
    return WebNotificationItem(
      id: row['id']?.toString() ?? '',
      reportId: row['report_id']?.toString() ?? '',
      title: row['title']?.toString() ?? 'Bildirim',
      body: row['body']?.toString() ?? '',
      isRead: readRaw == true ||
          readRaw?.toString().toLowerCase().trim() == 'true' ||
          readRaw?.toString().trim() == '1',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
    );
  }
}

class WebReportMessage {
  const WebReportMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    this.createdAt,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime? createdAt;

  factory WebReportMessage.fromRow(Map<String, dynamic> row) {
    return WebReportMessage(
      id: row['id']?.toString() ?? '',
      senderId: row['sender_id']?.toString() ?? '',
      receiverId: row['receiver_id']?.toString() ?? '',
      message: row['message']?.toString() ?? '',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
    );
  }
}

abstract final class ProfileFeaturesService {
  static SupabaseClient get _client => Supabase.instance.client;
  static const String _notificationsTable = 'notifications';
  static const String _messagesTable = 'report_messages';
  static const String _reportsTable = 'reports';
  static const String _profilesTable = 'profiles';

  static Future<WebProfileSnapshot> loadSnapshot() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Oturum bulunamadi.');
    }

    final meta = user.userMetadata ?? <String, dynamic>{};
    final authFirst = _trimOrNull(meta['first_name']);
    final authLast = _trimOrNull(meta['last_name']);
    final authAvatar = _trimOrNull(meta['avatar_url']);
    final authEmail = user.email ?? '—';

    String? firstName = authFirst;
    String? lastName = authLast;
    String? roleLabel;
    String? avatarUrl = authAvatar;
    var email = authEmail;

    final row = await _readProfileRow(user.id);
    if (row != null) {
      firstName = _trimOrNull(row['first_name']) ?? firstName;
      lastName = _trimOrNull(row['last_name']) ?? lastName;
      roleLabel = _trimOrNull(row['role']);
      email = _trimOrNull(row['email']) ?? email;
      avatarUrl = _trimOrNull(row['avatar_url']) ?? avatarUrl;
    }

    final full = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    return WebProfileSnapshot(
      displayName: full.isNotEmpty ? full : email,
      email: email,
      firstName: firstName,
      lastName: lastName,
      roleLabel: roleLabel ?? 'Gonullu Kullanici',
      avatarUrl: avatarUrl,
    );
  }

  static Future<void> updateName({
    required String firstName,
    required String lastName,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Oturum bulunamadi.');

    final first = firstName.trim();
    final last = lastName.trim();
    if (first.isEmpty || last.isEmpty) {
      throw const AuthException('Ad ve soyad zorunludur.');
    }

    final payload = <String, dynamic>{
      'first_name': first,
      'last_name': last,
      'email': user.email,
    };

    var updated = false;
    try {
      final rows = await _client
          .from(_profilesTable)
          .update(payload)
          .eq('user_id', user.id)
          .select('user_id')
          .limit(1);
      updated = rows.isNotEmpty;
    } catch (_) {}

    if (!updated) {
      try {
        final rows = await _client
            .from(_profilesTable)
            .update(payload)
            .eq('id', user.id)
            .select('id')
            .limit(1);
        updated = rows.isNotEmpty;
      } catch (_) {}
    }

    if (!updated) {
      await _client.from(_profilesTable).insert({
        'user_id': user.id,
        ...payload,
      });
    }

    try {
      await _client.auth.updateUser(
        UserAttributes(
          data: {'first_name': first, 'last_name': last},
        ),
      );
    } catch (_) {}
  }

  static Future<List<WebNotificationItem>> fetchMyNotifications() async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Oturum bulunamadi.');

    final rows = await _client
        .from(_notificationsTable)
        .select('id, report_id, title, body, is_read, created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final list = rows as List<dynamic>;
    return list
        .map(
          (e) => WebNotificationItem.fromRow(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  static Future<void> markNotificationRead(String notificationId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client
        .from(_notificationsTable)
        .update({'is_read': true})
        .eq('id', _dbIdValue(notificationId))
        .eq('user_id', user.id);
  }

  static Future<List<WebReportMessage>> fetchMessages(String reportId) async {
    final rows = await _client
        .from(_messagesTable)
        .select('id, sender_id, receiver_id, message, created_at')
        .eq('report_id', _dbIdValue(reportId))
        .order('created_at', ascending: true);
    final list = rows as List<dynamic>;
    return list
        .map((e) => WebReportMessage.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> sendMessage({
    required String reportId,
    required String messageText,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Oturum bulunamadi.');
    final body = messageText.trim();
    if (body.isEmpty) return;

    final rows = await _client
        .from(_reportsTable)
        .select('id, user_id, assigned_volunteer_id')
        .eq('id', _dbIdValue(reportId))
        .limit(1);
    if (rows.isEmpty) throw const AuthException('Ihbar bulunamadi.');
    final report = Map<String, dynamic>.from(rows.first as Map);
    final ownerId = _trimOrNull(report['user_id']);
    final assignedId = _trimOrNull(report['assigned_volunteer_id']);
    if (ownerId == null || assignedId == null) {
      throw const AuthException('Mesajlasma icin ihbarin gonulluye atanmis olmasi gerekir.');
    }

    String receiverId;
    String senderLabel;
    if (user.id == ownerId) {
      receiverId = assignedId;
      senderLabel = 'Ihbar sahibinden';
    } else if (user.id == assignedId) {
      receiverId = ownerId;
      senderLabel = 'Gonulluden';
    } else {
      throw const AuthException('Bu ihbar icin mesaj gonderme yetkiniz yok.');
    }

    await _client.from(_messagesTable).insert({
      'report_id': _dbIdValue(reportId),
      'sender_id': user.id,
      'receiver_id': receiverId,
      'message': body,
    });

    await _client.from(_notificationsTable).insert({
      'user_id': receiverId,
      'report_id': _dbIdValue(reportId),
      'title': 'Yeni mesaj',
      'body': '$senderLabel yeni mesaj: ${_truncate(body, 120)}',
      'is_read': false,
    });
  }

  static Future<Map<String, dynamic>?> _readProfileRow(String userId) async {
    try {
      final rows = await _client
          .from(_profilesTable)
          .select('id, user_id, first_name, last_name, email, role, avatar_url')
          .eq('user_id', userId)
          .limit(1);
      if (rows.isNotEmpty) return Map<String, dynamic>.from(rows.first as Map);
    } catch (_) {}
    try {
      final rows = await _client
          .from(_profilesTable)
          .select('id, user_id, first_name, last_name, email, role, avatar_url')
          .eq('id', userId)
          .limit(1);
      if (rows.isNotEmpty) return Map<String, dynamic>.from(rows.first as Map);
    } catch (_) {}
    return null;
  }

  static String _truncate(String text, int max) {
    if (text.length <= max) return text;
    return '${text.substring(0, max)}...';
  }

  static Object _dbIdValue(String raw) {
    final v = raw.trim();
    final asInt = int.tryParse(v);
    if (asInt != null) return asInt;
    return v;
  }

  static String? _trimOrNull(Object? value) {
    final t = value?.toString().trim();
    if (t == null || t.isEmpty) return null;
    return t;
  }
}
