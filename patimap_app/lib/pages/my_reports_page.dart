import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../report_pin.dart';
import '../services/report_service.dart';
import '../theme/app_colors.dart';
import '../widgets/profile_report_card.dart';

class MyReportsPage extends StatefulWidget {
  const MyReportsPage({super.key});

  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage> {
  bool _loading = true;
  String? _error;
  var _pins = <ReportPin>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Oturum bulunamadı.';
      });
      return;
    }
    try {
      final list = await ReportService.fetchReportsCreatedByUser(user.id);
      if (!mounted) return;
      setState(() {
        _pins = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ReportService.messageForError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Oluşturduğum İhbarlar'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.heading,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _error!,
            style: TextStyle(color: Colors.red.shade800),
          ),
        ],
      );
    }
    if (_pins.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          Icon(
            Icons.map_outlined,
            size: 56,
            color: AppColors.primary.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz ihbar oluşturmadınız',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.heading,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Haritaya katkı vermek için ana ekrandan yeni bir ihbar oluşturabilirsiniz.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                  height: 1.35,
                ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _pins.length,
      separatorBuilder: (context, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        return ProfileReportCard(
          pin: _pins[i],
          onDetailResult: (result) {
            if (result is Map && result['deleted'] == true) {
              _load();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text('İhbar başarıyla silindi.'),
                ),
              );
            }
          },
        );
      },
    );
  }
}
