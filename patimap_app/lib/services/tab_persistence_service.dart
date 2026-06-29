import 'package:shared_preferences/shared_preferences.dart';

import '../routes/app_routes.dart';

abstract final class TabPersistenceService {
  TabPersistenceService._();

  static const int defaultTabIndex = 0;
  static const String _tabIndexKey = 'last_bottom_tab_index';

  static const Map<int, String> _indexToRoute = <int, String>{
    0: AppRoutes.home,
    1: AppRoutes.reportCreate,
    2: AppRoutes.veterinarians,
    3: AppRoutes.profile,
  };

  static Future<void> saveTabIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_tabIndexKey, index);
  }

  static Future<int> loadTabIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_tabIndexKey);
    if (saved == null || !_indexToRoute.containsKey(saved)) {
      return defaultTabIndex;
    }
    return saved;
  }

  static Future<String> loadLastTabRoute() async {
    final index = await loadTabIndex();
    return _indexToRoute[index] ?? AppRoutes.home;
  }

  static Future<void> reset() => saveTabIndex(defaultTabIndex);
}
