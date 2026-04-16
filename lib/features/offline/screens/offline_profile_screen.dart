import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/offline/providers/offline_user_provider.dart';
import 'package:xparq_app/features/offline/providers/offline_friends_provider.dart';
import 'package:xparq_app/features/offline/services/offline_mesh_encryption_service.dart';
import 'package:xparq_app/features/offline/services/nearby_service.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';

class OfflineProfileScreen extends ConsumerStatefulWidget {
  const OfflineProfileScreen({super.key});

  @override
  ConsumerState<OfflineProfileScreen> createState() =>
      _OfflineProfileScreenState();
}

class _OfflineProfileScreenState extends ConsumerState<OfflineProfileScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final currentState = ref.read(offlineUserProvider);
    _nameController = TextEditingController(text: currentState.displayName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveName() {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty) {
      ref.read(offlineUserProvider.notifier).updateDisplayName(newName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.offlineNameSaved)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(offlineUserProvider);
    final themeColors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final softSurface = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);
    final softBorder = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);
    final mutedText = themeColors.onSurface.withValues(alpha: 0.5);
    final faintText = themeColors.onSurface.withValues(alpha: 0.4);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.offlineProfileTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/perfect_thunder_logo.png'),
                  fit: BoxFit.contain, // Use contain so the bolt isn't cropped
                ),
              ),
            ),
            const SizedBox(height: 0),
            Text(
              userState.isAnonymous
                  ? '@anonymous'
                  : _nameController.text.isNotEmpty
                      ? '@${_nameController.text}'
                      : AppLocalizations.of(context)!.offlineNamePlaceholder,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: userState.isAnonymous || _nameController.text.isEmpty
                    ? Colors.grey
                    : themeColors.onSurface,
              ),
            ),
            const SizedBox(height: 48),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'YOUR iXPARQ NAME',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: mutedText,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              enabled: !userState.isAnonymous,
              style: TextStyle(color: themeColors.onSurface),
              onChanged: (value) {
                // Trigger a rebuild to update the '@' text above
                setState(() {});
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: softSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                hintText: AppLocalizations.of(context)!.offlineDisplayNameHint,
                hintStyle: TextStyle(
                  color: faintText,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: userState.isAnonymous ? null : _saveName,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.offlineSaveName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (userState.isAnonymous)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  AppLocalizations.of(context)!.offlineAnonEditDisabled,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.redAccent.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ),

            const SizedBox(height: 48),

            const _MySecurityCard(),

            const SizedBox(height: 48),

            // Friends Section
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                AppLocalizations.of(context)!.offlineFriendsSection,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: mutedText,
                ),
              ),
            ),
            const SizedBox(height: 16),

            Consumer(
              builder: (context, ref, child) {
                final friends = ref.watch(offlineFriendsProvider);
                if (friends.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: softSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: softBorder,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline,
                          color: themeColors.onSurface.withValues(alpha: 0.2),
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!.offlineNoFriends,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: faintText,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: friends.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    final isConnected = NearbyService.instance.isPeerConnected(
                      friend.peerId,
                    );

                    return Container(
                      decoration: BoxDecoration(
                        color: softSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: softBorder,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isConnected
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.2),
                          child: Icon(
                            Icons.person,
                            color:
                                isConnected ? Colors.greenAccent : Colors.grey,
                          ),
                        ),
                        title: Text(
                          friend.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: themeColors.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          isConnected ? 'Connected' : 'Offline',
                          style: TextStyle(
                            color: isConnected
                                ? (Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.greenAccent
                                    : Colors.green.shade700)
                                : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _confirmDeleteFriend(friend),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteFriend(OfflineFriend friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          AppLocalizations.of(context)!.offlineRemoveFriendTitle,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          AppLocalizations.of(
            context,
          )!
              .offlineRemoveFriendDesc(friend.displayName),
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.72),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.offlineCancel),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(offlineFriendsProvider.notifier)
                  .removeFriend(friend.peerId);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(
                      context,
                    )!
                        .offlineFriendRemoved(friend.displayName),
                  ),
                ),
              );
            },
            child: Text(
              AppLocalizations.of(context)!.offlineClear,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _MySecurityCard extends StatelessWidget {
  const _MySecurityCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<String>(
      future: OfflineMeshEncryptionService.instance.getPublicKeyBase64(),
      builder: (context, snapshot) {
        final publicKey = snapshot.data ?? '';
        final fingerprint = OfflineMeshEncryptionService.instance
            .fingerprintFromPublicKey(publicKey);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: scheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    'My security key',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Fingerprint',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                fingerprint,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary.withValues(alpha: 0.14),
                  foregroundColor: scheme.primary,
                  disabledBackgroundColor:
                      scheme.onSurface.withValues(alpha: 0.08),
                  disabledForegroundColor:
                      scheme.onSurface.withValues(alpha: 0.38),
                ),
                onPressed: publicKey.isEmpty
                    ? null
                    : () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => _MySecurityQrSheet(
                            publicKey: publicKey,
                            fingerprint: fingerprint,
                          ),
                        ),
                child: const Text(
                  'Show verification QR',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MySecurityQrSheet extends StatelessWidget {
  final String publicKey;
  final String fingerprint;

  const _MySecurityQrSheet({
    required this.publicKey,
    required this.fingerprint,
  });

  @override
  Widget build(BuildContext context) {
    final qrPayload =
        '{"type":"offline_mesh_key","publicKey":"$publicKey","fingerprint":"$fingerprint"}';

    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Material(
          color: scheme.surface,
          elevation: 12,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Verification QR',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: QrImageView(
                    data: qrPayload,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  fingerprint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppLocalizations.of(context)!.offlineCancel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
