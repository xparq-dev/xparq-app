import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/chat/providers/chat_provider.dart';
import 'package:xparq_app/features/chat/widgets/chat_message_input.dart';
import 'package:xparq_app/features/chat/widgets/chat_message_tile.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.currentUserId,
    this.otherUserId,
    this.title = 'Chat',
  });

  final String currentUserId;
  final String? otherUserId;
  final String title;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late final TextEditingController _messageController;
  late final ChatRequest _request;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _request = ChatRequest(
      currentUserId: widget.currentUserId,
      otherUserId: widget.otherUserId,
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text;
    if (content.trim().isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();

    final success = await ref
        .read(chatProviderFamily(_request).notifier)
        .sendMessage(content: content);

    if (success) {
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ChatState>(chatProviderFamily(_request), (previous, next) {
      if (previous?.errorMessage == next.errorMessage ||
          next.errorMessage == null) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(next.errorMessage!)));
    });

    final state = ref.watch(chatProviderFamily(_request));

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: !_request.canChat
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'A recipient is required to open this chat.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.messages.isEmpty
                    ? const Center(
                        child: Text('No messages yet. Start the conversation.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        reverse: true,
                        itemCount: state.messages.length,
                        itemBuilder: (context, index) {
                          final message =
                              state.messages[state.messages.length - 1 - index];
                          return ChatMessageTile(
                            message: message,
                            isMe: message.senderId == widget.currentUserId,
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: ChatMessageInput(
                  controller: _messageController,
                  isSending: state.isSending || !_request.canChat,
                  onSend: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
