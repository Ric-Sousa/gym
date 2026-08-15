import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/student_theme.dart';
import '../../../../data/models/group_model.dart';
import '../../../../data/models/message_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../shared/providers/global_providers.dart';
import '../../../../core/services/audio_recording_model.dart';
import '../../../../shared/widgets/app_notification.dart';
import '../../../../shared/widgets/audio_message_player.dart';
import '../../../../shared/widgets/audio_record_button.dart';
import '../../../../shared/utils/audio_chat_message.dart';
import '../../../../shared/utils/chat_attachment.dart';
import '../../../../shared/utils/new_message_detector.dart';
import '../../../../shared/widgets/app_design_system.dart';

/// Ecrã de chat de grupo — alunos trocam horários/blocos.
class GroupChatScreen extends ConsumerStatefulWidget {
  final GroupModel group;
  final bool trackChatPresence;
  final bool isAdminChat;
  final VoidCallback? onExit;

  const GroupChatScreen({
    super.key,
    required this.group,
    this.trackChatPresence = true,
    this.isAdminChat = false,
    this.onExit,
  });

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen>
    with NewMessageDetector {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _imagePicker = ImagePicker();
  late GroupModel _group;
  bool _sending = false;
  bool _isRecording = false;
  bool _scrollCallbackScheduled = false;
  DateTime? _lastRequestedGroupReadAt;
  bool _markingGroupAsRead = false;
  // Guardado localmente porque ref fica invalido no dispose
  StateController<bool>? _chatNotifier;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';
  StateProvider<bool> get _presenceProvider =>
      widget.isAdminChat ? isAdminInChatProvider : isAlunoInChatProvider;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
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
      groupMessagesStreamProvider(_group.id),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar às conversas',
          onPressed: widget.onExit ?? () => Navigator.of(context).maybePop(),
        ),
        leadingWidth: 56,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: StudentThemeColors.of(
                  context,
                ).primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: StudentThemeColors.of(
                    context,
                  ).primary.withValues(alpha: 0.24),
                ),
              ),
              child: _group.imagemUrl != null && _group.imagemUrl!.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        _group.imagemUrl!,
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.group_outlined,
                          color: StudentThemeColors.of(context).primary,
                          size: 18,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.group_outlined,
                      color: StudentThemeColors.of(context).primary,
                      size: 18,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _group.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${_group.membros.length} membros',
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
        actions: [
          IconButton(
            tooltip: 'Informações do grupo',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showGroupInfo(
              messagesAsync.asData?.value ?? const <MessageModel>[],
            ),
          ),
          if (widget.isAdminChat)
            IconButton(
              tooltip: 'Gerir grupo',
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: _showAdminGroupActions,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: AppSurface(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              color: StudentThemeColors.of(
                context,
              ).primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 300;
                  Widget copy({required bool bounded}) => Row(
                    children: [
                      Icon(
                        Icons.forum_outlined,
                        color: StudentThemeColors.of(context).primary,
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
                          label: '${_group.membros.length}',
                          icon: Icons.people_outline,
                          color: StudentThemeColors.of(context).primary,
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: copy(bounded: false)),
                      const SizedBox(width: 10),
                      AppStatusPill(
                        label: '${_group.membros.length}',
                        icon: Icons.people_outline,
                        color: StudentThemeColors.of(context).primary,
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
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: StudentThemeColors.of(context).primary,
                ),
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

    _scheduleMarkGroupAsRead(messages);
    _scheduleScrollToBottom();

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
      itemCount: messages.length,
      itemBuilder: (_, i) =>
          _messageBubble(messages[i], i > 0 ? messages[i - 1] : null),
    );
  }

  void _scheduleMarkGroupAsRead(List<MessageModel> messages) {
    if (_userId.isEmpty || messages.isEmpty) return;
    final latest = messages
        .map((message) => message.timestamp)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final previous = _lastRequestedGroupReadAt;
    if (previous != null && !latest.isAfter(previous)) return;

    _lastRequestedGroupReadAt = latest;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _markGroupAsRead(latest);
    });
  }

  Future<void> _markGroupAsRead(DateTime readAt) async {
    if (_markingGroupAsRead || _userId.isEmpty) return;
    _markingGroupAsRead = true;
    try {
      await ref.read(groupRepositoryProvider).markAsRead(
            _group.id,
            _userId,
            readAt,
          );
    } catch (_) {
      // O badge pode continuar visível se a rede falhar; a próxima mensagem
      // ou reabertura tentará marcar novamente.
      if (_lastRequestedGroupReadAt == readAt) {
        _lastRequestedGroupReadAt = null;
      }
    } finally {
      _markingGroupAsRead = false;
    }
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

  void _scheduleScrollToBottom() {
    if (_scrollCallbackScheduled) return;
    _scrollCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollCallbackScheduled = false;
      if (mounted) _scrollToBottom();
    });
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
              if (!isMine) ...[
                _senderAvatar(msg.remetenteId),
                const SizedBox(width: 8),
              ],
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
                    color: isMine
                        ? StudentThemeColors.of(context).primary
                        : AppColors.surface,
                    border: Border.all(
                      color: isMine
                          ? StudentThemeColors.of(
                              context,
                            ).primaryFixed.withValues(alpha: 0.18)
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
                              : StudentThemeColors.of(context).primary,
                          inactiveColor: isMine
                              ? Colors.white70
                              : AppColors.textSecondary,
                          durationMs: msg.audioDurationMs,
                        )
                      : msg.isAttachment
                      ? Builder(
                          builder: (context) {
                            final imageWidth = (MediaQuery.sizeOf(context).width * 0.52)
                                .clamp(140.0, 210.0)
                                .toDouble();
                            final imageHeight = imageWidth * 0.81;
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                msg.attachmentUrl!,
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
              if (isMine) ...[
                const SizedBox(width: 8),
                _senderAvatar(msg.remetenteId),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _getSenderName(String uid) {
    if (uid == _userId) return 'Tu';
    if (uid == _group.criadoPor) {
      return _group.criadoPorNome ?? 'Administrador';
    }
    return _group.membrosNomes[uid] ?? 'Participante';
  }

  String? _getSenderPhoto(String uid) {
    if (uid == _group.criadoPor) return _group.criadoPorFoto;
    return _group.membrosFotos[uid];
  }

  Widget _senderAvatar(String uid) {
    final photoUrl = _getSenderPhoto(uid);
    final name = _getSenderName(uid);
    return CircleAvatar(
      radius: 15,
      backgroundColor: StudentThemeColors.of(context).primary.withValues(
        alpha: 0.14,
      ),
      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
          ? NetworkImage(photoUrl)
          : null,
      child: photoUrl == null || photoUrl.isEmpty
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: GoogleFonts.inter(
                color: StudentThemeColors.of(context).primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }

  Widget _buildInputBar() {
    final messageControls = Row(
      key: const ValueKey('group_message_controls'),
      children: [
        IconButton(
          onPressed: _sending ? null : _sendAttachment,
          icon: const Icon(Icons.attach_file_rounded),
          color: AppColors.textSecondary,
          tooltip: 'Enviar imagem',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surfaceHigh,
            minimumSize: const Size(44, 44),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: TextField(
            controller: _textCtrl,
            style: GoogleFonts.inter(color: AppColors.onSurface, fontSize: 14),
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
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppColors.outline.withValues(alpha: 0.35),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppColors.outline.withValues(alpha: 0.35),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: StudentThemeColors.of(
                    context,
                  ).primary.withValues(alpha: 0.55),
                  width: 1.4,
                ),
              ),
            ),
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sendMessage(),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: StudentThemeColors.of(context).primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: StudentThemeColors.of(
                  context,
                ).primary.withValues(alpha: 0.24),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 50, height: 50),
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
                        color: AppColors.surfaceHigh,
                        iconColor: StudentThemeColors.of(context).primary,
                        enabled: !_sending,
                        onRecordingChanged: (recording) {
                          if (mounted) setState(() => _isRecording = recording);
                        },
                        onAudioReady: _sendAudio,
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

  Future<void> _showGroupInfo(List<MessageModel> messages) async {
    final memberNames = <String, String>{..._group.membrosNomes};
    final memberPhotos = <String, String>{..._group.membrosFotos};
    var administratorName = _group.criadoPorNome ?? 'Administrador';
    String? administratorPhoto = _group.criadoPorFoto;

    // Os nomes e fotos são guardados no próprio grupo. Assim, os alunos
    // conseguem vê-los sem terem acesso de leitura aos perfis privados dos
    // restantes utilizadores. O admin também atualiza grupos antigos.
    if (widget.isAdminChat) {
      try {
        final students = await ref.read(userRepositoryProvider).getAllAlunos();
        for (final student in students) {
          if (!_group.membros.contains(student.uid)) continue;
          memberNames[student.uid] = student.nome;
          final photo = student.fotoPerfil;
          if (photo != null && photo.isNotEmpty) {
            memberPhotos[student.uid] = photo;
          } else {
            memberPhotos.remove(student.uid);
          }
        }
        final administrator = await ref
            .read(userRepositoryProvider)
            .getUser(_group.criadoPor);
        administratorName = administrator.nome;
        administratorPhoto = administrator.fotoPerfil;
        final update = <String, dynamic>{
          'membrosNomes': memberNames,
          'membrosFotos': memberPhotos,
          'criadoPorNome': administratorName,
        };
        if (administratorPhoto != null && administratorPhoto.isNotEmpty) {
          update['criadoPorFoto'] = administratorPhoto;
        }
        await ref.read(groupRepositoryProvider).updateGroup(_group.id, update);
        if (mounted) {
          setState(
            () => _group = _group.copyWith(
              membrosNomes: memberNames,
              membrosFotos: memberPhotos,
              criadoPorNome: administratorName,
              criadoPorFoto: administratorPhoto,
            ),
          );
        }
      } catch (_) {
        // A informação armazenada no grupo continua disponível como fallback.
      }
    }

    if (!mounted) return;
    final sharedImages = messages
        .where(
          (message) =>
              message.isAttachment &&
              (message.attachmentType?.startsWith('image/') ?? true),
        )
        .toList(growable: false);
    final studentIds = _group.membros
        .where((uid) => uid != _group.criadoPor)
        .toList(growable: false);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.82,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _groupAvatar(size: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _group.nome,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSurface,
                            ),
                          ),
                          Text(
                            '${_group.membros.length} alunos',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _groupInfoHeading('ADMINISTRADOR', Icons.admin_panel_settings_outlined),
                _groupPersonTile(
                  name: administratorName,
                  photoUrl: administratorPhoto,
                  role: 'Admin do grupo',
                  icon: Icons.admin_panel_settings_outlined,
                  highlighted: true,
                ),
                const SizedBox(height: 18),
                _groupInfoHeading(
                  'ALUNOS (${studentIds.length})',
                  Icons.people_outline,
                ),
                if (studentIds.isEmpty)
                  Text(
                    'Nenhum aluno associado.',
                    style: GoogleFonts.inter(color: AppColors.textSecondary),
                  )
                else
                  ...studentIds.map(
                    (uid) => _groupPersonTile(
                      name: memberNames[uid] ?? 'Participante',
                      photoUrl: memberPhotos[uid],
                      role: 'Aluno',
                      icon: Icons.person_outline,
                    ),
                  ),
                if (sharedImages.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _groupInfoHeading(
                    'IMAGENS PARTILHADAS (${sharedImages.length})',
                    Icons.photo_library_outlined,
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: sharedImages.length,
                    itemBuilder: (_, index) {
                      final image = sharedImages[index];
                      return GestureDetector(
                        onTap: () => _showSharedImage(image.attachmentUrl!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            image.attachmentUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.surfaceHigh,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _groupAvatar({double size = 40}) {
    final imageUrl = _group.imagemUrl;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: StudentThemeColors.of(context).primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: imageUrl != null && imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.groups_outlined,
                color: StudentThemeColors.of(context).primary,
              ),
            )
          : Icon(
              Icons.groups_outlined,
              color: StudentThemeColors.of(context).primary,
              size: size * 0.48,
            ),
    );
  }

  Widget _groupInfoHeading(String text, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: StudentThemeColors.of(context).primary,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _groupPersonTile({
    required String name,
    String? photoUrl,
    required String role,
    required IconData icon,
    bool highlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted
            ? StudentThemeColors.of(context).primary.withValues(alpha: 0.10)
            : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: highlighted
                ? StudentThemeColors.of(context).primary.withValues(alpha: 0.16)
                : AppColors.surface,
            backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl == null || photoUrl.isEmpty
                ? Icon(
                    icon,
                    size: 19,
                    color: highlighted
                        ? StudentThemeColors.of(context).primary
                        : AppColors.textSecondary,
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ),
          Text(
            role,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: highlighted
                  ? StudentThemeColors.of(context).primary
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showSharedImage(String url) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAdminGroupActions() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.image_outlined,
                  color: StudentThemeColors.of(context).primary,
                ),
                title: const Text('Imagem do grupo'),
                subtitle: const Text('Escolher ou substituir a imagem'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickGroupImage();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.people_outline,
                  color: StudentThemeColors.of(context).primary,
                ),
                title: const Text('Gerir membros'),
                subtitle: Text('${_group.membros.length} membros selecionados'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _manageGroupMembers();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickGroupImage() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1600,
      );
      if (file == null) return;
      if (mounted) setState(() => _sending = true);

      final extension = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : 'jpg';
      final contentType = file.mimeType ?? 'image/$extension';
      final url = await ref.read(storageDataSourceProvider).uploadFile(
        path:
            'chat_attachments/group_images/${_group.id}_${DateTime.now().millisecondsSinceEpoch}.$extension',
        fileBytes: await file.readAsBytes(),
        contentType: contentType,
      );
      await ref.read(groupRepositoryProvider).updateGroup(_group.id, {
        'imagemUrl': url,
      });
      if (mounted) {
        setState(() => _group = _group.copyWith(imagemUrl: url));
        showAppNotification(
          context,
          'Imagem do grupo atualizada.',
          type: NotificationType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppNotification(
          context,
          'Não foi possível atualizar a imagem do grupo.',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _manageGroupMembers() async {
    List<UserModel> students;
    try {
      students = await ref.read(userRepositoryProvider).getAllAlunos();
    } catch (_) {
      if (mounted) {
        showAppNotification(
          context,
          'Não foi possível carregar os alunos.',
          type: NotificationType.error,
        );
      }
      return;
    }

    final selectedIds = _group.membros.toSet();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Membros do grupo'),
          content: SizedBox(
            width: 420,
            height: MediaQuery.sizeOf(dialogContext).height * 0.5,
            child: students.isEmpty
                ? const Center(child: Text('Nenhum aluno disponível.'))
                : ListView.builder(
                    itemCount: students.length,
                    itemBuilder: (_, index) {
                      final student = students[index];
                      return CheckboxListTile(
                        value: selectedIds.contains(student.uid),
                        activeColor: StudentThemeColors.of(context).primary,
                        title: Text(student.nome),
                        subtitle: Text(student.email),
                        onChanged: (selected) => setDialogState(() {
                          if (selected == true) {
                            selectedIds.add(student.uid);
                          } else {
                            selectedIds.remove(student.uid);
                          }
                        }),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final memberNames = {
                    for (final student in students)
                      if (selectedIds.contains(student.uid))
                        student.uid: student.nome,
                  };
                  final memberPhotos = {
                    for (final student in students)
                      if (selectedIds.contains(student.uid) &&
                          student.fotoPerfil != null &&
                          student.fotoPerfil!.isNotEmpty)
                        student.uid: student.fotoPerfil!,
                  };
                  await ref.read(groupRepositoryProvider).updateGroup(
                    _group.id,
                    {
                      'membros': selectedIds.toList(),
                      'membrosNomes': memberNames,
                      'membrosFotos': memberPhotos,
                    },
                  );
                  if (!mounted) return;
                  setState(                      () => _group = _group.copyWith(
                        membros: selectedIds.toList(),
                        membrosNomes: memberNames,
                        membrosFotos: memberPhotos,
                      ),

                  );
                  Navigator.pop(dialogContext);
                } catch (_) {
                  if (mounted) {
                    showAppNotification(
                      context,
                      'Não foi possível atualizar os membros.',
                      type: NotificationType.error,
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendAttachment() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1800,
      );
      if (file == null) return;
      setState(() => _sending = true);
      final message = await createUploadedImageMessage(
        storage: ref.read(storageDataSourceProvider),
        senderId: _userId,
        chatId: _group.id,
        file: file,
      );
      await ref
          .read(groupRepositoryProvider)
          .sendMessage(_group.id, message.toMap());
      _notifyGroup(preview: 'Imagem');
    } catch (_) {
      if (mounted) {
        showAppNotification(
          context,
          'Não foi possível enviar o anexo.',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendAudio(RecordedAudio audio) async {
    setState(() => _sending = true);
    try {
      final message = await createUploadedAudioMessage(
        storage: ref.read(storageDataSourceProvider),
        senderId: _userId,
        chatId: _group.id,
        audio: audio,
      );
      await ref
          .read(groupRepositoryProvider)
          .sendMessage(_group.id, message.toMap());
      _notifyGroup(preview: 'Mensagem de áudio');
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
      await ref.read(groupRepositoryProvider).sendMessage(_group.id, {
        'remetenteId': _userId,
        'texto': text,
        'timestamp': DateTime.now(),
        'lida': false,
      });
      _textCtrl.clear();
      // Notificar membros do grupo (fire-and-forget)
      _notifyGroup(preview: text);
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
  void _notifyGroup({required String preview}) {
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
          'salaId': _group.id,
          'remetenteId': _userId,
          'texto': preview,
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
