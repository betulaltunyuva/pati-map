import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_messenger_key.dart';
import 'email_otp_verify_page.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'pages/assigned_reports_page.dart';
import 'pages/my_reports_page.dart';
import 'pages/notifications_page.dart';
import 'pages/profile_account_page.dart';
import 'pages/profile_page.dart';
import 'pages/report_detail_page.dart';
import 'pages/report_create_page.dart';
import 'pages/splash_screen.dart';
import 'report_pin.dart';
import 'models/email_otp_verify_args.dart';
import 'register_page.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';
import 'pages/veterinarians_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://jhhyvmgrfkqmxuuqtryv.supabase.co',
    // NOTE: Temporary diagnostic for Storage 404.
    // Legacy anon key from dashboard will be pasted here by you.
    //
    // anonKey: 'sb_publishable_dF4uaCyMAimEwqNP-75Z7w_N6eJBV1M', // old project key (kept for reference)
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpoaHl2bWdyZmtxbXh1dXF0cnl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzODEzNTAsImV4cCI6MjA4OTk1NzM1MH0.kLkAAESOUJE0iAh6KBKvBOQfcHV9BWMDci121TLCRjs',
  );
  // Used for diagnosing Storage 404 problems.
  // (Bucket/objectPath may be correct but project can be wrong.)
  debugPrint('Supabase init url: https://jhhyvmgrfkqmxuuqtryv.supabase.co');
  runApp(const PatiMapApp());
}

class PatiMapApp extends StatelessWidget {
  const PatiMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PatiMap',
      scaffoldMessengerKey: appMessengerKey,
      theme: AppTheme.light,
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.login: (_) => const LoginPage(),
        AppRoutes.register: (_) => const RegisterPage(),
        AppRoutes.home: (_) => const HomePage(),
        AppRoutes.reportCreate: (_) => const ReportCreatePage(),
        AppRoutes.notifications: (_) => const NotificationsPage(),
        AppRoutes.veterinarians: (_) => const VeterinariansPage(),
        AppRoutes.profile: (_) => const ProfilePage(),
        AppRoutes.profileMyReports: (_) => const MyReportsPage(),
        AppRoutes.profileAssignedReports: (_) => const AssignedReportsPage(),
        AppRoutes.profileAccount: (_) => const ProfileAccountPage(),
        AppRoutes.emailOtpVerify: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is! EmailOtpVerifyArgs) {
            return Scaffold(
              body: SafeArea(
                child: Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.login,
                        (route) => false,
                      );
                    },
                    child: const Text('Girişe dön'),
                  ),
                ),
              ),
            );
          }
          return EmailOtpVerifyPage(email: args.email);
        },
      },
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.reportDetail) {
          final args = settings.arguments;
          if (args is ReportPin) {
            return MaterialPageRoute<void>(
              builder: (_) => ReportDetailPage(pin: args),
              settings: settings,
            );
          }
          if (args is Map) {
            final pin = args['pin'];
            final autoOpenChat = args['autoOpenChat'] == true;
            if (pin is ReportPin) {
              return MaterialPageRoute<void>(
                builder: (_) => ReportDetailPage(
                  pin: pin,
                  autoOpenChat: autoOpenChat,
                ),
                settings: settings,
              );
            }
          }
        }
        return null;
      },
    );
  }
}
