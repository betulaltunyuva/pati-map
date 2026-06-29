import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class PatiMapFormFieldLabel extends StatelessWidget {
  const PatiMapFormFieldLabel(
    this.text, {
    super.key,
    this.isRequired = false,
  });

  final String text;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.heading,
                ),
          ),
          if (isRequired) ...[
            const SizedBox(width: 4),
            Text(
              '*',
              style: TextStyle(
                color: Colors.red.shade400,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PatiMapFormCard extends StatelessWidget {
  const PatiMapFormCard({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class PatiMapDropdownFormField<T> extends StatelessWidget {
  const PatiMapDropdownFormField({
    super.key,
    required this.value,
    required this.entries,
    required this.onSelected,
    this.validator,
    this.hintText,
  });

  final T? value;
  final List<DropdownMenuEntry<T>> entries;
  final ValueChanged<T?>? onSelected;
  final FormFieldValidator<T>? validator;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return DropdownMenuFormField<T>(
      initialSelection: value,
      hintText: hintText,
      enableSearch: false,
      expandedInsets: EdgeInsets.zero,
      dropdownMenuEntries: entries,
      onSelected: onSelected,
      validator: validator,
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.white),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
