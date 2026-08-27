import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/admin_theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/utils/storage_resource.dart';
import '../../../core/services/audio_recording_model.dart';
import '../../../core/services/sound_service.dart';
import '../../../shared/utils/new_message_detector.dart';
import '../../../data/models/message_model.dart';
import '../../../data/models/group_model.dart';
import '../../../data/models/user_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/providers/global_providers.dart';
import '../../../shared/providers/admin_providers.dart';
import '../../../shared/providers/chat_notification_providers.dart';
import '../../../shared/providers/admin_chat_unread_providers.dart';
import '../../aluno/chat/screens/chat_screen.dart'; // for chatMessagesProvider
import '../../aluno/chat/screens/group_chat_screen.dart';
import '../../../shared/widgets/audio_message_player.dart';
import '../../../shared/widgets/audio_record_button.dart';
import '../../../shared/utils/audio_chat_message.dart';
import '../../../shared/utils/chat_attachment.dart';
import '../../../shared/widgets/group_members_preview.dart';
import '../../../shared/widgets/profile_photo_viewer.dart';
import '../../../shared/widgets/app_design_system.dart';
import 'admin_messages_view.dart';

// ─── Color constants ──────────────────────────────────────────────

const _unreadPink = Color(0xFFFF6B6B);
const _badgeBlack = Color(0xFF1A1A1A);

String _adminNewMessagesLabel(int count) {
  if (count == 1) return '1 mensagem nova';
  return '$count mensagens novas';
}

/// Provider that computes unread conversation count.
final adminLegacyUnreadCountProvider = Provider<int>((ref) {
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

/// Conta mensagens não lidas dos grupos para o badge do chat do admin.
/// A leitura inicial também é considerada: o contador representa o estado
/// persistido em `lida`, e não apenas mensagens recebidas enquanto a tela está
/// aberta.
final adminLegacyGroupUnreadCountProvider = StreamProvider<int>((ref) {
  final adminId = ref.watch(
    authProvider.select((state) => state.user?.uid ?? ''),
  );
  if (adminId.isEmpty) return Stream.value(0);

  final firestore = FirebaseFirestore.instance;
  final controller = StreamController<int>();
  final counts = <String, int>{};
  final readAtByGroup = <String, DateTime?>{};
  final messagesByGroup = <String, List<Map<String, dynamic>>>{};
  final subscriptions =
      <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? groupsSubscription;

  void emitTotal() {
    if (!controller.isClosed) {
      controller.add(
        counts.values.fold<int>(0, (total, value) => total + value),
      );
    }
  }

  DateTime? timestampOf(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  void recalculate(String groupId) {
    final readAt = readAtByGroup[groupId];
    final messages = messagesByGroup[groupId] ?? const <Map<String, dynamic>>[];
    counts[groupId] = messages.where((data) {
      final timestamp = timestampOf(data['timestamp']);
      return data['lida'] != true &&
          data['remetenteId'] != adminId &&
          (readAt == null || (timestamp != null && timestamp.isAfter(readAt)));
    }).length;
  }

  void watchGroup(String groupId) {
    if (subscriptions.containsKey(groupId)) return;
    subscriptions[groupId] = firestore
        .collection(AppConstants.groupsCollection)
        .doc(groupId)
        .collection(AppConstants.groupMessagesSubcollection)
        .snapshots()
        .listen(
          (snapshot) {
            messagesByGroup[groupId] = snapshot.docs
                .map((doc) => doc.data())
                .toList();
            recalculate(groupId);
            emitTotal();
          },
          onError: (_) {
            counts[groupId] = 0;
            emitTotal();
          },
        );
  }

  groupsSubscription = firestore
      .collection(AppConstants.groupsCollection)
      .snapshots()
      .listen((snapshot) {
        final currentIds = snapshot.docs.map((doc) => doc.id).toSet();
        for (final oldId in subscriptions.keys.toList()) {
          if (!currentIds.contains(oldId)) {
            subscriptions.remove(oldId)?.cancel();
            counts.remove(oldId);
            readAtByGroup.remove(oldId);
            messagesByGroup.remove(oldId);
          }
        }
        for (final doc in snapshot.docs) {
          final raw = (doc.data()['lastReadAtByUser'] as Map?)?[adminId];
          readAtByGroup[doc.id] = timestampOf(raw);
          recalculate(doc.id);
        }
        for (final groupId in currentIds) {
          watchGroup(groupId);
        }
        emitTotal();
      }, onError: (_) => emitTotal());

  ref.onDispose(() {
    groupsSubscription?.cancel();
    for (final subscription in subscriptions.values) {
      subscription.cancel();
    }
    controller.close();
  });
  return controller.stream;
});

/// Tracks whether the admin chat modal is currently open.
final isChatModalOpenProvider = StateProvider<bool>((ref) => false);

// ─── Floating Chat Button ─────────────────────────────────────────

class FloatingChatButton extends ConsumerStatefulWidget {
  /// Called when admin taps "Ver perfil" on a student's name.
  final void Function(UserModel aluno)? onViewProfile;

  const FloatingChatButton({super.key, this.onViewProfile});

  @override
  ConsumerState<FloatingChatButton> createState() => _FloatingChatButtonState();
}

class _FloatingChatButtonState extends ConsumerState<FloatingChatButton> {
  double? _right;
  double? _bottom;

  @override
  Widget build(BuildContext context) {
    final directUnreadCount = ref.watch(adminUnreadCountProvider).value ?? 0;
    final groupUnreadCount = ref.watch(adminGroupUnreadCountProvider);
    final unreadCount = directUnreadCount + groupUnreadCount;
    final adminId = ref.watch(authProvider).user?.uid ?? '';
    final chatPreview = ref.watch(latestChatPreviewProvider(adminId));
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

    final compact = MediaQuery.sizeOf(context).width < 600;
    final buttonSize = compact ? 48.0 : 60.0;
    final defaultRight = compact ? 16.0 : 24.0;
    final defaultBottom = compact ? 16.0 : 24.0;

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxRight = (constraints.maxWidth - buttonSize - 8)
              .clamp(8.0, double.infinity)
              .toDouble();
          final maxBottom = (constraints.maxHeight - buttonSize - 8)
              .clamp(8.0, double.infinity)
              .toDouble();
          final right = (_right ?? defaultRight)
              .clamp(8.0, maxRight)
              .toDouble();
          final bottom = (_bottom ?? defaultBottom)
              .clamp(8.0, maxBottom)
              .toDouble();

          final content = Column(
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
                      boxShadow: const [],
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: compact ? 240 : 300,
                      ),
                      child: Text(
                        chatPreview != null && chatPreview.isNotEmpty
                            ? '$unreadCount · $chatPreview'
                            : '$unreadCount ${unreadCount == 1 ? 'nova mensagem' : 'novas mensagens'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              // Main floating button
              Material(
                elevation: 0,
                shadowColor: AdminThemeColors.of(context).shadowElevated,
                borderRadius: BorderRadius.circular(30),
                child: InkWell(
                  onTap: () => _openChatModal(context, ref),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: buttonSize,
                    height: buttonSize,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AdminThemeColors.of(context).lime,
                          AdminThemeColors.of(
                            context,
                          ).lime.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_rounded,
                          color: Colors.white,
                          size: compact ? 23 : 28,
                        ),
                        // Badge count on button — black
                        if (unreadCount > 0)
                          Positioned(
                            top: compact ? 6 : 10,
                            right: compact ? 6 : 10,
                            child: Container(
                              width: compact ? 18 : 20,
                              height: compact ? 18 : 20,
                              decoration: BoxDecoration(
                                color: _badgeBlack,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.transparent),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: compact ? 8 : 9,
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
          );

          final positionedContent = compact
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) {
                    setState(() {
                      _right = (right - details.delta.dx)
                          .clamp(8.0, maxRight)
                          .toDouble();
                      _bottom = (bottom - details.delta.dy)
                          .clamp(8.0, maxBottom)
                          .toDouble();
                    });
                  },
                  child: content,
                )
              : content;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: right,
                bottom: bottom,
                child: positionedContent,
              ),
            ],
          );
        },
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
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (dialogContext) {
        return Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: isMobile ? 72 : 100,
              right: isMobile ? 8 : 24,
              left: isMobile ? 8 : 0,
            ),
            child: _ChatPopover(
              isMobile: isMobile,
              screenWidth: screenWidth,
              screenHeight: screenHeight,
              onViewProfile: widget.onViewProfile,
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
  GroupModel? _selectedGroup;

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
    final modalHeight = (widget.screenHeight - (widget.isMobile ? 92 : 140))
        .clamp(260.0, 560.0)
        .toDouble();
    return Material(
      color: Colors.transparent,
      child: Container(
        width: widget.isMobile
            ? widget.screenWidth - 16
            : widget.screenWidth.clamp(340.0, 440.0).toDouble(),
        height: modalHeight,
        constraints: BoxConstraints(
          maxHeight: modalHeight,
          maxWidth: widget.isMobile
              ? widget.screenWidth - 16
              : widget.screenWidth.clamp(340.0, 440.0).toDouble(),
        ),
        decoration: BoxDecoration(
          color: AdminThemeColors.of(context).surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AdminThemeColors.of(context).border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 28,
              spreadRadius: 0,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: FadeSlideSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _selectedConversation == null && _selectedGroup == null
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
                  onSelectGroup: (group) =>
                      setState(() => _selectedGroup = group),
                )
              : _selectedGroup != null
              ? GroupChatScreen(
                  key: ValueKey('group_chat_${_selectedGroup!.id}'),
                  group: _selectedGroup!,
                  isAdminChat: true,
                  onExit: () => setState(() => _selectedGroup = null),
                )
              : _ChatDetailView(
                  key: ValueKey('chat_detail_${_selectedConversation!.roomId}'),
                  conversation: _selectedConversation!,
                  onViewProfile: widget.onViewProfile == null
                      ? null
                      : (aluno) {
                          // Fecha o showDialog do pop-up antes de mudar para o
                          // perfil principal do admin.
                          widget.onClose();
                          widget.onViewProfile!(aluno);
                        },
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
  final void Function(GroupModel) onSelectGroup;

  const _ConversationListView({
    super.key,
    required this.onClose,
    required this.onSelectConversation,
    required this.onSelectGroup,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(adminConversationsProvider);
    final directUnreadCount = ref.watch(adminUnreadCountProvider).value ?? 0;
    final groupUnreadCount = ref.watch(adminGroupUnreadCountProvider);

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
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AdminThemeColors.of(context).text,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Nova conversa',
                onPressed: () => showStartStudentChatDialog(
                  context,
                  ref,
                  (student) {
                    final adminId = ref.read(authProvider).user?.uid ?? '';
                    final roomId = ref
                        .read(chatRepositoryProvider)
                        .getChatRoomId(student.uid, adminId);
                    final conversation = ConversationPreview(
                      aluno: student,
                      roomId: roomId,
                    );
                    onSelectConversation(conversation);
                  },
                ),
                icon: Icon(
                  Icons.person_add_alt_1_outlined,
                  size: 20,
                  color: AdminThemeColors.of(context).lime,
                ),
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                tooltip: 'Criar grupo',
                onPressed: () => showCreateGroupDialog(context, ref),
                icon: Icon(
                  Icons.group_add_outlined,
                  size: 20,
                  color: AdminThemeColors.of(context).lime,
                ),
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  labelColor: AdminThemeColors.of(context).lime,
                  unselectedLabelColor: AdminThemeColors.of(context).muted,
                  indicatorColor: AdminThemeColors.of(context).lime,
                  labelStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: [
                    _AdminChatTab(
                      label: 'Alunos',
                      hasUnread: directUnreadCount > 0,
                    ),
                    _AdminChatTab(
                      label: 'Grupos',
                      hasUnread: groupUnreadCount > 0,
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      conversationsAsync.when(
                        data: (conversations) {
                          if (conversations.isEmpty) {
                            return _buildEmptyChatState(context);
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            itemCount: conversations.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final conv = conversations[index];
                              return ScrollReveal(
                                key: ValueKey(
                                  'admin-conversation-${conv.roomId}',
                                ),
                                child: _ConversationListTile(
                                  preview: conv,
                                  onTap: () => onSelectConversation(conv),
                                ),
                              );
                            },
                          );
                        },
                        loading: () => _buildLoadingState(context),
                        error: (_, __) => _buildErrorState(context),
                      ),
                      ref
                          .watch(adminGroupsProvider)
                          .when(
                            data: (groups) {
                              if (groups.isEmpty) {
                                return _buildEmptyGroupsState(context);
                              }
                              return ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                itemCount: groups.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (context, index) => ScrollReveal(
                                  key: ValueKey(
                                    'admin-group-${groups[index].id}',
                                  ),
                                  child: _AdminGroupTile(
                                    group: groups[index],
                                    onTap: () => onSelectGroup(groups[index]),
                                  ),
                                ),
                              );
                            },
                            loading: () => _buildLoadingState(context),
                            error: (_, __) => _buildErrorState(context),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: AdminThemeColors.of(context).lime,
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Text(
        'Erro ao carregar',
        style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted),
      ),
    );
  }

  Widget _buildEmptyChatState(BuildContext context) {
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

  Widget _buildEmptyGroupsState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.groups_outlined,
            size: 44,
            color: AdminThemeColors.of(context).border,
          ),
          const SizedBox(height: 14),
          Text(
            'Nenhum grupo criado',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AdminThemeColors.of(context).muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Usa o botão + para criar um grupo',
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
}

class _AdminChatTab extends StatelessWidget {
  final String label;
  final bool hasUnread;

  const _AdminChatTab({required this.label, required this.hasUnread});

  @override
  Widget build(BuildContext context) {
    final dotColor = AdminThemeColors.of(context).lime;
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (hasUnread) ...[
            const SizedBox(width: 6),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Group List Tile ───────────────────────────────────────────────

class _AdminGroupTile extends ConsumerWidget {
  final GroupModel group;
  final VoidCallback onTap;

  const _AdminGroupTile({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AdminThemeColors.of(context);
    final unreadCount =
        ref.watch(adminGroupUnreadCountsProvider).value?[group.id] ?? 0;
    final hasUnread = unreadCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: theme.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasUnread ? theme.lime.withValues(alpha: 0.65) : theme.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.limeDim,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child:
                        group.imagemUrl != null && group.imagemUrl!.isNotEmpty
                        ? StorageImage(
                            group.imagemUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.groups_outlined,
                              color: theme.lime,
                              size: 21,
                            ),
                          )
                        : Icon(
                            Icons.groups_outlined,
                            color: theme.lime,
                            size: 21,
                          ),
                  ),
                  if (hasUnread)
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: theme.lime,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.bg, width: 2),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: hasUnread
                            ? FontWeight.w800
                            : FontWeight.w700,
                        color: theme.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GroupMembersPreview(
                      group: group,
                      textColor: theme.text,
                      mutedColor: theme.muted,
                      accentColor: theme.lime,
                      compact: true,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasUnread
                          ? _adminNewMessagesLabel(unreadCount)
                          : 'Sem mensagens novas',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: hasUnread
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: hasUnread ? theme.lime : theme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.muted, size: 18),
            ],
          ),
        ),
      ),
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
                    child: StorageAvatar(
                      resource: aluno.fotoPerfil,
                      radius: 20,
                      backgroundColor: AdminThemeColors.of(context).surface2,
                      fallback: Text(
                        aluno.nome.isNotEmpty
                            ? aluno.nome[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.montserrat(
                          color: AdminThemeColors.of(context).lime,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
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
                                      : lastMsg.isAttachment
                                      ? 'Imagem anexada'
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
    if (aluno.fotoPerfil == null || aluno.fotoPerfil!.trim().isEmpty) return;
    showProfilePhotoViewer(
      context: context,
      photoUrl: aluno.fotoPerfil,
      name: aluno.nome,
      accentColor: AdminThemeColors.of(context).lime,
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
  final _imagePicker = ImagePicker();
  bool _isMarkingAsRead = false;
  bool _didInitialScroll = false;
  bool _isRecording = false;
  bool _scrollCallbackScheduled = false;
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
        participantId: widget.conversation.aluno.uid,
        readAt: readAt,
      );
      _readRetryCount = 0;
      // O provider de conversas já não observa o cursor de leitura, para não
      // recriar o listener a cada alteração local. Revalida apenas depois de
      // uma leitura concluída, uma vez por abertura/conversa.
      ref.invalidate(adminConversationsProvider);
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

  void _scheduleScrollToBottom({bool jump = false}) {
    if (_scrollCallbackScheduled) return;
    _scrollCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollCallbackScheduled = false;
      if (!mounted || !_scrollController.hasClients) return;
      if (jump) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      } else {
        _scrollToBottom();
      }
    });
  }

  Future<void> _sendAudio(RecordedAudio audio) async {
    final adminId = ref.read(authProvider).user?.uid ?? '';
    if (adminId.isEmpty) return;

    MessageModel? uploadedMessage;
    try {
      final participants = [adminId, widget.conversation.aluno.uid];
      await ref
          .read(chatRepositoryProvider)
          .ensureChatRoom(widget.conversation.roomId, participants);
      final message = await createUploadedAudioMessage(
        storage: ref.read(storageDataSourceProvider),
        senderId: adminId,
        chatId: widget.conversation.roomId,
        audio: audio,
      );
      uploadedMessage = message;
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            widget.conversation.roomId,
            message,
            participantIds: participants,
          );
      // A trigger notifica áudio após a mensagem ser persistida.
    } catch (error) {
      await cleanupUploadedMessage(
        ref.read(storageDataSourceProvider),
        uploadedMessage,
      );
      debugPrint('Erro ao enviar áudio do admin: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível enviar o áudio.')),
        );
      }
    }
  }

  Future<void> _sendAttachment() async {
    final adminId = ref.read(authProvider).user?.uid ?? '';
    if (adminId.isEmpty) return;

    MessageModel? uploadedMessage;
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1800,
      );
      if (file == null) return;
      final participants = [adminId, widget.conversation.aluno.uid];
      await ref
          .read(chatRepositoryProvider)
          .ensureChatRoom(widget.conversation.roomId, participants);
      final message = await createUploadedImageMessage(
        storage: ref.read(storageDataSourceProvider),
        senderId: adminId,
        chatId: widget.conversation.roomId,
        file: file,
      );
      uploadedMessage = message;
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            widget.conversation.roomId,
            message,
            participantIds: participants,
          );
      // A trigger notifica anexos após a mensagem ser persistida.
      _scrollToBottom();
    } catch (error) {
      await cleanupUploadedMessage(
        ref.read(storageDataSourceProvider),
        uploadedMessage,
      );
      debugPrint('Erro ao enviar imagem do admin: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível enviar a imagem.')),
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
    final participants = [adminId, widget.conversation.aluno.uid];

    try {
      // A conversa pode ter sido iniciada pelo admin e ainda não ter uma sala.
      // Garante os participantes antes da primeira mensagem.
      await ref
          .read(chatRepositoryProvider)
          .ensureChatRoom(widget.conversation.roomId, participants);
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            widget.conversation.roomId,
            msg,
            participantIds: participants,
          );
      // A trigger notifyChatMessageCreated notifica a mensagem persistida.

      _scrollToBottom();
    } catch (_) {
      // Silently ignore
    }
  }

  void _showPhotoZoom(BuildContext context, UserModel aluno) {
    if (aluno.fotoPerfil == null || aluno.fotoPerfil!.trim().isEmpty) return;
    showProfilePhotoViewer(
      context: context,
      photoUrl: aluno.fotoPerfil,
      name: aluno.nome,
      accentColor: AdminThemeColors.of(context).lime,
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
                child: StorageAvatar(
                  resource: aluno.fotoPerfil,
                  radius: 16,
                  backgroundColor: AdminThemeColors.of(context).limeDim,
                  fallback: Text(
                    aluno.nome.isNotEmpty ? aluno.nome[0].toUpperCase() : '?',
                    style: GoogleFonts.montserrat(
                      color: AdminThemeColors.of(context).lime,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Name with dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTapDown: (details) => _showStudentDropdown(
                          context,
                          details.globalPosition,
                        ),
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
                  _scheduleScrollToBottom(jump: true);
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
                  items.add(
                    _ChatBubble(
                      msg: msg,
                      isMine: isMine,
                      senderPhoto: isMine ? authState.user?.fotoPerfil : widget.conversation.aluno.fotoPerfil,
                      senderName: isMine ? (authState.user?.nome ?? 'Administrador') : widget.conversation.aluno.nome,
                    ),
                  );
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  height: 54,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 52),
                          child: IgnorePointer(
                            ignoring: _isRecording,
                            child: AnimatedOpacity(
                              opacity: _isRecording ? 0 : 1,
                              duration: const Duration(milliseconds: 160),
                              child: Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Enviar imagem',
                                    onPressed: _sendAttachment,
                                    icon: Icon(
                                      Icons.image_outlined,
                                      color: AdminThemeColors.of(context).muted,
                                      size: 20,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(
                                      width: 38,
                                      height: 42,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        maxHeight: 120,
                                      ),
                                      child: TextField(
                                        controller: _msgController,
                                        minLines: 1,
                                        maxLines: 3,
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                        textInputAction: TextInputAction.send,
                                        onSubmitted: (_) => _sendMessage(),
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: AdminThemeColors.of(
                                            context,
                                          ).text,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Escreve uma mensagem...',
                                          hintStyle: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: AdminThemeColors.of(
                                              context,
                                            ).muted,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 10,
                                              ),
                                          filled: true,
                                          fillColor: AdminThemeColors.of(
                                            context,
                                          ).surface,
                                          hoverColor: AdminThemeColors.of(
                                            context,
                                          ).surface2,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
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
                                          color: AdminThemeColors.of(
                                            context,
                                          ).bg,
                                          size: 19,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: _isRecording
                            ? Alignment.center
                            : Alignment.centerRight,
                        child: SizedBox(
                          width: _isRecording ? constraints.maxWidth : 44,
                          height: 54,
                          child: AudioRecordButton(
                            fullWidth: true,
                            color: AdminThemeColors.of(context).surface,
                            iconColor: AdminThemeColors.of(context).lime,
                            onRecordingChanged: (recording) {
                              if (mounted) {
                                setState(() => _isRecording = recording);
                              }
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
              left: (position.dx - 120)
                  .clamp(
                    8.0,
                    (MediaQuery.sizeOf(context).width - 168).clamp(
                      8.0,
                      double.infinity,
                    ),
                  )
                  .toDouble(),
              top: (position.dy + 4)
                  .clamp(
                    8.0,
                    (MediaQuery.sizeOf(context).height - 72).clamp(
                      8.0,
                      double.infinity,
                    ),
                  )
                  .toDouble(),
              child: Material(
                elevation: 0,
                borderRadius: BorderRadius.circular(14),
                color: AdminThemeColors.of(context).surface,
                child: Container(
                  width: 160,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
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
  final String? senderPhoto;
  final String senderName;

  const _ChatBubble({
    required this.msg,
    required this.isMine,
    required this.senderPhoto,
    required this.senderName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AdminThemeColors.of(context);
    final time = DateFormat('HH:mm').format(msg.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine) ...[
              StorageAvatar(
                resource: senderPhoto,
                radius: 15,
                fallback: Text(senderName.isEmpty ? '?' : senderName[0].toUpperCase()),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
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
              else if (msg.isAttachment)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: StorageImage(
                    msg.attachmentUrl!,
                    width: (MediaQuery.sizeOf(context).width - 72)
                        .clamp(140.0, 220.0)
                        .toDouble(),
                    height:
                        (MediaQuery.sizeOf(context).width - 72)
                            .clamp(140.0, 220.0)
                            .toDouble() *
                        0.77,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return SizedBox(
                        width: (MediaQuery.sizeOf(context).width - 72)
                            .clamp(140.0, 220.0)
                            .toDouble(),
                        height:
                            (MediaQuery.sizeOf(context).width - 72)
                                .clamp(140.0, 220.0)
                                .toDouble() *
                            0.77,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.lime,
                            value: progress.expectedTotalBytes == null
                                ? null
                                : progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      width: 220,
                      height: 170,
                      color: theme.surface,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: theme.muted,
                        size: 30,
                      ),
                    ),
                  ),
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
            if (isMine) ...[
              const SizedBox(width: 6),
              StorageAvatar(
                resource: senderPhoto,
                radius: 15,
                fallback: Text(senderName.isEmpty ? '?' : senderName[0].toUpperCase()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
