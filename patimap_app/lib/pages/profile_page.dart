import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../components/bottom_nav.dart';
import '../models/user_profile_snapshot.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../report_pin.dart';
import '../services/report_service.dart';
import '../services/tab_persistence_service.dart';
import '../theme/app_colors.dart';
import '../widgets/profile/profile_header_card.dart';
import '../widgets/profile/profile_menu_card.dart';
import '../widgets/profile/profile_sign_out_card.dart';
import '../widgets/profile/profile_ui_tokens.dart';

const Color _profilePageBg = AppColors.scaffoldBackground;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  UserProfileSnapshot? _profile;
  bool _loadingProfile = true;
  int _createdCount = 0;
  int _assignedCount = 0;

  @override
  void initState() {
    super.initState();
    TabPersistenceService.saveTabIndex(3);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loadingProfile = true);
    final snapshot = await ProfileService.loadSnapshot();
    var created = 0;
    var assigned = 0;
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final results = await Future.wait<List<ReportPin>>([
          ReportService.fetchReportsCreatedByUser(user.id),
          ReportService.fetchReportsAssignedToUser(user.id),
        ]);
        created = results[0].length;
        assigned = results[1].length;
      } catch (_) {
        // Ağ / RLS: sayılar 0 kalsın, profil yine yüklensün
      }
    }
    if (!mounted) return;
    setState(() {
      _profile = snapshot;
      _createdCount = created;
      _assignedCount = assigned;
      _loadingProfile = false;
    });
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

  Future<void> _onSignOut() async {
    await TabPersistenceService.reset();
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = _profile;

    return Scaffold(
      backgroundColor: _profilePageBg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadProfile,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: ProfileUiTokens.pagePadding,
            children: [
              const SizedBox(height: 4),
              Text(
                'Profil',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.heading,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hesabiniz ve aktiviteleriniz',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              if (_loadingProfile || snapshot == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                ProfileHeaderCard(
                  snapshot: snapshot,
                  createdCount: _createdCount,
                  assignedCount: _assignedCount,
                ),
                SizedBox(height: ProfileUiTokens.sectionGap + 2),
                Text(
                  'Hizli Islemler',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.heading,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),
                ProfileMenuCard(
                  onAccount: () => Navigator.of(context)
                      .pushNamed(AppRoutes.profileAccount),
                  onMyReports: () => Navigator.of(context)
                      .pushNamed(AppRoutes.profileMyReports),
                  onAssigned: () => Navigator.of(context)
                      .pushNamed(AppRoutes.profileAssignedReports),
                  onSettings: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text('Ayarlar yakinda eklenecek.'),
                      ),
                    );
                  },
                  onHelp: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text(
                          'Destek için yakında iletişim bilgileri burada olacak.',
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: ProfileUiTokens.sectionGap),
                ProfileSignOutCard(onSignOut: _onSignOut),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: 3,
        onTap: (index) => _goToTab(index),
      ),
    );
  }
}
