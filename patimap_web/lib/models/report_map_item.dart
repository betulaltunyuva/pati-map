class ReportMapItem {
  const ReportMapItem({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.title,
    required this.type,
    this.urgency,
    this.status,
    this.userId,
    this.assignedVolunteerId,
    this.description,
    this.createdAt,
    this.assignedAt,
    this.photoUrl,
    this.locationNote,
    this.animalTypeKey,
    this.customAnimalType,
    this.reportStatusKey,
    this.customReportStatus,
    this.hasGeoCoordinates = false,
    this.riskLevel,
  });

  final String id;
  final double latitude;
  final double longitude;
  final String title;
  final String type;
  final String? urgency;
  final String? status;
  final String? userId;
  final String? assignedVolunteerId;
  final String? description;
  final DateTime? createdAt;
  final DateTime? assignedAt;
  final String? photoUrl;
  final String? locationNote;
  final String? animalTypeKey;
  final String? customAnimalType;
  final String? reportStatusKey;
  final String? customReportStatus;

  /// Veritabaninda gercek enlem/boylam var; yoksa haritada sentetik konum uretilmez.
  final bool hasGeoCoordinates;
  final String? riskLevel;

  bool get isAssigned => (status ?? '').toUpperCase().trim() == 'ASSIGNED';

  String get urgencyLabelTr {
    switch ((urgency ?? '').toLowerCase().trim()) {
      case 'urgent':
        return 'Yuksek';
      case 'normal':
        return 'Orta';
      case 'low':
        return 'Dusuk';
      default:
        return 'Orta';
    }
  }

  String get animalTypeLabelTr {
    final custom = customAnimalType?.trim();
    final key = animalTypeKey?.toLowerCase().trim();
    if (key == 'other' && custom != null && custom.isNotEmpty) return custom;
    switch (key) {
      case 'cat':
        return 'Kedi';
      case 'dog':
        return 'Kopek';
      case 'bird':
        return 'Kus';
      case 'other':
        return 'Diger';
      default:
        return (custom != null && custom.isNotEmpty) ? custom : '—';
    }
  }

  String get situationLabelTr {
    final custom = customReportStatus?.trim();
    final key = reportStatusKey?.toLowerCase().trim();
    if (key == 'other' && custom != null && custom.isNotEmpty) return custom;
    switch (key) {
      case 'injured':
        return 'Yarali';
      case 'hungry':
      case 'open':
        return 'Ac';
      case 'missing':
        return 'Kaybolmus';
      case 'thirsty':
        return 'Susuz';
      case 'needs_care':
        return 'Bakima Muhtac';
      case 'attacked':
        return 'Saldiriya Ugramis';
      case 'other':
        return 'Diger';
      default:
        return (custom != null && custom.isNotEmpty) ? custom : '—';
    }
  }
}
