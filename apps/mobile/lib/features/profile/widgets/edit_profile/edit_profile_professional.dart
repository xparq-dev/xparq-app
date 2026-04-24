// lib/features/profile/widgets/edit_profile/edit_profile_professional.dart

import 'package:flutter/material.dart';
import 'edit_profile_widgets.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

class EditProfileProfessional extends StatelessWidget {
  final TextEditingController workController;
  final TextEditingController educationController;
  final TextEditingController experienceController;
  final List<String> skills;
  final bool isEditing;
  final Function(String, bool) onToggleSkill;

  static const _allSkills = [
    '💻 Coding',
    '🎨 Design',
    '📈 Marketing',
    '✍️ Writing',
    '📊 Data',
    '🤝 Sales',
    '💡 Strategy',
    '📷 Photo',
    '🎥 Video',
    '🎧 Audio',
    '🗣️ Languages',
    '🍳 Cooking',
    '🛠️ Engineering',
    '🧬 Science',
  ];

  const EditProfileProfessional({
    super.key,
    required this.workController,
    required this.educationController,
    required this.experienceController,
    required this.skills,
    required this.isEditing,
    required this.onToggleSkill,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.editProfileSectionProfessional,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          EditProfileWidgets.buildTextField(
            context: context,
            controller: workController,
            label: l10n.editProfileWorkLabel,
            hint: l10n.editProfileWorkHint,
            isEditing: isEditing,
          ),
          const SizedBox(height: 16),
          EditProfileWidgets.buildTextField(
            context: context,
            controller: educationController,
            label: l10n.editProfileEducationLabel,
            hint: l10n.editProfileEducationHint,
            isEditing: isEditing,
          ),
          const SizedBox(height: 16),
          EditProfileWidgets.buildTextField(
            context: context,
            controller: experienceController,
            label: l10n.editProfileExperienceLabel,
            hint: l10n.editProfileExperienceHint,
            isEditing: isEditing,
            maxLines: 10,
            maxLength: 3000,
          ),
          const SizedBox(height: 16),
          _buildSkillsSection(context, l10n),
        ],
      ),
    );
  }

  Widget _buildSkillsSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.editProfileSkillsLabel(skills.length.toString()),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allSkills.map((tag) {
            final isSelected = skills.contains(tag);
            return FilterChip(
              label: Text(
                tag,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? Theme.of(context).colorScheme.surface
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              selected: isSelected,
              onSelected: isEditing ? (val) => onToggleSkill(tag, val) : null,
              selectedColor: const Color(0xFF81C784),
              backgroundColor: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.05),
              checkmarkColor: Theme.of(context).colorScheme.surface,
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF81C784)
                    : Colors.transparent,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
