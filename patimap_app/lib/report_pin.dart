import 'package:flutter/material.dart';

import 'theme/app_colors.dart';

enum ReportType {
  injured,
  open,
  missing,
}

enum ReportUrgency {
  urgent,
  normal,
  low,
}

/// Hayvan türü; Supabase `animal_type` kolonu ile uyumlu anahtarlar.
enum ReportAnimalType {
  cat,
  dog,
  bird,
  other;

  String get storageKey => name;

  String get labelTr => switch (this) {
        ReportAnimalType.cat => 'Kedi',
        ReportAnimalType.dog => 'Köpek',
        ReportAnimalType.bird => 'Kuş',
        ReportAnimalType.other => 'Diğer',
      };
}

/// İhbar durumu / senaryosu; Supabase `report_status` kolonu ile uyumlu anahtarlar.
enum ReportSituation {
  injured,
  hungry,
  missing,
  thirsty,
  needsCare,
  attacked,
  other;

  String get storageKey => switch (this) {
        ReportSituation.injured => 'injured',
        ReportSituation.hungry => 'hungry',
        ReportSituation.missing => 'missing',
        ReportSituation.thirsty => 'thirsty',
        ReportSituation.needsCare => 'needs_care',
        ReportSituation.attacked => 'attacked',
        ReportSituation.other => 'other',
      };

  String get labelTr => switch (this) {
        ReportSituation.injured => 'Yaralı',
        ReportSituation.hungry => 'Aç',
        ReportSituation.missing => 'Kaybolmuş',
        ReportSituation.thirsty => 'Susuz',
        ReportSituation.needsCare => 'Bakıma Muhtaç',
        ReportSituation.attacked => 'Saldırıya Uğramış',
        ReportSituation.other => 'Diğer',
      };
}

/// Harita rengi / eski filtreler için görsel kategori (legacy `type` + yeni `report_status`).
ReportType reportPinVisualTypeFromSituationKey(String? raw) {
  switch (raw?.toLowerCase().trim()) {
    case 'injured':
    case 'needs_care':
    case 'attacked':
      return ReportType.injured;
    case 'missing':
      return ReportType.missing;
    case 'hungry':
    case 'thirsty':
    case 'other':
    case 'open':
      return ReportType.open;
    default:
      return ReportType.open;
  }
}

String reportAnimalLabelTr(String? key, String? custom) {
  final c = custom?.trim();
  final k = key?.toLowerCase().trim();
  if (k == 'other' && c != null && c.isNotEmpty) return c;
  switch (k) {
    case 'cat':
      return 'Kedi';
    case 'dog':
      return 'Köpek';
    case 'bird':
      return 'Kuş';
    case 'other':
      return 'Diğer';
    default:
      return (c != null && c.isNotEmpty) ? c : '—';
  }
}

String reportSituationLabelTr(String? key, String? custom) {
  final c = custom?.trim();
  final k = key?.toLowerCase().trim();
  if (k == 'other' && c != null && c.isNotEmpty) return c;
  switch (k) {
    case 'injured':
      return 'Yaralı';
    case 'hungry':
    case 'open':
      return 'Aç';
    case 'missing':
      return 'Kaybolmuş';
    case 'thirsty':
      return 'Susuz';
    case 'needs_care':
      return 'Bakıma Muhtaç';
    case 'attacked':
      return 'Saldırıya Uğramış';
    case 'other':
      return 'Diğer';
    default:
      return (c != null && c.isNotEmpty) ? c : '—';
  }
}

/// Map pin backed by Supabase `reports` rows.
class ReportPin {
  const ReportPin({
    required this.id,
    required this.type,
    required this.urgency,
    required this.isUnassigned,
    required this.x,
    required this.y,
    required this.latitude,
    required this.longitude,
    required this.title,
    this.count = 1,
    this.description = '',
    this.status = 'OPEN',
    this.userId,
    this.createdAt,
    this.assignedVolunteerId,
    this.assignedAt,
    this.locationNote,
    this.photoUrl,
    this.animalTypeKey,
    this.customAnimalType,
    this.reportStatusKey,
    this.customReportStatus,
    this.riskLevel,
    this.aiScore,
  });

  final String id;
  final ReportType type;
  final ReportUrgency urgency;
  final bool isUnassigned;

  /// Normalized map position (0-1) inside the map area.
  final double x;
  final double y;

  /// Coordinates used for real map markers.
  final double latitude;
  final double longitude;

  /// Short summary for UI hints.
  final String title;
  final int count;

  /// Full description from API.
  final String description;

  /// e.g. OPEN, CLOSED
  final String status;
  final String? userId;
  final DateTime? createdAt;
  final String? assignedVolunteerId;

  /// Üstlenme anı (Supabase `assigned_at`). Yeni üstlenmelerde dolu olmalı.
  final DateTime? assignedAt;
  final String? photoUrl;
  final String? locationNote;

  /// Supabase `animal_type` (örn. cat, dog, bird, other).
  final String? animalTypeKey;

  /// `animal_type == other` ise kullanıcı metni.
  final String? customAnimalType;

  /// Supabase `report_status` (örn. injured, hungry, …); yoksa legacy `type`.
  final String? reportStatusKey;

  /// `report_status == other` ise kullanıcı metni.
  final String? customReportStatus;
  final String? riskLevel;
  final int? aiScore;

  bool get isAssigned => status.toUpperCase() == 'ASSIGNED';

  /// Harita markerı: OPEN her zaman görünür.
  /// ASSIGNED kayıtlar yalnızca üstlenme anından itibaren 24 saat görünür.
  bool shouldShowOnMap({DateTime? at}) {
    final now = (at ?? DateTime.now()).toUtc();
    final s = status.toUpperCase();
    if (s == 'OPEN') return true;
    if (s == 'ASSIGNED') {
      if (assignedAt == null) return false;
      final cutoff = now.subtract(const Duration(hours: 24));
      return assignedAt!.toUtc().isAfter(cutoff);
    }
    return true;
  }

  String get animalTypeLabelTr =>
      reportAnimalLabelTr(animalTypeKey, customAnimalType);

  String get situationLabelTr =>
      reportSituationLabelTr(reportStatusKey, customReportStatus);

  String get typeLabelTr => switch (type) {
        ReportType.injured => 'Yaralı',
        ReportType.open => 'Aç',
        ReportType.missing => 'Kaybolmuş',
      };

  String get urgencyLabelTr => switch (urgency) {
        ReportUrgency.urgent => 'Yüksek',
        ReportUrgency.normal => 'Orta',
        ReportUrgency.low => 'Düşük',
      };

  String get displayRiskLevel {
    final raw = riskLevel?.trim();
    if (raw == null || raw.isEmpty) return 'Belirlenmedi';
    final normalized = raw
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
    if (normalized.contains('yuksek')) return 'Yüksek Risk';
    if (normalized.contains('orta')) return 'Orta Risk';
    if (normalized.contains('dusuk')) return 'Düşük Risk';
    return raw;
  }

  int get displayAiScore => aiScore ?? 0;

  /// Pin color from type and urgency.
  Color get color {
    final Color base = switch (type) {
      ReportType.injured => Colors.redAccent,
      ReportType.open => Colors.orangeAccent,
      ReportType.missing => AppColors.primaryLight,
    };
    return switch (urgency) {
      ReportUrgency.urgent =>
        Color.lerp(base, const Color(0xFFC62828), 0.38)!,
      ReportUrgency.normal => base,
      ReportUrgency.low => Color.lerp(base, Colors.grey.shade400, 0.22)!,
    };
  }
}

/// Lat/lng to normalized position, or deterministic fallback from [id].
abstract final class MapPinPlacement {
  MapPinPlacement._();

  /// Approx. Turkey bounds for placeholder map.
  static const double _latMin = 36.0;
  static const double _latMax = 42.2;
  static const double _lonMin = 26.0;
  static const double _lonMax = 45.0;

  static (double x, double y) normalizedForReport({
    required String id,
    double? latitude,
    double? longitude,
  }) {
    if (latitude != null && longitude != null) {
      final nx =
          ((longitude - _lonMin) / (_lonMax - _lonMin)).clamp(0.0, 1.0);
      final nyTop =
          (1.0 - ((latitude - _latMin) / (_latMax - _latMin))).clamp(0.0, 1.0);
      return (nx.clamp(0.1, 0.9), nyTop.clamp(0.1, 0.9));
    }
    return _fromId(id);
  }

  /// Normalized map position (0-1) -> lat/lng using the same bounds as
  /// [normalizedForReport].
  static (double latitude, double longitude) latLngFromNormalized({
    required double x,
    required double y,
  }) {
    final nx = x.clamp(0.0, 1.0);
    final ny = y.clamp(0.0, 1.0);

    final lon = _lonMin + nx * (_lonMax - _lonMin);
    final lat = _latMin + (1.0 - ny) * (_latMax - _latMin);
    return (lat, lon);
  }

  static (double x, double y) _fromId(String id) {
    var h = 0x811c9dc5;
    for (final u in id.codeUnits) {
      h = (h ^ u) * 0x01000193;
      h &= 0x7fffffff;
    }
    final x = 0.14 + (h % 720) / 1000.0;
    final y = 0.14 + ((h ~/ 19) % 720) / 1000.0;
    return (x.clamp(0.12, 0.88), y.clamp(0.12, 0.88));
  }
}
