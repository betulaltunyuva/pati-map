import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../services/notification_service.dart';
import '../services/report_service.dart';
import '../theme/app_colors.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = true;
  String? _error;
  List<AppNotification> _notifications = const [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await NotificationService.fetchMyNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ReportService.messageForError(e);
      });
    }
  }

  Future<void> _openNotification(AppNotification item) async {
    await NotificationService.markAsRead(notificationId: item.id);
    if (!mounted) return;
    setState(() {
      _notifications = _notifications
          .map((e) => e.id == item.id
              ? AppNotification(
                  id: e.id,
                  userId: e.userId,
                  reportId: e.reportId,
                  title: e.title,
                  body: e.body,
                  isRead: true,
                  createdAt: e.createdAt,
                )
              : e)
          .toList();
    });

    try {
      final pin = await ReportService.fetchReportById(item.reportId);
      if (!mounted) return;
      if (pin == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İlgili ihbar bulunamadı.')),
        );
        return;
      }
      await Navigator.of(context).pushNamed(
        AppRoutes.reportDetail,
        arguments: {
          'pin': pin,
          'autoOpenChat': true,
        },
      );
      if (!mounted) return;
      _loadNotifications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ReportService.messageForError(e))),
      );
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd.$mm $hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Bildirimler'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.heading,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _loadNotifications,
          child: _buildBody(context),
        ),
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
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _error!,
            style: TextStyle(color: Colors.red.shade700),
          ),
        ],
      );
    }

    if (_notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        children: [
          Icon(Icons.notifications_none_rounded, size: 56, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            'Henüz bildirim yok',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.heading,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      itemCount: _notifications.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _notifications[index];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openNotification(item),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: item.isRead ? const Color(0xFFE2E8F0) : AppColors.primary,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.isRead ? Icons.notifications_none_rounded : Icons.notifications_active,
                    color: item.isRead ? Colors.grey.shade500 : AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            color: AppColors.heading,
                            fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.body,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatDate(item.createdAt),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
