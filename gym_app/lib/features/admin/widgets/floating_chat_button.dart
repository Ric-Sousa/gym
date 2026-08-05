import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/config/admin_theme.dart';
import '../../../core/services/audio_recording_model.dart';
import '../../../core/services/sound_service.dart';
import '../../../shared/utils/new_message_detector.dart';
import '../../../data/models/message_model.dart';
import '../../../data/models/user_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/providers/global_providers.dart';
import '../../../shared/providers/chat_notification_providers.dart';
import '../../aluno/chat/screens/chat_screen.dart'; // for chatMessagesProvider
import '../../../shared/widgets/audio_message_player.dart';
import '../../../shared/widgets/audio_record_button.dart';
import '../../../shared/utils/audio_chat_message.dart';
import 'admin_messages_view.dart';

// ─── Color constants ──────────────────────────────────────────────

const _unreadPink = Color(0xFFFF6B6B);
const _badgeBlack = Color(0xFF1A1A1A);

/// Provider that computes unread conversation count.
final adminUnreadCountProvider = Provider<int>((ref) {
  final conversationsAsync = ref.watch(adminConversationsProvider);
  return conversationsAsync.whenOrNull(
        data: (conversations) {
          // O estado de leitura é por mensagem recebida. Não usar
          // lastMessage.lida: a última mensagem pode ter sido enviada pelo
          // próprio admin e continuar com lida=false.
          // Soma mensagens, não conversas: se a mesma conversa passar de
          // 1 para 2 mensagens novas, o listener também deve detetar aumento.
          return conversations.fold<int>(
            0,
            (total, conversation) => total + conversation.unreadCount,
          );
        },
      ) ??
      0;
});

/// Tracks whether the admin chat modal is currently open.
final isChatModalOpenProvider = StateProvider<bool>((ref) => false);

// ─── Floating Chat Button ─────────────────────────────────────────

class FloatingChatButton extends ConsumerWidget {
  /// Called when admin taps "Ver perfil" on a student's name.
  final void Function(UserModel aluno)? onViewProfile;

  const FloatingChatButton({super.key, this.onViewProfile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(
      adminUnreadCountProvider,
    ); // O som observa eventos de mensagem diretamente, não o contador visual.
    // Assim alterações de lida/readAt nunca são confundidas com mensagens.
    void playIncomingSound() {
      final soundEnabled = ref.read(authProvider).user?.soundEnabled ?? true;
      if (!ref.read(isChatModalOpenProvider) &&
          !ref.read(isAdminInChatProvider) &&
          soundEnabled) {
        SoundService().playNotificationChime();
      }
    }

    ref.listen<AsyncValue<StableChatNotification>>(
      stableAdminChatNotificationProvider,
      (_, event) => event.whenData((_) => playIncomingSound()),
    );
    ref.listen<AsyncValue<StableChatNotification>>(
      stableAdminGroupNotificationProvider,
      (_, event) => event.whenData((_) => playIncomingSound()),
    );

    return Positioned(
      bottom: 24,
      right: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Unread badge chip above the button — black, minimalist
          if (unreadCount > 0)
            GestureDetector(
              onTap: () => _openChatModal(context, ref),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _badgeBlack,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  '$unreadCount ${unreadCount == 1 ? 'nova mensagem' : 'novas mensagens'}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          // Main floating button
          Material(
            elevation: 8,
            shadowColor: AdminThemeColors.of(
              context,
            ).lime.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(30),
            child: InkWell(
              onTap: () => _openChatModal(context, ref),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AdminThemeColors.of(context).lime,
                      AdminThemeColors.of(context).lime.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AdminThemeColors.of(
                        context,
                      ).lime.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.chat_bubble_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    // Badge count on button — black
                    if (unreadCount > 0)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _badgeBlack,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openChatModal(BuildContext context, WidgetRef ref) {
    ref.read(isChatModalOpenProvider.notifier).state = true;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (dialogContext) {
        return Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: 100,
              right: isMobile ? 8 : 24,
              left: isMobile ? 8 : 0,
            ),
            child: _ChatPopover(
              isMobile: isMobile,
              screenWidth: screenWidth,
              screenHeight: screenHeight,
              onViewProfile: onViewProfile,
              onClose: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        );
      },
    ).then((_) {
      ref.read(isChatModalOpenProvider.notifier).state = false;
    });
  }
}

// ─── Chat Popover (List ↔ Chat) ───────────────────────────────────

class _ChatPopover extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  final bool isMobile;
  final double screenWidth;
  final double screenHeight;
  final void Function(UserModel)? onViewProfile;

  const _ChatPopover({
    required this.onClose,
    required this.isMobile,
    required this.screenWidth,
    required this.screenHeight,
    this.onViewProfile,
  });

  @override
  ConsumerState<_ChatPopover> createState() => _ChatPopoverState();
}

class _ChatPopoverState extends ConsumerState<_ChatPopover> {
  ConversationPreview? _selectedConversation;

  /// Atualiza apenas o cursor local antes da transição para o detalhe.
  /// A única escrita no Firestore é feita pelo detalhe, depois de receber a
  /// fotografia efetivamente exibida das mensagens.
  void _setOptimisticReadCursor(ConversationPreview conversation) {
    final lastMessage = conversation.lastMessage;
    if (lastMessage == null) return;

    final roomId = conversation.roomId;
    final current = ref.read(adminConversationReadAtProvider);
    final previous = current[roomId];
    if (previous == null || lastMessage.timestamp.isAfter(previous)) {
      ref.read(adminConversationReadAtProvider.notifier).state = {
        ...current,
        roomId: lastMessage.timestamp,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: widget.isMobile ? widget.screenWidth - 16 : 400,
        height: 560,
        constraints: BoxConstraints(maxHeight: widget.screenHeight * 0.7),
        decoration: BoxDecoration(
          color: AdminThemeColors.of(context).surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AdminThemeColors.of(context).border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 36,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _selectedConversation == null
              ? _ConversationListView(
                  key: const ValueKey('conversation_list'),
                  onClose: widget.onClose,
                  onSelectConversation: (conv) {
                    // A abertura da conversa já conta como leitura. O cursor
                    // otimista evita que snapshots antigos repintem o badge.
                    setState(
                      () =>
                          _selectedConversation = conv.copyWith(unreadCount: 0),
                    );
                    _setOptimisticReadCursor(conv);
                  },
                )
              : _ChatDetailView(
                  key: ValueKey('chat_detail_${_selectedConversation!.roomId}'),
                  conversation: _selectedConversation!,
                  onViewProfile: widget.onViewProfile,
                  onBack: () => setState(() => _selectedConversation = null),
                ),
        ),
      ),
    );
  }
}

// ─── Conversation List View ───────────────────────────────────────

class _ConversationListView extends ConsumerWidget {
  final VoidCallback onClose;
  final void Function(ConversationPreview) onSelectConversation;

  const _ConversationListView({
    super.key,
    required this.onClose,
    required this.onSelectConversation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(adminConversationsProvider);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AdminThemeColors.of(context).border),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AdminThemeColors.of(context).limeDim,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.chat_bubble_rounded,
                  color: AdminThemeColors.of(context).lime,
                  size: 17,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'MENSAGENS',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AdminThemeColors.of(context).text,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: Icon(
                  Icons.close,
                  size: 20,
                  color: AdminThemeColors.of(context).muted,
                ),
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: conversationsAsync.when(
            data: (conversations) {
              if (conversations.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_outlined,
                        size: 44,
                        color: AdminThemeColors.of(context).border,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Nenhuma conversa',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AdminThemeColors.of(context).muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'As mensagens dos alunos\naparecerão aqui',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AdminThemeColors.of(context).muted,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                itemCount: conversations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final conv = conversations[index];
                  return _ConversationListTile(
                    preview: conv,
                    onTap: () => onSelectConversation(conv),
                  );
                },
              );
            },
            loading: () => Center(
              child: CircularProgressIndicator(
                color: AdminThemeColors.of(context).lime,
              ),
            ),
            error: (_, __) => Center(
              child: Text(
                'Erro ao carregar',
                style: GoogleFonts.inter(
                  color: AdminThemeColors.of(context).muted,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Conversation List Tile ───────────────────────────────────────

class _ConversationListTile extends StatelessWidget {
  final ConversationPreview preview;
  final VoidCallback onTap;

  const _ConversationListTile({required this.preview, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final aluno = preview.aluno;
    final lastMsg = preview.lastMessage;
    final hasUnread = preview.unreadCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminThemeColors.of(context).border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar with pink dot when unread
              Stack(
                children: [
                  GestureDetector(
                    onTap: () => _showPhotoZoom(context, aluno),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: AdminThemeColors.of(context).surface2,
                      backgroundImage: aluno.fotoPerfil != null
                          ? NetworkImage(aluno.fotoPerfil!)
                          : null,
                      child: aluno.fotoPerfil == null
                          ? Text(
                              aluno.nome.isNotEmpty
                                  ? aluno.nome[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.barlowCondensed(
                                color: AdminThemeColors.of(context).lime,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            )
                          : null,
                    ),
                  ),
                  if (hasUnread)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _unreadPink,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AdminThemeColors.of(context).bg,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            aluno.nome,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: AdminThemeColors.of(context).text,
                            ),
                          ),
                        ),
                        if (lastMsg != null)
                          Text(
                            _formatRelativeTime(lastMsg.timestamp),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AdminThemeColors.of(context).muted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasUnread
                          ? 'Enviou ${preview.unreadCount == 1 ? 'uma mensagem' : '${preview.unreadCount} mensagens'}'
                          : (lastMsg == null
                                ? 'Inicia a conversa'
                                : (lastMsg.isAudio
                                      ? 'Mensagem de áudio'
                                      : lastMsg.texto)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: hasUnread
                            ? FontWeight.w500
                            : FontWeight.w400,
                        color: hasUnread
                            ? AdminThemeColors.of(context).text
                            : AdminThemeColors.of(context).muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhotoZoom(BuildContext context, UserModel aluno) {
    if (aluno.fotoPerfil == null) return;
    showDialog(
      context: context,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  aluno.fotoPerfil!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => CircleAvatar(
                    radius: 80,
                    backgroundColor: AdminThemeColors.of(context).surface2,
                    child: Text(
                      aluno.nome.isNotEmpty ? aluno.nome[0].toUpperCase() : '?',
                      style: GoogleFonts.barlowCondensed(
                        color: AdminThemeColors.of(context).lime,
                        fontWeight: FontWeight.w700,
                        fontSize: 50,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                aluno.nome,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return DateFormat('HH:mm').format(dt);
    if (diff.inDays < 7) return DateFormat('EEE', 'pt').format(dt);
    return DateFormat('dd/MM').format(dt);
  }
}

// ─── Chat Detail View (drill-down) ────────────────────────────────

class _ChatDetailView extends ConsumerStatefulWidget {
  final ConversationPreview conversation;
  final VoidCallback onBack;
  final void Function(UserModel)? onViewProfile;

  const _ChatDetailView({
    super.key,
    required this.conversation,
    required this.onBack,
    this.onViewProfile,
  });

  @override
  ConsumerState<_ChatDetailView> createState() => _ChatDetailViewState();
}

class _ChatDetailViewState extends ConsumerState<_ChatDetailView>
    with NewMessageDetector {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isMarkingAsRead = false;
  bool _didInitialScroll = false;
  DateTime? _lastVisibleMessageTimestamp;
  DateTime? _pendingReadAt;
  Timer? _readRetryTimer;
  int _readRetryCount = 0;

  @override
  void initState() {
    super.initState();
    // A leitura é iniciada pelo clique da conversa. Não escrever no Firestore
    // a partir do build, pois isso cria um ciclo de rebuilds/streams.
  }

  @override
  void dispose() {
    _readRetryTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleReadRetry(DateTime readAt) {
    if (!mounted || _readRetryCount >= 3) return;
    _readRetryCount++;
    _readRetryTimer?.cancel();
    _readRetryTimer = Timer(const Duration(milliseconds: 500), () {
      _readRetryTimer = null;
      if (mounted) _markAsRead(readAt);
    });
  }

  /// Marca como lidas as mensagens do aluno que já chegaram ao detalhe.
  /// É disparado pelo callback do stream, nunca durante o build síncrono.
  Future<void> _markAsRead(DateTime readAt) async {
    if (!mounted) return;
    if (_isMarkingAsRead) {
      // O stream pode receber mensagens durante o batch. Guarda apenas o
      // maior cursor para que nenhuma mensagem fique perdida na corrida.
      if (_pendingReadAt == null || readAt.isAfter(_pendingReadAt!)) {
        _pendingReadAt = readAt;
      }
      return;
    }

    _isMarkingAsRead = true;
    final adminId = ref.read(authProvider).user?.uid ?? '';
    if (adminId.isEmpty) {
      _isMarkingAsRead = false;
      return;
    }

    var failed = false;
    try {
      await markAdminConversationAsRead(
        roomId: widget.conversation.roomId,
        adminId: adminId,
        readAt: readAt,
      );
      _readRetryCount = 0;
    } catch (error) {
      failed = true;
      debugPrint('⚠️ Não foi possível marcar mensagens como lidas: $error');
      if (_pendingReadAt == null || readAt.isAfter(_pendingReadAt!)) {
        _pendingReadAt = readAt;
      }
    } finally {
      _isMarkingAsRead = false;
      final pendingReadAt = _pendingReadAt;
      _pendingReadAt = null;
      final shouldProcessPending =
          mounted && pendingReadAt != null && !pendingReadAt.isBefore(readAt);
      if (shouldProcessPending) {
        if (failed) {
          _scheduleReadRetry(pendingReadAt);
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _markAsRead(pendingReadAt);
          });
        }
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendAudio(RecordedAudio audio) async {
    final adminId = ref.read(authProvider).user?.uid ?? '';
    if (adminId.isEmpty) return;

    try {
      final message = await createUploadedAudioMessage(
        storage: ref.read(storageDataSourceProvider),
        senderId: adminId,
        chatId: widget.conversation.roomId,
        audio: audio,
      );
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(widget.conversation.roomId, message);
    } catch (error) {
      debugPrint('Erro ao enviar áudio do admin: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível enviar o áudio.')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();
    // NOTA: Nao chamamos FocusScope.of(context).unfocus() aqui porque
    // no Flutter Web causa o bug 'ViewInsets cannot be negative'
    // (window.dart:99 assertion) ao dispensar o teclado virtual.
    // O campo de texto e limpo e continua funcional.
    final authState = ref.read(authProvider);
    final adminId = authState.user?.uid ?? '';

    final msg = MessageModel(
      remetenteId: adminId,
      texto: text,
      timestamp: DateTime.now(),
    );

    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(widget.conversation.roomId, msg);
      _scrollToBottom();
    } catch (_) {
      // Silently ignore
    }
  }

  void _showPhotoZoom(BuildContext context, UserModel aluno) {
    if (aluno.fotoPerfil == null) return;
    showDialog(
      context: context,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  aluno.fotoPerfil!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => CircleAvatar(
                    radius: 80,
                    backgroundColor: AdminThemeColors.of(context).surface2,
                    child: Text(
                      aluno.nome.isNotEmpty ? aluno.nome[0].toUpperCase() : '?',
                      style: GoogleFonts.barlowCondensed(
                        color: AdminThemeColors.of(context).lime,
                        fontWeight: FontWeight.w700,
                        fontSize: 50,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                aluno.nome,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(
      chatMessagesProvider(widget.conversation.roomId),
    );
    final aluno = widget.conversation.aluno;

    return Column(
      children: [
        // Header with back button, photo zoom, and name dropdown
        Container(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
          decoration: BoxDecoration(
            color: AdminThemeColors.of(context).bg,
            border: Border(
              bottom: BorderSide(color: AdminThemeColors.of(context).border),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: AdminThemeColors.of(context).text,
                ),
                onPressed: widget.onBack,
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              // Photo with zoom
              GestureDetector(
                onTap: () => _showPhotoZoom(context, aluno),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AdminThemeColors.of(context).limeDim,
                  backgroundImage: aluno.fotoPerfil != null
                      ? NetworkImage(aluno.fotoPerfil!)
                      : null,
                  child: aluno.fotoPerfil == null
                      ? Text(
                          aluno.nome.isNotEmpty
                              ? aluno.nome[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.barlowCondensed(
                            color: AdminThemeColors.of(context).lime,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              // Name with dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTapDown: (details) =>
                          _showStudentDropdown(context, details.globalPosition),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              aluno.nome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AdminThemeColors.of(context).text,
                                decoration: TextDecoration.underline,
                                decorationStyle: TextDecorationStyle.dotted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 16,
                            color: AdminThemeColors.of(context).muted,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Aluno',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AdminThemeColors.of(context).muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Messages
        Expanded(
          child: Container(
            color: AdminThemeColors.of(context).surface,
            child: messagesAsync.when(
              data: (messages) {
                detectNewMessages(
                  messages,
                  ref.read(authProvider).user?.uid ?? '',
                  playSound: false,
                );
                if (messages.isNotEmpty) {
                  final visibleAt = messages.last.timestamp;
                  if (_lastVisibleMessageTimestamp == null ||
                      visibleAt.isAfter(_lastVisibleMessageTimestamp!)) {
                    _lastVisibleMessageTimestamp = visibleAt;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _markAsRead(visibleAt);
                    });
                  }
                }
                // Scroll to bottom on initial load + when near bottom
                final nearBottom =
                    !_scrollController.hasClients ||
                    _scrollController.position.pixels >=
                        _scrollController.position.maxScrollExtent - 100;
                if (!_didInitialScroll || nearBottom) {
                  _didInitialScroll = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(
                        _scrollController.position.maxScrollExtent,
                      );
                    }
                  });
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 40,
                          color: AdminThemeColors.of(context).border,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Nenhuma mensagem ainda',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AdminThemeColors.of(context).muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Envia a primeira mensagem!',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AdminThemeColors.of(context).muted,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final authState = ref.watch(authProvider);
                final myId = authState.user?.uid ?? '';

                // Build message items with date separators
                final items = <Widget>[];
                DateTime? lastDate;
                for (var i = 0; i < messages.length; i++) {
                  final msg = messages[i];
                  final msgDate = DateTime(
                    msg.timestamp.year,
                    msg.timestamp.month,
                    msg.timestamp.day,
                  );
                  if (lastDate == null || msgDate != lastDate) {
                    lastDate = msgDate;
                    items.add(_DateSeparatorAdmin(date: msgDate));
                  }
                  final isMine = msg.remetenteId == myId;
                  items.add(_ChatBubble(msg: msg, isMine: isMine));
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(14),
                  itemCount: items.length,
                  itemBuilder: (context, index) => items[index],
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: AdminThemeColors.of(context).lime,
                ),
              ),
              error: (_, __) => Center(
                child: Text(
                  'Erro ao carregar mensagens',
                  style: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).muted,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Message input
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: AdminThemeColors.of(context).bg,
            border: Border(
              top: BorderSide(color: AdminThemeColors.of(context).border),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: TextField(
                      controller: _msgController,
                      minLines: 1,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AdminThemeColors.of(context).text,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Escreve uma mensagem...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 13,
                          color: AdminThemeColors.of(context).muted,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: AdminThemeColors.of(context).surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: AdminThemeColors.of(
                              context,
                            ).lime.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                AudioRecordButton(
                  color: AdminThemeColors.of(context).surface,
                  iconColor: AdminThemeColors.of(context).lime,
                  onAudioReady: _sendAudio,
                ),
                const SizedBox(width: 4),
                Material(
                  color: AdminThemeColors.of(context).lime,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: _sendMessage,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.send_rounded,
                        color: AdminThemeColors.of(context).bg,
                        size: 19,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Shows a popup menu with "Ver perfil" option anchored at [position].
  void _showStudentDropdown(BuildContext context, Offset position) {
    final aluno = widget.conversation.aluno;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (entry.mounted) entry.remove();
        },
        child: Stack(
          children: [
            Positioned(
              left: position.dx - 120,
              top: position.dy + 4,
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(10),
                color: AdminThemeColors.of(context).surface,
                child: Container(
                  width: 160,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AdminThemeColors.of(context).border,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          entry.remove();
                          // Close the chat popover and call the callback
                          widget.onBack(); // back to list
                          widget.onViewProfile?.call(aluno);
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 16,
                                color: AdminThemeColors.of(context).text,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Ver perfil',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AdminThemeColors.of(context).text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    overlay.insert(entry);
  }
}

// ─── Date Separator (admin version) ───────────────────────────────

class _DateSeparatorAdmin extends StatelessWidget {
  final DateTime date;
  const _DateSeparatorAdmin({required this.date});

  String _format(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Ontem';
    if (diff < 7) return 'Há $diff dias';
    if (d.year == now.year) return DateFormat('d MMMM', 'pt').format(d);
    return DateFormat('d MMM yyyy', 'pt').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider(height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AdminThemeColors.of(context).surface2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _format(date),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AdminThemeColors.of(context).muted,
                ),
              ),
            ),
          ),
          const Expanded(child: Divider(height: 1)),
        ],
      ),
    );
  }
}

// ─── Chat Bubble ──────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final MessageModel msg;
  final bool isMine;

  const _ChatBubble({required this.msg, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final theme = AdminThemeColors.of(context);
    final time = DateFormat('HH:mm').format(msg.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMine ? theme.limeDim : theme.surface2,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
            border: Border.all(
              color: isMine ? theme.lime.withValues(alpha: 0.3) : theme.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (msg.isAudio)
                AudioMessagePlayer(
                  url: msg.audioUrl!,
                  isMine: isMine,
                  activeColor: theme.lime,
                  inactiveColor: theme.muted,
                  durationMs: msg.audioDurationMs,
                )
              else
                Text(
                  msg.texto,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: theme.text,
                    height: 1.35,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                time,
                style: GoogleFonts.inter(fontSize: 10, color: theme.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
