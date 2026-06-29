import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../services/report_map_service.dart';
import '../theme/app_palette.dart';
import '../utils/risk_analyzer.dart';

class CreateReportDialog extends StatefulWidget {
  const CreateReportDialog({super.key});

  @override
  State<CreateReportDialog> createState() => _CreateReportDialogState();
}

class _CreateReportDialogState extends State<CreateReportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _addressNoteController = TextEditingController();
  final _customAnimalController = TextEditingController();
  final _customSituationController = TextEditingController();
  final _locationSearchController = TextEditingController();
  final _picker = ImagePicker();
  final _mapController = MapController();

  String? _animalType;
  String? _situation;
  String? _urgency;
  LatLng? _pickedPoint;
  Uint8List? _photoBytes;
  String? _photoName;
  bool _submitting = false;
  bool _searchingLocation = false;
  List<_LocationSearchResult> _locationResults = const [];
  String? _pickedAddress;
  bool _resolvingAddress = false;
  String _locationTypeFilter = 'all';
  final _cityFilterController = TextEditingController();
  final _districtFilterController = TextEditingController();
  Timer? _citySearchDebounce;

  static const List<(String, String)> _locationTypeFilters = [
    ('all', 'Tum Sonuclar'),
    ('place', 'Yer / Bolge'),
    ('highway', 'Yol / Cadde'),
    ('amenity', 'Kurum / Nokta'),
    ('building', 'Bina'),
  ];

  static const _animalTypes = [
    ('cat', 'Kedi'),
    ('dog', 'Köpek'),
    ('bird', 'Kuş'),
    ('other', 'Diğer'),
  ];
  static const _situations = [
    ('injured', 'Yaralı'),
    ('hungry', 'Aç'),
    ('missing', 'Kaybolmuş'),
    ('thirsty', 'Susuz'),
    ('needs_care', 'Bakıma Muhtaç'),
    ('attacked', 'Saldırıya Uğramış'),
    ('other', 'Diğer'),
  ];
  static const _urgencies = [
    ('low', 'Düşük'),
    ('normal', 'Orta'),
    ('urgent', 'Yüksek'),
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressNoteController.dispose();
    _customAnimalController.dispose();
    _customSituationController.dispose();
    _locationSearchController.dispose();
    _cityFilterController.dispose();
    _districtFilterController.dispose();
    _citySearchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _searchLocation() async {
    final query = _locationSearchController.text.trim();
    if (query.length < 3) {
      _showMessage('Konum aramak için en az 3 karakter girin.');
      return;
    }
    setState(() => _searchingLocation = true);
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'jsonv2',
        'limit': '8',
        'countrycodes': 'tr',
        'addressdetails': '1',
      });
      final response = await http.get(
        uri,
        headers: const {'Accept': 'application/json'},
      );
      if (response.statusCode != 200) {
        throw Exception('Konum arama yaniti gecersiz: ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) throw Exception('Konum arama formati gecersiz');
      final parsed = <_LocationSearchResult>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final lat = double.tryParse(map['lat']?.toString() ?? '');
        final lon = double.tryParse(map['lon']?.toString() ?? '');
        final label = map['display_name']?.toString().trim() ?? '';
        if (lat == null || lon == null || label.isEmpty) continue;
        parsed.add(
          _LocationSearchResult(
            label: label,
            point: LatLng(lat, lon),
            className: map['class']?.toString().trim().toLowerCase(),
            typeName: map['type']?.toString().trim().toLowerCase(),
            city: _cityFromAddress(map['address']),
            district: _districtFromAddress(map['address']),
          ),
        );
      }
      if (!mounted) return;
      setState(() => _locationResults = parsed);
      if (parsed.isEmpty) {
        _showMessage('Sonuc bulunamadi. Daha farkli bir konum yazin.');
      }
    } catch (_) {
      _showMessage('Konum aramasi yapilamadi. Lutfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _searchingLocation = false);
    }
  }

  void _pickLocationResult(_LocationSearchResult result) {
    setState(() {
      _pickedPoint = result.point;
      _pickedAddress = result.label;
      _locationResults = const [];
    });
    _mapController.move(result.point, 14);
  }

  Future<void> _resolveAddressForPoint(LatLng point) async {
    setState(() => _resolvingAddress = true);
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
        'format': 'jsonv2',
        'zoom': '18',
        'addressdetails': '1',
      });
      final response = await http.get(
        uri,
        headers: const {'Accept': 'application/json'},
      );
      if (response.statusCode != 200) {
        throw Exception('Adres cozumleme basarisiz: ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw Exception('Adres cozumleme formati gecersiz');
      final map = Map<String, dynamic>.from(decoded);
      final displayName = map['display_name']?.toString().trim();
      if (!mounted) return;
      setState(() {
        _pickedAddress = (displayName != null && displayName.isNotEmpty)
            ? displayName
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pickedAddress = null;
      });
    } finally {
      if (mounted) {
        setState(() => _resolvingAddress = false);
      }
    }
  }

  String? _cityFromAddress(Object? rawAddress) {
    if (rawAddress is! Map) return null;
    final address = Map<String, dynamic>.from(rawAddress);
    final city = address['city']?.toString().trim();
    if (city != null && city.isNotEmpty) return city;
    final town = address['town']?.toString().trim();
    if (town != null && town.isNotEmpty) return town;
    final state = address['state']?.toString().trim();
    if (state != null && state.isNotEmpty) return state;
    return null;
  }

  String? _districtFromAddress(Object? rawAddress) {
    if (rawAddress is! Map) return null;
    final address = Map<String, dynamic>.from(rawAddress);
    final district = address['county']?.toString().trim();
    if (district != null && district.isNotEmpty) return district;
    final suburb = address['suburb']?.toString().trim();
    if (suburb != null && suburb.isNotEmpty) return suburb;
    final neighbourhood = address['neighbourhood']?.toString().trim();
    if (neighbourhood != null && neighbourhood.isNotEmpty) return neighbourhood;
    return null;
  }

  List<_LocationSearchResult> _filteredLocationResults() {
    final cityFilter = _cityFilterController.text.trim().toLowerCase();
    final districtFilter = _districtFilterController.text.trim().toLowerCase();
    return _locationResults.where((result) {
      final typeMatches =
          _locationTypeFilter == 'all' || result.className == _locationTypeFilter;
      if (!typeMatches) return false;
      final city = result.city?.toLowerCase() ?? '';
      final district = result.district?.toLowerCase() ?? '';
      final label = result.label.toLowerCase();
      final cityMatches =
          cityFilter.isEmpty || city.contains(cityFilter) || label.contains(cityFilter);
      final districtMatches = districtFilter.isEmpty ||
          district.contains(districtFilter) ||
          label.contains(districtFilter);
      return cityMatches && districtMatches;
    }).toList(growable: false);
  }

  Future<void> _focusMapToAdministrativeQuery({
    required String cityRaw,
    required String districtRaw,
  }) async {
    final city = cityRaw.trim();
    final district = districtRaw.trim();
    final query = [district, city].where((e) => e.isNotEmpty).join(', ');
    if (query.length < 2) return;
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'jsonv2',
        'limit': '1',
        'countrycodes': 'tr',
      });
      final response = await http.get(
        uri,
        headers: const {'Accept': 'application/json'},
      );
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) return;
      final first = decoded.first;
      if (first is! Map) return;
      final map = Map<String, dynamic>.from(first);
      final lat = double.tryParse(map['lat']?.toString() ?? '');
      final lon = double.tryParse(map['lon']?.toString() ?? '');
      if (lat == null || lon == null) return;
      final zoom = district.isNotEmpty ? 12.8 : 10.8;
      _mapController.move(LatLng(lat, lon), zoom);
    } catch (_) {
      // Silent fail: filtering should continue even if city lookup fails.
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (!mounted || file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _photoName = file.name;
      });
    } catch (_) {
      _showMessage('Galeri acilamadi. Lutfen tekrar deneyin.');
    }
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      _showMessage(
        'Lutfen zorunlu alanlari doldurun: Tur, Durum, Aciliyet ve Aciklama.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final selectedAddress = _pickedAddress?.trim();
      final addressNote = _addressNoteController.text.trim();
      final description = _descriptionController.text.trim();
      final riskResult = await analyzeRiskWithAI(description);
      final locationNote = (() {
        final hasSelected = selectedAddress != null && selectedAddress.isNotEmpty;
        final hasNote = addressNote.isNotEmpty;
        if (hasSelected && hasNote) {
          return '$selectedAddress - $addressNote';
        }
        if (hasSelected) return selectedAddress;
        if (hasNote) return addressNote;
        return null;
      })();

      await ReportMapService.createReport(
        animalType: _animalType!,
        customAnimalType:
            _animalType == 'other' ? _customAnimalController.text.trim() : null,
        reportSituation: _situation!,
        customReportSituation: _situation == 'other'
            ? _customSituationController.text.trim()
            : null,
        urgency: _urgency!,
        description: description,
        latitude: _pickedPoint?.latitude,
        longitude: _pickedPoint?.longitude,
        locationNote: locationNote,
        photoBytes: _photoBytes,
        photoFileName: _photoName,
        riskLevel: riskResult.riskLevel,
        aiScore: riskResult.aiScore,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _showMessage(ReportMapService.messageForError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 980;
    final visibleLocationResults = _filteredLocationResults();
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: wide ? 980 : 620,
          maxHeight: 760,
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'İhbar Oluştur',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.navy,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sectionCard(
                          title: 'Temel Bilgiler',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _fieldContainer(
                                    context,
                                    _dropdownField(
                                      label: 'Tur *',
                                      hint: 'Hayvan türünü seçin',
                                      value: _animalType,
                                      items: _animalTypes,
                                      onChanged: (v) => setState(() => _animalType = v),
                                      validator: (v) =>
                                          v == null ? 'Hayvan turu secimi gerekli' : null,
                                    ),
                                  ),
                                  _fieldContainer(
                                    context,
                                    _dropdownField(
                                      label: 'Durum *',
                                      hint: 'Durumu seçin',
                                      value: _situation,
                                      items: _situations,
                                      onChanged: (v) => setState(() => _situation = v),
                                      validator: (v) =>
                                          v == null ? 'Durum secimi gerekli' : null,
                                    ),
                                  ),
                                  _fieldContainer(
                                    context,
                                    _dropdownField(
                                      label: 'Aciliyet *',
                                      hint: 'Aciliyeti seçin',
                                      value: _urgency,
                                      items: _urgencies,
                                      onChanged: (v) => setState(() => _urgency = v),
                                      validator: (v) =>
                                          v == null ? 'Aciliyet secimi gerekli' : null,
                                    ),
                                  ),
                                ],
                              ),
                              if (_animalType == 'other') ...[
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _customAnimalController,
                                  decoration: const InputDecoration(
                                    labelText: 'Hayvan türünü yazın *',
                                  ),
                                  validator: (value) {
                                    if (_animalType != 'other') return null;
                                    if ((value ?? '').trim().isEmpty) {
                                      return 'Bu alan gerekli';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                              if (_situation == 'other') ...[
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _customSituationController,
                                  decoration: const InputDecoration(
                                    labelText: 'Durumu yazın *',
                                  ),
                                  validator: (value) {
                                    if (_situation != 'other') return null;
                                    if ((value ?? '').trim().isEmpty) {
                                      return 'Bu alan gerekli';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                              TextFormField(
                                controller: _addressNoteController,
                                minLines: 2,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  labelText: 'Adres tarifi / yakın nokta',
                                  hintText: 'Örn: park yanı, bina önünde',
                                  alignLabelWithHint: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _sectionCard(
                          title: 'Açıklama',
                          child: TextFormField(
                            controller: _descriptionController,
                            minLines: 4,
                            maxLines: 8,
                            decoration: const InputDecoration(
                              labelText: 'Açıklama *',
                              hintText: 'Konum, hayvanın durumu, gördüğünüz saat vb.',
                              alignLabelWithHint: true,
                            ),
                            validator: (value) {
                              final text = (value ?? '').trim();
                              if (text.isEmpty) return 'Açıklama gerekli';
                              if (text.length < 10) return 'En az 10 karakter yazın';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        _sectionCard(
                          title: 'Fotoğraf',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _pickPhoto,
                                icon: const Icon(Icons.add_photo_alternate_outlined),
                                label: Text(
                                  _photoBytes == null
                                      ? 'Fotoğraf Ekle'
                                      : 'Fotoğraf Seçildi',
                                ),
                              ),
                              if (_photoBytes != null) ...[
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    height: 170,
                                    child: Image.memory(
                                      _photoBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _sectionCard(
                          title: 'Konum',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _locationSearchController,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => _searchLocation(),
                                decoration: InputDecoration(
                                  labelText: 'Konum filtrele / ara',
                                  hintText: 'Il, ilce, mahalle veya adres yazin',
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  suffixIcon: _searchingLocation
                                      ? const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        )
                                      : IconButton(
                                          onPressed: _searchLocation,
                                          icon: const Icon(Icons.arrow_forward_rounded),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  SizedBox(
                                    width: 240,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _locationTypeFilter,
                                      decoration: const InputDecoration(
                                        labelText: 'Sonuc tipi filtresi',
                                      ),
                                      items: _locationTypeFilters
                                          .map(
                                            (entry) => DropdownMenuItem<String>(
                                              value: entry.$1,
                                              child: Text(entry.$2),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setState(() => _locationTypeFilter = value);
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width: 280,
                                    child: TextField(
                                      controller: _cityFilterController,
                                      onChanged: (value) {
                                        setState(() {});
                                        _citySearchDebounce?.cancel();
                                        _citySearchDebounce = Timer(
                                          const Duration(milliseconds: 450),
                                          () => _focusMapToAdministrativeQuery(
                                            cityRaw: _cityFilterController.text,
                                            districtRaw: _districtFilterController.text,
                                          ),
                                        );
                                      },
                                      onSubmitted: (_) => _focusMapToAdministrativeQuery(
                                        cityRaw: _cityFilterController.text,
                                        districtRaw: _districtFilterController.text,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Il filtresi',
                                        hintText: 'Orn: Elazig, Ankara',
                                        prefixIcon: Icon(Icons.filter_alt_outlined),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 280,
                                    child: TextField(
                                      controller: _districtFilterController,
                                      onChanged: (_) {
                                        setState(() {});
                                        _citySearchDebounce?.cancel();
                                        _citySearchDebounce = Timer(
                                          const Duration(milliseconds: 450),
                                          () => _focusMapToAdministrativeQuery(
                                            cityRaw: _cityFilterController.text,
                                            districtRaw: _districtFilterController.text,
                                          ),
                                        );
                                      },
                                      onSubmitted: (_) => _focusMapToAdministrativeQuery(
                                        cityRaw: _cityFilterController.text,
                                        districtRaw: _districtFilterController.text,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Ilce / Mahalle filtresi',
                                        hintText: 'Orn: Merkez, Izzetpasa',
                                        prefixIcon: Icon(Icons.location_city_outlined),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_locationResults.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  constraints: const BoxConstraints(maxHeight: 180),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FBF9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppPalette.border),
                                  ),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: visibleLocationResults.length,
                                    separatorBuilder: (_, _) => Divider(
                                      height: 1,
                                      color: Colors.grey.shade300,
                                    ),
                                    itemBuilder: (context, index) {
                                      final result = visibleLocationResults[index];
                                      return ListTile(
                                        dense: true,
                                        leading: const Icon(Icons.place_outlined, size: 20),
                                        title: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              result.label,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Tip: ${result.className ?? '-'} • Il: ${result.city ?? '-'}',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        onTap: () => _pickLocationResult(result),
                                      );
                                    },
                                  ),
                                ),
                                if (visibleLocationResults.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      'Secili filtrelere uygun sonuc yok.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                              ],
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 260,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: FlutterMap(
                                    mapController: _mapController,
                                    options: MapOptions(
                                      initialCenter: _pickedPoint ?? const LatLng(39.0, 35.0),
                                      initialZoom: _pickedPoint == null ? 5.6 : 13,
                                      onTap: (_, point) async {
                                        setState(() => _pickedPoint = point);
                                        await _resolveAddressForPoint(point);
                                      },
                                    ),
                                    children: [
                                      TileLayer(
                                        urlTemplate:
                                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                        userAgentPackageName: 'com.patimap.web',
                                      ),
                                      if (_pickedPoint != null)
                                        MarkerLayer(
                                          markers: [
                                            Marker(
                                              point: _pickedPoint!,
                                              width: 38,
                                              height: 38,
                                              child: const Icon(
                                                Icons.location_on_rounded,
                                                color: AppPalette.primaryBlue,
                                                size: 32,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _pickedPoint == null
                                    ? 'Haritadan nokta secin veya ustteki alanla konum filtreleyin.'
                                    : _resolvingAddress
                                        ? 'Adres cozumleniyor... (${_pickedPoint!.latitude.toStringAsFixed(5)}, ${_pickedPoint!.longitude.toStringAsFixed(5)})'
                                        : _pickedAddress == null
                                            ? 'Seçilen konum: ${_pickedPoint!.latitude.toStringAsFixed(5)}, ${_pickedPoint!.longitude.toStringAsFixed(5)}'
                                            : 'Seçilen konum: $_pickedAddress (${_pickedPoint!.latitude.toStringAsFixed(5)}, ${_pickedPoint!.longitude.toStringAsFixed(5)})',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.primaryBlue,
                    ),
                    child: Text(_submitting ? 'Gönderiliyor...' : 'İhbarı Gönder'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldContainer(BuildContext context, Widget child) {
    final w = MediaQuery.of(context).size.width;
    final width = w >= 980 ? 285.0 : (w >= 700 ? 220.0 : double.infinity);
    return SizedBox(width: width, child: child);
  }

  Widget _dropdownField({
    required String label,
    required String hint,
    required String? value,
    required List<(String, String)> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8FBF9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      items: items
          .map(
            (entry) => DropdownMenuItem<String>(
              value: entry.$1,
              child: Text(entry.$2),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppPalette.navy,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _LocationSearchResult {
  const _LocationSearchResult({
    required this.label,
    required this.point,
    this.className,
    this.typeName,
    this.city,
    this.district,
  });

  final String label;
  final LatLng point;
  final String? className;
  final String? typeName;
  final String? city;
  final String? district;
}
