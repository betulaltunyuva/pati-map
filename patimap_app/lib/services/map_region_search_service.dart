import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

import '../data/turkey_il_centers.dart';
import '../map/map_region_models.dart';

/// Şehir / ilçe / mahalle araması: geocoding + il önerileri.
abstract final class MapRegionSearchService {
  MapRegionSearchService._();

  static const double zoomProvince = 9.35;
  static const double zoomDistrict = 11.6;
  static const double zoomNeighborhood = 14.1;

  static const double radiusProvinceKm = 52.0;
  static const double radiusDistrictKm = 18.0;
  static const double radiusNeighborhoodKm = 4.5;

  /// Tam metin arama (Enter / arama düğmesi).
  static Future<AppliedMapRegion?> resolveQuery(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return null;

    try {
      await setLocaleIdentifier('tr_TR');
    } catch (_) {}

    final exactIl = TurkeyIlCenters.exactProvince(query);
    if (exactIl != null) {
      return AppliedMapRegion(
        center: exactIl.center,
        zoom: exactIl.zoom,
        radiusKm: exactIl.radiusKm,
        queryText: query,
        displayLabel: exactIl.title,
      );
    }

    try {
      var locations = await locationFromAddress('$query, Türkiye');
      if (locations.isEmpty) {
        locations = await locationFromAddress(query);
      }
      if (locations.isEmpty) return null;

      final loc = locations.first;
      final center = LatLng(loc.latitude, loc.longitude);
      final pm = await _placemark(loc.latitude, loc.longitude);
      final (zoom, radiusKm) = _zoomAndRadius(pm, query);
      final label = _formatLabel(pm, query) ?? query;

      return AppliedMapRegion(
        center: center,
        zoom: zoom,
        radiusKm: radiusKm,
        queryText: query,
        displayLabel: label,
      );
    } catch (_) {
      return null;
    }
  }

  /// Yazarken öneriler (il listesi + sınırlı geocoding).
  static Future<List<MapRegionSuggestion>> suggestions(
    String rawQuery, {
    int maxItems = 8,
  }) async {
    final q = rawQuery.trim();
    if (q.length < 2) return [];

    final fromIl = TurkeyIlCenters.matching(q, limit: maxItems);
    if (fromIl.length >= maxItems) return fromIl;

    final merged = <String, MapRegionSuggestion>{};
    for (final s in fromIl) {
      merged[s.title.toLowerCase()] = s;
    }

    try {
      await setLocaleIdentifier('tr_TR');
      final locations = await locationFromAddress('$q, Türkiye');
      var count = 0;
      for (final loc in locations) {
        if (count >= 4) break;
        final pm = await _placemark(loc.latitude, loc.longitude);
        final label = _formatLabel(pm, q) ?? q;
        final key = normalizeMapQuery(label);
        if (key.isEmpty) continue;
        if (merged.containsKey(key)) continue;
        final (zoom, radiusKm) = _zoomAndRadius(pm, q);
        merged[key] = MapRegionSuggestion(
          title: label,
          subtitle: _subtitleFrom(pm),
          center: LatLng(loc.latitude, loc.longitude),
          zoom: zoom,
          radiusKm: radiusKm,
        );
        count++;
      }
    } catch (_) {}

    return merged.values.take(maxItems).toList(growable: false);
  }

  static Future<Placemark?> _placemark(double lat, double lon) async {
    try {
      final list = await placemarkFromCoordinates(lat, lon);
      return list.isEmpty ? null : list.first;
    } catch (_) {
      return null;
    }
  }

  static String? _formatLabel(Placemark? pm, String fallback) {
    if (pm == null) return fallback;
    final parts = <String>[
      if ((pm.subLocality ?? '').trim().isNotEmpty) pm.subLocality!.trim(),
      if ((pm.locality ?? '').trim().isNotEmpty) pm.locality!.trim(),
      if ((pm.subAdministrativeArea ?? '').trim().isNotEmpty)
        pm.subAdministrativeArea!.trim(),
      if ((pm.administrativeArea ?? '').trim().isNotEmpty)
        pm.administrativeArea!.trim(),
    ];
    if (parts.isEmpty) return fallback;
    final seen = <String>{};
    final uniq = <String>[];
    for (final p in parts) {
      final k = p.toLowerCase();
      if (seen.add(k)) uniq.add(p);
    }
    return uniq.take(3).join(', ');
  }

  static String _subtitleFrom(Placemark? pm) {
    if (pm == null) return 'Konum';
    final country = (pm.country ?? '').trim();
    if (country.isNotEmpty) return country;
    return 'Adres sonucu';
  }

  static (double zoom, double radiusKm) _zoomAndRadius(
    Placemark? pm,
    String query,
  ) {
    if (pm == null) {
      return (zoomDistrict, radiusDistrictKm);
    }
    final q = normalizeMapQuery(query);
    final sub = normalizeMapQuery(pm.subLocality);
    final loc = normalizeMapQuery(pm.locality);
    final th = normalizeMapQuery(pm.thoroughfare);
    final subAdm = normalizeMapQuery(pm.subAdministrativeArea);

    if (sub.isNotEmpty && q.length >= 3 && (sub.contains(q) || q.contains(sub))) {
      return (zoomNeighborhood, radiusNeighborhoodKm);
    }
    if (th.isNotEmpty && q.length >= 4 && (th.contains(q) || q.contains(th))) {
      return (zoomNeighborhood + 0.2, radiusNeighborhoodKm * 0.9);
    }
    if (loc.isNotEmpty && (loc.contains(q) || q.contains(loc))) {
      return (zoomDistrict, radiusDistrictKm);
    }
    if (subAdm.isNotEmpty && (subAdm.contains(q) || q.contains(subAdm))) {
      return (zoomDistrict - 0.2, radiusDistrictKm * 1.15);
    }
    return (zoomProvince, radiusProvinceKm);
  }
}
