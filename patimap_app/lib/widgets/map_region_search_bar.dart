import 'dart:async';

import 'package:flutter/material.dart';

import '../map/map_camera_controller.dart';
import '../map/map_region_models.dart';
import '../services/map_region_search_service.dart';
import '../theme/map_screen_style.dart';

/// Harita üstü: şehir / ilçe / mahalle arama + öneri listesi.
class MapRegionSearchBar extends StatefulWidget {
  const MapRegionSearchBar({
    super.key,
    required this.mapCameraController,
    required this.onRegionApplied,
    required this.onRegionCleared,
  });

  final MapCameraController mapCameraController;
  final ValueChanged<AppliedMapRegion> onRegionApplied;
  final VoidCallback onRegionCleared;

  @override
  State<MapRegionSearchBar> createState() => _MapRegionSearchBarState();
}

class _MapRegionSearchBarState extends State<MapRegionSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  List<MapRegionSuggestion> _suggestions = const [];
  bool _loadingSuggest = false;
  bool _busySearch = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) {
      if (mounted) {
        setState(() {
          _suggestions = const [];
          _busySearch = false;
        });
      }
      return;
    }

    setState(() => _busySearch = true);
    final result = await MapRegionSearchService.resolveQuery(q);
    if (!mounted) return;
    setState(() => _busySearch = false);

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Bölge bulunamadı'),
        ),
      );
      return;
    }

    _applyRegion(result);
  }

  void _applyRegion(AppliedMapRegion region) {
    _focusNode.unfocus();
    setState(() {
      _suggestions = const [];
      _controller.text = region.displayLabel;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.mapCameraController.moveTo(region.center, region.zoom);
    });
    widget.onRegionApplied(region);
  }

  void _onClear() {
    _controller.clear();
    _focusNode.unfocus();
    setState(() => _suggestions = const []);
    widget.onRegionCleared();
  }

  void _scheduleSuggest(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 380), () async {
      setState(() => _loadingSuggest = true);
      final list = await MapRegionSearchService.suggestions(value.trim());
      if (!mounted) return;
      setState(() {
        _loadingSuggest = false;
        _suggestions = list;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = MapScreenStyle.accent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MapScreenStyle.mapHorizontalPadding,
        4,
        MapScreenStyle.mapHorizontalPadding,
        6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.96),
            elevation: 0,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: accent.withValues(alpha: 0.14),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      onChanged: _scheduleSuggest,
                      onSubmitted: _runSearch,
                      style: TextStyle(
                        color: MapScreenStyle.title,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: 'Şehir, ilçe veya mahalle ara',
                        hintStyle: TextStyle(
                          color: MapScreenStyle.subtitleMuted,
                          fontWeight: FontWeight.w400,
                          fontSize: 14.5,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.place_outlined,
                          color: accent.withValues(alpha: 0.75),
                          size: 22,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_controller.text.isNotEmpty)
                              IconButton(
                                tooltip: 'Temizle',
                                onPressed: _busySearch ? null : _onClear,
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: MapScreenStyle.subtitleMuted,
                                  size: 20,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: IconButton(
                                tooltip: 'Ara',
                                onPressed: _busySearch
                                    ? null
                                    : () => _runSearch(_controller.text),
                                icon: _busySearch
                                    ? SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: accent.withValues(
                                            alpha: 0.85,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.search_rounded,
                                        color: accent,
                                        size: 24,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_focusNode.hasFocus &&
              (_suggestions.isNotEmpty || _loadingSuggest))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                elevation: 3,
                shadowColor: Colors.black.withValues(alpha: 0.12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: _loadingSuggest && _suggestions.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color:
                                      accent.withValues(alpha: 0.85),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Öneriler aranıyor…',
                                style: TextStyle(
                                  color: MapScreenStyle.subtitleMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            color: Colors.grey.shade200,
                          ),
                          itemBuilder: (context, index) {
                            final s = _suggestions[index];
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              leading: Icon(
                                Icons.location_city_rounded,
                                color: accent.withValues(alpha: 0.75),
                                size: 22,
                              ),
                              title: Text(
                                s.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: MapScreenStyle.title,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                s.subtitle,
                                style: TextStyle(
                                  color: MapScreenStyle.subtitleMuted,
                                  fontSize: 12,
                                ),
                              ),
                              onTap: () {
                                _applyRegion(
                                  AppliedMapRegion(
                                    center: s.center,
                                    zoom: s.zoom,
                                    radiusKm: s.radiusKm,
                                    queryText: s.title,
                                    displayLabel: s.title,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
