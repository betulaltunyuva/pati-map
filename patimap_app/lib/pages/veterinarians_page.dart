import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/bottom_nav.dart';
import '../routes/app_routes.dart';
import '../services/tab_persistence_service.dart';
import '../theme/app_colors.dart';

enum _VetFilter { nearest, within5, within10, all }

class VeterinariansPage extends StatefulWidget {
  const VeterinariansPage({super.key});

  @override
  State<VeterinariansPage> createState() => _VeterinariansPageState();
}

class _VeterinariansPageState extends State<VeterinariansPage> {
  static const List<int> _searchRadiiMeters = [5000, 10000, 25000, 50000, 100000];
  static const List<String> _nominatimFallbackQueries = [
    'veteriner Elazığ',
    'veteriner kliniği Elazığ',
    'hayvan hastanesi Elazığ',
    'veterinary clinic Elazığ',
    'pet clinic Elazığ',
  ];
  static const List<String> _nominatimNearestQueries = [
    'veteriner',
    'veteriner kliniği',
    'hayvan hastanesi',
    'veterinary clinic',
    'pet clinic',
  ];
  static const Map<String, String> _osmHeaders = <String, String>{
    'Accept': 'application/json',
    'User-Agent': 'PatiMapApp/1.0 (nearby-vets)',
  };

  final MapController _mapController = MapController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _cardKeys = <String, GlobalKey>{};

  bool _loading = true;
  String? _sourceNote;
  String _searchStage = '';
  Position? _position;
  List<_VetItem> _items = const [];
  _VetFilter _filter = _VetFilter.nearest;
  String? _selectedVetKey;
  String? _hoveredVetKey;

  @override
  void initState() {
    super.initState();
    TabPersistenceService.saveTabIndex(2);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _sourceNote = null;
      _searchStage = 'Konum aliniyor...';
      _items = const [];
      _selectedVetKey = null;
      _hoveredVetKey = null;
    });

    try {
      final permission = await _ensureLocationPermission();
      if (!permission) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() => _position = position);

      final result = await _searchWithFallback(position);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _sourceNote = result.note;
        _selectedVetKey = result.items.isNotEmpty ? _vetKey(result.items.first) : null;
      });
      if (result.items.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToPoints());
      }
    } catch (_) {
      // Keep page responsive without blocking with an error panel.
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<_FallbackSearchResult> _searchWithFallback(Position position) async {
    final cityName = await _resolveCityName(position) ?? 'Elazığ';
    final overpass = await _searchByGrowingRadius(position);
    if (overpass.isNotEmpty) return _FallbackSearchResult(items: overpass);

    final nominatim = await _searchNominatimFallback(position, cityName);
    if (nominatim.isNotEmpty) {
      return _FallbackSearchResult(
        items: nominatim,
        note: 'Sonuclar OpenStreetMap/Nominatim kaynaklarindan listeleniyor.',
      );
    }

    final nearestFromNominatim = await _searchNearestWithNominatim(position, cityName);
    if (nearestFromNominatim.isNotEmpty) {
      return _FallbackSearchResult(
        items: nearestFromNominatim,
        note: 'En yakin sonuc Nominatim uzerinden bulundu.',
      );
    }

    return const _FallbackSearchResult(
      items: [],
      note: 'Yakındaki veterinerler farklı kaynaklardan aranıyor.',
    );
  }

  Future<List<_VetItem>> _searchByGrowingRadius(Position position) async {
    for (final radius in _searchRadiiMeters) {
      if (!mounted) return const [];
      setState(() => _searchStage = '${radius ~/ 1000} km icinde veteriner araniyor...');
      final attempt = await _queryOverpassByRadius(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusMeters: radius,
      );
      if (attempt.items.isNotEmpty) return attempt.items;
    }
    return const [];
  }

  Future<List<_VetItem>> _searchNominatimFallback(Position position, String cityName) async {
    final seen = <String>{};
    final all = <_VetItem>[];

    for (final query in _nominatimFallbackQueries) {
      try {
        final effectiveQuery = query.replaceAll('Elazığ', cityName);
        final response = await http
            .get(
              Uri.https('nominatim.openstreetmap.org', '/search', {
                'q': effectiveQuery,
                'format': 'jsonv2',
                'limit': '40',
                'addressdetails': '1',
                'countrycodes': 'tr',
              }),
              headers: _osmHeaders,
            )
            .timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) continue;
        final decoded = jsonDecode(response.body);
        if (decoded is! List) continue;

        for (final raw in decoded) {
          if (raw is! Map) continue;
          final row = Map<String, dynamic>.from(raw);
          final lat = _toDouble(row['lat']);
          final lon = _toDouble(row['lon']);
          if (lat == null || lon == null) continue;
          final key = '${lat.toStringAsFixed(6)}:${lon.toStringAsFixed(6)}';
          if (seen.contains(key)) continue;
          seen.add(key);

          final displayName = row['display_name']?.toString().trim();
          final name = row['name']?.toString().trim();
          all.add(
            _VetItem(
              name: (name == null || name.isEmpty) ? 'Veteriner Klinigi' : name,
              address: (displayName == null || displayName.isEmpty) ? 'Adres bilgisi bulunamadi' : displayName,
              latitude: lat,
              longitude: lon,
              distanceKm: _distanceKm(position.latitude, position.longitude, lat, lon),
              hasPreciseLocation: true,
            ),
          );
        }
      } catch (_) {
        continue;
      }
    }
    all.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return all;
  }

  Future<List<_VetItem>> _searchNearestWithNominatim(Position position, String cityName) async {
    final seen = <String>{};
    final all = <_VetItem>[];

    final lat = position.latitude;
    final lon = position.longitude;
    final minLon = (lon - 2.0).toStringAsFixed(6);
    final maxLon = (lon + 2.0).toStringAsFixed(6);
    final minLat = (lat - 2.0).toStringAsFixed(6);
    final maxLat = (lat + 2.0).toStringAsFixed(6);
    final viewbox = '$minLon,$maxLat,$maxLon,$minLat';

    for (final query in _nominatimNearestQueries) {
      try {
        final effectiveQuery = '$query $cityName';
        final response = await http
            .get(
              Uri.https('nominatim.openstreetmap.org', '/search', {
                'q': effectiveQuery,
                'format': 'jsonv2',
                'limit': '60',
                'addressdetails': '1',
                'countrycodes': 'tr',
                'viewbox': viewbox,
                'bounded': '1',
              }),
              headers: _osmHeaders,
            )
            .timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) continue;
        final decoded = jsonDecode(response.body);
        if (decoded is! List) continue;

        for (final raw in decoded) {
          if (raw is! Map) continue;
          final row = Map<String, dynamic>.from(raw);
          final foundLat = _toDouble(row['lat']);
          final foundLon = _toDouble(row['lon']);
          if (foundLat == null || foundLon == null) continue;

          final key = '${foundLat.toStringAsFixed(6)}:${foundLon.toStringAsFixed(6)}';
          if (seen.contains(key)) continue;
          seen.add(key);

          final displayName = row['display_name']?.toString().trim();
          final name = row['name']?.toString().trim();
          all.add(
            _VetItem(
              name: (name == null || name.isEmpty) ? 'Veteriner Klinigi' : name,
              address: (displayName == null || displayName.isEmpty)
                  ? 'Adres bilgisi bulunamadi'
                  : displayName,
              latitude: foundLat,
              longitude: foundLon,
              distanceKm: _distanceKm(position.latitude, position.longitude, foundLat, foundLon),
              hasPreciseLocation: true,
            ),
          );
        }
      } catch (_) {
        continue;
      }
    }

    all.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return all;
  }

  String _buildOverpassQuery({
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) =>
      '''
[out:json][timeout:25];
(
  node["amenity"="veterinary"](around:$radiusMeters,$latitude,$longitude);
  way["amenity"="veterinary"](around:$radiusMeters,$latitude,$longitude);
  relation["amenity"="veterinary"](around:$radiusMeters,$latitude,$longitude);
  node["healthcare"="veterinary"](around:$radiusMeters,$latitude,$longitude);
  way["healthcare"="veterinary"](around:$radiusMeters,$latitude,$longitude);
  relation["healthcare"="veterinary"](around:$radiusMeters,$latitude,$longitude);
  node["name"~"veteriner|veterinary|vet|klinik|hayvan",i](around:$radiusMeters,$latitude,$longitude);
  way["name"~"veteriner|veterinary|vet|klinik|hayvan",i](around:$radiusMeters,$latitude,$longitude);
);
out center tags;
''';

  Future<_OverpassAttemptResult> _queryOverpassByRadius({
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) async {
    final query = _buildOverpassQuery(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );

    try {
      final response = await http
          .post(
            Uri.parse('https://overpass-api.de/api/interpreter'),
            headers: const {
              'Content-Type': 'text/plain',
              'User-Agent': 'PatiMapApp/1.0 (nearby-vets)',
            },
            body: query,
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return const _OverpassAttemptResult(items: []);
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return const _OverpassAttemptResult(items: []);
      final elements = decoded['elements'];
      if (elements is! List) return const _OverpassAttemptResult(items: []);

      final items = <_VetItem>[];
      for (final raw in elements) {
        if (raw is! Map) continue;
        final row = Map<String, dynamic>.from(raw);
        final lat = _toDouble(row['lat']) ?? _toDouble((row['center'] as Map?)?['lat']);
        final lon = _toDouble(row['lon']) ?? _toDouble((row['center'] as Map?)?['lon']);
        if (lat == null || lon == null) continue;
        final tags = row['tags'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(row['tags'] as Map<String, dynamic>)
            : <String, dynamic>{};
        final name = tags['name']?.toString().trim();
        items.add(
          _VetItem(
            name: (name == null || name.isEmpty) ? 'Veteriner Klinigi' : name,
            address: _addressFromTags(tags),
            latitude: lat,
            longitude: lon,
            distanceKm: _distanceKm(latitude, longitude, lat, lon),
            hasPreciseLocation: true,
          ),
        );
      }

      final deduped = _dedupeByCoordinate(items)..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      return _OverpassAttemptResult(items: deduped);
    } catch (_) {
      return const _OverpassAttemptResult(items: []);
    }
  }

  Future<String?> _resolveCityName(Position position) async {
    try {
      final response = await http
          .get(
            Uri.https('nominatim.openstreetmap.org', '/reverse', {
              'lat': position.latitude.toString(),
              'lon': position.longitude.toString(),
              'format': 'jsonv2',
              'addressdetails': '1',
            }),
            headers: _osmHeaders,
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final addressRaw = decoded['address'];
      if (addressRaw is! Map) return null;
      final address = Map<String, dynamic>.from(addressRaw);
      final city = address['city']?.toString().trim();
      final town = address['town']?.toString().trim();
      final county = address['county']?.toString().trim();
      return city?.isNotEmpty == true
          ? city
          : town?.isNotEmpty == true
              ? town
              : county;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  List<_VetItem> _dedupeByCoordinate(List<_VetItem> list) {
    final seen = <String>{};
    final out = <_VetItem>[];
    for (final item in list) {
      final key = _vetKey(item);
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(item);
    }
    return out;
  }

  String _addressFromTags(Map<String, dynamic> tags) {
    final full = tags['addr:full']?.toString().trim();
    if (full != null && full.isNotEmpty) return full;
    final street = tags['addr:street']?.toString().trim() ?? '';
    final number = tags['addr:housenumber']?.toString().trim() ?? '';
    final district = tags['addr:suburb']?.toString().trim() ?? '';
    final city = tags['addr:city']?.toString().trim() ?? '';
    final parts = <String>[
      if (street.isNotEmpty) '$street ${number.isNotEmpty ? number : ''}'.trim(),
      if (district.isNotEmpty) district,
      if (city.isNotEmpty) city,
    ];
    return parts.isEmpty ? 'Adres bilgisi bulunamadi' : parts.join(', ');
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earth = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = pow(sin(dLat / 2), 2) + cos(_toRad(lat1)) * cos(_toRad(lat2)) * pow(sin(dLon / 2), 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earth * c;
  }

  double _toRad(double degree) => degree * pi / 180;
  double? _toDouble(Object? value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');

  String _vetKey(_VetItem item) =>
      '${item.latitude.toStringAsFixed(6)}:${item.longitude.toStringAsFixed(6)}';

  List<_VetItem> get _visibleItems {
    switch (_filter) {
      case _VetFilter.nearest:
        return _items.isEmpty ? const [] : [_items.first];
      case _VetFilter.within5:
        return _items.where((e) => e.distanceKm <= 5).toList();
      case _VetFilter.within10:
        return _items.where((e) => e.distanceKm <= 10).toList();
      case _VetFilter.all:
        return _items;
    }
  }

  Future<void> _showRouteToVet(_VetItem item) async {
    final pos = _position;
    final query = Uri.encodeComponent('${item.name} Elazığ');
    final uri = (item.hasPreciseLocation && pos != null)
        ? Uri.parse(
            'https://www.google.com/maps/dir/?api=1'
            '&origin=${pos.latitude},${pos.longitude}'
            '&destination=${item.latitude},${item.longitude}'
            '&travelmode=driving',
          )
        : Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openNearbySearchInGoogleMaps() async {
    final pos = _position;
    final uri = pos == null
        ? Uri.parse('https://www.google.com/maps/search/?api=1&query=veteriner+Elazığ')
        : Uri.parse(
            'https://www.google.com/maps/search/veteriner/@${pos.latitude},${pos.longitude},14z',
          );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _scrollToVet(_VetItem item) async {
    final key = _cardKeys[_vetKey(item)]?.currentContext;
    if (key == null) return;
    await Scrollable.ensureVisible(key, duration: const Duration(milliseconds: 300), alignment: 0.1);
  }

  void _focusOnVet(_VetItem item) {
    final pos = _position;
    if (pos == null) return;
    setState(() => _selectedVetKey = _vetKey(item));
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([
          LatLng(pos.latitude, pos.longitude),
          LatLng(item.latitude, item.longitude),
        ]),
        padding: const EdgeInsets.all(62),
        maxZoom: 14.5,
      ),
    );
  }

  void _fitMapToPoints() {
    final pos = _position;
    if (pos == null || _items.isEmpty) return;
    final points = <LatLng>[
      LatLng(pos.latitude, pos.longitude),
      ..._items.map((e) => LatLng(e.latitude, e.longitude)),
    ];
    _mapController.fitCamera(
      CameraFit.bounds(bounds: LatLngBounds.fromPoints(points), padding: const EdgeInsets.all(42), maxZoom: 14.5),
    );
  }

  Future<void> _goToTab(int index) async {
    final targetRoute = switch (index) {
      0 => AppRoutes.home,
      1 => AppRoutes.reportCreate,
      2 => AppRoutes.veterinarians,
      3 => AppRoutes.profile,
      _ => AppRoutes.home,
    };
    if (targetRoute == ModalRoute.of(context)?.settings.name) return;
    await TabPersistenceService.saveTabIndex(index);
    if (!mounted) return;
    Navigator.of(context).pushNamed(targetRoute);
  }

  @override
  Widget build(BuildContext context) {
    final nearest = _items.isNotEmpty ? _items.first : null;
    final visible = _visibleItems;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Yakın Veterinerler'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                children: [
                  Text(
                    'Konumunuza en yakin veterinerleri gosterir.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                  ),
                  if (_sourceNote != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _sourceNote!,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.my_location_rounded),
                        label: const Text('Konuma Gore Yenile'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<_VetFilter>(
                          initialValue: _filter,
                          decoration: const InputDecoration(isDense: true),
                          items: const [
                            DropdownMenuItem(value: _VetFilter.nearest, child: Text('En yakin')),
                            DropdownMenuItem(value: _VetFilter.within5, child: Text('5 km')),
                            DropdownMenuItem(value: _VetFilter.within10, child: Text('10 km')),
                            DropdownMenuItem(value: _VetFilter.all, child: Text('Tumu')),
                          ],
                          onChanged: (v) => setState(() => _filter = v ?? _VetFilter.nearest),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_loading)
                    Text(_searchStage, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                  if (_position != null) ...[
                    const SizedBox(height: 8),
                    _MobileVetMap(
                      controller: _mapController,
                      position: _position!,
                      items: visible,
                      selectedVetKey: _selectedVetKey,
                      nearestVetKey: nearest == null ? null : _vetKey(nearest),
                      onVetTap: (item) async {
                        setState(() => _selectedVetKey = _vetKey(item));
                        await _scrollToVet(item);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (visible.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Yakinda listelenecek veteriner bulunamadi.',
                            style: TextStyle(
                              color: AppColors.heading,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _openNearbySearchInGoogleMaps,
                            icon: const Icon(Icons.travel_explore_rounded),
                            label: const Text('Google Maps’te veteriner ara'),
                          ),
                        ],
                      ),
                    )
                  else
                    ...visible.map((item) {
                      final key = _vetKey(item);
                      _cardKeys.putIfAbsent(key, GlobalKey.new);
                      final isNearest = nearest != null && key == _vetKey(nearest);
                      final isSelected = _selectedVetKey == key || _hoveredVetKey == key;
                      return Padding(
                        key: _cardKeys[key],
                        padding: const EdgeInsets.only(bottom: 10),
                        child: MouseRegion(
                          onEnter: (_) => setState(() => _hoveredVetKey = key),
                          onExit: (_) => setState(() => _hoveredVetKey = null),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _focusOnVet(item),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : isNearest
                                          ? AppColors.primary.withValues(alpha: 0.5)
                                          : AppColors.border,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.local_hospital_rounded, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.heading)),
                                      ),
                                      if (isNearest)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: const Text('En yakin', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(item.address, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Uzaklik: ${item.distanceKm.toStringAsFixed(1)} km',
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.heading),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Tahmini sure: Google Maps uzerinden hesaplanir',
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      FilledButton.icon(
                                        onPressed: () => _focusOnVet(item),
                                        icon: const Icon(Icons.location_searching_rounded),
                                        label: const Text('Haritada Goster'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () => _showRouteToVet(item),
                                        icon: const Icon(Icons.route_rounded),
                                        label: const Text('Yol Tarifi Al'),
                                      ),
                                    ],
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Konumu Google Maps uzerinden dogrulayiniz.',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(currentIndex: 2, onTap: _goToTab),
    );
  }
}

class _MobileVetMap extends StatefulWidget {
  const _MobileVetMap({
    required this.controller,
    required this.position,
    required this.items,
    required this.selectedVetKey,
    required this.nearestVetKey,
    required this.onVetTap,
  });

  final MapController controller;
  final Position position;
  final List<_VetItem> items;
  final String? selectedVetKey;
  final String? nearestVetKey;
  final ValueChanged<_VetItem> onVetTap;

  @override
  State<_MobileVetMap> createState() => _MobileVetMapState();
}

class _MobileVetMapState extends State<_MobileVetMap> {
  String _keyFor(_VetItem item) =>
      '${item.latitude.toStringAsFixed(6)}:${item.longitude.toStringAsFixed(6)}';

  @override
  void didUpdateWidget(covariant _MobileVetMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items != oldWidget.items || widget.position != oldWidget.position) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    }
  }

  void _fit() {
    final points = <LatLng>[
      LatLng(widget.position.latitude, widget.position.longitude),
      ...widget.items.map((e) => LatLng(e.latitude, e.longitude)),
    ];
    if (points.length < 2) {
      widget.controller.move(points.first, 14);
      return;
    }
    widget.controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(40),
        maxZoom: 14.2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userPoint = LatLng(widget.position.latitude, widget.position.longitude);
    return Container(
      height: 250,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: FlutterMap(
        mapController: widget.controller,
        options: MapOptions(initialCenter: userPoint, initialZoom: 11.8),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.patimap.app',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: userPoint,
                width: 24,
                height: 24,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
              ...widget.items.map((vet) {
                final key = _keyFor(vet);
                final isSelected = widget.selectedVetKey == key;
                final isNearest = widget.nearestVetKey == key;
                return Marker(
                  point: LatLng(vet.latitude, vet.longitude),
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () => widget.onVetTap(vet),
                    child: Icon(
                      Icons.local_hospital_rounded,
                      color: isSelected
                          ? AppColors.primary
                          : isNearest
                              ? AppColors.heading
                              : Colors.redAccent,
                      size: isSelected ? 34 : 30,
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

class _VetItem {
  const _VetItem({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.hasPreciseLocation,
  });

  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final bool hasPreciseLocation;
}

class _OverpassAttemptResult {
  const _OverpassAttemptResult({required this.items});
  final List<_VetItem> items;
}

class _FallbackSearchResult {
  const _FallbackSearchResult({required this.items, this.note});
  final List<_VetItem> items;
  final String? note;
}

