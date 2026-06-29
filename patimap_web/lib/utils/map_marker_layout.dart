import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/report_map_item.dart';

/// Haritada gosterilen pinler ile dashboard sayilari ayni kaynaktan turetilir.
class MapMarkerLayout {
  MapMarkerLayout._();

  static String cellKey(ReportMapItem item) {
    final lat = item.latitude.toStringAsFixed(4);
    final lng = item.longitude.toStringAsFixed(4);
    return '$lat|$lng';
  }

  static List<ReportMapItem> _geoItems(List<ReportMapItem> items) =>
      items.where((e) => e.hasGeoCoordinates).toList();

  static Map<String, List<ReportMapItem>> _groupByCell(List<ReportMapItem> items) {
    final groups = <String, List<ReportMapItem>>{};
    for (final item in _geoItems(items)) {
      groups.putIfAbsent(cellKey(item), () => []).add(item);
    }
    return groups;
  }

  /// Haritada pin olan ihbarlar (konum basina bir kayit; coklu ihbar ayni pinde).
  static List<ReportMapItem> reportsOnMapPins(List<ReportMapItem> items) {
    return [
      for (final group in _groupByCell(items).values) group.first,
    ];
  }

  /// Haritadaki pin sayisi (gorunen marker adedi).
  static int pinCount(List<ReportMapItem> items) =>
      markersForMap(items).length;

  /// Dashboard / harita: her konumda tek marker; [clusterSize] > 1 ise rozet.
  static List<({ReportMapItem item, LatLng point, int clusterSize})> markersForMap(
    List<ReportMapItem> items,
  ) {
    return [
      for (final group in _groupByCell(items).values)
        (
          item: group.first,
          point: LatLng(group.first.latitude, group.first.longitude),
          clusterSize: group.length,
        ),
    ];
  }

  /// Eski spread — baska sayfalarda gerekirse; dashboard [markersForMap] kullanir.
  static List<({ReportMapItem item, LatLng point})> spreadForDisplay(
    List<ReportMapItem> items,
  ) {
    final groups = _groupByCell(items);
    final out = <({ReportMapItem item, LatLng point})>[];
    for (final group in groups.values) {
      if (group.length == 1) {
        final item = group.first;
        out.add((item: item, point: LatLng(item.latitude, item.longitude)));
        continue;
      }
      for (var i = 0; i < group.length; i++) {
        final item = group[i];
        final angle = (2 * math.pi * i) / group.length;
        const radiusDeg = 0.028;
        final latRad = item.latitude * math.pi / 180;
        final lat = item.latitude + radiusDeg * math.sin(angle);
        final lng = item.longitude +
            (radiusDeg * math.cos(angle)) / math.cos(latRad).clamp(0.35, 1.0);
        out.add((item: item, point: LatLng(lat, lng)));
      }
    }
    return out;
  }
}
