import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/shared/widgets/ui/buttons/galaxy_button.dart';
import 'package:xparq_app/shared/widgets/ui/cards/glass_card.dart';
import 'package:xparq_app/features/social/providers/social_provider.dart';
import 'package:xparq_app/features/social/widgets/post_card_widget.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key, required this.currentUserId});

  final String currentUserId;

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  late final TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController();

    Future.microtask(() {
      ref.read(socialProvider.notifier).loadFeed();
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _createPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    FocusScope.of(context).unfocus();

    await ref
        .read(socialProvider.notifier)
        .createPost(content: content, userId: widget.currentUserId);

    final nextState = ref.read(socialProvider);
    if (nextState.errorMessage == null) {
      _contentController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SocialState>(socialProvider, (previous, next) {
      if (previous?.errorMessage != next.errorMessage &&
          next.errorMessage != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }

      if (previous?.successMessage != next.successMessage &&
          next.successMessage != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.successMessage!)));
      }
    });

    final state = ref.watch(socialProvider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Feed')),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => ref.read(socialProvider.notifier).loadFeed(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: BorderRadius.circular(24),
                  opacity: 0.08,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Create Post',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _contentController,
                        minLines: 3,
                        maxLines: 6,
                        maxLength: 4096,
                        enabled: !state.isCreating,
                        decoration: InputDecoration(
                          hintText: 'What would you like to share?',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _contentController,
                        builder: (context, value, _) {
                          final hasText = value.text.trim().isNotEmpty;
                          return GalaxyButton(
                            label: 'Post',
                            isLoading: state.isCreating,
                            onTap: (state.isCreating || !hasText)
                                ? null
                                : _createPost,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.posts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text(
                        'No posts yet. Be the first to share something.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...state.posts.map((post) => PostCardWidget(post: post)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
