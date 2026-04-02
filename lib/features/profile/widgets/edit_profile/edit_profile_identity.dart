// lib/features/profile/widgets/edit_profile/edit_profile_identity.dart

import 'package:flutter/material.dart';
import 'edit_profile_widgets.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

class EditProfileIdentity extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController handleController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final bool isEditing;
  final int handleCooldown;

  const EditProfileIdentity({
    super.key,
    required this.nameController,
    required this.handleController,
    required this.emailController,
    required this.phoneController,
    required this.isEditing,
    required this.handleCooldown,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name & Handle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              EditProfileWidgets.buildTextField(
                context: context,
                controller: nameController,
                label: l10n.editProfileNameLabel,
                hint: l10n.editProfileNameHint,
                isEditing: isEditing,
                maxLength: 30,
                validator: (v) =>
                    (v == null || v.trim().length < 3) ? 'Min 3 chars' : null,
              ),
              const SizedBox(height: 16),
              _buildHandleField(context, l10n),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Contact Info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.editProfileContactInfo,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.editProfileContactInfoDesc,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 12),
              EditProfileWidgets.buildTextField(
                context: context,
                controller: emailController,
                label: l10n.editProfileContactEmailLabel,
                hint: 'example@email.com',
                isEditing: isEditing,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              EditProfileWidgets.buildTextField(
                context: context,
                controller: phoneController,
                label: l10n.editProfileContactPhoneLabel,
                hint: '08XXXXXXXX',
                isEditing: isEditing,
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHandleField(BuildContext context, AppLocalizations l10n) {
    final locked = handleCooldown > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: handleController,
          enabled: !locked && isEditing,
          decoration: InputDecoration(
            labelText: l10n.editProfileHandleLabel,
            prefixText: '@',
            prefixStyle: const TextStyle(
              color: Color(0xFF4FC3F7),
              fontWeight: FontWeight.bold,
            ),
            filled: true,
            fillColor: locked
                ? Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.02)
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            suffixIcon: locked
                ? const Icon(Icons.lock_outline, size: 18)
                : null,
          ),
          onChanged: (v) {
            final safe = v.toLowerCase().replaceAll(' ', '');
            if (safe != v) {
              handleController.text = safe;
              handleController.selection = TextSelection.fromPosition(
                TextPosition(offset: safe.length),
              );
            }
          },
        ),
        if (locked)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              l10n.editProfileHandleCooldown(handleCooldown.toString()),
              style: const TextStyle(fontSize: 11, color: Colors.orangeAccent),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              l10n.editProfileHandleLockNote,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.38),
              ),
            ),
          ),
      ],
    );
  }
}
