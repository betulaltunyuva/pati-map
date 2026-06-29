import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Gezegen yüzeyinde iki nokta arası km (WGS84 yaklaşımı).
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const earthKm = 6371.0;
  double rad(double d) => d * math.pi / 180.0;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthKm * c;
}

/// Arama normalizasyonu (Türkçe karşılaştırma için basit dönüşüm).
String normalizeMapQuery(String? input) {
  if (input == null) return '';
  var s = input.trim().toLowerCase();
  const map = {
    'ı': 'i',
    'ğ': 'g',
    'ü': 'u',
    'ş': 's',
    'ö': 'o',
    'ç': 'c',
    'â': 'a',
    'î': 'i',
    'û': 'u',
  };
  final buf = StringBuffer();
  for (final c in s.runes) {
    final ch = String.fromCharCode(c);
    buf.write(map[ch] ?? ch);
  }
  return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Otomatik tamamlama satırı.
final class MapRegionSuggestion {
  const MapRegionSuggestion({
    required this.title,
    required this.subtitle,
    required this.center,
    required this.zoom,
    required this.radiusKm,
  });

  final String title;
  final String subtitle;
  final LatLng center;
  final double zoom;
  final double radiusKm;
}

/// Uygulanan bölge filtresi + harita kadrajı.
final class AppliedMapRegion {
  const AppliedMapRegion({
    required this.center,
    required this.zoom,
    required this.radiusKm,
    required this.queryText,
    required this.displayLabel,
  });

  final LatLng center;
  final double zoom;
  final double radiusKm;
  final String queryText;
  final String displayLabel;
}
