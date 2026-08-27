import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/student_theme.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../core/utils/storage_resource.dart';
import '../../../../data/models/message_model.dart';
import '../../../../data/models/group_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/providers/global_providers.dart';
import '../../../../shared/providers/admin_chat_unread_providers.dart';
import '../../../../shared/widgets/app_notification.dart';
import '../../../../shared/widgets/audio_message_player.dart';
import '../../../../shared/widgets/audio_record_button.dart';
import '../../../../shared/widgets/group_members_preview.dart';
import '../../../../shared/widgets/profile_photo_viewer.dart';
import '../../../../shared/widgets/app_design_system.dart';
import '../../../../core/services/audio_recording_model.dart';
import '../../../../shared/utils/audio_chat_message.dart';
import '../../../../shared/utils/chat_attachment.dart';
import '../../../../shared/utils/new_message_detector.dart';
import 'group_chat_screen.dart';

final personalProfileProvider = StreamProvider.family<UserModel?, String>((ref, uid) {
  if (uid.isEmpty) return Stream.value(null);
  return ref.read(userRepositoryProvider).userStream(uid).map<UserModel?>((user) => user);
});

final chatMessagesProvider = StreamProvider.family<List<MessageModel>, String>((
  ref,
  salaId,
) {
  if (salaId.isEmpty) return Stream.value(const <MessageModel>[]);
  return ref.read(chatRepositoryProvider).messagesStream(salaId);
});

/// Provider estável dos grupos do aluno. Não criar providers dentro de build:
/// cada rebuild recriava a consulta e podia entrar num ciclo de listeners.
final alunoGroupsProvider = StreamProvider.family<List<GroupModel>, String>((
  ref,
  userId,
) {
  if (userId.isEmpty) return Stream.value(const <GroupModel>[]);
  debugPrint('[groups] iniciar consulta: uid=$userId');
  return ref.read(groupRepositoryProvider).watchMyGroups(userId).handleError((
    error,
    stack,
  ) {
    debugPrint('[groups] erro na consulta para uid=$userId: $error');
  });
});

String _newMessagesLabel(int count) {
  if (count <= 0) return 'Sem mensagens novas';
  if (count == 1) return '1 mensagem nova';
  return '$count mensagens novas';
}

/// Ecrã de chat — Kinetic Dark.
class ChatScreen extends ConsumerStatefulWidget {
  final String? chatPartnerId;
  final String? chatPartnerName;
  final String? chatPartnerPhoto;

  /// The shell controls presence for its IndexedStack tab. Standalone routes
  /// (for example a direct PT chat) manage their own presence.
  final bool trackChatPresence;

  const ChatScreen({
    super.key,
    this.chatPartnerId,
    this.chatPartnerName,
    this.chatPartnerPhoto,
    this.trackChatPresence = true,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with NewMessageDetector {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _imagePicker = ImagePicker();
  bool _isFocused = false;
  bool _isRecording = false;
  bool _scrollCallbackScheduled = false;
  Timer? _typingDebounce;
  bool _typingSent = false;
  DateTime? _lastRequestedDirectReadAt;
  DateTime? _pendingDirectReadAt;
  bool _markingDirectAsRead = false;
  String? _fetchedPartnerPhoto;

  List<String>? _directParticipantIds(String userId) {
    final partnerId = widget.chatPartnerId;
    if (userId.isEmpty || partnerId == null || partnerId.isEmpty) return null;
    return [userId, partnerId];
  }

  // Guardado localmente porque ref fica invalido no dispose
  StateController<bool>? _chatNotifier;

  @override
  void initState() {
    super.initState();
    if (widget.trackChatPresence) {
      // Marca a presença antes da primeira build. Assim o listener de unread
      // nunca toca som durante a abertura da conversa.
      _chatNotifier = ref.read(isAlunoInChatProvider.notifier);
      Future.microtask(() {
        if (mounted) _chatNotifier?.state = true;
      });
    }
    _focusNode.addListener(() {
      if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
    });
    _textController.addListener(_onTyping);
    _fetchPartnerPhotoIfNeeded();
  }

  /// If no photo was passed, fetch the partner's UserModel to get it.
  Future<void> _fetchPartnerPhotoIfNeeded() async {
    if (widget.chatPartnerPhoto != null) return;
    final partnerId = widget.chatPartnerId;
    if (partnerId == null || partnerId.isEmpty) return;

    try {
      final user = await ref.read(userRepositoryProvider).getUser(partnerId);
      if (mounted) setState(() => _fetchedPartnerPhoto = user.fotoPerfil);
    } catch (_) {
      // Silencioso — mostra iniciais como fallback.
    }
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se o chatPartnerId mudou (ex: admin trocou de aluno), reseta o estado
    if (widget.chatPartnerId != oldWidget.chatPartnerId) {
      _typingDebounce?.cancel();
      // Limpa typing status da sala antiga antes de mudar
      if (_currentSalaId != null && _currentUserId != null) {
        ref
            .read(chatRepositoryProvider)
            .setTypingStatus(
              _currentSalaId!,
              _currentUserId!,
              false,
              participantIds: _directParticipantIds(_currentUserId!),
            );
      }
      _textController.clear();
      _currentSalaId = null;
      _currentUserId = null;
      _typingSent = false;
      _lastRequestedDirectReadAt = null;
      _pendingDirectReadAt = null;
      _fetchedPartnerPhoto = null;
      resetDetector();
      _fetchPartnerPhotoIfNeeded();
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
    _typingDebounce?.cancel();
    // Previne novas escritas de typing no Firestore — nao chamamos
    // _clearTypingStatus() aqui porque e assincrono e o ref/widget
    // ja nao sao validos apos o dispose.
    _typingSent = false;
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Dispara o indicador de digitacao com debounce de 2.5 segundos.
  void _onTyping() {
    _typingDebounce?.cancel();
    final salaId = _currentSalaId;
    final userId = _currentUserId;
    if (salaId == null || userId == null) return;

    final texto = _textController.text;
    if (texto.isEmpty) {
      _clearTypingStatus();
      return;
    }

    // Só escreve no Firestore uma vez ate ser limpo
    if (!_typingSent) {
      _typingSent = true;
      ref
          .read(chatRepositoryProvider)
          .setTypingStatus(
            salaId,
            userId,
            true,
            participantIds: _directParticipantIds(userId),
          );
    }

    // Após 2.5s sem teclar, limpa o indicador
    _typingDebounce = Timer(const Duration(milliseconds: 2500), () {
      _clearTypingStatus();
    });
  }

  String? _currentSalaId;
  String? _currentUserId;

  Future<void> _clearTypingStatus() async {
    _typingSent = false;
    if (_currentSalaId != null && _currentUserId != null) {
      try {
        await ref
            .read(chatRepositoryProvider)
            .setTypingStatus(
              _currentSalaId!,
              _currentUserId!,
              false,
              participantIds: _directParticipantIds(_currentUserId!),
            );
      } catch (_) {}
    }
  }

  void _scheduleMarkDirectAsRead(
    List<MessageModel> messages,
    String salaId,
    String userId,
  ) {
    if (messages.isEmpty || userId.isEmpty) return;
    final latest = messages
        .map((message) => message.timestamp)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final previous = _lastRequestedDirectReadAt;
    if (previous != null && !latest.isAfter(previous)) return;

    _lastRequestedDirectReadAt = latest;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _markDirectAsRead(salaId, userId, latest);
    });
  }

  Future<void> _markDirectAsRead(
    String salaId,
    String userId,
    DateTime readAt,
  ) async {
    if (!mounted) return;
    if (_markingDirectAsRead) {
      if (_pendingDirectReadAt == null ||
          readAt.isAfter(_pendingDirectReadAt!)) {
        _pendingDirectReadAt = readAt;
      }
      return;
    }
    _markingDirectAsRead = true;
    final isAdmin = ref.read(authProvider).user?.isAdmin ?? false;
    if (isAdmin) {
      final current = ref.read(adminConversationReadAtProvider);
      final previous = current[salaId];
      if (previous == null || readAt.isAfter(previous)) {
        ref.read(adminConversationReadAtProvider.notifier).state = {
          ...current,
          salaId: readAt,
        };
      }
    }
    try {
      await ref
          .read(chatRepositoryProvider)
          .markMessagesAsRead(
            salaId,
            userId,
            readAt,
            persistConversationCursor: isAdmin,
          );
    } catch (_) {
      if (_lastRequestedDirectReadAt == readAt) {
        _lastRequestedDirectReadAt = null;
      }
    } finally {
      _markingDirectAsRead = false;
      final pending = _pendingDirectReadAt;
      _pendingDirectReadAt = null;
      if (mounted && pending != null && !pending.isBefore(readAt)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _markDirectAsRead(salaId, userId, pending);
        });
      }
    }
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

  void _scheduleScrollToBottom() {
    if (_scrollCallbackScheduled) return;
    _scrollCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollCallbackScheduled = false;
      if (mounted) _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userId = authState.user?.uid ?? '';
    // A aba do aluno começa sempre na lista de conversas. Só uma instância
    // criada com chatPartnerId representa uma conversa aberta.
    final isDirectConversation =
        widget.chatPartnerId != null && widget.chatPartnerId!.isNotEmpty;
    if (!isDirectConversation) {
      return _buildChatList(userId);
    }

    final otherId = widget.chatPartnerId!;
    if (otherId == userId) {
      return _buildChatList(userId);
    }

    final salaId = ref
        .read(chatRepositoryProvider)
        .getChatRoomId(userId, otherId);
    _currentSalaId = salaId;
    _currentUserId = userId;
    final messagesAsync = ref.watch(chatMessagesProvider(salaId));
    final typingAsync = ref.watch(
      typingStreamProvider((salaId: salaId, userId: userId)),
    );
    final userName = authState.user?.nome ?? '';
    // A conversa principal do aluno é com a Sara Gameiro. No Admin, o nome
    // real do aluno continua a chegar por chatPartnerName.
    final adminName = 'Sara Gameiro';
    final isStudent = !(authState.user?.isAdmin ?? false);

    // Nome e iniciais da outra pessoa (admin ve aluno, aluno ve admin)
    final partnerName = widget.chatPartnerName;
    final partnerPhoto = widget.chatPartnerPhoto ?? _fetchedPartnerPhoto;
    final otherName = partnerName != null && partnerName.isNotEmpty
        ? partnerName
        : adminName;
    final otherInitials = partnerName != null && partnerName.isNotEmpty
        ? partnerName[0].toUpperCase()
        : 'SG';
    final otherSubtitle = isStudent ? 'Personal Trainer' : 'Aluno';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        // Botão explícito: esta conversa é uma rota independente no mobile.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar às conversas',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Row(
          children: [
            GestureDetector(
              onTap: partnerPhoto == null || partnerPhoto.trim().isEmpty
                  ? null
                  : () => showProfilePhotoViewer(
                      context: context,
                      photoUrl: partnerPhoto,
                      name: otherName,
                      accentColor: StudentThemeColors.of(context).primary,
                    ),
              child: StorageAvatar(
                resource: partnerPhoto,
                radius: 16,
                backgroundColor: StudentThemeColors.of(
                  context,
                ).primary.withValues(alpha: 0.15),
                fallback: Text(
                  otherInitials,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: StudentThemeColors.of(context).primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.onSurface,
                    ),
                  ),
                  Text(
                    otherSubtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: StudentThemeColors.of(context).primary,
                      fontWeight: FontWeight.w500,
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
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                detectNewMessages(messages, userId, playSound: false);
                _scheduleMarkDirectAsRead(messages, salaId, userId);
                _scheduleScrollToBottom();
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      AppStrings.noMessages,
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    ),
                  );
                }
                // Combina mensagens com separadores de data
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
                    items.add(_DateSeparator(date: msgDate));
                  }
                  final isMine = msg.remetenteId == userId;
                  final showName =
                      i == 0 || messages[i - 1].remetenteId != msg.remetenteId;
                  items.add(
                    _MessageBubble(
                      message: msg,
                      isMine: isMine,
                      showName: showName,
                      senderName: isMine ? 'Tu' : otherName,
                      senderInitials: isMine
                          ? (userName.isNotEmpty
                                ? userName[0].toUpperCase()
                                : '?')
                          : otherInitials,
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                  itemCount: items.length,
                  itemBuilder: (_, index) => ScrollReveal(
                    key: ValueKey('direct-message-$index'),
                    beginOffset: const Offset(0, 0.03),
                    child: items[index],
                  ),
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: StudentThemeColors.of(context).primary,
                ),
              ),
              error: (_, __) => Center(
                child: Text(
                  'Erro ao carregar mensagens',
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
          // Indicador de digitacao
          StreamBuilder<String?>(
            stream: typingAsync,
            builder: (_, snap) {
              final isTyping = snap.hasData && snap.data != null;
              return AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: isTyping
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: StudentThemeColors.of(
                                context,
                              ).primary.withValues(alpha: 0.15),
                              child: Text(
                                otherInitials,
                                style: GoogleFonts.montserrat(
                                  fontSize: 7,
                                  fontWeight: FontWeight.w700,
                                  color: StudentThemeColors.of(context).primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$otherName está a escrever',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: StudentThemeColors.of(context).primary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _TypingDots(),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              );
            },
          ),
          _buildMessageInput(salaId, userId),
        ],
      ),
    );
  }

  Widget _buildMessageInput(String salaId, String userId) {
    final messageControls = Row(
      key: const ValueKey('message_composer'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          onPressed: () => _sendAttachment(salaId, userId),
          icon: const Icon(Icons.attach_file_rounded),
          color: AppColors.textSecondary,
          tooltip: 'Enviar imagem',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            minimumSize: const Size(44, 44),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _isFocused ? AppColors.surfaceHighest : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isFocused
                    ? StudentThemeColors.of(
                        context,
                      ).primary.withValues(alpha: 0.4)
                    : AppColors.outline.withValues(alpha: 0.3),
              ),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: StudentThemeColors.of(
                          context,
                        ).primary.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.inter(
                  color: AppColors.onSurface,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: AppStrings.typeMessage,
                  hintStyle: GoogleFonts.inter(
                    color: AppColors.outlineVariant,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  filled: true,
                  fillColor: _isFocused
                      ? AppColors.surfaceHighest
                      : AppColors.surface,
                  hoverColor: AppColors.surfaceHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _sendMessage(salaId, userId),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: StudentThemeColors.of(context).primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: StudentThemeColors.of(
                      context,
                    ).primary.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border(
          top: BorderSide(color: AppColors.outline.withValues(alpha: 0.5)),
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: AppColors.surfaceLowest.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              height: 54,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 54),
                      child: IgnorePointer(
                        ignoring: _isRecording,
                        child: AnimatedOpacity(
                          opacity: _isRecording ? 0 : 1,
                          duration: const Duration(milliseconds: 160),
                          child: messageControls,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: _isRecording
                        ? Alignment.center
                        : Alignment.centerRight,
                    child: SizedBox(
                      width: _isRecording ? constraints.maxWidth : 50,
                      height: 54,
                      child: AudioRecordButton(
                        fullWidth: true,
                        color: AppColors.surface,
                        iconColor: StudentThemeColors.of(context).primary,
                        onRecordingChanged: (recording) {
                          if (mounted) setState(() => _isRecording = recording);
                        },
                        onAudioReady: (audio) =>
                            _sendAudio(salaId, userId, audio),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildChatList(String userId) {
    final authState = ref.watch(authProvider);
    final personalId = authState.user?.personalId;
    final hasPT = personalId != null && personalId.isNotEmpty;

    final groupsAsync = ref.watch(alunoGroupsProvider(userId));
    final groupCount = groupsAsync.asData?.value.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conversas',
              style: GoogleFonts.montserrat(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 22),
            // ── PT Chat ──
            if (hasPT) ...[
              Text(
                'CONVERSA PRINCIPAL',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.06,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              ScrollReveal(child: _buildPTChatTile(personalId)),
              const SizedBox(height: 24),
            ],
            // ── Grupos ──
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'GRUPOS',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.06,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (groupCount > 0)
                  Text(
                    '$groupCount grupo(s)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            groupsAsync.when(
              data: (groups) {
                if (groups.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.outline),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.surfaceLowest.withValues(
                            alpha: 0.28,
                          ),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.group_outlined,
                          size: 32,
                          color: AppColors.textSecondary.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nenhum grupo disponível',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'O teu PT pode criar grupos para\ntroca de horários entre alunos.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: groups
                      .map(
                        (g) => ScrollReveal(
                          key: ValueKey('student-group-${g.id}'),
                          child: _groupTile(g),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(
                    color: StudentThemeColors.of(context).primary,
                  ),
                ),
              ),
              error: (error, __) {
                debugPrint('Erro ao carregar grupos do aluno: $error');
                return _buildEmptyGroupsState(
                  message: 'Não foi possível carregar os grupos.',
                  onRetry: () => ref.invalidate(alunoGroupsProvider(userId)),
                );
              },
            ),
            if (!hasPT) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AppColors.info.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ainda não tens um Personal Trainer associado.\nPede ao teu PT para te vincular.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyGroupsState({
    required String message,
    VoidCallback? onRetry,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          Icon(
            Icons.group_outlined,
            size: 32,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            onRetry == null
                ? 'O teu PT pode criar grupos para troca de horários.'
                : 'Verifica a ligação e tenta novamente.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Tentar novamente'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPTChatTile(String personalId) {
    final personalPhoto = ref.watch(personalProfileProvider(personalId)).asData?.value?.fotoPerfil;
    final userId = ref.watch(authProvider).user?.uid ?? '';
    final roomId = ref
        .read(chatRepositoryProvider)
        .getChatRoomId(userId, personalId);
    final messagesAsync = ref.watch(chatMessagesProvider(roomId));
    final unreadCount = countUnreadMessages(
      messagesAsync.asData?.value ?? const <MessageModel>[],
      userId,
    );
    final hasUnread = unreadCount > 0;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          // Navega para o chat 1:1 com o PT
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatPartnerId: personalId,
                chatPartnerName: 'Sara Gameiro',
                chatPartnerPhoto: personalPhoto,
                // A aba Chat do shell já controla a presença. Não a desligar
                // ao fechar esta rota enquanto a aba continua visível.
                trackChatPresence: false,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: StudentThemeColors.of(
                context,
              ).primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          StudentThemeColors.of(context).primary,
                          StudentThemeColors.of(context).primaryDim,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: StorageAvatar(
                      resource: personalPhoto,
                      radius: 22,
                      backgroundColor: Colors.transparent,
                      fallback: const Text(
                        'SG',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  if (hasUnread)
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: StudentThemeColors.of(context).primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sara Gameiro',
                      style: GoogleFonts.inter(
                        fontWeight: hasUnread
                            ? FontWeight.w800
                            : FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasUnread
                          ? _newMessagesLabel(unreadCount)
                          : 'Sem mensagens novas',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: hasUnread
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: StudentThemeColors.of(
                          context,
                        ).primary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: StudentThemeColors.of(context).primary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupTile(GroupModel group) {
    return Consumer(
      builder: (context, ref, child) {
        final userId = ref.watch(authProvider).user?.uid ?? '';
        final messagesAsync = ref.watch(groupMessagesStreamProvider(group.id));
        final unreadCount = countUnreadMessages(
          messagesAsync.asData?.value ?? const <MessageModel>[],
          userId,
          readAt: group.lastReadAtByUser[userId],
        );
        final hasUnread = unreadCount > 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      GroupChatScreen(group: group, trackChatPresence: false),
                ),
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: hasUnread
                        ? StudentThemeColors.of(
                            context,
                          ).primary.withValues(alpha: 0.45)
                        : AppColors.outline,
                  ),
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: StudentThemeColors.of(
                              context,
                            ).primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.group,
                            color: StudentThemeColors.of(context).primary,
                            size: 22,
                          ),
                        ),
                        if (hasUnread)
                          Positioned(
                            top: -1,
                            right: -1,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: StudentThemeColors.of(context).primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.surface,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.nome,
                            style: GoogleFonts.inter(
                              fontWeight: hasUnread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          GroupMembersPreview(
                            group: group,
                            textColor: AppColors.onSurface,
                            mutedColor: AppColors.textSecondary,
                            accentColor: StudentThemeColors.of(context).primary,
                            compact: true,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _newMessagesLabel(unreadCount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: hasUnread
                                  ? StudentThemeColors.of(context).primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (group.lastTimestamp != null)
                      Text(
                        _formatGroupTime(group.lastTimestamp!),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                        ),
                      ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatGroupTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return DateFormat('HH:mm').format(dt);
    if (diff.inDays < 7) return DateFormat('EEE', 'pt').format(dt);
    return DateFormat('dd/MM').format(dt);
  }

  Future<void> _sendAttachment(String salaId, String userId) async {
    final participants = _directParticipantIds(userId);
    if (participants == null) return;
    MessageModel? uploadedMessage;
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1800,
      );
      if (file == null) return;
      await ref
          .read(chatRepositoryProvider)
          .ensureChatRoom(salaId, participants);
      final message = await createUploadedImageMessage(
        storage: ref.read(storageDataSourceProvider),
        senderId: userId,
        chatId: salaId,
        file: file,
      );
      uploadedMessage = message;
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(salaId, message, participantIds: participants);
      // A trigger notifica anexos após a mensagem ser persistida.
    } catch (error) {
      await cleanupUploadedMessage(
        ref.read(storageDataSourceProvider),
        uploadedMessage,
      );
      debugPrint('Erro ao enviar anexo: $error');
      if (mounted) {
        showAppNotification(
          context,
          'Não foi possível enviar o anexo.',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _sendAudio(
    String salaId,
    String userId,
    RecordedAudio audio,
  ) async {
    final participants = _directParticipantIds(userId);
    if (participants == null) return;
    MessageModel? uploadedMessage;
    try {
      await ref
          .read(chatRepositoryProvider)
          .ensureChatRoom(salaId, participants);
      final message = await createUploadedAudioMessage(
        storage: ref.read(storageDataSourceProvider),
        senderId: userId,
        chatId: salaId,
        audio: audio,
      );
      uploadedMessage = message;
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(salaId, message, participantIds: participants);
      // A trigger notifica áudio após a mensagem ser persistida.
    } catch (error) {
      await cleanupUploadedMessage(
        ref.read(storageDataSourceProvider),
        uploadedMessage,
      );
      debugPrint('Erro ao enviar áudio: $error');
      if (mounted) {
        showAppNotification(
          context,
          'Não foi possível enviar o áudio.',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _sendMessage(String salaId, String userId) async {
    final participants = _directParticipantIds(userId);
    if (participants == null) return;
    final texto = _textController.text.trim();
    if (texto.isEmpty) return;

    final message = MessageModel(
      remetenteId: userId,
      texto: texto,
      timestamp: DateTime.now(),
    );

    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(salaId, message, participantIds: participants);
      _typingDebounce?.cancel();
      _clearTypingStatus();
      _textController.clear();
      _scrollToBottom();
      // A trigger notifyChatMessageCreated notifica a mensagem efetivamente persistida.
    } catch (e) {
      debugPrint('❌ Erro ao enviar mensagem: $e');
      if (mounted) {
        showAppNotification(
          context,
          AppStrings.messageSendError,
          type: NotificationType.error,
        );
      }
    }
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  final bool showName;
  final String senderName;
  final String senderInitials;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.showName,
    required this.senderName,
    required this.senderInitials,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(message.timestamp);
    final avatar = CircleAvatar(
      radius: 14,
      backgroundColor: isMine
          ? StudentThemeColors.of(context).primary.withValues(alpha: 0.2)
          : AppColors.secondary.withValues(alpha: 0.2),
      child: Text(
        senderInitials,
        style: GoogleFonts.montserrat(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isMine
              ? StudentThemeColors.of(context).primary
              : AppColors.secondary,
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 4, top: showName ? 10 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMine) ...[avatar, const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (showName)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      senderName,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.65,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMine
                        ? StudentThemeColors.of(
                            context,
                          ).primary.withValues(alpha: 0.15)
                        : AppColors.surfaceHigh,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isMine
                          ? const Radius.circular(16)
                          : const Radius.circular(2),
                      bottomRight: isMine
                          ? const Radius.circular(2)
                          : const Radius.circular(16),
                    ),
                    border: Border.all(
                      color: isMine
                          ? StudentThemeColors.of(
                              context,
                            ).primary.withValues(alpha: 0.25)
                          : AppColors.outline.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: isMine
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (message.isAudio)
                        AudioMessagePlayer(
                          url: message.audioUrl!,
                          isMine: isMine,
                          activeColor: isMine
                              ? StudentThemeColors.of(context).primary
                              : AppColors.secondary,
                          inactiveColor: AppColors.textSecondary,
                          durationMs: message.audioDurationMs,
                        )
                      else if (message.isAttachment)
                        Builder(
                          builder: (context) {
                            final imageWidth =
                                (MediaQuery.sizeOf(context).width * 0.52)
                                    .clamp(140.0, 210.0)
                                    .toDouble();
                            final imageHeight = imageWidth * 0.81;
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: StorageImage(
                                message.attachmentUrl!,
                                width: imageWidth,
                                height: imageHeight,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => SizedBox(
                                  width: imageWidth,
                                  height: imageHeight,
                                  child: const Center(
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      else
                        Text(
                          message.texto,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.onSurface,
                            height: 1.4,
                          ),
                        ),
                      const SizedBox(height: 3),
                      Text(
                        time,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMine) ...[const SizedBox(width: 8), avatar],
        ],
      ),
    );
  }
}

/// Separador de data entre grupos de mensagens.
class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

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
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const Expanded(
            child: Divider(color: AppColors.outlineVariant, height: 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _format(date),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const Expanded(
            child: Divider(color: AppColors.outlineVariant, height: 1),
          ),
        ],
      ),
    );
  }
}

/// Três pontos animados que indicam "a escrever...".
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final t = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(0, t),
            const SizedBox(width: 3),
            _dot(1, t),
            const SizedBox(width: 3),
            _dot(2, t),
          ],
        );
      },
    );
  }

  Widget _dot(int index, double t) {
    final delay = index * 0.2;
    final phase = (t + delay) % 1.0;
    // Efeito de fade in/out suave
    final opacity = phase < 0.5 ? phase * 2.0 : (1.0 - phase) * 2.0;
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: StudentThemeColors.of(
          context,
        ).primary.withValues(alpha: 0.3 + opacity * 0.7),
        shape: BoxShape.circle,
      ),
    );
  }
}
