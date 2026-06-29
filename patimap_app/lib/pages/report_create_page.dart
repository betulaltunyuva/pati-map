import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../app_messenger_key.dart';
import '../components/bottom_nav.dart';
import '../report_pin.dart';
import '../routes/app_routes.dart';
import '../services/report_service.dart';
import '../services/tab_persistence_service.dart';
import '../theme/app_colors.dart';
import '../utils/risk_analyzer.dart';
import '../widgets/pati_map_form_fields.dart';
import '../widgets/pati_map_primary_button.dart';

class ReportCreatePage extends StatefulWidget {
  const ReportCreatePage({super.key});

  @override
  State<ReportCreatePage> createState() => _ReportCreatePageState();
}

class _ReportCreatePageState extends State<ReportCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _addressNoteController = TextEditingController();
  final _customAnimalController = TextEditingController();
  final _customSituationController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  ReportAnimalType? _animalType;
  ReportSituation? _situation;
  ReportUrgency? _urgency;
  String _locationSummary = 'Konum henüz alınmadı';
  double? _selectedLatitude;
  double? _selectedLongitude;
  String? _selectedLocationText;
  XFile? _selectedPhoto;
  bool _submitting = false;

  static String _urgencyLabel(ReportUrgency u) => switch (u) {
        ReportUrgency.low => 'Düşük',
        ReportUrgency.normal => 'Orta',
        ReportUrgency.urgent => 'Yüksek',
      };

  @override
  void initState() {
    super.initState();
    TabPersistenceService.saveTabIndex(1);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressNoteController.dispose();
    _customAnimalController.dispose();
    _customSituationController.dispose();
    super.dispose();
  }

  Future<void> _goToTab(BuildContext context, int index) async {
    final targetRoute = switch (index) {
      0 => AppRoutes.home,
      1 => AppRoutes.reportCreate,
      2 => AppRoutes.veterinarians,
      3 => AppRoutes.profile,
      _ => AppRoutes.home,
    };

    if (targetRoute == ModalRoute.of(context)?.settings.name) return;
    await TabPersistenceService.saveTabIndex(index);
    if (!context.mounted) return;
    Navigator.of(context).pushNamed(targetRoute);
  }

  Future<void> _onSubmit() async {
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      appMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Lütfen zorunlu alanları (Tür, Durum, Aciliyet, Açıklama) doldurun.',
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      Uint8List? photoBytes;
      String? photoFileName;
      String? photoPath;
      if (_selectedPhoto != null) {
        photoBytes = await _selectedPhoto!.readAsBytes();
        photoFileName = _selectedPhoto!.name;
        photoPath = _selectedPhoto!.path;
      }
      final analysis = await analyzeRiskWithAI(
        _descriptionController.text.trim(),
      );
      await ReportService.createReport(
        animalType: _animalType!,
        customAnimalType: _animalType == ReportAnimalType.other
            ? _customAnimalController.text.trim()
            : null,
        reportSituation: _situation!,
        customReportSituation: _situation == ReportSituation.other
            ? _customSituationController.text.trim()
            : null,
        urgency: _urgency!,
        description: _descriptionController.text.trim(),
        riskLevel: analysis.riskLevel,
        aiScore: analysis.aiScore,
        latitude: _selectedLatitude,
        longitude: _selectedLongitude,
        locationNote: _addressNoteController.text.trim().isEmpty
            ? null
            : _addressNoteController.text.trim(),
        photoBytes: photoBytes,
        photoFileName: photoFileName,
        photoPath: photoPath,
      );
      if (!mounted) return;

      appMessengerKey.currentState?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: const Text('İhbar başarıyla oluşturuldu'),
          backgroundColor: AppColors.success,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      await Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } catch (e) {
      if (mounted) {
        appMessengerKey.currentState?.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(ReportService.messageForError(e)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _onPhotoPlaceholderTap() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (!mounted || file == null) return;
      setState(() => _selectedPhoto = file);
    } catch (_) {
      appMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Galeri açılamadı. Lütfen tekrar deneyin.'),
        ),
      );
    }
  }

  Future<void> _onLocationPlaceholderTap() async {
    final result = await Navigator.of(context).push<_PickedLocation>(
      MaterialPageRoute(
        builder: (_) => _LocationPickerPage(
          initialLatitude: _selectedLatitude,
          initialLongitude: _selectedLongitude,
          initialLocationText: _selectedLocationText,
        ),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _selectedLatitude = result.latitude;
      _selectedLongitude = result.longitude;
      _selectedLocationText = result.locationText;
      _locationSummary =
          '${result.locationText ?? 'Konum seçildi'}\n'
          '(${result.latitude.toStringAsFixed(5)}, ${result.longitude.toStringAsFixed(5)})';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.pets_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'İhbar Oluştur',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.heading,
                          ),
                        ),
                        Text(
                          'Sokak hayvanı için ihbar bilgilerini doldurun',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PatiMapFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const PatiMapFormFieldLabel('Tür', isRequired: true),
                            PatiMapDropdownFormField<ReportAnimalType>(
                              value: _animalType,
                              hintText: 'Hayvan türünü seçin',
                              entries: ReportAnimalType.values
                                  .map(
                                    (t) => DropdownMenuEntry<ReportAnimalType>(
                                      value: t,
                                      label: t.labelTr,
                                    ),
                                  )
                                  .toList(),
                              onSelected: (v) => setState(() {
                                _animalType = v;
                                if (v != ReportAnimalType.other) {
                                  _customAnimalController.clear();
                                }
                              }),
                              validator: (v) =>
                                  v == null ? 'Hayvan türü seçimi gerekli' : null,
                            ),
                            if (_animalType == ReportAnimalType.other) ...[
                              const SizedBox(height: 14),
                              const PatiMapFormFieldLabel(
                                'Hayvan Türünü Yazın',
                                isRequired: true,
                              ),
                              TextFormField(
                                controller: _customAnimalController,
                                textCapitalization: TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  hintText: 'Örn: Tavşan, kaplumbağa',
                                ),
                                validator: (value) {
                                  if (_animalType != ReportAnimalType.other) {
                                    return null;
                                  }
                                  final t = value?.trim() ?? '';
                                  if (t.isEmpty) return 'Bu alan gerekli';
                                  return null;
                                },
                              ),
                            ],
                            const SizedBox(height: 20),
                            const PatiMapFormFieldLabel(
                              'Durum',
                              isRequired: true,
                            ),
                            PatiMapDropdownFormField<ReportSituation>(
                              value: _situation,
                              hintText: 'Durumu seçin',
                              entries: ReportSituation.values
                                  .map(
                                    (s) => DropdownMenuEntry<ReportSituation>(
                                      value: s,
                                      label: s.labelTr,
                                    ),
                                  )
                                  .toList(),
                              onSelected: (v) => setState(() {
                                _situation = v;
                                if (v != ReportSituation.other) {
                                  _customSituationController.clear();
                                }
                              }),
                              validator: (v) =>
                                  v == null ? 'Durum seçimi gerekli' : null,
                            ),
                            if (_situation == ReportSituation.other) ...[
                              const SizedBox(height: 14),
                              const PatiMapFormFieldLabel(
                                'Durumu Yazın',
                                isRequired: true,
                              ),
                              TextFormField(
                                controller: _customSituationController,
                                textCapitalization: TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  hintText: 'Kısaca durumu açıklayın',
                                ),
                                validator: (value) {
                                  if (_situation != ReportSituation.other) {
                                    return null;
                                  }
                                  final t = value?.trim() ?? '';
                                  if (t.isEmpty) return 'Bu alan gerekli';
                                  return null;
                                },
                              ),
                            ],
                            const SizedBox(height: 20),
                            const PatiMapFormFieldLabel(
                              'Aciliyet',
                              isRequired: true,
                            ),
                            PatiMapDropdownFormField<ReportUrgency>(
                              value: _urgency,
                              hintText: 'Seçin',
                              entries: ReportUrgency.values
                                  .map(
                                    (u) => DropdownMenuEntry<ReportUrgency>(
                                      value: u,
                                      label: _urgencyLabel(u),
                                    ),
                                  )
                                  .toList(),
                              onSelected: (v) => setState(() => _urgency = v),
                              validator: (v) =>
                                  v == null ? 'Aciliyet seçimi gerekli' : null,
                            ),
                            const SizedBox(height: 20),
                            const PatiMapFormFieldLabel(
                              'Açıklama',
                              isRequired: true,
                            ),
                            TextFormField(
                              controller: _descriptionController,
                              minLines: 4,
                              maxLines: 8,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                hintText:
                                    'Konum, hayvanın durumu, gördüğünüz saat vb.',
                                alignLabelWithHint: true,
                              ),
                              validator: (value) {
                                final t = value?.trim() ?? '';
                                if (t.isEmpty) {
                                  return 'Açıklama gerekli';
                                }
                                if (t.length < 10) {
                                  return 'En az 10 karakter yazın';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      PatiMapFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const PatiMapFormFieldLabel('Fotoğraf'),
                            OutlinedButton.icon(
                              onPressed: _onPhotoPlaceholderTap,
                              icon: const Icon(Icons.add_photo_alternate_outlined),
                              label: Text(
                                _selectedPhoto == null
                                    ? 'Fotoğraf Ekle'
                                    : 'Fotoğraf Seçildi',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.heading,
                                side: BorderSide(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_selectedPhoto != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  height: 160,
                                  width: double.infinity,
                                  child: Image.file(
                                    File(_selectedPhoto!.path),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              _selectedPhoto == null
                                  ? 'Galeriden 1 adet fotoğraf seçebilirsiniz.'
                                  : 'Fotoğraf başarıyla seçildi. İsterseniz tekrar seçim yapabilirsiniz.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      PatiMapFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const PatiMapFormFieldLabel('Konum'),
                            Text(
                              _locationSummary,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade800,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _onLocationPlaceholderTap,
                              icon: const Icon(Icons.location_searching_rounded),
                              label: const Text('Haritadan Konum Seç'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.heading,
                                side: BorderSide(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Haritada bir noktaya dokunarak konum seçin. İsterseniz mevcut konumunuza da gidebilirsiniz.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const PatiMapFormFieldLabel(
                              'Adres tarifi / yakın nokta',
                            ),
                            TextFormField(
                              controller: _addressNoteController,
                              minLines: 2,
                              maxLines: 4,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                hintText:
                                    'Örn: Park yanı, market arkası, bina önü',
                                alignLabelWithHint: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      PatiMapPrimaryButton(
                        label: _submitting ? 'Gönderiliyor…' : 'İhbarı Gönder',
                        onPressed: _submitting ? null : () => _onSubmit(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: 1,
        onTap: (index) => _goToTab(context, index),
      ),
    );
  }
}

class _PickedLocation {
  const _PickedLocation({
    required this.latitude,
    required this.longitude,
    this.locationText,
  });

  final double latitude;
  final double longitude;
  final String? locationText;
}

class _LocationPickerPage extends StatefulWidget {
  const _LocationPickerPage({
    required this.initialLatitude,
    required this.initialLongitude,
    this.initialLocationText,
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialLocationText;

  @override
  State<_LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<_LocationPickerPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  LatLng? _selectedPoint;
  String? _selectedLocationText;
  List<Location> _searchResults = const [];
  bool _locating = false;
  bool _resolvingAddress = false;
  bool _searchingAddress = false;

  static const LatLng _defaultCenter = LatLng(41.015, 28.979);

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedPoint = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _selectedLocationText = widget.initialLocationText;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _resolveAddressForPoint(LatLng point) async {
    setState(() => _resolvingAddress = true);
    try {
      await setLocaleIdentifier('tr_TR');
      final places = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      final first = places.isNotEmpty ? places.first : null;
      if (!mounted) return;
      setState(() {
        _selectedLocationText = _formatPlacemark(first);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _selectedLocationText = null;
      });
    } finally {
      if (mounted) {
        setState(() => _resolvingAddress = false);
      }
    }
  }

  String? _formatPlacemark(Placemark? p) {
    if (p == null) return null;
    final parts = <String>[
      if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality!.trim(),
      if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
      if ((p.street ?? '').trim().isNotEmpty) p.street!.trim(),
      if ((p.thoroughfare ?? '').trim().isNotEmpty) p.thoroughfare!.trim(),
      if ((p.name ?? '').trim().isNotEmpty) p.name!.trim(),
      if ((p.subAdministrativeArea ?? '').trim().isNotEmpty)
        p.subAdministrativeArea!.trim(),
      if ((p.administrativeArea ?? '').trim().isNotEmpty)
        p.administrativeArea!.trim(),
      if ((p.country ?? '').trim().isNotEmpty) p.country!.trim(),
    ];
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  Future<void> _goToMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _showInfo('Konum servisleri kapalı.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showInfo('Konum izni verilmedi.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final target = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _selectedPoint = target);
      _mapController.move(target, 15);
      await _resolveAddressForPoint(target);
    } catch (_) {
      _showInfo('Konum alınamadı.');
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.length < 3) {
      _showInfo('Arama için en az 3 karakter girin.');
      return;
    }

    setState(() => _searchingAddress = true);
    try {
      await setLocaleIdentifier('tr_TR');
      final results = await locationFromAddress(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results.take(8).toList(growable: false);
      });
      if (_searchResults.isEmpty) {
        _showInfo('Sonuç bulunamadı.');
      }
    } catch (_) {
      _showInfo('Adres araması başarısız oldu.');
    } finally {
      if (mounted) setState(() => _searchingAddress = false);
    }
  }

  Future<void> _onSearchResultSelected(Location result) async {
    final point = LatLng(result.latitude, result.longitude);
    _searchFocusNode.unfocus();
    setState(() {
      _selectedPoint = point;
      _searchResults = const [];
    });
    _mapController.move(point, 15);
    await _resolveAddressForPoint(point);
  }

  Future<void> _onMapTap(LatLng point) async {
    _searchFocusNode.unfocus();
    setState(() {
      _selectedPoint = point;
      _searchResults = const [];
    });
    await _resolveAddressForPoint(point);
  }

  void _showInfo(String text) {
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
    final initialCenter = _selectedPoint ?? _defaultCenter;
    final initialZoom = _selectedPoint == null ? 7.4 : 14.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Konum Seç'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: initialZoom,
              onTap: (_, point) => _onMapTap(point),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              if (_selectedPoint != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPoint!,
                      width: 38,
                      height: 38,
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: AppColors.primary,
                        size: 34,
                      ),
                    ),
                  ],
                ),
              const RichAttributionWidget(
                popupBackgroundColor: Colors.white,
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: null,
                  ),
                  TextSourceAttribution(
                    'CARTO',
                    onTap: null,
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 12,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'pick_loc_my_loc',
              backgroundColor: Colors.white,
              onPressed: _goToMyLocation,
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchAddress(),
                    decoration: InputDecoration(
                      hintText: 'Mahalle, cadde, sokak veya adres ara',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchingAddress
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.arrow_forward_rounded),
                              onPressed: _searchAddress,
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: Colors.grey.shade200,
                      ),
                      itemBuilder: (context, index) {
                        final item = _searchResults[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined),
                          title: Text(
                            'Sonuç ${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${item.latitude.toStringAsFixed(5)}, ${item.longitude.toStringAsFixed(5)}',
                          ),
                          onTap: () => _onSearchResultSelected(item),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_selectedPoint != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _resolvingAddress
                            ? 'Adres çözümleniyor...'
                            : '${_selectedLocationText ?? 'Adres bulunamadı'}\n'
                                '(${_selectedPoint!.latitude.toStringAsFixed(5)}, ${_selectedPoint!.longitude.toStringAsFixed(5)})',
                        style: const TextStyle(fontSize: 13, height: 1.25),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: _selectedPoint == null
                        ? null
                        : () => Navigator.of(context).pop(
                              _PickedLocation(
                                latitude: _selectedPoint!.latitude,
                                longitude: _selectedPoint!.longitude,
                                locationText: _selectedLocationText,
                              ),
                            ),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      _selectedPoint == null
                          ? 'Haritadan bir nokta seçin'
                          : 'Bu Konumu Kullan',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
