import '../report_pin.dart';
import 'map_region_models.dart';

/// Bölge araması aktifken ihbarın görünür olup olmayacağı.
/// Önce yarıçap; gerekirse metin (adres notu / başlık / açıklama) eşleşmesi.
bool reportPinInAppliedRegion(ReportPin pin, AppliedMapRegion? region) {
  if (region == null) return true;

  final d = haversineKm(
    pin.latitude,
    pin.longitude,
    region.center.latitude,
    region.center.longitude,
  );
  if (d <= region.radiusKm) return true;

  final q = normalizeMapQuery(region.queryText);
  if (q.length < 2) return false;

  bool containsNorm(String? text) {
    final n = normalizeMapQuery(text);
    if (n.isEmpty) return false;
    return n.contains(q) || q.contains(n);
  }

  return containsNorm(pin.locationNote) ||
      containsNorm(pin.title) ||
      containsNorm(pin.description);
}
