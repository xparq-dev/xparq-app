import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/shared/widgets/ui/cards/glass_card.dart';
import 'package:xparq_app/shared/widgets/common/xparq_image.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:xparq_app/features/chat/domain/models/chat_model.dart';

class MemberSearchPopup extends ConsumerStatefulWidget {
  final ChatModel chat;

  const MemberSearchPopup({super.key, required this.chat});

  @override
  ConsumerState<MemberSearchPopup> createState() => _MemberSearchPopupState();
}

class _MemberSearchPopupState extends ConsumerState<MemberSearchPopup> {
  final _searchController = TextEditingController();
  List<PlanetModel> _results = [];
  bool _isLoading = false;

  void _onSearch() async {
    if (_searchController.text.isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final users = await ref
          .read(chatRepositoryProvider)
          .searchUsers(_searchController.text);
      // Filter out those already in the chat
      final filtered = users
          .where((u) => !widget.chat.participants.contains(u.id))
          .toList();
      if (mounted) {
        setState(() {
          _results = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
      }
    }
  }

  void _addMember(PlanetModel user) async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .addMember(widget.chat.chatId, user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${user.xparqName} added to ${widget.chat.name ?? "Cluster"}',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          color: Colors.transparent,
          child: GlassCard(
            blur: 20,
            opacity: 0.1,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 500),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'INVITE TO CLUSTER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => _onSearch(),
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search Sparqs...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white70,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_results.isEmpty &&
                      _searchController.text.isNotEmpty)
                    const Center(
                      child: Text(
                        'No results found in this sector.',
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _results.length,
                        separatorBuilder: (__, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final user = _results[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundImage: user.photoUrl.isNotEmpty
                                  ? XparqImage.getImageProvider(user.photoUrl)
                                  : null,
                              child: user.photoUrl.isEmpty
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(
                              user.xparqName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '@${user.handle}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                            trailing: TextButton(
                              onPressed: () => _addMember(user),
                              child: const Text(
                                'ADD',
                                style: TextStyle(
                                  color: Color(0xFF4FC3F7),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
