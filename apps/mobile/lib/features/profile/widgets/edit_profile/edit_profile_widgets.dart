// lib/features/profile/widgets/edit_profile/edit_profile_widgets.dart

import 'package:flutter/material.dart';
import 'package:xparq_app/shared/widgets/common/expandable_text.dart';

class EditProfileWidgets {
  static Widget buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required bool isEditing,
    FocusNode? focusNode,
    String? hint,
    Widget? suffixIcon,
    int? maxLength,
    int maxLines = 1,
    bool? enabled,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    if (!isEditing && maxLines > 1 && controller.text.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.35),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          ExpandableText(
            text: controller.text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      maxLength: maxLength,
      maxLines: maxLines,
      validator: validator,
      enabled: enabled ?? isEditing,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.35),
          fontSize: 13,
        ),
        floatingLabelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          fontSize: 12,
        ),
        hintText: hint,
        hintStyle: TextStyle(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.15),
          fontSize: 13,
        ),
        filled: true,
        fillColor: Theme.of(
          context,
        ).colorScheme.onSurface.withValues(alpha: 0.05),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        counterStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          fontSize: 10,
        ),
      ),
    );
  }

  static void showSelectionPicker({
    required BuildContext context,
    required String title,
    required List<String> options,
    required Function(String) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final opt = options[index];
                    return InkWell(
                      onTap: () {
                        onSelect(opt);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.1),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          opt,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget buildPickerField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required List<String> options,
    required String title,
    required bool isEditing,
    required Function(String) onSelect,
  }) {
    return GestureDetector(
      onTap: isEditing
          ? () => showSelectionPicker(
              context: context,
              title: title,
              options: options,
              onSelect: onSelect,
            )
          : null,
      child: AbsorbPointer(
        absorbing: !isEditing,
        child: buildTextField(
          context: context,
          controller: controller,
          label: label,
          isEditing: isEditing,
          hint: 'Tap to select',
        ),
      ),
    );
  }

  static void showIconSelectionPicker({
    required BuildContext context,
    required String title,
    required List<Map<String, String>> options,
    required String? currentValue,
    required Function(String) onSelect,
    int crossAxisCount = 4,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final item = options[index];
                        final type = item['type']!;
                        final name = item['name'];
                        final icon = item['icon']!;
                        final isSelected = currentValue == type;

                        return GestureDetector(
                          onTap: () {
                            onSelect(type);
                            Navigator.pop(context);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  icon,
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    name != null ? '$type\n$name' : type,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
