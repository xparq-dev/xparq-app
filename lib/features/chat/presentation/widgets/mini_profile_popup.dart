import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:xparq_app/shared/router/app_router.dart';
import 'package:xparq_app/shared/widgets/ui/cards/glass_card.dart';
import 'package:xparq_app/shared/widgets/common/expandable_text.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';

class MiniProfilePopup extends ConsumerWidget {
  final PlanetModel profile;
  final String chatId;

  const MiniProfilePopup({
    super.key,
    required this.profile,
    required this.chatId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF1D9BF0);
    final chatSettings = ref.watch(chatSettingsProvider).valueOrNull ?? {};
    final isSilenced =
        chatSettings[chatId]?['silenced_until'] != null &&
        DateTime.parse(
          chatSettings[chatId]!['silenced_until'],
        ).isAfter(DateTime.now());

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        child: Material(
          color: Colors.transparent,
          child: GlassCard(
            borderRadius: BorderRadius.circular(24),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar with Glow
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: isDark
                              ? Colors.white10
                              : Colors.black12,
                          backgroundImage: profile.photoUrl.isNotEmpty
                              ? CachedNetworkImageProvider(profile.photoUrl)
                              : null,
                          child: profile.photoUrl.isEmpty
                              ? Icon(
                                  Icons.person,
                                  size: 40,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: profile.isActuallyOnline
                                  ? const Color(0xFF4CAF50)
                                  : Colors.grey,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Name & Handle
                    Text(
                      profile.xparqName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '@${profile.handle}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Bio
                    if (profile.bio.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ExpandableText(
                          text: profile.bio,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          trimLines: 3,
                        ),
                      ),

                    // Stats / Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          'Galactic Orbit',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ActionButton(
                          icon: Icons.call_outlined,
                          label: 'Call',
                          onTap: () =>
                              _launchCaller(profile.contactPhone ?? ''),
                        ),
                        _ActionButton(
                          icon: isSilenced
                              ? Icons.notifications_off
                              : Icons.notifications_none_outlined,
                          label: isSilenced ? 'Unmute' : 'Silent',
                          onTap: () => _toggleSilent(ref, isSilenced),
                        ),
                        _ActionButton(
                          icon: Icons.public_outlined,
                          label: 'Planet',
                          onTap: () {
                            Navigator.pop(context);
                            context.push(
                              '${AppRoutes.otherProfile}/${profile.id}',
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _launchCaller(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _toggleSilent(WidgetRef ref, bool isCurrentlySilenced) async {
    final until = isCurrentlySilenced
        ? null
        : DateTime.now().add(
            const Duration(days: 365 * 10),
          ); // Permanent-ish mute
    await ref.read(chatRepositoryProvider).silenceChat(chatId, until);
    ref.invalidate(chatSettingsProvider);
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF1D9BF0), size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

