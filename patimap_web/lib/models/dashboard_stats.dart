class DashboardStats {
  const DashboardStats({
    required this.openReports,
    required this.urgentReports,
    required this.resolvedReports,
    required this.volunteerCount,
  });

  final int openReports;
  final int urgentReports;
  final int resolvedReports;
  final int volunteerCount;
}
