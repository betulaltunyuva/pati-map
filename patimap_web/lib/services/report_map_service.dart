import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/report_map_item.dart';

class ReportMapService {
  static SupabaseClient get _client => Supabase.instance.client;

  static const String tableName = 'reports';
  static const String _reportSelect =
      'id, user_id, assigned_volunteer_id, assigned_at, type, urgency, description, status, latitude, longitude, created_at, location_note, photo_url, animal_type, custom_animal_type, report_status, custom_report_status, risk_level';

  static Future<List<ReportMapItem>> fetchItems() async {
    try {
      final data = await _client
          .from(tableName)
          .select(_reportSelect)
          .order('created_at', ascending: false);

      final parsed = _parseRows(data).where(_shouldShowOnMap).toList();
      _debugLogItems(parsed);
      return parsed;
    } catch (error) {
      debugPrint('ReportMapService error on "$tableName": $error');
      rethrow;
    }
  }

  static List<ReportMapItem> _parseRows(dynamic data) {
    if (data is! List) return const [];

    final items = <ReportMapItem>[];
    for (final row in data) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      final lat = _toDouble(map['latitude']);
      final lng = _toDouble(map['longitude']);
      final id = map['id']?.toString();
      if (id == null || id.isEmpty) continue;
      final hasGeoCoordinates = lat != null && lng != null;
      final resolvedPosition = _resolveLatLng(
        id: id,
        latitude: lat,
        longitude: lng,
      );

      final description = _trimOrNull(map['description']);
      final title = _deriveTitle(description) ?? 'Ihbar #$id';
      final createdAt = DateTime.tryParse(map['created_at']?.toString() ?? '');
      final assignedAt = DateTime.tryParse(map['assigned_at']?.toString() ?? '');
      final status = _trimOrNull(map['status']);
      final urgency = _trimOrNull(map['urgency']);
      final type = _trimOrNull(map['type']) ?? 'open';
      final userId = _trimOrNull(map['user_id']);
      final assignedVolunteerId = _trimOrNull(map['assigned_volunteer_id']);
      final photoUrl = _trimOrNull(map['photo_url']);
      final locationNote = _trimOrNull(map['location_note']);
      final animalTypeKey = _trimOrNull(map['animal_type']);
      final customAnimalType = _trimOrNull(map['custom_animal_type']);
      final reportStatusKey = _trimOrNull(map['report_status']);
      final customReportStatus = _trimOrNull(map['custom_report_status']);

      items.add(
        ReportMapItem(
          id: id,
          latitude: resolvedPosition.$1,
          longitude: resolvedPosition.$2,
          title: title,
          type: type,
          urgency: urgency,
          status: status,
          userId: userId,
          assignedVolunteerId: assignedVolunteerId,
          description: description,
          createdAt: createdAt,
          assignedAt: assignedAt,
          photoUrl: photoUrl,
          locationNote: locationNote,
          animalTypeKey: animalTypeKey,
          customAnimalType: customAnimalType,
          reportStatusKey: reportStatusKey,
          customReportStatus: customReportStatus,
          hasGeoCoordinates: hasGeoCoordinates,
          riskLevel: _trimOrNull(map['risk_level']),
        ),
      );
    }
    return items;
  }

  static Future<ReportMapItem?> fetchReportById(String reportId) async {
    final rows = await _client
        .from(tableName)
        .select(_reportSelect)
        .eq('id', reportId)
        .limit(1);
    if (rows.isEmpty) return null;
    final parsed = _parseRows([rows.first]);
    return parsed.isEmpty ? null : parsed.first;
  }

  static Future<ReportMapItem> assignVolunteerToReport({
    required String reportId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Gonullu ustlenme icin lutfen giris yapin.');
    }

    final current = await fetchReportById(reportId);
    if (current == null) {
      throw const AuthException('Ihbar bulunamadi.');
    }
    if (current.isAssigned) {
      throw const AuthException('Bu ihbar zaten ustlenilmis durumda.');
    }

    final assignedNow = DateTime.now().toUtc();
    final data = await _client
        .from(tableName)
        .update({
          'status': 'ASSIGNED',
          'assigned_volunteer_id': user.id,
          'assigned_at': assignedNow.toIso8601String(),
        })
        .eq('id', reportId)
        .select(_reportSelect);

    if (data.isEmpty) {
      throw const AuthException(
        'Ihbar guncellenemedi. RLS politikalarini kontrol edin.',
      );
    }

    final parsed = _parseRows(data);
    if (parsed.isEmpty || !parsed.first.isAssigned) {
      throw const AuthException(
        'Guncelleme dogrulanamadi. Kolon ve RLS eslemesini kontrol edin.',
      );
    }
    return parsed.first;
  }

  static Future<void> createReport({
    required String animalType,
    String? customAnimalType,
    required String reportSituation,
    String? customReportSituation,
    required String urgency,
    required String description,
    double? latitude,
    double? longitude,
    String? locationNote,
    Uint8List? photoBytes,
    String? photoFileName,
    String? riskLevel,
    int? aiScore,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Oturum bulunamadi. Lutfen tekrar giris yapin.');
    }

    String? photoUrl;
    if (photoBytes != null && photoBytes.isNotEmpty) {
      try {
        const bucket = 'report-images';
        final rawName = (photoFileName ?? 'photo').split('/').last;
        final dot = rawName.lastIndexOf('.');
        final ext = dot == -1 ? '' : rawName.substring(dot + 1);
        final nameWithoutExt = dot == -1 ? rawName : rawName.substring(0, dot);
        final safeExt = (ext.isEmpty || ext.length > 5) ? 'jpg' : ext.toLowerCase();
        final safeBaseName =
            nameWithoutExt.isEmpty ? 'photo' : nameWithoutExt;
        final objectPath =
            'reports/${user.id}/${DateTime.now().millisecondsSinceEpoch}_$safeBaseName.$safeExt';

        final storage = _client.storage.from(bucket);
        await storage.uploadBinary(
          objectPath,
          photoBytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _imageContentType(safeExt),
          ),
        );
        photoUrl = storage.getPublicUrl(objectPath);
      } catch (e) {
        debugPrint('Report create photo upload error: $e');
        throw const AuthException('Fotograf yuklenemedi. Lutfen tekrar deneyin.');
      }
    }

    await _client.from(tableName).insert({
      'user_id': user.id,
      'animal_type': animalType,
      'report_status': reportSituation,
      'custom_animal_type': animalType == 'other' ? customAnimalType?.trim() : null,
      'custom_report_status':
          reportSituation == 'other' ? customReportSituation?.trim() : null,
      'urgency': urgency,
      'description': description.trim(),
      'status': 'OPEN',
      'photo_url': photoUrl,
      'latitude': latitude,
      'longitude': longitude,
      'location_note':
          locationNote?.trim().isNotEmpty == true ? locationNote!.trim() : null,
      'risk_level': riskLevel,
      'ai_score': aiScore,
    });
  }

  static String messageForError(Object error) {
    if (error is AuthException) {
      final m = error.message.trim();
      if (m.isNotEmpty) return m;
    }
    if (error is PostgrestException) {
      final msg = error.message.trim();
      if (msg.isNotEmpty) return msg;
    }
    return 'Beklenmeyen bir hata olustu. Lutfen tekrar deneyin.';
  }

  static bool _shouldShowOnMap(ReportMapItem item) {
    final status = item.status?.toUpperCase().trim() ?? 'OPEN';
    if (status == 'OPEN') return true;
    if (status == 'ASSIGNED') {
      if (item.assignedAt == null) return true;
      final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 24));
      return item.assignedAt!.toUtc().isAfter(cutoff);
    }
    return true;
  }

  static String? _deriveTitle(String? description) {
    if (description == null || description.isEmpty) return null;
    if (description.length <= 44) return description;
    return '${description.substring(0, 44)}...';
  }

  static String? _trimOrNull(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static String _imageContentType(String extLower) {
    switch (extLower.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }

  static (double, double) _resolveLatLng({
    required String id,
    required double? latitude,
    required double? longitude,
  }) {
    if (latitude != null && longitude != null) {
      return (latitude, longitude);
    }
    final (x, y) = _normalizedFromId(id);
    const latMin = 36.0;
    const latMax = 42.2;
    const lonMin = 26.0;
    const lonMax = 45.0;
    final lon = lonMin + x * (lonMax - lonMin);
    final lat = latMin + (1.0 - y) * (latMax - latMin);
    return (lat, lon);
  }

  static (double, double) _normalizedFromId(String id) {
    var h = 0x811c9dc5;
    for (final u in id.codeUnits) {
      h = (h ^ u) * 0x01000193;
      h &= 0x7fffffff;
    }
    final x = (0.14 + (h % 720) / 1000.0).clamp(0.12, 0.88);
    final y = (0.14 + ((h ~/ 19) % 720) / 1000.0).clamp(0.12, 0.88);
    return (x, y);
  }

  static void _debugLogItems(List<ReportMapItem> items) {
    debugPrint('ReportMapService source table: $tableName');
    debugPrint('ReportMapService total fetched items: ${items.length}');
    for (var i = 0; i < items.length && i < 5; i++) {
      final item = items[i];
      debugPrint(
        'ReportMapService item[$i] id=${item.id} lat=${item.latitude} lng=${item.longitude}',
      );
    }
  }
}
