import 'package:flutter/material.dart';

import 'components/bottom_nav.dart';
import 'components/real_map_section.dart';
import 'components/mobile_header.dart';
import 'components/report_filter_sheet.dart';
import 'map/map_camera_controller.dart';
import 'map/map_region_models.dart';
import 'map/map_region_pin_filter.dart';
import 'models/report_filter_state.dart';
import 'report_pin.dart';
import 'routes/app_routes.dart';
import 'services/report_service.dart';
import 'services/tab_persistence_service.dart';
import 'theme/map_screen_style.dart';
import 'widgets/map_region_search_bar.dart';
import 'widgets/pati_map_primary_button.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MapCameraController _mapCamera = MapCameraController();

  ReportFilterState _filterState = const ReportFilterState(
    types: {},
    urgency: null,
    onlyUnassigned: false,
  );

  List<ReportPin> _pins = const [];
  bool _loadingPins = true;
  AppliedMapRegion? _appliedMapRegion;

  @override
  void initState() {
    super.initState();
    TabPersistenceService.saveTabIndex(0);
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _loadingPins = true);
    try {
      final list = await ReportService.fetchReportsForMap();
      if (!mounted) return;
      setState(() {
        _pins = list;
        _loadingPins = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pins = const [];
        _loadingPins = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ReportService.messageForError(e)),
        ),
      );
    }
  }

  List<ReportPin> get _filteredPins {
    final typesFilter = _filterState.types;

    return _pins.where((pin) {
      if (typesFilter.isNotEmpty) {
        final mapToType = switch (pin.type) {
          ReportType.injured => ReportTypeFilter.injured,
          ReportType.open => ReportTypeFilter.open,
          ReportType.missing => ReportTypeFilter.missing,
        };
        if (!typesFilter.contains(mapToType)) return false;
      }

      if (_filterState.urgency != null) {
        final mapToUrgency = switch (pin.urgency) {
          ReportUrgency.urgent => ReportUrgencyFilter.urgent,
          ReportUrgency.normal => ReportUrgencyFilter.normal,
          ReportUrgency.low => ReportUrgencyFilter.low,
        };
        if (_filterState.urgency != mapToUrgency) return false;
      }

      if (_filterState.onlyUnassigned && !pin.isUnassigned) return false;

      return true;
    }).where((pin) => reportPinInAppliedRegion(pin, _appliedMapRegion)).toList();
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<ReportFilterState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => ReportFilterSheet(initialState: _filterState),
    );

    if (!mounted) return;
    if (result == null) return;

    setState(() => _filterState = result);
  }

  void _onPinTapped(ReportPin pin) {
    Navigator.of(context)
        .pushNamed(
          AppRoutes.reportDetail,
          arguments: pin,
        )
        .then((result) {
          if (!mounted) return;
          if (result is ReportPin) {
            _loadReports();
          }
        });
  }

  Future<void> _onTabSelected(int index) async {
    if (index == 0) return;

    final targetRoute = switch (index) {
      1 => AppRoutes.reportCreate,
      2 => AppRoutes.veterinarians,
      3 => AppRoutes.profile,
      _ => AppRoutes.home,
    };

    await TabPersistenceService.saveTabIndex(index);
    if (!mounted) return;
    Navigator.of(context).pushNamed(targetRoute);
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    return Theme(
      data: baseTheme.copyWith(
        scaffoldBackgroundColor: MapScreenStyle.scaffoldBackground,
        bottomNavigationBarTheme: baseTheme.bottomNavigationBarTheme.copyWith(
          backgroundColor: MapScreenStyle.navBarBackground,
          selectedItemColor: MapScreenStyle.navSelected,
          unselectedItemColor: MapScreenStyle.navUnselected,
          selectedIconTheme: const IconThemeData(
            size: 26,
            color: MapScreenStyle.navSelected,
          ),
          unselectedIconTheme: IconThemeData(
            size: 24,
            color: MapScreenStyle.navUnselected,
          ),
          selectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.05,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: MapScreenStyle.navUnselected,
          ),
          elevation: 0,
        ),
      ),
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: MapScreenStyle.scaffoldBackground,
            body: SafeArea(
              child: Column(
                children: [
                  MobileHeader(
                    title: 'PatiMap',
                    mapScreenLayout: true,
                    onNotificationTap: () {
                      Navigator.of(context).pushNamed(AppRoutes.notifications);
                    },
                    onProfileTap: () {
                      TabPersistenceService.saveTabIndex(3);
                      Navigator.of(context)
                          .pushNamed(AppRoutes.profile);
                    },
                  ),
                  MapRegionSearchBar(
                    mapCameraController: _mapCamera,
                    onRegionApplied: (region) {
                      setState(() => _appliedMapRegion = region);
                    },
                    onRegionCleared: () {
                      setState(() => _appliedMapRegion = null);
                    },
                  ),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        RealMapSection(
                          mapCameraController: _mapCamera,
                          pins: _filteredPins,
                          activeFilterCount: _filterState.activeFilterCount,
                          onFilterPressed: _openFilters,
                          onPinTapped: _onPinTapped,
                        ),
                        if (_loadingPins)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Center(
                                child: SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: MapScreenStyle.accent
                                        .withValues(alpha: 0.85),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                    child: PatiMapPrimaryButton(
                      mapScreenAppearance: true,
                      label: '+ İhbar Oluştur',
                      onPressed: () {
                        TabPersistenceService.saveTabIndex(1);
                        Navigator.of(context)
                            .pushNamed(AppRoutes.reportCreate);
                      },
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: MapScreenStyle.navBarBackground,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.04,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: BottomNav(
                currentIndex: 0,
                onTap: (index) => _onTabSelected(index),
              ),
            ),
          );
        },
      ),
    );
  }
}
