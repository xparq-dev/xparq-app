import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/social/providers/orbit_providers.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
// Reusing avatar logic if available, or build custom

class OrbitRequestsScreen extends ConsumerWidget {
  const OrbitRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(incomingRequestsProvider);
    final currentUser = ref.watch(supabaseAuthStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.requests),
        centerTitle: true,
      ),
      body: requestsAsync.when(
        data: (requestUids) {
          if (requestUids.isEmpty) {
            return Center(
              child: Text(
                AppLocalizations.of(context)!.orbitNoIncoming,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.54),
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: requestUids.length,
            itemBuilder: (context, index) {
              final senderUid = requestUids[index];
              return _RequestTile(
                key: ValueKey(senderUid),
                senderUid: senderUid,
                currentUid: currentUser!.id,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(AppLocalizations.of(context)!.errorPrefix(e.toString())),
        ),
      ),
    );
  }
}

class _RequestTile extends ConsumerStatefulWidget {
  final String senderUid;
  final String currentUid;

  const _RequestTile({
    super.key,
    required this.senderUid,
    required this.currentUid,
  });

  @override
  ConsumerState<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends ConsumerState<_RequestTile> {
  bool _isProcessing = false;
  String _status = 'pending'; // pending, accepted, rejected

  void _handleAccept() async {
    setState(() => _isProcessing = true);
    try {
      await ref
          .read(orbitRepositoryProvider)
          .acceptRequest(widget.currentUid, widget.senderUid);
      if (mounted) setState(() => _status = 'accepted');
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _handleReject() async {
    setState(() => _isProcessing = true);
    try {
      await ref
          .read(orbitRepositoryProvider)
          .rejectRequest(widget.currentUid, widget.senderUid);
      if (mounted) setState(() => _status = 'rejected');
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // We need to fetch the profile of the sender
    final senderProfileAsync = ref.watch(
      planetProfileByUidProvider(widget.senderUid),
    );

    return senderProfileAsync.when(
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
              // Reject
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: _handleReject,
              ),
              // Accept
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                onPressed: _handleAccept,
              ),
            ],
          );
        }

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(profile.photoUrl),
            radius: 24,
          ),
          title: Text(
            profile.xparqName,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            profile.bio,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withOpacity(0.54),
            ),
          ),
          trailing: trailingWidget,
        );
      },
      loading: () => ListTile(
        leading: const CircleAvatar(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text(AppLocalizations.of(context)!.loading),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
