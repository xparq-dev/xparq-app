// lib/features/profile/widgets/about_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/shared/widgets/common/expandable_text.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';

class AboutTab extends ConsumerStatefulWidget {
  final PlanetModel profile;
  final bool isOwnProfile;
  const AboutTab({
    super.key,
    required this.profile,
    required this.isOwnProfile,
  });

  @override
  ConsumerState<AboutTab> createState() => _AboutTabState();
}

class _AboutTabState extends ConsumerState<AboutTab> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = widget.profile;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profile.bio.isNotEmpty)
            _buildSection(
              context,
              title: AppLocalizations.of(context)!.bio,
              child: ExpandableText(
                text: profile.bio,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
          if (profile.extendedBio != null && profile.extendedBio!.isNotEmpty)
            _buildSection(
              context,
              title: AppLocalizations.of(context)!.extendedBio,
              child: ExpandableText(
                text: profile.extendedBio!,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          _buildSection(
            context,
            title: AppLocalizations.of(context)!.basicInfo,
            child: Column(
              children: [
                if (profile.gender != null && profile.gender!.isNotEmpty)
                  _buildInfoRow(
                    context,
                    Icons.person_outline,
                    AppLocalizations.of(context)!.gender,
                    profile.gender!,
                  ),
                if (profile.locationName != null &&
                    profile.locationName!.isNotEmpty)
                  _buildInfoRow(
                    context,
                    Icons.location_on_outlined,
                    AppLocalizations.of(context)!.location,
                    profile.locationName!,
                  ),
                if (profile.contactEmail != null &&
                    profile.contactEmail!.isNotEmpty)
                  _buildInfoRow(
                    context,
                    Icons.email_outlined,
                    AppLocalizations.of(context)!.email,
                    profile.isContactPublic || widget.isOwnProfile
                        ? profile.contactEmail!
                        : _maskedEmail(profile.contactEmail!),
                    trailing: _buildEyeToggle(theme, profile),
                  ),
                if (profile.contactPhone != null &&
                    profile.contactPhone!.isNotEmpty)
                  _buildInfoRow(
                    context,
                    Icons.phone_outlined,
                    AppLocalizations.of(context)!.tel,
                    profile.isContactPublic || widget.isOwnProfile
                        ? profile.contactPhone!
                        : _maskedPhone(profile.contactPhone!),
                    trailing:
                        (profile.contactEmail == null ||
                            profile.contactEmail!.isEmpty)
                        ? _buildEyeToggle(theme, profile)
                        : null,
                  ),
              ],
            ),
          ),
          // Additional sections
          _buildSection(
            context,
            title: 'STELLAR DECOR',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (profile.mbti != null && profile.mbti!.isNotEmpty)
                  _IdentityChip(
                    icon: Icons.psychology,
                    label: profile.mbti!,
                    color: Colors.blueGrey,
                  ),
                if (profile.zodiac != null && profile.zodiac!.isNotEmpty)
                  _IdentityChip(
                    icon: Icons.auto_awesome,
                    label: profile.zodiac!,
                    color: Colors.amber,
                  ),
                if (profile.bloodType != null && profile.bloodType!.isNotEmpty)
                  _IdentityChip(
                    icon: Icons.bloodtype_outlined,
                    label: 'Type ${profile.bloodType}',
                    color: Colors.redAccent,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildEyeToggle(ThemeData theme, PlanetModel profile) {
    if (!widget.isOwnProfile && !profile.isContactPublic) {
      return TextButton(
        onPressed: () => _handleContactRequest(context),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
        ),
        child: const Text(
          'Request',
          style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 12),
        ),
      );
    }

    final isVisible = profile.isContactPublic;
    return GestureDetector(
      onTap: widget.isOwnProfile
          ? () async {
              try {
                await ref.read(authRepositoryProvider).updatePlanetProfile(
                  profile.id,
                  {'is_contact_public': !isVisible},
                );
                ref.invalidate(planetProfileProvider);
                ref.invalidate(planetProfileByUidProvider(profile.id));
              } catch (e) {
                if (mounted) {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          : null,
      child: Icon(
        isVisible ? Icons.visibility : Icons.visibility_off_outlined,
        size: 18,
        color: isVisible
            ? const Color(0xFF4FC3F7)
            : theme.colorScheme.onSurface.withValues(alpha: 0.3),
      ),
    );
  }

  Future<void> _handleContactRequest(BuildContext context) async {
    final currentUser = ref.read(supabaseAuthStateProvider).valueOrNull;
    if (currentUser == null) return;
    final myProfile = ref.read(planetProfileProvider).valueOrNull;
    if (myProfile == null) return;

    try {
      final chat = await ref
          .read(chatBaseRepositoryProvider)
          .getOrCreateChat(myUid: currentUser.id, otherUid: widget.profile.id);
      await ref
          .read(contactRequestRepositoryProvider)
          .sendContactRequest(
            chatId: chat.chatId,
            senderProfile: myProfile,
            targetUid: widget.profile.id,
          );
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.contactRequestSent),
            backgroundColor: const Color(0xFF4FC3F7),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.error(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _maskedEmail(String email) {
    final atIdx = email.indexOf('@');
    if (atIdx < 2) return email;
    final local = email.substring(0, atIdx);
    final domain = email.substring(atIdx);
    return '${local[0]}${'*' * (local.length - 2)}${local[local.length - 1]}$domain';
  }

  String _maskedPhone(String phone) {
    if (phone.length < 5) return phone;
    const visible = 2, tail = 2;
    final stars = '*' * (phone.length - visible - tail);
    return '${phone.substring(0, visible)}$stars${phone.substring(phone.length - tail)}';
  }
}

class _IdentityChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _IdentityChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
