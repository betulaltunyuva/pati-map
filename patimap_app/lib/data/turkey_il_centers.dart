import 'package:latlong2/latlong.dart';

import '../map/map_region_models.dart';

/// Türkiye illeri — yaklaşık merkez koordinatları (harita önerileri ve hızlı odak).
abstract final class TurkeyIlCenters {
  TurkeyIlCenters._();

  static const double _zProvince = 9.35;
  static const double _rProvince = 52.0;

  static const Map<String, LatLng> _coords = {
    'Adana': LatLng(37.0000, 35.3213),
    'Adıyaman': LatLng(37.7648, 38.2786),
    'Afyonkarahisar': LatLng(38.7638, 30.5403),
    'Ağrı': LatLng(39.7191, 43.0506),
    'Aksaray': LatLng(38.3687, 34.0370),
    'Amasya': LatLng(40.6499, 35.8353),
    'Ankara': LatLng(39.9334, 32.8597),
    'Antalya': LatLng(36.8841, 30.7056),
    'Ardahan': LatLng(41.1105, 42.7029),
    'Artvin': LatLng(41.1828, 41.8183),
    'Aydın': LatLng(37.8444, 27.8456),
    'Balıkesir': LatLng(39.6484, 27.8826),
    'Bartın': LatLng(41.5811, 32.4610),
    'Batman': LatLng(37.8812, 41.1351),
    'Bayburt': LatLng(40.2552, 40.2249),
    'Bilecik': LatLng(40.1456, 29.9791),
    'Bingöl': LatLng(38.8847, 40.4982),
    'Bitlis': LatLng(38.4016, 42.1078),
    'Bolu': LatLng(40.7350, 31.6061),
    'Burdur': LatLng(37.7203, 30.2908),
    'Bursa': LatLng(40.1826, 29.0665),
    'Çanakkale': LatLng(40.1553, 26.4142),
    'Çankırı': LatLng(40.6013, 33.6134),
    'Çorum': LatLng(40.5506, 34.9556),
    'Denizli': LatLng(37.7765, 29.0864),
    'Diyarbakır': LatLng(37.9144, 40.2306),
    'Düzce': LatLng(40.8438, 31.1565),
    'Edirne': LatLng(41.6818, 26.5623),
    'Elazığ': LatLng(38.6748, 39.2228),
    'Erzincan': LatLng(39.7500, 39.5000),
    'Erzurum': LatLng(39.9043, 41.2678),
    'Eskişehir': LatLng(39.7767, 30.5206),
    'Gaziantep': LatLng(37.0662, 37.3833),
    'Giresun': LatLng(40.9128, 38.3895),
    'Gümüşhane': LatLng(40.4603, 39.5125),
    'Hakkâri': LatLng(37.5744, 43.7408),
    'Hatay': LatLng(36.4018, 36.3498),
    'Iğdır': LatLng(39.8880, 44.0048),
    'Isparta': LatLng(37.7648, 30.5566),
    'İstanbul': LatLng(41.0082, 28.9784),
    'İzmir': LatLng(38.4237, 27.1428),
    'Kahramanmaraş': LatLng(37.5858, 36.9371),
    'Karabük': LatLng(41.2061, 32.6204),
    'Karaman': LatLng(37.1759, 33.2287),
    'Kars': LatLng(40.6013, 43.0975),
    'Kastamonu': LatLng(41.3887, 33.7827),
    'Kayseri': LatLng(38.7312, 35.4787),
    'Kırıkkale': LatLng(39.8468, 33.5153),
    'Kırklareli': LatLng(41.7333, 27.2167),
    'Kırşehir': LatLng(39.1425, 34.1709),
    'Kilis': LatLng(36.7184, 37.1212),
    'Kocaeli': LatLng(40.8533, 29.8815),
    'Konya': LatLng(37.8667, 32.4833),
    'Kütahya': LatLng(39.4242, 29.9833),
    'Malatya': LatLng(38.3552, 38.3095),
    'Manisa': LatLng(38.6191, 27.4289),
    'Mardin': LatLng(37.3131, 40.7350),
    'Mersin': LatLng(36.8121, 34.6415),
    'Muğla': LatLng(37.2153, 28.3636),
    'Muş': LatLng(38.9462, 41.7539),
    'Nevşehir': LatLng(38.6939, 34.6857),
    'Niğde': LatLng(37.9667, 34.6833),
    'Ordu': LatLng(40.9839, 37.8764),
    'Osmaniye': LatLng(37.2130, 36.1763),
    'Rize': LatLng(41.0201, 40.5234),
    'Sakarya': LatLng(40.7569, 30.3783),
    'Samsun': LatLng(41.2928, 36.3313),
    'Siirt': LatLng(37.9274, 41.9400),
    'Sinop': LatLng(42.0231, 35.1531),
    'Sivas': LatLng(39.7477, 37.0179),
    'Şanlıurfa': LatLng(37.1591, 38.7969),
    'Şırnak': LatLng(37.4187, 42.4918),
    'Tekirdağ': LatLng(40.9833, 27.5167),
    'Tokat': LatLng(40.3167, 36.5500),
    'Trabzon': LatLng(41.0015, 39.7178),
    'Tunceli': LatLng(39.3074, 39.4388),
    'Uşak': LatLng(38.6823, 29.4082),
    'Van': LatLng(38.4891, 43.4089),
    'Yalova': LatLng(40.6500, 29.2667),
    'Yozgat': LatLng(39.8181, 34.8147),
    'Zonguldak': LatLng(41.4564, 31.7987),
  };

  /// Sorgu tam bir il adıysa (ör. "Elazığ", "kayseri") tek sonuç döner.
  static MapRegionSuggestion? exactProvince(String rawQuery) {
    final q = normalizeMapQuery(rawQuery);
    if (q.length < 2) return null;
    for (final e in _coords.entries) {
      if (normalizeMapQuery(e.key) == q) {
        return MapRegionSuggestion(
          title: e.key,
          subtitle: 'İl merkezi',
          center: e.value,
          zoom: _zProvince,
          radiusKm: _rProvince,
        );
      }
    }
    return null;
  }

  static List<MapRegionSuggestion> matching(String rawQuery, {int limit = 8}) {
    final q = normalizeMapQuery(rawQuery);
    if (q.isEmpty) return [];
    final out = <MapRegionSuggestion>[];
    for (final e in _coords.entries) {
      final nameNorm = normalizeMapQuery(e.key);
      if (nameNorm.contains(q) || q.contains(nameNorm)) {
        out.add(
          MapRegionSuggestion(
            title: e.key,
            subtitle: 'İl merkezi',
            center: e.value,
            zoom: _zProvince,
            radiusKm: _rProvince,
          ),
        );
        if (out.length >= limit) break;
      }
    }
    return out;
  }
}
