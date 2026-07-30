import 'dart:async';
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
import '../../../../shared/utils/new_message_detector.dart';
import 'group_chat_screen.dart';

final chatMessagesProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, salaId) {
  return ref.read(chatRepositoryProvider).messagesStream(salaId);
});

/// Ecrã de chat — Kinetic Dark.
class ChatScreen extends ConsumerStatefulWidget {
  final String? chatPartnerId;
  final String? chatPartnerName;
  final String? chatPartnerPhoto;
  const ChatScreen({super.key, this.chatPartnerId, this.chatPartnerName, this.chatPartnerPhoto});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with NewMessageDetector {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _isFocused = false;
  Timer? _typingDebounce;
  bool _typingSent = false;
  String? _fetchedPartnerPhoto;

  @override
  void initState() {
    super.initState();
    ref.read(isAlunoInChatProvider.notifier).state = true;
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
        ref.read(chatRepositoryProvider).setTypingStatus(
            _currentSalaId!, _currentUserId!, false);
      }
      _textController.clear();
      _currentSalaId = null;
      _currentUserId = null;
      _typingSent = false;
      _fetchedPartnerPhoto = null;
      resetDetector();
      _fetchPartnerPhotoIfNeeded();
    }
  }

  @override
  void dispose() {
    ref.read(isAlunoInChatProvider.notifier).state = false;
    _typingDebounce?.cancel();
    // Limpa o indicador de digitacao ao sair
    _clearTypingStatus();
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
      ref.read(chatRepositoryProvider).setTypingStatus(salaId, userId, true);
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
        await ref.read(chatRepositoryProvider).setTypingStatus(
            _currentSalaId!, _currentUserId!, false);
      } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userId = authState.user?.uid ?? '';
    final otherId = widget.chatPartnerId ?? authState.user?.personalId ?? '';

    if (otherId.isEmpty || otherId == userId) {
      return _buildChatList(userId);
    }

    final salaId = ref.read(chatRepositoryProvider).getChatRoomId(userId, otherId);
    _currentSalaId = salaId;
    _currentUserId = userId;
    final messagesAsync = ref.watch(chatMessagesProvider(salaId));
    final typingAsync = ref.watch(chatRepositoryProvider).typingStream(salaId, userId);
    final userName = authState.user?.nome ?? '';
    final adminName = 'Sara Gameiro';
    final isStudent = !(authState.user?.isAdmin ?? false);

    // Nome e iniciais da outra pessoa (admin ve aluno, aluno ve admin)
    final partnerName = widget.chatPartnerName;
    final partnerPhoto = widget.chatPartnerPhoto ?? _fetchedPartnerPhoto;
    final otherName = partnerName != null && partnerName.isNotEmpty ? partnerName : adminName;
    final otherInitials = partnerName != null && partnerName.isNotEmpty
        ? partnerName[0].toUpperCase()
        : 'SG';
    final otherSubtitle = isStudent ? 'Personal Trainer' : 'Aluno';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              otherName,
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
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          backgroundImage: partnerPhoto != null ? NetworkImage(partnerPhoto) : null,
          child: partnerPhoto == null
              ? Text(
                  otherInitials,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                )
              : null,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                detectNewMessages(messages, userId, playSound: false);
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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
                  final msgDate = DateTime(msg.timestamp.year, msg.timestamp.month, msg.timestamp.day);
                  if (lastDate == null || msgDate != lastDate) {
                    lastDate = msgDate;
                    items.add(_DateSeparator(date: msgDate));
                  }
                  final isMine = msg.remetenteId == userId;
                  final showName = i == 0 || messages[i - 1].remetenteId != msg.remetenteId;
                  items.add(_MessageBubble(
                    message: msg,
                    isMine: isMine,
                    showName: showName,
                    senderName: isMine ? 'Tu' : otherName,
                    senderInitials: isMine
                        ? (userName.isNotEmpty ? userName[0].toUpperCase() : '?')
                        : otherInitials,
                  ));
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (_, index) => items[index],
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
          // Indicador de digitacao
          StreamBuilder<String?>(
            stream: typingAsync,
            builder: (_, snap) {
              final isTyping = snap.hasData && snap.data != null;
              return AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: isTyping
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                              child: Text(
                                otherInitials,
                                style: GoogleFonts.montserrat(
                                  fontSize: 7,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$otherName está a escrever',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.primary,
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
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border(
          top: BorderSide(color: AppColors.outline.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: _isFocused
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : AppColors.outline.withValues(alpha: 0.3),
                  ),
                  boxShadow: _isFocused
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.inter(color: AppColors.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: AppStrings.typeMessage,
                    hintStyle: GoogleFonts.inter(color: AppColors.outlineVariant, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _sendMessage(salaId, userId),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFFD81B60)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList(String userId) {
    final authState = ref.watch(authProvider);
    final personalId = authState.user?.personalId;
    final hasPT = personalId != null && personalId.isNotEmpty;

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
            // ── PT Chat ──
            if (hasPT) ...[
              Text('PERSONAL TRAINER', style: GoogleFonts.barlowCondensed(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.06, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              _buildPTChatTile(personalId),
              const SizedBox(height: 24),
            ],
            // ── Grupos ──
            Row(
              children: [
                Expanded(
                  child: Text('GRUPOS', style: GoogleFonts.barlowCondensed(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.06, color: AppColors.textSecondary)),
                ),
                if (groupsAsync.valueOrNull?.isNotEmpty == true)
                  Text('${groupsAsync.value!.length} grupo(s)', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.6))),
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
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.group_outlined, size: 32, color: AppColors.textSecondary.withValues(alpha: 0.3)),
                        const SizedBox(height: 8),
                        Text('Nenhum grupo disponível', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text('O teu PT pode criar grupos para\ntroca de horários entre alunos.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.6))),
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
            if (!hasPT) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.info.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: AppColors.info.withValues(alpha: 0.6)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Ainda não tens um Personal Trainer associado.\nPede ao teu PT para te vincular.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
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

  Widget _buildPTChatTile(String personalId) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          // Navega para o chat 1:1 com o PT
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(chatPartnerId: personalId, chatPartnerName: 'Sara Gameiro', chatPartnerPhoto: null),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFFD81B60)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('SG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sara Gameiro', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.onSurface)),
                    const SizedBox(height: 2),
                    Text('Personal Trainer', style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary.withValues(alpha: 0.7))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupTile(GroupModel group) {
    final hasPreview = group.lastMessage != null && group.lastMessage!.isNotEmpty;
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
                      Text(
                        hasPreview
                            ? (group.lastMessage!.length > 40 ? '${group.lastMessage!.substring(0, 40)}...' : group.lastMessage!)
                            : '${group.membros.length} membros \u2022 Troca de hor\u00e1rios',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, color: hasPreview ? AppColors.onSurface.withValues(alpha: 0.7) : AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (group.lastTimestamp != null)
                  Text(
                    _formatGroupTime(group.lastTimestamp!),
                    style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary.withValues(alpha: 0.6)),
                  ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ),
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
      _typingDebounce?.cancel();
      _clearTypingStatus();
      _textController.clear();
      _scrollToBottom();
      // Notificar o destinatário (fire-and-forget, sem bloquear)
      _notifyChat(salaId, userId, texto);
    } catch (e) {
      debugPrint('❌ Erro ao enviar mensagem: $e');
      if (mounted) {
        showAppNotification(context, AppStrings.messageSendError, type: NotificationType.error);
      }
    }
  }

  /// Envia notificação push ao destinatário via Cloud Function (best-effort).
  void _notifyChat(String salaId, String remetenteId, String texto) {
    // Fire-and-forget — não bloqueia o envio da mensagem
    Future(() async {
      try {
        await FirebaseFunctions.instanceFor(region: 'europe-west1')
            .httpsCallable('sendChatNotification')
            .call({
          'salaId': salaId,
          'remetenteId': remetenteId,
          'texto': texto,
        });
      } catch (_) {}
    });
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
          ? AppColors.primary.withValues(alpha: 0.2)
          : AppColors.secondary.withValues(alpha: 0.2),
      child: Text(
        senderInitials,
        style: GoogleFonts.montserrat(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isMine ? AppColors.primary : AppColors.secondary,
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: 4,
        top: showName ? 10 : 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMine) ...[avatar, const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMine
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.surfaceHigh,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isMine ? const Radius.circular(16) : const Radius.circular(2),
                      bottomRight: isMine ? const Radius.circular(2) : const Radius.circular(16),
                    ),
                    border: Border.all(
                      color: isMine
                          ? AppColors.primary.withValues(alpha: 0.25)
                          : AppColors.outline.withValues(alpha: 0.4),
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
                border: Border.all(color: AppColors.outline.withValues(alpha: 0.3)),
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
    final opacity = phase < 0.5
        ? phase * 2.0
        : (1.0 - phase) * 2.0;
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.3 + opacity * 0.7),
        shape: BoxShape.circle,
      ),
    );
  }
}
