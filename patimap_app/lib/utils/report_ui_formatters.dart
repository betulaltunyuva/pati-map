/// Tarih gösterimi (profil listeleri, kartlar).
String formatReportDate(DateTime? dt) {
  if (dt == null) return '—';
  final local = dt.toLocal();
  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final yyyy = local.year.toString();
  return '$dd.$mm.$yyyy';
}

/// Kayıt durumu (OPEN / ASSIGNED / …) kısa Türkçe etiket.
String reportRecordStatusLabelTr(String status) {
  switch (status.toUpperCase().trim()) {
    case 'OPEN':
      return 'Açık';
    case 'ASSIGNED':
      return 'Üstlenildi';
    case 'CLOSED':
      return 'Kapatıldı';
    default:
      return status.isEmpty ? '—' : status;
  }
}
