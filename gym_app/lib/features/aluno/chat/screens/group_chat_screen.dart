import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../data/models/group_model.dart';
import '../../../../data/models/message_model.dart';
import '../../../../shared/providers/global_providers.dart';
import '../../../../core/services/audio_recording_model.dart';
import '../../../../shared/widgets/app_notification.dart';
import '../../../../shared/widgets/audio_message_player.dart';
import '../../../../shared/widgets/audio_record_button.dart';
import '../../../../shared/utils/audio_chat_message.dart';
import '../../../../shared/utils/new_message_detector.dart';

/// Ecrã de chat de grupo — alunos trocam horários/blocos.
class GroupChatScreen extends ConsumerStatefulWidget {
  final GroupModel group;
  final bool trackChatPresence;
  final bool isAdminChat;

  const GroupChatScreen({
    super.key,
    required this.group,
    this.trackChatPresence = true,
    this.isAdminChat = false,
  });

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen>
    with NewMessageDetector {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  // Guardado localmente porque ref fica invalido no dispose
  StateController<bool>? _chatNotifier;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';
  StateProvider<bool> get _presenceProvider =>
      widget.isAdminChat ? isAdminInChatProvider : isAlunoInChatProvider;

  @override
  void initState() {
    super.initState();
    if (widget.trackChatPresence) {
      // Marca a presença antes da primeira build para impedir que a carga
      // inicial de mensagens seja interpretada como uma notificação nova.
      _chatNotifier = ref.read(_presenceProvider.notifier);
      Future.microtask(() {
        if (mounted) _chatNotifier?.state = true;
      });
    }
  }

  @override
  void dispose() {
    // Usa Future.microtask para adiar a modificacao do provider —
    // durante o dispose o widget tree esta a ser finalizado e o
    // Riverpod nao permite modificar providers nessa fase.
    final notifier = _chatNotifier;
    if (widget.trackChatPresence && notifier != null) {
      Future.microtask(() => notifier.state = false);
    }
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Usa provider estável (module-level) — nunca inline StreamProvider no build()!
    final messagesAsync = ref.watch(
      groupMessagesStreamProvider(widget.group.id),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.group.nome,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            Text(
              '${widget.group.membros.length} membros',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) => _buildMessageList(messages),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (_, __) => const Center(
                child: Text(
                  'Erro',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageList(List<MessageModel> messages) {
    detectNewMessages(messages, _userId, playSound: false);
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_outlined,
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhuma mensagem ainda',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Sê o primeiro a enviar!',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (_, i) => _messageBubble(
        messages[i],
        i < messages.length - 1 ? messages[i + 1] : null,
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _messageBubble(MessageModel msg, MessageModel? next) {
    final isMine = msg.remetenteId == _userId;
    final showName =
        !isMine && (next == null || next.remetenteId != msg.remetenteId);
    final timeStr = DateFormat('HH:mm').format(msg.timestamp);

    return Padding(
      padding: EdgeInsets.only(bottom: showName ? 12 : 2),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (showName)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 2),
              child: Text(
                msg.remetenteId == _userId
                    ? 'Tu'
                    : _getSenderName(msg.remetenteId),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: isMine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (isMine) ...[
                Text(
                  timeStr,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMine ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMine ? 16 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 16),
                    ),
                  ),
                  child: msg.isAudio
                      ? AudioMessagePlayer(
                          url: msg.audioUrl!,
                          isMine: isMine,
                          activeColor: isMine
                              ? Colors.white
                              : AppColors.primary,
                          inactiveColor: isMine
                              ? Colors.white70
                              : AppColors.textSecondary,
                          durationMs: msg.audioDurationMs,
                        )
                      : Text(
                          msg.texto,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: isMine ? Colors.white : AppColors.onSurface,
                          ),
                        ),
                ),
              ),
              if (!isMine) ...[
                const SizedBox(width: 6),
                Text(
                  timeStr,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _getSenderName(String uid) {
    if (uid == _userId) return 'Tu';
    return 'Aluno ${uid.hashCode.abs() % 100}'; // Placeholder amigavel
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textCtrl,
                style: GoogleFonts.inter(
                  color: AppColors.onSurface,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Mensagem...',
                  hintStyle: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            AudioRecordButton(
              color: AppColors.surfaceHigh,
              iconColor: AppColors.primary,
              onAudioReady: _sendAudio,
            ),
            const SizedBox(width: 4),
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 18),
                onPressed: _sending ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendAudio(RecordedAudio audio) async {
    setState(() => _sending = true);
    try {
      final message = await createUploadedAudioMessage(
        storage: ref.read(storageDataSourceProvider),
        senderId: _userId,
        chatId: widget.group.id,
        audio: audio,
      );
      await ref
          .read(groupRepositoryProvider)
          .sendMessage(widget.group.id, message.toMap());
      _notifyGroup();
    } catch (_) {
      if (mounted) {
        showAppNotification(
          context,
          'Não foi possível enviar o áudio.',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await ref.read(groupRepositoryProvider).sendMessage(widget.group.id, {
        'remetenteId': _userId,
        'texto': text,
        'timestamp': DateTime.now(),
        'lida': false,
      });
      _textCtrl.clear();
      // Notificar membros do grupo (fire-and-forget)
      _notifyGroup();
    } catch (_) {
      if (mounted)
        showAppNotification(
          context,
          'Erro ao enviar.',
          type: NotificationType.error,
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Envia notificação push aos membros do grupo (best-effort).
  void _notifyGroup() {
    // Fire-and-forget — não bloqueia o envio da mensagem
    Future(() async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        final authToken = await user.getIdToken(true);
        if (authToken == null || authToken.isEmpty) return;

        await FirebaseFunctions.instanceFor(
          region: 'europe-west1',
        ).httpsCallable('sendChatNotification').call({
          'salaId': widget.group.id,
          'remetenteId': _userId,
          'texto': '[${widget.group.nome}] Nova mensagem de grupo',
          'authToken': authToken,
        });
      } on FirebaseFunctionsException catch (e) {
        // Log apenas em debug — nao incomoda o utilizador
        debugPrint(
          '⚠️ Cloud Function sendChatNotification: ${e.code} — ${e.message}',
        );
      } catch (e) {
        debugPrint('⚠️ Cloud Function sendChatNotification erro: $e');
      }
    });
  }
}
