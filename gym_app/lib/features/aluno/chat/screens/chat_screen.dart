import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../data/models/message_model.dart';
import '../../../../data/models/group_model.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/providers/global_providers.dart';
import '../../../../shared/widgets/app_notification.dart';
import 'group_chat_screen.dart';

final chatMessagesProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, salaId) {
  return ref.read(chatRepositoryProvider).messagesStream(salaId);
});

/// Ecrã de chat — Kinetic Dark.
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
    final otherId = widget.chatPartnerId ?? authState.user?.personalId ?? '';

    if (otherId.isEmpty || otherId == userId) {
      return _buildChatList(userId);
    }

    final salaId = ref.read(chatRepositoryProvider).getChatRoomId(userId, otherId);
    final messagesAsync = ref.watch(chatMessagesProvider(salaId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          AppStrings.chatTitle,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      AppStrings.noMessages,
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (_, index) {
                    final message = messages[index];
                    final isMine = message.remetenteId == userId;
                    return _MessageBubble(message: message, isMine: isMine);
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (_, __) => Center(
                child: Text(
                  'Erro ao carregar mensagens',
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
          _buildMessageInput(salaId, userId),
        ],
      ),
    );
  }

  Widget _buildMessageInput(String salaId, String userId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        border: const Border(top: BorderSide(color: AppColors.outline)),
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
                style: GoogleFonts.inter(color: AppColors.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: AppStrings.typeMessage,
                  hintStyle: GoogleFonts.inter(color: AppColors.outlineVariant),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () => _sendMessage(salaId, userId),
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList(String userId) {
    final groupsAsync = ref.watch(
      FutureProvider<List<GroupModel>>((ref) {
        if (userId.isEmpty) return [];
        return ref.read(groupRepositoryProvider).getMyGroups(userId);
      }),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Chats', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GRUPOS', style: GoogleFonts.barlowCondensed(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.06, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            groupsAsync.when(
              data: (groups) {
                if (groups.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.group_outlined, size: 20, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(width: 8),
                        Text('Nenhum grupo disponível', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }
                return Column(
                  children: groups.map((g) => _groupTile(g)).toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.chat_outlined, size: 36, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                    const SizedBox(height: 8),
                    Text('Chat com PT indisponivel', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text('Pede ao teu personal trainer para te associar.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupTile(GroupModel group) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupChatScreen(group: group))),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.group, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.nome, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.onSurface)),
                      const SizedBox(height: 2),
                      Text('${group.membros.length} membros',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
              ],
            ),
          ),
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
      // Notificar o destinatário (fire-and-forget, sem bloquear)
      _notifyChat(salaId, userId, texto);
    } catch (_) {
      if (mounted) {
        showAppNotification(context, AppStrings.messageSendError, type: NotificationType.error);
      }
    }
  }

  /// Envia notificação push ao destinatário via Cloud Function (best-effort).
  void _notifyChat(String salaId, String remetenteId, String texto) {
    FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('sendChatNotification')
        .call({
      'salaId': salaId,
      'remetenteId': remetenteId,
      'texto': texto,
    }).catchError((_) {}); // silencioso — a Cloud Function trata o envio
  }
}

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
          color: isMine ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMine ? const Radius.circular(12) : const Radius.circular(2),
            bottomRight: isMine ? const Radius.circular(2) : const Radius.circular(12),
          ),
          border: Border.all(
            color: isMine
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.outline,
          ),
        ),
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.texto,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
