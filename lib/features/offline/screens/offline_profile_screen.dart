import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/offline/providers/offline_user_provider.dart';
import 'package:xparq_app/features/offline/providers/offline_friends_provider.dart';
import 'package:xparq_app/features/offline/services/nearby_service.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

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
                  color: themeColors.onSurface.withOpacity(0.5),
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
                fillColor: Colors.grey.withOpacity(
                  0.2,
                ), // Grey background
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                hintText: AppLocalizations.of(context)!.offlineDisplayNameHint,
                hintStyle: TextStyle(
                  color: themeColors.onSurface.withOpacity(0.4),
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
                    color: Colors.redAccent.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ),

            const SizedBox(height: 48),

            // Friends Section
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                AppLocalizations.of(context)!.offlineFriendsSection,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: themeColors.onSurface.withOpacity(0.5),
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
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline,
                          color: themeColors.onSurface.withOpacity(0.2),
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!.offlineNoFriends,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: themeColors.onSurface.withOpacity(0.4),
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
                        color: themeColors.onSurface.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: themeColors.onSurface.withOpacity(0.1),
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isConnected
                              ? Colors.green.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.2),
                          child: Icon(
                            Icons.person,
                            color: isConnected
                                ? Colors.greenAccent
                                : Colors.grey,
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
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          AppLocalizations.of(context)!.offlineRemoveFriendTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          AppLocalizations.of(
            context,
          )!.offlineRemoveFriendDesc(friend.displayName),
          style: const TextStyle(color: Colors.white70),
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
                    )!.offlineFriendRemoved(friend.displayName),
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
