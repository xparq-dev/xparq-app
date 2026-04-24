// lib/features/profile/widgets/edit_profile/edit_profile_persona.dart

import 'package:flutter/material.dart';
import 'edit_profile_widgets.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:xparq_app/shared/constants/thailand_provinces.dart';

class EditProfilePersona extends StatelessWidget {
  final TextEditingController shortBioController;
  final TextEditingController extendedBioController;
  final TextEditingController genderController;
  final TextEditingController occupationController;
  final TextEditingController locationController;
  final TextEditingController link1Controller;
  final TextEditingController link2Controller;
  final TextEditingController link3Controller;
  final FocusNode locationFocusNode;
  final bool isEditing;
  final VoidCallback onGpsLocation;
  final Function(String) onGenderSelect;

  static const _genderOptions = [
    'Male',
    'Female',
    'Non-binary',
    'LGBTQ+',
    'Prefer not to say',
    'Custom',
  ];

  const EditProfilePersona({
    super.key,
    required this.shortBioController,
    required this.extendedBioController,
    required this.genderController,
    required this.occupationController,
    required this.locationController,
    required this.link1Controller,
    required this.link2Controller,
    required this.link3Controller,
    required this.locationFocusNode,
    required this.isEditing,
    required this.onGpsLocation,
    required this.onGenderSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // Bio Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              EditProfileWidgets.buildTextField(
                context: context,
                controller: shortBioController,
                label: l10n.editProfileShortBioLabel,
                hint: l10n.editProfileShortBioHint,
                isEditing: isEditing,
                maxLength: 200,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              EditProfileWidgets.buildTextField(
                context: context,
                controller: extendedBioController,
                label: l10n.editProfileExtendedBioLabel,
                hint: l10n.editProfileExtendedBioHint,
                isEditing: isEditing,
                maxLength: 2000,
                maxLines: 8,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Details Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: EditProfileWidgets.buildPickerField(
                      context: context,
                      controller: genderController,
                      label: l10n.editProfileGenderLabel,
                      options: _genderOptions,
                      title: l10n.editProfileSelectGender,
                      isEditing: isEditing,
                      onSelect: onGenderSelect,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: EditProfileWidgets.buildTextField(
                      context: context,
                      controller: occupationController,
                      label: l10n.editProfileOccupationLabel,
                      hint: l10n.editProfileOccupationHint,
                      isEditing: isEditing,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildLocationAutocomplete(context, l10n),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Links Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              EditProfileWidgets.buildTextField(
                context: context,
                controller: link1Controller,
                label: l10n.editProfileLinkLabel('1'),
                hint: l10n.editProfileLink1Hint,
                isEditing: isEditing,
              ),
              const SizedBox(height: 12),
              EditProfileWidgets.buildTextField(
                context: context,
                controller: link2Controller,
                label: l10n.editProfileLinkLabel('2'),
                hint: l10n.editProfileLink2Hint,
                isEditing: isEditing,
              ),
              const SizedBox(height: 12),
              EditProfileWidgets.buildTextField(
                context: context,
                controller: link3Controller,
                label: l10n.editProfileLinkLabel('3'),
                hint: l10n.editProfileLink3Hint,
                isEditing: isEditing,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationAutocomplete(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return Autocomplete<String>(
      textEditingController: locationController,
      focusNode: locationFocusNode,
      displayStringForOption: (option) => formatThailandLocation(option),
      optionsBuilder: (TextEditingValue textEditingValue) {
        String text = textEditingValue.text;
        if (text.endsWith(', TH')) {
          text = text.substring(0, text.length - 4);
        }
        if (text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return thailandProvinces.where((String option) {
          return option.toLowerCase().contains(text.toLowerCase());
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return EditProfileWidgets.buildTextField(
          context: context,
          focusNode: focusNode,
          controller: controller,
          label: l10n.editProfileLocationLabel,
          hint: l10n.editProfileLocationHint,
          isEditing: isEditing,
          suffixIcon: isEditing
              ? IconButton(
                  icon: const Icon(
                    Icons.gps_fixed,
                    size: 20,
                    color: Color(0xFF4FC3F7),
                  ),
                  onPressed: onGpsLocation,
                  tooltip: 'Use Current Location',
                )
              : null,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8.0,
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).cardColor,
            child: SizedBox(
              height: 250,
              width: MediaQuery.of(context).size.width - 40,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                ),
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return ListTile(
                    visualDensity: VisualDensity.compact,
                    title: Text(
                      option,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                    trailing: Text(
                      'TH',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
