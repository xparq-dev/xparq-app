// lib/features/profile/widgets/edit_profile/edit_profile_stellar.dart

import 'package:flutter/material.dart';
import 'edit_profile_widgets.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/core/utils/stellar_identity_helper.dart';

class EditProfileStellar extends StatelessWidget {
  final TextEditingController mbtiController;
  final TextEditingController zodiacController;
  final TextEditingController bloodTypeController;
  final List<String> constellations;
  final bool isEditing;
  final Function(String) onMbtiSelect;
  final Function(String) onZodiacSelect;
  final Function(String) onBloodTypeSelect;
  final Function(String, bool) onToggleInterest;

  // MBTI, Zodiac, Blood types are now handled by StellarIdentityHelper

  static const _allConstellations = [
    '🎵 Music',
    '🎮 Gaming',
    '📚 Books',
    '🎨 Art',
    '🏃 Sports',
    '🍜 Food',
    '✈️ Travel',
    '💻 Tech',
    '🎬 Movies',
    '🌿 Nature',
    '🔭 Science',
    '💃 Dance',
    '🎤 Karaoke',
    '👽 Sci-Fi',
    '🔥 18+',
  ];

  const EditProfileStellar({
    super.key,
    required this.mbtiController,
    required this.zodiacController,
    required this.bloodTypeController,
    required this.constellations,
    required this.isEditing,
    required this.onMbtiSelect,
    required this.onZodiacSelect,
    required this.onBloodTypeSelect,
    required this.onToggleInterest,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildIconPickerField(
                  context,
                  controller: mbtiController,
                  label: l10n.editProfileMbtiLabel,
                  options: StellarIdentityHelper.getMbtiTypes(),
                  title: l10n.editProfileSelectMbti,
                  onSelect: onMbtiSelect,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildIconPickerField(
                  context,
                  controller: zodiacController,
                  label: l10n.editProfileZodiacLabel,
                  options: StellarIdentityHelper.getZodiacTypes(context),
                  title: l10n.editProfileSelectZodiac,
                  onSelect: onZodiacSelect,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildIconPickerField(
                  context,
                  controller: bloodTypeController,
                  label: l10n.editProfileBloodLabel,
                  options: StellarIdentityHelper.getBloodTypes(context),
                  title: l10n.editProfileSelectBloodType,
                  onSelect: onBloodTypeSelect,
                  crossAxisCount: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInterestsSection(context, l10n),
        ],
      ),
    );
  }

  Widget _buildInterestsSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.editProfileInterestsLabel(constellations.length.toString()),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allConstellations.map((tag) {
            final isSelected = constellations.contains(tag);
            return FilterChip(
              label: Text(
                tag,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? Theme.of(context).colorScheme.surface
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              selected: isSelected,
              onSelected: isEditing
                  ? (val) => onToggleInterest(tag, val)
                  : null,
              selectedColor: const Color(0xFF4FC3F7),
              backgroundColor: Theme.of(
                context,
              ).colorScheme.onSurface.withOpacity(0.05),
              checkmarkColor: Theme.of(context).colorScheme.surface,
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF4FC3F7)
                    : Colors.transparent,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildIconPickerField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required List<Map<String, String>> options,
    required String title,
    required Function(String) onSelect,
    int crossAxisCount = 4,
  }) {
    final icon = label.contains('MBTI')
        ? StellarIdentityHelper.getIconForMbti(controller.text)
        : (label.contains('Zodiac')
            ? StellarIdentityHelper.getIconForZodiac(controller.text)
            : StellarIdentityHelper.getIconForBloodType(controller.text));

    return GestureDetector(
      onTap: isEditing
          ? () => EditProfileWidgets.showIconSelectionPicker(
                context: context,
                title: title,
                options: options,
                currentValue: controller.text,
                onSelect: onSelect,
                crossAxisCount: crossAxisCount,
              )
          : null,
      child: AbsorbPointer(
        absorbing: !isEditing,
        child: EditProfileWidgets.buildTextField(
          context: context,
          controller: controller,
          label: label,
          isEditing: isEditing,
          hint: 'Tap to select',
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              icon,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
