import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
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
import '../../../../shared/widgets/app_design_system.dart';

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
        leadingWidth: 56,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.24),
                ),
              ),
              child: const Icon(
                Icons.group_outlined,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.group.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: AppSurface(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 300;
                  Widget copy({required bool bounded}) => Row(
                    children: [
                      Icon(
                        Icons.forum_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      if (bounded)
                        Expanded(
                          child: Text(
                            'Partilha horários e mantém o grupo alinhado.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.onSurface,
                              height: 1.35,
                            ),
                          ),
                        )
                      else
                        Flexible(
                          child: Text(
                            'Partilha horários e mantém o grupo alinhado.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.onSurface,
                              height: 1.35,
                            ),
                          ),
                        ),
                    ],
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: constraints.maxWidth,
                          child: copy(bounded: true),
                        ),
                        const SizedBox(height: 10),
                        AppStatusPill(
                          label: '${widget.group.membros.length}',
                          icon: Icons.people_outline,
                          color: AppColors.primary,
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: copy(bounded: false)),
                      const SizedBox(width: 10),
                      AppStatusPill(
                        label: '${widget.group.membros.length}',
                        icon: Icons.people_outline,
                        color: AppColors.primary,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
      itemCount: messages.length,
      itemBuilder: (_, i) =>
          _messageBubble(messages[i], i > 0 ? messages[i - 1] : null),
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

  Widget _messageBubble(MessageModel msg, MessageModel? previous) {
    final isMine = msg.remetenteId == _userId;
    final showName =
        !isMine &&
        (previous == null || previous.remetenteId != msg.remetenteId);
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
                    border: Border.all(
                      color: isMine
                          ? AppColors.primaryFixed.withValues(alpha: 0.18)
                          : AppColors.outline.withValues(alpha: 0.65),
                    ),
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
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border(
          top: BorderSide(color: AppColors.outline.withValues(alpha: 0.5)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.surfaceLowest.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
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
                    horizontal: 18,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(
                      color: AppColors.outline.withValues(alpha: 0.35),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(
                      color: AppColors.outline.withValues(alpha: 0.35),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.55),
                      width: 1.4,
                    ),
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.24),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
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
