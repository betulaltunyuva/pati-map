import 'package:flutter/material.dart';

import '../models/report_filter_state.dart';
import '../theme/app_colors.dart';
import '../widgets/pati_map_primary_button.dart';

class ReportFilterSheet extends StatefulWidget {
  const ReportFilterSheet({super.key, required this.initialState});

  final ReportFilterState initialState;

  @override
  State<ReportFilterSheet> createState() => _ReportFilterSheetState();
}

class _ReportFilterSheetState extends State<ReportFilterSheet> {
  late Set<ReportTypeFilter> _types;
  late ReportUrgencyFilter? _urgency;
  late bool _onlyUnassigned;

  @override
  void initState() {
    super.initState();
    _types = {...widget.initialState.types};
    _urgency = widget.initialState.urgency;
    _onlyUnassigned = widget.initialState.onlyUnassigned;
  }

  void _toggleType(ReportTypeFilter type) {
    setState(() {
      if (_types.contains(type)) {
        _types.remove(type);
      } else {
        _types.add(type);
      }
    });
  }

  void _toggleUrgency(ReportUrgencyFilter urgency) {
    setState(() {
      _urgency = (_urgency == urgency) ? null : urgency;
    });
  }

  String _typeLabel(ReportTypeFilter type) {
    switch (type) {
      case ReportTypeFilter.injured:
        return 'Yaralı';
      case ReportTypeFilter.open:
        return 'Aç';
      case ReportTypeFilter.missing:
        return 'Kaybolmuş';
    }
  }

  String _urgencyLabel(ReportUrgencyFilter urgency) {
    switch (urgency) {
      case ReportUrgencyFilter.urgent:
        return 'Acil';
      case ReportUrgencyFilter.normal:
        return 'Orta';
      case ReportUrgencyFilter.low:
        return 'Düşük';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Filtreler',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.heading,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Tür',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.heading,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: ReportTypeFilter.values.map((t) {
                        final selected = _types.contains(t);
                        return ChoiceChip(
                          label: Text(_typeLabel(t)),
                          selected: selected,
                          selectedColor: AppColors.primary.withValues(alpha: 0.18),
                          backgroundColor: Colors.grey.shade100,
                          onSelected: (_) => _toggleType(t),
                          labelStyle: TextStyle(
                            color: selected ? AppColors.primary : Colors.grey.shade800,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Aciliyet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.heading,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: ReportUrgencyFilter.values.map((u) {
                        final selected = _urgency == u;
                        return ChoiceChip(
                          label: Text(_urgencyLabel(u)),
                          selected: selected,
                          selectedColor: AppColors.primary.withValues(alpha: 0.18),
                          backgroundColor: Colors.grey.shade100,
                          onSelected: (_) => _toggleUrgency(u),
                          labelStyle: TextStyle(
                            color: selected ? AppColors.primary : Colors.grey.shade800,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    CheckboxListTile(
                      value: _onlyUnassigned,
                      onChanged: (v) => setState(() => _onlyUnassigned = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        'Üstlenilmemiş ihbarlar',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _types = {};
                                _urgency = null;
                                _onlyUnassigned = false;
                              });
                            },
                            child: Text(
                              'Sıfırla',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: PatiMapPrimaryButton(
                            label: 'Uygula',
                            onPressed: () {
                              Navigator.of(context).pop(
                                ReportFilterState(
                                  types: _types,
                                  urgency: _urgency,
                                  onlyUnassigned: _onlyUnassigned,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
