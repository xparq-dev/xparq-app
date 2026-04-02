import 'package:flutter/material.dart';
import 'package:xparq_app/core/widgets/galaxy_button.dart';
import 'package:xparq_app/core/widgets/galaxy_text_field.dart';
import 'package:xparq_app/core/widgets/glass_card.dart';

class ProfileForm extends StatelessWidget {
  const ProfileForm({
    super.key,
    required this.nameController,
    required this.bioController,
    required this.isLoading,
    required this.onSave,
  });

  final TextEditingController nameController;
  final TextEditingController bioController;
  final bool isLoading;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(28),
      opacity: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Profile Details',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Update your name and bio.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 24),
          GalaxyTextField(
            controller: nameController,
            label: 'Name',
            enabled: !isLoading,
            maxLength: 32,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: bioController,
            enabled: !isLoading,
            minLines: 4,
            maxLines: 6,
            maxLength: 300,
            decoration: InputDecoration(
              labelText: 'Bio',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          GalaxyButton(
            label: 'Save Profile',
            isLoading: isLoading,
            onTap: isLoading ? null : onSave,
          ),
        ],
      ),
    );
  }
}
