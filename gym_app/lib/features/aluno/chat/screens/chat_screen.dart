import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../data/models/message_model.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/providers/global_providers.dart';

/// Provider do chat.
final chatMessagesProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, salaId) {
  return ref.read(chatRepositoryProvider).messagesStream(salaId);
});

/// Ecrã de chat entre aluno e personal trainer.
/// Se [chatPartnerId] for fornecido (ex: pelo admin), usa-o como o outro participante.
/// Caso contrário, usa o [personalId] do utilizador autenticado (modo aluno).
class ChatScreen extends ConsumerStatefulWidget {
  final String? chatPartnerId;

  const ChatScreen({super.key, this.chatPartnerId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userId = authState.user?.uid ?? '';

    // Determina o outro participante
    final otherId = widget.chatPartnerId ??
        authState.user?.personalId ??
        '';

    if (otherId.isEmpty || otherId == userId) {
      return const Scaffold(
        body: Center(
          child: Text('Nenhum participante associado ao chat.'),
        ),
      );
    }

    final salaId = ref.read(chatRepositoryProvider).getChatRoomId(
          userId,
          otherId,
        );
    final messagesAsync = ref.watch(chatMessagesProvider(salaId));

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.chatTitle),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Lista de mensagens
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _scrollToBottom());
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      AppStrings.noMessages,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (_, index) {
                    final message = messages[index];
                    final isMine = message.remetenteId == userId;
                    return _MessageBubble(
                      message: message,
                      isMine: isMine,
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  const Center(child: Text('Erro ao carregar mensagens')),
            ),
          ),
          // Campo de texto
          _buildMessageInput(salaId, userId),
        ],
      ),
    );
  }

  Widget _buildMessageInput(String salaId, String userId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: AppStrings.typeMessage,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.backgroundLight,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () => _sendMessage(salaId, userId),
                icon: const Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage(String salaId, String userId) async {
    final texto = _textController.text.trim();
    if (texto.isEmpty) return;

    final message = MessageModel(
      remetenteId: userId,
      texto: texto,
      timestamp: DateTime.now(),
    );

    try {
      await ref.read(chatRepositoryProvider).sendMessage(salaId, message);
      _textController.clear();
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.messageSendError),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

/// Bubble de mensagem.
class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(message.timestamp);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? AppColors.primary : AppColors.backgroundLight,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMine
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: isMine
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.texto,
              style: TextStyle(
                color: isMine ? AppColors.textOnPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: 10,
                color: isMine
                    ? AppColors.textOnPrimary.withValues(alpha: 0.7)
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
