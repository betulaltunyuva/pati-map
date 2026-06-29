import 'dart:convert';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/panel_empty_state.dart';
import '../components/panel_header_actions.dart';
import '../components/scroll_reveal.dart';
import '../components/web_panel_layout.dart';
import '../theme/app_palette.dart';
import '../utils/panel_responsive.dart';
import 'dashboard_page.dart';
import 'map_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';

class NearbyVetsPage extends StatefulWidget {
  const NearbyVetsPage({super.key});

  @override
  State<NearbyVetsPage> createState() => _NearbyVetsPageState();
}

class _NearbyVetsPageState extends State<NearbyVetsPage> {
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
    'User-Agent': 'PatiMapWeb/1.0 (nearby-vets)',
  };

  final MapController _mapController = MapController();
  final ScrollController _listScrollController = ScrollController();
  final Map<String, GlobalKey> _cardKeys = <String, GlobalKey>{};

  bool _loading = true;
  String? _error;
  String _searchStage = '';
  String? _sourceNote;
  Position? _position;
  List<_VetItem> _items = const [];
  _VetFilter _filter = _VetFilter.nearest;
  String? _selectedVetKey;
  String? _hoveredVetKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _sourceNote = null;
      _searchStage = 'Konum aliniyor...';
      _items = const [];
    });

    try {
      final permission = await _ensureLocationPermission();
      if (!permission) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Konum izni olmadan yakin veterinerler bulunamaz. Lutfen tarayici ayarlarindan konum izni verin.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      debugPrint('NearbyVets user location: lat=${position.latitude}, lon=${position.longitude}');

      if (!mounted) return;
      setState(() => _position = position);

      final fallbackResult = await _searchWithFallback(position);
      if (!mounted) return;

      setState(() {
        _items = fallbackResult.items;
        _sourceNote = fallbackResult.note;
        _searchStage = fallbackResult.items.isEmpty ? 'Arama tamamlandi.' : 'En yakin veterinerler listelendi.';
        _error = null;
        _selectedVetKey =
            fallbackResult.items.isNotEmpty ? _vetKey(fallbackResult.items.first) : null;
        _hoveredVetKey = null;
      });

      if (fallbackResult.items.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToPoints());
      }
    } catch (e) {
      debugPrint('NearbyVets load error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Veteriner verisi alinamadi, lutfen tekrar deneyin.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<_FallbackSearchResult> _searchWithFallback(Position position) async {
    final cityName = await _resolveCityName(position) ?? 'Elazığ';
    final overpass = await _searchByGrowingRadius(position);
    if (overpass.isNotEmpty) {
      return _FallbackSearchResult(items: overpass);
    }

    if (mounted) {
      setState(() => _searchStage = 'Overpass bos dondu, Nominatim fallback araniyor...');
    }
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
      final km = radius ~/ 1000;
      setState(() => _searchStage = '$km km icinde veteriner araniyor...');
      debugPrint('NearbyVets trying radius: $radius');

      var responded = false;
      var elementCount = 0;
      try {
        final attempt = await _queryOverpassByRadius(
          latitude: position.latitude,
          longitude: position.longitude,
          radiusMeters: radius,
        );
        responded = attempt.responded;
        elementCount = attempt.elementCount;
        debugPrint('NearbyVets api responded: $responded');
        debugPrint('NearbyVets element count: $elementCount');
        if (attempt.items.isNotEmpty) {
          final results = attempt.items;
          results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
          final debugList = results
              .map((e) => '${e.name} (${e.distanceKm.toStringAsFixed(2)} km)')
              .toList();
          debugPrint('NearbyVets sorted list: $debugList');
          return results;
        }
      } catch (e) {
        debugPrint('NearbyVets radius error ($radius): $e');
      } finally {
        debugPrint(
          'NearbyVets radius done -> radius:$radius responded:$responded elements:$elementCount',
        );
      }
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

          final name = row['name']?.toString().trim();
          final displayName = row['display_name']?.toString().trim();
          all.add(
            _VetItem(
              name: (name == null || name.isEmpty) ? 'Veteriner Klinigi' : name,
              address: (displayName == null || displayName.isEmpty)
                  ? 'Adres bilgisi bulunamadi'
                  : displayName,
              latitude: lat,
              longitude: lon,
              distanceKm: _distanceKm(position.latitude, position.longitude, lat, lon),
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
        final response = await http
            .get(
              Uri.https('nominatim.openstreetmap.org', '/search', {
                'q': '$query $cityName',
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

          final name = row['name']?.toString().trim();
          final displayName = row['display_name']?.toString().trim();
          all.add(
            _VetItem(
              name: (name == null || name.isEmpty) ? 'Veteriner Klinigi' : name,
              address: (displayName == null || displayName.isEmpty)
                  ? 'Adres bilgisi bulunamadi'
                  : displayName,
              latitude: foundLat,
              longitude: foundLon,
              distanceKm: _distanceKm(position.latitude, position.longitude, foundLat, foundLon),
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

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return false;
    if (permission == LocationPermission.denied) return false;
    return true;
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
          'User-Agent': 'PatiMapWeb/1.0 (nearby-vets)',
        },
        body: query,
      )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('Overpass status: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const _OverpassAttemptResult(items: [], responded: true, elementCount: 0);
      }
      final elements = decoded['elements'];
      if (elements is! List) {
        return const _OverpassAttemptResult(items: [], responded: true, elementCount: 0);
      }

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
          ),
        );
      }

      final deduped = _dedupeByCoordinate(items);
      deduped.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      return _OverpassAttemptResult(
        items: deduped,
        responded: true,
        elementCount: elements.length,
      );
    } on TimeoutException catch (e) {
      debugPrint('NearbyVets overpass timeout: $e');
      return const _OverpassAttemptResult(items: [], responded: false, elementCount: 0);
    } catch (e) {
      debugPrint('NearbyVets overpass error: $e');
      return const _OverpassAttemptResult(items: [], responded: false, elementCount: 0);
    }
  }

  List<_VetItem> _dedupeByCoordinate(List<_VetItem> list) {
    final seen = <String>{};
    final out = <_VetItem>[];
    for (final item in list) {
      final key = '${item.latitude.toStringAsFixed(6)}:${item.longitude.toStringAsFixed(6)}';
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
      if (city != null && city.isNotEmpty) return city;
      if (town != null && town.isNotEmpty) return town;
      if (county != null && county.isNotEmpty) return county;
      return null;
    } catch (_) {
      return null;
    }
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

  double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

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

  Future<void> _scrollToVet(_VetItem item) async {
    final key = _vetKey(item);
    final cardKey = _cardKeys[key];
    final contextForCard = cardKey?.currentContext;
    if (contextForCard == null) return;
    await Scrollable.ensureVisible(
      contextForCard,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.1,
    );
  }

  void _focusOnVet(_VetItem item) {
    final pos = _position;
    if (pos == null) return;
    setState(() => _selectedVetKey = _vetKey(item));
    final points = <LatLng>[
      LatLng(pos.latitude, pos.longitude),
      LatLng(item.latitude, item.longitude),
    ];
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(56),
        maxZoom: 16,
      ),
    );
  }

  Future<void> _showRouteToVet(_VetItem item) async {
    final cityHint = _position != null ? await _resolveCityName(_position!) ?? 'Elazığ' : 'Elazığ';
    final query = Uri.encodeComponent('${item.name} $cityHint');
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
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
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(40),
        maxZoom: 15.5,
      ),
    );
  }

  void _onMenuSelected(BuildContext context, WebMenuItem item) {
    switch (item) {
      case WebMenuItem.dashboard:
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DashboardPage()));
        return;
      case WebMenuItem.reports:
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ReportsPage()));
        return;
      case WebMenuItem.map:
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MapPage()));
        return;
      case WebMenuItem.volunteers:
        return;
      case WebMenuItem.settings:
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nearest = _items.isNotEmpty ? _items.first : null;
    final visibleItems = _visibleItems;
    return WebPanelLayout(
      revealScope: 'volunteers',
      currentItem: WebMenuItem.volunteers,
      title: 'PatiMap',
      onMenuSelected: (item) => _onMenuSelected(context, item),
      headerTrailing: PanelHeaderActions.authStream(
        context,
        onLogin: () => PanelHeaderActions.openLogin(context),
        onRegister: () => PanelHeaderActions.openRegister(context),
        onProfile: () => PanelHeaderActions.openProfile(context),
        onSettings: () => PanelHeaderActions.openSettings(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScrollReveal(
            detectKey: const ValueKey<String>('volunteers_intro_toolbar'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Yakin Veterinerler',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Konumunuza gore en yakin veterinerler listelenir.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final mobile = PanelResponsive.isMobile(constraints.maxWidth);
                    final filterField = DropdownButtonFormField<_VetFilter>(
                      initialValue: _filter,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: _VetFilter.nearest,
                          child: Text('En yakin'),
                        ),
                        DropdownMenuItem(
                          value: _VetFilter.within5,
                          child: Text('5 km icindekiler'),
                        ),
                        DropdownMenuItem(
                          value: _VetFilter.within10,
                          child: Text('10 km icindekiler'),
                        ),
                        DropdownMenuItem(
                          value: _VetFilter.all,
                          child: Text('Tumu'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _filter = value);
                      },
                    );

                    if (mobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.my_location_rounded, size: 18),
                            label: const Text('Konuma Gore Yenile'),
                          ),
                          if (_loading) ...[
                            const SizedBox(height: 8),
                            Text(
                              _searchStage,
                              style: const TextStyle(
                                color: AppPalette.textMuted,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          filterField,
                        ],
                      );
                    }

                    return Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.my_location_rounded, size: 18),
                          label: const Text('Konuma Gore Yenile'),
                        ),
                        if (_loading)
                          Text(
                            _searchStage,
                            style: const TextStyle(
                              color: AppPalette.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        SizedBox(width: 180, child: filterField),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_position != null)
            ScrollReveal(
              detectKey: const ValueKey<String>('volunteers_map_legend'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MapPreview(
                    controller: _mapController,
                    position: _position!,
                    items: visibleItems,
                    selectedVetKey: _selectedVetKey,
                    nearestVetKey: nearest == null ? null : _vetKey(nearest),
                    onVetTap: (item) async {
                      setState(() => _selectedVetKey = _vetKey(item));
                      await _scrollToVet(item);
                    },
                    onRouteTap: (item) => _showRouteToVet(item),
                  ),
                  const SizedBox(height: 8),
                  const Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    children: [
                      _MapLegendItem(
                        icon: Icons.circle,
                        iconColor: AppPalette.primaryBlue,
                        label: 'Mavi nokta: Benim konumum',
                      ),
                      _MapLegendItem(
                        icon: Icons.local_hospital_rounded,
                        iconColor: Colors.redAccent,
                        label:
                            'Veteriner ikonu: Veteriner / hayvan hastanesi',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ScrollReveal(
            detectKey: const ValueKey<String>('volunteers_results'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          if (_sourceNote != null) ...[
            Text(
              _sourceNote!,
              style: const TextStyle(
                color: AppPalette.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (_error != null)
            PanelErrorState(message: _error!)
          else if (_loading)
            const PanelListSkeleton(itemCount: 3)
          else if (visibleItems.isEmpty && _position != null)
            PanelEmptyState(
              icon: Icons.local_hospital_outlined,
              title: 'Yakinlarda veteriner bulunamadi.',
              subtitle: 'Arama yaricapini genisletmeyi deneyin veya haritada manuel arama yapin.',
              action: OutlinedButton.icon(
                onPressed: () async {
                  final lat = _position!.latitude;
                  final lon = _position!.longitude;
                  final uri = Uri.parse(
                    'https://www.google.com/maps/search/veteriner/@$lat,$lon,14z',
                  );
                  await launchUrl(
                    uri,
                    mode: LaunchMode.platformDefault,
                    webOnlyWindowName: '_blank',
                  );
                },
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text("Google Maps'te veteriner ara"),
              ),
            )
          else
            ListView.separated(
              controller: _listScrollController,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleItems.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = visibleItems[index];
                final key = _vetKey(item);
                _cardKeys.putIfAbsent(key, GlobalKey.new);
                final isNearest =
                    nearest != null && item.latitude == nearest.latitude && item.longitude == nearest.longitude;
                final isSelected = _selectedVetKey == key || _hoveredVetKey == key;
                return Container(
                  key: _cardKeys[key],
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppPalette.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppPalette.primaryBlue
                          : isNearest
                              ? AppPalette.primaryBlue.withValues(alpha: 0.45)
                              : AppPalette.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? AppPalette.primaryBlue.withValues(alpha: 0.16)
                            : AppPalette.navy.withValues(alpha: 0.05),
                        blurRadius: isSelected ? 20 : 14,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _hoveredVetKey = key),
                    onExit: (_) => setState(() => _hoveredVetKey = null),
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedVetKey = key);
                        _focusOnVet(item);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppPalette.primaryBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.local_hospital_rounded, color: AppPalette.primaryBlue, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: const TextStyle(color: AppPalette.navy, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                    if (isNearest)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppPalette.primaryBlue.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: const Text(
                                          'En yakin',
                                          style: TextStyle(color: AppPalette.primaryBlue, fontWeight: FontWeight.w700, fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(item.address, style: const TextStyle(color: AppPalette.textMuted, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Text(
                                  'Uzaklik: ${item.distanceKm.toStringAsFixed(1)} km',
                                  style: const TextStyle(color: AppPalette.navy, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Tahmini sure: Google Maps uzerinden hesaplanir',
                                  style: TextStyle(color: AppPalette.textMuted, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: () => _focusOnVet(item),
                                      icon: const Icon(Icons.location_searching_rounded, size: 18),
                                      label: const Text('Haritada Goster'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _showRouteToVet(item),
                                      icon: const Icon(Icons.route_rounded, size: 18),
                                      label: const Text('Yol Tarifi Al'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Konumu Google Maps uzerinden dogrulayiniz.',
                                  style: TextStyle(
                                    color: AppPalette.textMuted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPreview extends StatefulWidget {
  const _MapPreview({
    required this.controller,
    required this.position,
    required this.items,
    required this.onVetTap,
    required this.onRouteTap,
    required this.selectedVetKey,
    required this.nearestVetKey,
  });

  final MapController controller;
  final Position position;
  final List<_VetItem> items;
  final ValueChanged<_VetItem> onVetTap;
  final ValueChanged<_VetItem> onRouteTap;
  final String? selectedVetKey;
  final String? nearestVetKey;

  @override
  State<_MapPreview> createState() => _MapPreviewState();
}

class _MapPreviewState extends State<_MapPreview> {
  String _keyFor(_VetItem item) =>
      '${item.latitude.toStringAsFixed(6)}:${item.longitude.toStringAsFixed(6)}';

  @override
  void didUpdateWidget(covariant _MapPreview oldWidget) {
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
        padding: const EdgeInsets.all(36),
        maxZoom: 15.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userPoint = LatLng(widget.position.latitude, widget.position.longitude);
    return Container(
      height: 300,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppPalette.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.border),
      ),
      child: FlutterMap(
        mapController: widget.controller,
        options: MapOptions(
          initialCenter: userPoint,
          initialZoom: 13,
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.patimap.web',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: userPoint,
                width: 24,
                height: 24,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppPalette.primaryBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
              ...widget.items.map((vet) {
                final key = _keyFor(vet);
                final isSelected = widget.selectedVetKey == key;
                final isNearest = widget.nearestVetKey == key;
                final showPopup = isSelected;
                return Marker(
                  point: LatLng(vet.latitude, vet.longitude),
                  width: 210,
                  height: showPopup ? 176 : 56,
                  child: GestureDetector(
                    onTap: () => widget.onVetTap(vet),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_hospital_rounded,
                          color: isSelected
                              ? AppPalette.primaryBlue
                              : isNearest
                                  ? AppPalette.navy
                                  : Colors.redAccent,
                          size: isSelected ? 36 : (isNearest ? 33 : 30),
                        ),
                        if (showPopup)
                          Container(
                            width: 198,
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppPalette.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vet.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppPalette.navy,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Uzaklik: ${vet.distanceKm.toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                    color: AppPalette.textMuted,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
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

class _MapLegendItem extends StatelessWidget {
  const _MapLegendItem({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppPalette.textMuted,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}

enum _VetFilter {
  nearest,
  within5,
  within10,
  all,
}

class _VetItem {
  const _VetItem({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
  });

  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double distanceKm;
}

class _OverpassAttemptResult {
  const _OverpassAttemptResult({
    required this.items,
    required this.responded,
    required this.elementCount,
  });

  final List<_VetItem> items;
  final bool responded;
  final int elementCount;
}

class _FallbackSearchResult {
  const _FallbackSearchResult({
    required this.items,
    this.note,
  });

  final List<_VetItem> items;
  final String? note;
}

