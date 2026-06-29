import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../report_pin.dart';
import 'notification_service.dart';

/// Supabase `public.reports` tablosuna ihbar ekler.
///
/// Projede tablo yoksa Supabase SQL Editor’da örnek:
/// ```sql
/// create table public.reports (
///   id uuid primary key default gen_random_uuid(),
///   user_id uuid not null references auth.users (id) on delete cascade,
///   type text not null,
///   urgency text not null,
///   description text not null,
///   status text not null default 'OPEN',
///   photo_url text,
///   latitude double precision,
///   longitude double precision,
///   created_at timestamptz not null default now(),
///   location_note text,
///   animal_type text,
///   custom_animal_type text,
///   report_status text,
///   custom_report_status text
/// );
/// -- İsteğe bağlı: mevcut projede kolon yoksa:
/// -- alter table public.reports add column if not exists animal_type text;
/// -- alter table public.reports add column if not exists custom_animal_type text;
/// -- alter table public.reports add column if not exists report_status text;
/// -- alter table public.reports add column if not exists custom_report_status text;
/// alter table public.reports enable row level security;
/// create policy "reports_insert_own" on public.reports
///   for insert to authenticated with check (auth.uid() = user_id);
/// create policy "reports_select_authenticated" on public.reports
///   for select to authenticated using (true);
/// -- Gönüllü üstlenme (PATCH) için örnek:
/// alter table public.reports add column if not exists assigned_volunteer_id uuid references auth.users (id);
/// alter table public.reports add column if not exists assigned_at timestamptz;
/// -- Bkz. supabase/migrations/*_add_reports_assigned_at.sql
/// create policy "reports_update_assign_volunteer" on public.reports
///   for update to authenticated using (true) with check (true);
/// ```
abstract final class ReportService {
  static const String tableName = 'reports';
  static const String _messagesTableName = 'report_messages';

  static const String _reportSelect =
      'id, user_id, assigned_volunteer_id, assigned_at, type, urgency, description, status, latitude, longitude, created_at, location_note, photo_url, animal_type, custom_animal_type, report_status, custom_report_status, risk_level, ai_score';

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<ReportPin?> fetchReportById(String reportId) async {
    final reportIdValue = _dbIdValue(reportId);
    final rows = await _client
        .from(tableName)
        .select(_reportSelect)
        .eq('id', reportIdValue)
        .limit(1);

    if (rows.isEmpty) return null;
    final first = rows.first as Map;
    return _rowToPin(Map<String, dynamic>.from(first));
  }

  /// Harita için ihbarlar (en yeni önce).
  /// OPEN: hep; ASSIGNED: `assigned_at` yoksa veya üstlenmeden beri 24 saat dolmadıysa.
  /// Kayıtlar silinmez; süresi dolanlar yalnızca harita listesinden çıkar.
  static Future<List<ReportPin>> fetchReportsForMap() async {
    final rows = await _client
        .from(tableName)
        .select(_reportSelect)
        .order('created_at', ascending: false);

    final list = rows as List<dynamic>;
    return list
        .map((e) => _rowToPin(Map<String, dynamic>.from(e as Map)))
        .where((p) => p.shouldShowOnMap())
        .toList();
  }

  static ReportPin _rowToPin(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final legacyTypeRaw = row['type']?.toString().trim();
    final reportStatusCol = row['report_status']?.toString().trim();
    final situationKey = (reportStatusCol != null && reportStatusCol.isNotEmpty)
        ? reportStatusCol
        : legacyTypeRaw;
    final type = reportPinVisualTypeFromSituationKey(situationKey);
    final urgency = _parseUrgency(row['urgency']?.toString());
    final description = row['description']?.toString() ?? '';
    final statusRaw = row['status']?.toString().trim() ?? '';
    final status = statusRaw.isEmpty ? 'OPEN' : statusRaw;
    final userId = row['user_id']?.toString();
    final assignedVolunteerId = row['assigned_volunteer_id']?.toString();
    final assignedAt = DateTime.tryParse(row['assigned_at']?.toString() ?? '');
    final locationNote = row['location_note']?.toString();
    final photoUrl = row['photo_url']?.toString();
    final animalTypeKey = row['animal_type']?.toString().trim();
    final customAnimalType = row['custom_animal_type']?.toString();
    final customReportStatus = row['custom_report_status']?.toString();
    final riskLevel = row['risk_level']?.toString();
    final aiScore = (row['ai_score'] as num?)?.toInt();
    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
    final lat = (row['latitude'] as num?)?.toDouble();
    final lng = (row['longitude'] as num?)?.toDouble();
    final (x, y) = MapPinPlacement.normalizedForReport(
      id: id,
      latitude: lat,
      longitude: lng,
    );

    final (fallbackLat, fallbackLng) = MapPinPlacement.latLngFromNormalized(
      x: x,
      y: y,
    );
    final resolvedLat = lat ?? fallbackLat;
    final resolvedLng = lng ?? fallbackLng;

    return ReportPin(
      id: id,
      type: type,
      urgency: urgency,
      isUnassigned: status.toUpperCase() == 'OPEN',
      x: x,
      y: y,
      latitude: resolvedLat,
      longitude: resolvedLng,
      title: _titleFromDescription(description),
      count: 1,
      description: description,
      status: status,
      userId: userId,
      createdAt: createdAt,
      assignedVolunteerId: assignedVolunteerId,
      assignedAt: assignedAt,
      locationNote: locationNote,
      photoUrl: photoUrl,
      animalTypeKey:
          (animalTypeKey != null && animalTypeKey.isNotEmpty) ? animalTypeKey : null,
      customAnimalType: customAnimalType,
      reportStatusKey:
          (situationKey != null && situationKey.isNotEmpty) ? situationKey : null,
      customReportStatus: customReportStatus,
      riskLevel: riskLevel,
      aiScore: aiScore,
    );
  }

  static String _titleFromDescription(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'İhbar';
    const maxLen = 48;
    if (t.length <= maxLen) return t;
    return '${t.substring(0, maxLen)}…';
  }

  static ReportUrgency _parseUrgency(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'urgent':
        return ReportUrgency.urgent;
      case 'normal':
        return ReportUrgency.normal;
      case 'low':
        return ReportUrgency.low;
      default:
        return ReportUrgency.normal;
    }
  }

  /// Yeni kayıtlarda yalnızca `animal_type`, `report_status`, isteğe bağlı `custom_*`
  /// kolonları doldurulur. Legacy `type` kolonu artık insert edilmez (eski satırlar
  /// okunurken `report_status` yoksa `type` fallback kullanılır).
  static Future<void> createReport({
    required ReportAnimalType animalType,
    String? customAnimalType,
    required ReportSituation reportSituation,
    String? customReportSituation,
    required ReportUrgency urgency,
    required String description,
    required String riskLevel,
    required int aiScore,
    double? latitude,
    double? longitude,
    String? locationNote,
    Uint8List? photoBytes,
    String? photoFileName,
    String? photoPath,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw ReportSubmitException(
        'Oturum bulunamadı. Lütfen tekrar giriş yapın.',
      );
    }

    String? photoUrl;
    if (photoBytes != null) {
      try {
        const bucket = 'report-images';
        if (photoPath == null || photoPath.isEmpty) {
          throw ReportSubmitException('Fotoğraf yolu bulunamadı.');
        }

        final rawName = (photoFileName ?? 'photo').split('/').last;
        final dot = rawName.lastIndexOf('.');
        final ext = dot == -1 ? '' : rawName.substring(dot + 1);
        final nameWithoutExt = dot == -1 ? rawName : rawName.substring(0, dot);
        final safeExt = (ext.isEmpty || ext.length > 5) ? 'jpg' : ext;
        final safeBaseName =
            nameWithoutExt.isEmpty ? 'photo' : nameWithoutExt;

        final objectPath =
            'reports/${user.id}/${DateTime.now().millisecondsSinceEpoch}_$safeBaseName.$safeExt';

        final storage = _client.storage.from(bucket);
        final file = File(photoPath);

        await storage.upload(
          objectPath,
          file,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

        photoUrl = storage.getPublicUrl(objectPath);

      } catch (e) {
        debugPrint('Fotoğraf upload hatası: $e');
        throw ReportSubmitException('Fotoğraf yüklenemedi. Lütfen tekrar deneyin.');
      }
    }

    final situationKey = reportSituation.storageKey;
    await _client.from(tableName).insert({
      'user_id': user.id,
      'animal_type': animalType.storageKey,
      'report_status': situationKey,
      'custom_animal_type': animalType == ReportAnimalType.other
          ? customAnimalType?.trim()
          : null,
      'custom_report_status': reportSituation == ReportSituation.other
          ? customReportSituation?.trim()
          : null,
      'urgency': urgency.name,
      'description': description,
      'risk_level': riskLevel,
      'ai_score': aiScore,
      'status': 'OPEN',
      'photo_url': photoUrl,
      'latitude': latitude,
      'longitude': longitude,
      'location_note': locationNote,
    });
  }

  static Future<ReportPin> assignVolunteerToReport({
    required String reportId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw ReportAssignException(
        'Gönüllü üstlenme için lütfen giriş yapın.',
      );
    }

    final current = await fetchReportById(reportId);
    if (current == null) {
      throw ReportAssignException('İhbar bulunamadı.');
    }

    if (current.status.toUpperCase() == 'ASSIGNED') {
      throw ReportAssignException('Bu ihbar zaten üstlenilmiş durumda.');
    }

    if (current.userId != null && current.userId == user.id) {
      throw ReportAssignException(
        'Kendi oluşturduğunuz ihbarı gönüllü olarak üstlenemezsiniz.',
      );
    }

    // return=representation: güncellenen satır yoksa (ör. RLS) liste boş gelir; sessiz başarı olmaz.
    final assignedNow = DateTime.now().toUtc();
    final reportIdValue = _dbIdValue(reportId);
    final data = await _client.from(tableName).update({
      'status': 'ASSIGNED',
      'assigned_volunteer_id': user.id,
      'assigned_at': assignedNow.toIso8601String(),
    }).eq('id', reportIdValue).select(_reportSelect);

    if (data.isEmpty) {
      throw ReportAssignException(
        'İhbar güncellenemedi. Supabase reports tablosu için UPDATE (RLS) politikası ve assigned_volunteer_id kolonu gerekli olabilir.',
      );
    }

    final updated = _rowToPin(
      Map<String, dynamic>.from(data.first as Map),
    );

    if (!updated.isAssigned ||
        updated.assignedVolunteerId == null ||
        updated.assignedVolunteerId != user.id) {
      throw ReportAssignException(
        'Güncelleme doğrulanamadı. RLS veya kolon eşlemesini kontrol edin.',
      );
    }

    return updated;
  }

  /// Profil: kullanıcının oluşturduğu ihbarlar (`user_id`).
  /// Haritadaki 24 saat süzmesi burada uygulanmaz; tam liste.
  static Future<List<ReportPin>> fetchReportsCreatedByUser(
    String userId,
  ) async {
    final rows = await _client
        .from(tableName)
        .select(_reportSelect)
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final list = rows as List<dynamic>;
    return list
        .map((e) => _rowToPin(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Profil: kullanıcının üstlendiği ihbarlar (`assigned_volunteer_id`).
  static Future<List<ReportPin>> fetchReportsAssignedToUser(
    String userId,
  ) async {
    final rows = await _client
        .from(tableName)
        .select(_reportSelect)
        .eq('assigned_volunteer_id', userId)
        .order('created_at', ascending: false);

    final list = rows as List<dynamic>;
    return list
        .map((e) => _rowToPin(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> deleteOwnReport({
    required String reportId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw ReportSubmitException('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
    }

    final deletedRows = await _client
        .from(tableName)
        .delete()
        .eq('id', _dbIdValue(reportId))
        .eq('user_id', user.id)
        .select('id')
        .limit(1);

    if (deletedRows.isEmpty) {
      throw ReportSubmitException(
        'İhbar silinemedi. Kayıt size ait olmayabilir veya daha önce silinmiş olabilir.',
      );
    }
  }

  static Future<List<ReportMessage>> fetchReportMessages({
    required String reportId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw ReportSubmitException('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
    }

    final reportIdValue = _dbIdValue(reportId);
    final rows = await _client
        .from(_messagesTableName)
        .select('id, report_id, sender_id, receiver_id, message, created_at')
        .eq('report_id', reportIdValue)
        .order('created_at', ascending: true);

    final list = rows as List<dynamic>;
    return list
        .map((e) => ReportMessage.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> sendReportMessage({
    required String reportId,
    required String receiverId,
    required String message,
    required String senderLabel,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw ReportSubmitException('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
    }

    final text = message.trim();
    if (text.isEmpty) {
      throw ReportSubmitException('Mesaj boş olamaz.');
    }

    final reportIdValue = _dbIdValue(reportId);
    final receiverIdValue = _dbIdValue(receiverId);
    await _client.from(_messagesTableName).insert({
      'report_id': reportIdValue,
      'sender_id': user.id,
      'receiver_id': receiverIdValue,
      'message': text,
    });

    await NotificationService.createMessageNotification(
      receiverId: receiverId,
      reportId: reportId,
      messageText: text,
      senderLabel: senderLabel,
    );
  }

  static String messageForError(Object error) {
    if (error is ReportSubmitException) return error.message;
    if (error is PostgrestException) {
      final msg = error.message.trim();
      if (msg.isNotEmpty) return _humanizePostgrest(msg);
      return 'Kayıt sırasında bir sorun oluştu. Lütfen tekrar deneyin.';
    }
    if (error is AuthException) {
      final m = error.message.trim();
      if (m.isNotEmpty) return m;
    }
    return 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';
  }

  static String _humanizePostgrest(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('column') && lower.contains('does not exist')) {
      if (lower.contains('assigned_at')) {
        return 'Sunucuda assigned_at kolonu yok. Supabase SQL Editor’da patimap_app/supabase/reports_app_columns.sql dosyasını çalıştırın.';
      }
      return 'Sunucuda eksik kolon var (ör. assigned_at, animal_type, report_status). '
          'Supabase SQL Editor’da supabase/reports_app_columns.sql dosyasını çalıştırın.';
    }
    if (lower.contains('relation') && lower.contains('does not exist')) {
      return 'Sunucuda "$tableName" tablosu bulunamadı. Supabase şemasını kontrol edin.';
    }
    if (lower.contains('row-level security') ||
        lower.contains('new row violates row-level security')) {
      return 'Bu işlem için yetkiniz yok veya oturum süresi dolmuş olabilir.';
    }
    if (lower.contains('foreign key') || lower.contains('violates foreign key')) {
      return 'Kullanıcı kaydı sunucu ile uyumsuz. Tekrar giriş yapmayı deneyin.';
    }
    if (lower.contains('invalid input syntax for type uuid')) {
      return 'Mesajlaşma tablosundaki id tipleri mevcut ihbar verileriyle uyumlu değil. '
          'Supabase\'de report_messages.report_id ve receiver_id alan tiplerini kontrol edin.';
    }
    return raw;
  }

  static Object _dbIdValue(String raw) {
    final v = raw.trim();
    final asInt = int.tryParse(v);
    if (asInt != null) return asInt;
    return v;
  }
}

class ReportSubmitException implements Exception {
  ReportSubmitException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReportAssignException extends ReportSubmitException {
  ReportAssignException(super.message);
}

class ReportMessage {
  const ReportMessage({
    required this.id,
    required this.reportId,
    required this.senderId,
    required this.receiverId,
    required this.message,
    this.createdAt,
  });

  final String id;
  final String reportId;
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime? createdAt;

  factory ReportMessage.fromRow(Map<String, dynamic> row) {
    return ReportMessage(
      id: row['id']?.toString() ?? '',
      reportId: row['report_id']?.toString() ?? '',
      senderId: row['sender_id']?.toString() ?? '',
      receiverId: row['receiver_id']?.toString() ?? '',
      message: row['message']?.toString() ?? '',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
    );
  }
}
