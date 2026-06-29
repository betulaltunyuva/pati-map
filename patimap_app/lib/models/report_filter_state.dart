enum ReportTypeFilter {
  injured,
  open,
  missing,
}

enum ReportUrgencyFilter {
  urgent,
  normal,
  low,
}

class ReportFilterState {
  const ReportFilterState({
    required this.types,
    required this.urgency,
    required this.onlyUnassigned,
  });

  final Set<ReportTypeFilter> types;
  final ReportUrgencyFilter? urgency;
  final bool onlyUnassigned;

  int get activeFilterCount {
    var count = 0;
    if (types.isNotEmpty) count += 1;
    if (urgency != null) count += 1;
    if (onlyUnassigned) count += 1;
    return count;
  }

  ReportFilterState copyWith({
    Set<ReportTypeFilter>? types,
    ReportUrgencyFilter? urgency,
    bool? onlyUnassigned,
  }) {
    return ReportFilterState(
      types: types ?? this.types,
      urgency: urgency ?? this.urgency,
      onlyUnassigned: onlyUnassigned ?? this.onlyUnassigned,
    );
  }
}
