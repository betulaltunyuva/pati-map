import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_assets.dart';
import '../map/map_camera_controller.dart';
import '../report_pin.dart';
import '../theme/map_screen_style.dart';

/// İhbar yokken başlangıç kadrajı: Türkiye geneli dengeli (çok yakın/uzak değil).
const LatLng _kTurkeyOverviewCenter = LatLng(39.12, 35.08);
const double _kTurkeyOverviewZoom = 6.05;

class RealMapSection extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables — opsiyonel [MapCameraController] nedeniyle const değil.
  RealMapSection({
    super.key,
    this.mapCameraController,
    required this.pins,
    required this.activeFilterCount,
    required this.onFilterPressed,
    required this.onPinTapped,
  });

  final MapCameraController? mapCameraController;
  final List<ReportPin> pins;
  final int activeFilterCount;
  final VoidCallback onFilterPressed;
  final ValueChanged<ReportPin> onPinTapped;

  @override
  State<RealMapSection> createState() => _RealMapSectionState();
}

class _RealMapSectionState extends State<RealMapSection> {
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  bool _locating = false;

  void _onExternalCameraMove(LatLng center, double zoom) {
    _mapController.move(center, zoom);
  }

  @override
  void initState() {
    super.initState();
    widget.mapCameraController?.attach(_onExternalCameraMove);
  }

  @override
  void dispose() {
    widget.mapCameraController?.detach();
    super.dispose();
  }

  @override
  void didUpdateWidget(RealMapSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapCameraController != widget.mapCameraController) {
      oldWidget.mapCameraController?.detach();
      widget.mapCameraController?.attach(_onExternalCameraMove);
    }
  }

  Future<void> _onMyLocationPressed() async {
    if (_locating) return;
    setState(() => _locating = true);

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _showMessage('Konum servisleri kapalı. Lütfen açın.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Konum izni verilmedi.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final target = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() => _userLocation = target);
      _mapController.move(target, 15.0);
    } catch (_) {
      _showMessage('Konum alınamadı. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    const markerSize = MapScreenStyle.markerSize;
    const mapInset = MapScreenStyle.mapInset;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MapScreenStyle.mapHorizontalPadding,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MapScreenStyle.mapRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: MapScreenStyle.mapCanvasBackground,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.85),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: MapScreenStyle.mapCardElevationAlpha,
                ),
                blurRadius: MapScreenStyle.mapCardElevationBlur,
                offset: const Offset(0, MapScreenStyle.mapCardElevationY),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;

              final points = widget.pins
                  .map((p) => LatLng(p.latitude, p.longitude))
                  .toList(growable: false);

              final initialCenter =
                  points.isNotEmpty ? points.first : _kTurkeyOverviewCenter;
              final initialZoom = points.length == 1
                  ? 12.5
                  : points.isEmpty
                      ? _kTurkeyOverviewZoom
                      : 7.2;

              final initialCameraFit = points.length > 1
                  ? CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(points),
                      padding: const EdgeInsets.all(58),
                      maxZoom: 15.75,
                      minZoom: 4,
                    )
                  : null;

              final markers = widget.pins
                  .map(
                    (pin) => Marker(
                      point: LatLng(pin.latitude, pin.longitude),
                      width: markerSize,
                      height: markerSize,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => widget.onPinTapped(pin),
                        child: _MapPinMarker(
                          markerSize: markerSize,
                          pin: pin,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false);

              final sidePanelMaxH = math.max(0.0, h - mapInset * 2);
              final sidePanelMaxW = math.max(0.0, w * 0.58);

              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: initialCenter,
                        initialZoom: initialZoom,
                        initialCameraFit: initialCameraFit,
                        backgroundColor: MapScreenStyle.mapCanvasBackground,
                        interactionOptions: const InteractionOptions(
                          flags: ~InteractiveFlag.doubleTapZoom,
                        ),
                      ),
                      children: [
                        ColorFiltered(
                          colorFilter: ColorFilter.matrix(
                            MapScreenStyle.tileLayerContrastMatrix,
                          ),
                          child: TileLayer(
                            // light_all aynı URL; hafif matris ile yollar/etiket/sınır biraz daha belirgin.
                            urlTemplate:
                                'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                          ),
                        ),
                        MarkerLayer(markers: markers),
                        if (_userLocation != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _userLocation!,
                                width: markerSize,
                                height: markerSize,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: MapScreenStyle.userLocationRing
                                        .withValues(alpha: 0.18),
                                    border: Border.all(
                                      color: MapScreenStyle.userLocationRing
                                          .withValues(alpha: 0.35),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.my_location_rounded,
                                      color: MapScreenStyle.userLocationRing
                                          .withValues(alpha: 0.95),
                                      size: markerSize * 0.52,
                                    ),
                                  ),
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
                  ),

                  Positioned(
                    right: mapInset,
                    top: mapInset,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: sidePanelMaxW,
                        maxHeight: sidePanelMaxH,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topRight,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _ActionChipButton(
                              label: 'Konumum',
                              icon: Icons.my_location_rounded,
                              onPressed: _onMyLocationPressed,
                            ),
                            const SizedBox(height: 8),
                            _ActionChipButton(
                              label: 'Filtrele',
                              icon: Icons.filter_alt_rounded,
                              badgeText: widget.activeFilterCount > 0
                                  ? '${widget.activeFilterCount}'
                                  : null,
                              onPressed: widget.onFilterPressed,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MapPinMarker extends StatelessWidget {
  const _MapPinMarker({
    required this.markerSize,
    required this.pin,
  });

  final double markerSize;
  final ReportPin pin;

  @override
  Widget build(BuildContext context) {
    final isAssigned = pin.isAssigned;

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: Image.asset(
            AppAssets.miniMarkerPng,
            fit: BoxFit.contain,
          ),
        ),
        if (isAssigned)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: MapScreenStyle.accent.withValues(alpha: 0.95),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 8,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.badgeText,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    final chipRadius = 14.0;
    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(chipRadius),
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(chipRadius),
            border: Border.all(
              color: MapScreenStyle.accent.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: MapScreenStyle.accent,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: MapScreenStyle.title,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    letterSpacing: -0.1,
                  ),
                ),
                if (badgeText != null) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: MapScreenStyle.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeText!,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: MapScreenStyle.accent,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

