import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/shared/router/app_router.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/social/providers/orbit_providers.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

class OrbitListScreen extends ConsumerStatefulWidget {
  final String uid;
  final int initialTabIndex; // 0 = Orbiters, 1 = Orbiting

  const OrbitListScreen({
    super.key,
    required this.uid,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<OrbitListScreen> createState() => _OrbitListScreenState();
}

class _OrbitListScreenState extends ConsumerState<OrbitListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final currentUser = ref.read(supabaseAuthStateProvider).valueOrNull;
    final isOwnList = currentUser?.id == widget.uid;

    _tabController = TabController(
      length: isOwnList ? 3 : 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(supabaseAuthStateProvider).valueOrNull;
    final isOwnList = currentUser?.id == widget.uid;
    final requestsAsync = ref.watch(incomingRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.orbitConnectionsTitle,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4FC3F7),
          labelColor: const Color(0xFF4FC3F7),
          unselectedLabelColor: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.54),
          tabs: [
            Tab(text: AppLocalizations.of(context)!.orbiters),
            Tab(text: AppLocalizations.of(context)!.orbiting),
            if (isOwnList)
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(AppLocalizations.of(context)!.requests),
                    requestsAsync.maybeWhen(
                      data: (list) => list.isNotEmpty
                          ? Container(
                              margin: const EdgeInsetsDirectional.only(
                                start: 6,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${list.length}',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OrbitList(uid: widget.uid, collection: 'orbited_by'),
          _OrbitList(uid: widget.uid, collection: 'orbiting'),
          if (isOwnList) _RequestsList(currentUid: widget.uid),
        ],
      ),
    );
  }
}

class _RequestsList extends ConsumerWidget {
  final String currentUid;
  const _RequestsList({required this.currentUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(incomingRequestsProvider);

    return requestsAsync.when(
      data: (uids) {
        if (uids.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none_outlined,
                  size: 64,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.24),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.orbitNoRequests,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.54),
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: uids.length,
          itemBuilder: (context, index) {
            return _RequestTileWrapper(
              senderUid: uids[index],
              currentUid: currentUid,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(AppLocalizations.of(context)!.errorPrefix(e.toString())),
      ),
    );
  }
}

class _RequestTileWrapper extends ConsumerStatefulWidget {
  final String senderUid;
  final String currentUid;
  const _RequestTileWrapper({
    required this.senderUid,
    required this.currentUid,
  });

  @override
  ConsumerState<_RequestTileWrapper> createState() =>
      _RequestTileWrapperState();
}

class _RequestTileWrapperState extends ConsumerState<_RequestTileWrapper> {
  bool _isProcessing = false;
  String _status = 'pending'; // 'pending', 'accepted', 'rejected'

  Future<void> _handleAccept() async {
    setState(() => _isProcessing = true);
    try {
      await ref
          .read(orbitRepositoryProvider)
          .acceptRequest(widget.currentUid, widget.senderUid);
      if (mounted) setState(() => _status = 'accepted');
    } catch (e) {
      debugPrint('ORBIT: Accept Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleReject() async {
    setState(() => _isProcessing = true);
    try {
      await ref
          .read(orbitRepositoryProvider)
          .rejectRequest(widget.currentUid, widget.senderUid);
      if (mounted) setState(() => _status = 'rejected');
    } catch (e) {
      debugPrint('ORBIT: Reject Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(
      planetProfileByUidProvider(widget.senderUid),
    );

    return profileAsync.when(
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();

        Widget trailingWidget;
        if (_isProcessing) {
          trailingWidget = const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        } else if (_status == 'accepted') {
          trailingWidget = Text(
            AppLocalizations.of(context)!.orbitAccepted,
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          );
        } else if (_status == 'rejected') {
          trailingWidget = Text(
            AppLocalizations.of(context)!.orbitDeclined,
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          );
        } else {
          trailingWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.redAccent),
                onPressed: _handleReject,
              ),
              IconButton(
                icon: const Icon(Icons.check, color: Colors.greenAccent),
                onPressed: _handleAccept,
              ),
            ],
          );
        }

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(profile.photoUrl),
          ),
          title: Text(
            profile.xparqName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(AppLocalizations.of(context)!.orbitWantsToWithYou),
          trailing: trailingWidget,
        );
      },
      loading: () =>
          ListTile(title: Text(AppLocalizations.of(context)!.loadingProfile)),
      error: (__, _) => const SizedBox.shrink(),
    );
  }
}

class _OrbitList extends ConsumerWidget {
  final String uid;
  final String collection; // 'orbited_by' or 'orbiting'

  const _OrbitList({required this.uid, required this.collection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(
      orbitListProvider(OrbitListParams(uid, collection)),
    );

    return stream.when(
      data: (users) {
        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  collection == 'orbited_by'
                      ? Icons.group_off_outlined
                      : Icons.public_off_outlined,
                  size: 64,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.24),
                ),
                const SizedBox(height: 16),
                Text(
                  collection == 'orbited_by'
                      ? AppLocalizations.of(context)!.orbitNoOrbiters
                      : AppLocalizations.of(context)!.orbitNotOrbiting,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.54),
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: user.photoUrl.isNotEmpty
                    ? NetworkImage(user.photoUrl)
                    : null,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.10),
                child: user.photoUrl.isEmpty
                    ? Icon(
                        Icons.person,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.54),
                      )
                    : null,
              ),
              title: Text(
                user.xparqName,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                user.bio.isNotEmpty ? user.bio : user.ageGroup.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.54),
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                onPressed: () {
                  final currentUid = ref
                      .read(authRepositoryProvider)
                      .currentUser
                      ?.id;
                  if (currentUid != null) {
                    _showUnorbitDialog(context, ref, currentUid, user);
                  }
                },
              ),
              onTap: () {
                final currentUid = ref
                    .read(authRepositoryProvider)
                    .currentUser
                    ?.id;
                if (user.id == currentUid) {
                  context.push(AppRoutes.profile);
                } else {
                  context.push('${AppRoutes.otherProfile}/${user.id}');
                }
              },
            );
          },
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.24),
        ),
      ),
      error: (err, stack) => Center(
        child: Text(
          AppLocalizations.of(context)!.errorPrefix(err.toString()),
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.38),
          ),
        ),
      ),
    );
  }

  void _showUnorbitDialog(
    BuildContext context,
    WidgetRef ref,
    String currentUid,
    dynamic contact,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.disconnectConfirmTitle),
          content: Text(
            AppLocalizations.of(
              context,
            )!.orbitDisconnectDesc(contact.xparqName),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () async {
                try {
                  // Wait for the repository method to complete
                  await ref
                      .read(orbitRepositoryProvider)
                      .removeOrbit(currentUid, contact.id);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(
                            context,
                          )!.failedPrefix(e.toString()),
                        ),
                      ),
                    );
                  }
                }
              },
              child: Text(
                AppLocalizations.of(context)!.disconnect,
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}

