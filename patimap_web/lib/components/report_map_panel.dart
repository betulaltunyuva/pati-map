import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/report_map_item.dart';
import '../services/report_map_service.dart';
import '../theme/app_palette.dart';
import 'panel_empty_state.dart';
import '../utils/map_marker_layout.dart';

const String _webMiniMarkerAsset = 'assets/images/minimarker.png';

class ReportMapPanel extends StatefulWidget {
  const ReportMapPanel({
    super.key,
    this.height = 320,
    this.title = 'Harita Onizleme',
    this.liftOnHover = false,
    this.onMarkerTap,
    this.onDataLoaded,
    this.selectionId,
    this.reloadSignal = 0,
    this.items,
    this.itemsLoading = false,
    this.itemsError,
    this.onReload,
  });

  final double height;
  final String title;
  /// Dashboard gibi yerlerde kart hover (yukari + shadow) efekti.
  final bool liftOnHover;
  final ValueChanged<ReportMapItem>? onMarkerTap;
  final ValueChanged<List<ReportMapItem>>? onDataLoaded;
  final String? selectionId;
  final int reloadSignal;

  /// Verilirse panel kendi fetch yapmaz (Dashboard ile aynı liste).
  final List<ReportMapItem>? items;
  final bool itemsLoading;
  final Object? itemsError;
  final VoidCallback? onReload;

  @override
  State<ReportMapPanel> createState() => _ReportMapPanelState();
}

class _ReportMapPanelState extends State<ReportMapPanel> {
  Future<List<ReportMapItem>>? _itemsFuture;
  bool _hover = false;

  bool get _usesExternalItems => widget.items != null;

  @override
  void initState() {
    super.initState();
    if (!_usesExternalItems) {
      _itemsFuture = ReportMapService.fetchItems();
    }
  }

  @override
  void didUpdateWidget(covariant ReportMapPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_usesExternalItems) return;
    if (oldWidget.reloadSignal != widget.reloadSignal) {
      _reload();
    }
  }

  Future<void> _reload() async {
    if (_usesExternalItems) {
      widget.onReload?.call();
      return;
    }
    setState(() {
      _itemsFuture = ReportMapService.fetchItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final elevated = widget.liftOnHover && _hover;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: widget.height,
      padding: const EdgeInsets.all(16),
      transform: Matrix4.translationValues(
        0,
        widget.liftOnHover && _hover ? -5 : 0,
        0,
      ),
      decoration: BoxDecoration(
        color: AppPalette.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppPalette.border),
        boxShadow: [
          BoxShadow(
            color: AppPalette.navy.withValues(alpha: elevated ? 0.085 : 0.042),
            blurRadius: elevated ? 28 : 20,
            offset: Offset(0, elevated ? 14 : 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.navy,
                ),
              ),
              const Spacer(),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppPalette.pageBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppPalette.border),
                ),
                child: IconButton(
                  onPressed: _reload,
                  tooltip: 'Yenile',
                  iconSize: 18,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _usesExternalItems
                  ? _buildItemsBody(widget.items!)
                  : FutureBuilder<List<ReportMapItem>>(
                      future: _itemsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          debugPrint('ReportMapPanel: ${snapshot.error}');
                          return _ErrorPlaceholder(onRetry: _reload);
                        }
                        return _buildItemsBody(
                          snapshot.data ?? const <ReportMapItem>[],
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );

    if (!widget.liftOnHover) return card;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: card,
    );
  }

  Widget _buildItemsBody(List<ReportMapItem> items) {
    if (_usesExternalItems && widget.itemsLoading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
      );
    }
    if (_usesExternalItems && widget.itemsError != null) {
      debugPrint('ReportMapPanel external: ${widget.itemsError}');
      return _ErrorPlaceholder(onRetry: _reload);
    }
    widget.onDataLoaded?.call(items);
    if (items.isEmpty) {
      return const _EmptyPlaceholder();
    }
    return _buildMap(items);
  }

  Widget _buildMap(List<ReportMapItem> items) {
    const turkeyCenter = LatLng(39.0, 35.0);
    final geoItems = items.where((e) => e.hasGeoCoordinates).toList();
    final markers = MapMarkerLayout.markersForMap(geoItems);
    return FlutterMap(
      options: const MapOptions(
        initialCenter: turkeyCenter,
        initialZoom: 5.6,
        minZoom: 4.0,
        maxZoom: 18.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.patimap.web',
        ),
        MarkerLayer(
          markers: markers
              .map(
                (entry) => Marker(
                  point: entry.point,
                  width: entry.clusterSize > 1 ? 28 : 18,
                  height: entry.clusterSize > 1 ? 30 : 22,
                  child: GestureDetector(
                    onTap: () {
                      widget.onMarkerTap?.call(entry.item);
                    },
                    child: _MapMarkerPin(
                      selected: widget.selectionId == entry.item.id,
                      assigned: entry.item.isAssigned,
                      clusterSize: entry.clusterSize,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _MapMarkerPin extends StatelessWidget {
  const _MapMarkerPin({
    this.selected = false,
    this.assigned = false,
    this.clusterSize = 1,
  });

  final bool selected;
  final bool assigned;
  final int clusterSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: selected ? 1.06 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: AppPalette.navy.withValues(alpha: selected ? 0.18 : 0.1),
                  blurRadius: selected ? 5 : 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Opacity(
              opacity: selected ? 1 : 0.86,
              child: Image.asset(
                _webMiniMarkerAsset,
                width: 18,
                height: 22,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        if (assigned)
          Positioned(
            top: -1,
            right: -1,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppPalette.primaryBlue.withValues(alpha: 0.88),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 6,
                color: Colors.white,
              ),
            ),
          ),
        if (clusterSize > 1)
          Positioned(
            top: -4,
            left: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppPalette.navy,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: Text(
                '$clusterSize',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ErrorPlaceholder extends StatelessWidget {
  const _ErrorPlaceholder({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppPalette.pageBackground,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Harita verisi yuklenemedi',
            style: TextStyle(
              color: AppPalette.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppPalette.pageBackground,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: const PanelEmptyState(
        icon: Icons.map_outlined,
        title: 'Gosterilecek konumlu ihbar yok.',
        subtitle: 'Konum bilgisi olan ihbarlar haritada listelenir.',
      ),
    );
  }
}
