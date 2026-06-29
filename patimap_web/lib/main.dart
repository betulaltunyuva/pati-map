import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'components/scroll_reveal.dart';
import 'pages/dashboard_page.dart';
import 'theme/app_palette.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureScrollRevealForPanel();
  await Supabase.initialize(
    url: 'https://jhhyvmgrfkqmxuuqtryv.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpoaHl2bWdyZmtxbXh1dXF0cnl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzODEzNTAsImV4cCI6MjA4OTk1NzM1MH0.kLkAAESOUJE0iAh6KBKvBOQfcHV9BWMDci121TLCRjs',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PatiMap Web Panel',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppPalette.pageBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppPalette.primaryBlue,
          primary: AppPalette.primaryBlue,
          secondary: AppPalette.navy,
          surface: AppPalette.cardBackground,
          error: AppPalette.error,
        ),
        cardColor: AppPalette.cardBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppPalette.cardBackground,
          foregroundColor: AppPalette.navy,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: AppPalette.cardBackground,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppPalette.radiusLg),
            side: const BorderSide(color: AppPalette.border),
          ),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            color: AppPalette.navy,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
          titleMedium: TextStyle(
            color: AppPalette.navy,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
          bodyLarge: TextStyle(
            color: AppPalette.navy,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
          bodyMedium: TextStyle(
            color: AppPalette.textMuted,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppPalette.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppPalette.radiusMd),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppPalette.navy,
            side: const BorderSide(color: AppPalette.border),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppPalette.radiusMd),
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppPalette.navy,
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          actionTextColor: const Color(0xFFBFDBFE),
          disabledActionTextColor: const Color(0xFF94A3B8),
          showCloseIcon: true,
          closeIconColor: const Color(0xFFE2E8F0),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
          ),
          insetPadding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        ),
        dividerColor: AppPalette.border,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppPalette.cardBackground,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: const OutlineInputBorder(),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppPalette.border),
            borderRadius: BorderRadius.circular(AppPalette.radiusMd),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppPalette.primaryBlue, width: 1.4),
            borderRadius: BorderRadius.circular(AppPalette.radiusMd),
          ),
        ),
      ),
      home: const DashboardPage(),
    );
  }
}
