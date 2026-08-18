import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_colors.dart';
import '../../../core/config/admin_theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/utils/storage_resource.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/message_model.dart';
import '../../../data/models/group_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/providers/global_providers.dart';
import '../../../shared/widgets/admin_responsive_dialog.dart';
import '../../../shared/widgets/admin_design_system.dart';
import '../../../shared/widgets/group_members_preview.dart';
import '../../../shared/widgets/app_design_system.dart';
import '../../../shared/providers/admin_providers.dart';
import '../../../shared/providers/admin_chat_unread_providers.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/aluno/chat/screens/group_chat_screen.dart';

/// Converte valores de timestamp vindos do Firestore sem deixar uma falha
/// de formato interromper a lista inteira de conversas.
DateTime? _readTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

/// Provider que obtém as conversas do admin com alunos.
///
/// A contagem é calculada a partir da mesma fotografia de mensagens que
/// fornece `lastMessage`. Não há uma query separada de `lida == false`, pois
/// duas queries independentes podem terminar em ordens diferentes e fazer o
/// contador oscilar durante a marcação como lida.
final adminConversationsProvider = StreamProvider<List<ConversationPreview>>((
  ref,
) {
  // Apenas o UID é uma dependência do listener. O cursor de leitura é lido
  // quando chega cada snapshot; observá-lo aqui cancelava e recriava o canal
  // Firestore sempre que o admin abria uma conversa.
  final adminId = ref.watch(authProvider.select((s) => s.user?.uid ?? ''));

  if (adminId.isEmpty) return const Stream.empty();

  final firestore = FirebaseFirestore.instance;
  return firestore
      .collection(AppConstants.chatCollection)
      .where(FieldPath.documentId, isGreaterThanOrEqualTo: 'chat_')
      .where(FieldPath.documentId, isLessThanOrEqualTo: 'chat_\uf8ff')
      .snapshots()
      .handleError((_, __) {
        // Swallow Firestore stream errors to prevent UI crashes on web.
      })
      .asyncMap((snapshot) async {
        final conversations = <ConversationPreview>[];
        for (final doc in snapshot.docs) {
          final roomId = doc.id;
          final parts = roomId.split('_');
          if (parts.length < 3) continue;

          final uid1 = parts[1];
          final uid2 = parts[2];
          final isParticipant = uid1 == adminId || uid2 == adminId;
          if (!isParticipant) continue;

          final alunoId = uid1 == adminId ? uid2 : uid1;

          try {
            final alunoDoc = await firestore
                .collection(AppConstants.usersCollection)
                .doc(alunoId)
                .get();
            if (!alunoDoc.exists) continue;
            final aluno = UserModel.fromMap(alunoId, alunoDoc.data()!);

            MessageModel? lastMessage;
            final roomMessages = <MessageModel>[];
            try {
              // Uma única leitura é usada tanto para o preview como para o
              // unreadCount. Assim, não existe uma segunda resposta antiga
              // capaz de repor as mensagens já lidas.
              final messageSnap = await firestore
                  .collection(AppConstants.chatCollection)
                  .doc(roomId)
                  .collection(AppConstants.messagesSubcollection)
                  .orderBy('timestamp', descending: false)
                  .get();
              roomMessages.addAll(
                messageSnap.docs.map(
                  (messageDoc) =>
                      MessageModel.fromMap(messageDoc.id, messageDoc.data()),
                ),
              );
              if (roomMessages.isNotEmpty) {
                lastMessage = roomMessages.last;
              }
            } catch (_) {
              // Fallback para o preview gravado na sala se a subcoleção
              // estiver temporariamente indisponível.
              final data = doc.data();
              final timestamp = _readTimestamp(data['lastTimestamp']);
              if (data['lastMessage'] != null && timestamp != null) {
                lastMessage = MessageModel(
                  id: roomId,
                  remetenteId: data['lastSenderId'] as String? ?? '',
                  texto: data['lastMessage'] as String? ?? '',
                  timestamp: timestamp,
                );
              }
            }

            final parentData = doc.data();
            var lastReadAt = _readTimestamp(parentData['lastReadAt']);
            final optimisticTime = ref.read(
              adminConversationReadAtProvider,
            )[roomId];
            if (optimisticTime != null &&
                (lastReadAt == null || optimisticTime.isAfter(lastReadAt))) {
              lastReadAt = optimisticTime;
            }

            int unreadCount;
            if (roomMessages.isNotEmpty) {
              // Depois da primeira leitura, o cursor é a fonte de verdade.
              // O campo lida continua a ser atualizado para compatibilidade,
              // mas não pode fazer mensagens antigas reaparecerem.
              unreadCount = roomMessages
                  .where(
                    (message) =>
                        message.remetenteId != adminId &&
                        (lastReadAt == null
                            ? !message.lida
                            : message.timestamp.isAfter(lastReadAt)),
                  )
                  .length;
            } else {
              unreadCount =
                  lastReadAt != null &&
                      lastMessage != null &&
                      !lastMessage.timestamp.isAfter(lastReadAt)
                  ? 0
                  : (lastMessage != null &&
                            !lastMessage.lida &&
                            lastMessage.remetenteId != adminId
                        ? 1
                        : 0);
            }

            conversations.add(
              ConversationPreview(
                aluno: aluno,
                lastMessage: lastMessage,
                roomId: roomId,
                unreadCount: unreadCount,
              ),
            );
          } catch (_) {
            // Só ignora se o documento do aluno nao existir.
          }
        }

        // Ordenar por última mensagem (mais recente primeiro)
        conversations.sort((a, b) {
          final timeA = a.lastMessage?.timestamp ?? DateTime(2000);
          final timeB = b.lastMessage?.timestamp ?? DateTime(2000);
          return timeB.compareTo(timeA);
        });

        return conversations;
      });
});

/// Marca como lidas apenas as mensagens do aluno que já estavam visíveis até
/// [readAt]. O cursor é gravado no documento da sala para que a leitura
/// sobreviva a reinícios e para que mensagens posteriores continuem novas.
Future<void> markAdminConversationAsRead({
  required String roomId,
  required String adminId,
  required DateTime readAt,
}) async {
  if (roomId.isEmpty || adminId.isEmpty) return;

  final firestore = FirebaseFirestore.instance;
  final roomRef = firestore.collection(AppConstants.chatCollection).doc(roomId);

  // Não filtrar por `where('lida', isEqualTo: false)`: mensagens antigas
  // podem não ter esse campo e o modelo trata-as como não lidas. Ler a sala
  // uma vez e considerar tudo que não seja explicitamente lido evita que
  // essas mensagens permaneçam no contador.
  final snapshot = await roomRef
      .collection(AppConstants.messagesSubcollection)
      .get();
  final received = snapshot.docs.where((doc) {
    final data = doc.data();
    final timestamp = _readTimestamp(data['timestamp']);
    return data['lida'] != true &&
        data['remetenteId'] != adminId &&
        timestamp != null &&
        !timestamp.isAfter(readAt);
  }).toList();

  // Firestore limita um WriteBatch a 500 operações. Atualizamos apenas as
  // mensagens; o campo lida é a fonte persistente de leitura e evita que uma
  // falha de permissão no documento pai bloqueie todas as marcações.
  for (var offset = 0; offset < received.length; offset += 499) {
    final end = offset + 499 < received.length ? offset + 499 : received.length;
    final batch = firestore.batch();
    for (final doc in received.sublist(offset, end)) {
      batch.update(doc.reference, {'lida': true});
    }
    await batch.commit();
  }

  // Persiste também o cursor da sala. Assim a lista de conversas e o badge
  // continuam a considerar lidas as mensagens antigas depois de uma nova
  // subscrição ou de um snapshot que chegue fora de ordem.
  await roomRef.set({'lastReadAt': readAt}, SetOptions(merge: true));
}

/// View de mensagens do admin — lista de conversas + gestão de grupos.
class AdminMessagesView extends ConsumerWidget {
  final Function(UserModel) onSelect;
  const AdminMessagesView({required this.onSelect, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(adminConversationsProvider);
    final groupsPager = ref.watch(adminGroupsPagerProvider);
    final AsyncValue<List<GroupModel>> groupsAsync =
        groupsPager.isLoading && groupsPager.items.isEmpty
        ? const AsyncLoading<List<GroupModel>>()
        : groupsPager.error != null
        ? AsyncError<List<GroupModel>>(groupsPager.error!, StackTrace.current)
        : AsyncData<List<GroupModel>>(groupsPager.items);
    final isMobile = MediaQuery.of(context).size.width < 900;

    return AdminPageFrame(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : AdminDesignTokens.pageHorizontal,
        isMobile ? 16 : AdminDesignTokens.pageTop,
        isMobile ? 16 : AdminDesignTokens.pageHorizontal,
        isMobile ? 24 : AdminDesignTokens.pageBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: 'Mensagens',
            subtitle: 'Acompanha conversas individuais e grupos de alunos.',
            icon: Icons.forum_outlined,
            action: ElevatedButton.icon(
              onPressed: () => showCreateGroupDialog(context, ref),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Novo grupo'),
            ),
          ),
          const SizedBox(height: 26),
          // ── Grupos ──
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 520;
              final heading = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GRUPOS DE ALUNOS',
                    style: GoogleFonts.montserrat(
                      fontSize: isMobile ? 18 : 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.01,
                      color: AdminThemeColors.of(context).text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Grupos para troca de horários e blocos',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AdminThemeColors.of(context).muted,
                    ),
                  ),
                ],
              );
              if (stacked) {
                return heading;
              }

              return heading;
            },
          ),
          const SizedBox(height: 12),
          groupsAsync.when(
            data: (groups) {
              if (groups.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: AdminSurface(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.group_outlined,
                          size: 18,
                          color: AdminThemeColors.of(context).muted,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Nenhum grupo criado',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AdminThemeColors.of(context).muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final g in groups)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AdminSurface(
                        padding: const EdgeInsets.all(12),
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (_) => Dialog(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            insetPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            child: SafeArea(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: 520,
                                    maxHeight:
                                        (MediaQuery.of(context).size.height *
                                                0.78)
                                            .clamp(320.0, 760.0)
                                            .toDouble(),
                                  ),
                                  child: SizedBox(
                                    width: isMobile
                                        ? MediaQuery.of(context).size.width - 24
                                        : 420,
                                    height:
                                        (MediaQuery.of(context).size.height *
                                                0.78)
                                            .clamp(320.0, 760.0)
                                            .toDouble(),
                                    child: GroupChatScreen(
                                      group: g,
                                      isAdminChat: true,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: _AdminMessagesGroupSummaryContent(group: g),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
          if (groupsPager.hasMore)
            Center(
              child: OutlinedButton.icon(
                onPressed: groupsPager.isLoading ? null : groupsPager.loadMore,
                icon: groupsPager.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded, size: 18),
                label: Text(
                  groupsPager.isLoading
                      ? 'A carregar...'
                      : 'Carregar mais grupos',
                ),
              ),
            ),
          // ── Conversas Individuais ──
          Text(
            'CONVERSAS',
            style: GoogleFonts.montserrat(
              fontSize: isMobile ? 18 : 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.01,
              color: AdminThemeColors.of(context).text,
            ),
          ),
          const SizedBox(height: 12),
          conversationsAsync.when(
            data: (conversations) {
              if (conversations.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AdminThemeColors.of(context).surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AdminThemeColors.of(context).border,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.chat_outlined,
                          size: 36,
                          color: AdminThemeColors.of(context).muted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nenhuma conversa',
                          style: GoogleFonts.inter(
                            color: AdminThemeColors.of(context).muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: conversations
                    .map(
                      (c) => ScrollReveal(
                        key: ValueKey('admin-page-conversation-${c.roomId}'),
                        child: _ConversationTile(
                          preview: c,
                          onTap: () => onSelect(c.aluno),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (_, __) => Center(
              child: Text(
                'Erro',
                style: GoogleFonts.inter(
                  color: AdminThemeColors.of(context).muted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminMessagesGroupSummaryContent extends ConsumerWidget {
  final GroupModel group;

  const _AdminMessagesGroupSummaryContent({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AdminThemeColors.of(context);
    final unreadCount =
        ref.watch(adminGroupUnreadCountsProvider).value?[group.id] ?? 0;
    final hasUnread = unreadCount > 0;

    return Row(
      children: [
        Stack(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.limeDim,
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: group.imagemUrl != null && group.imagemUrl!.isNotEmpty
                  ? StorageImage(
                      group.imagemUrl!,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.group, color: theme.lime, size: 18),
                    )
                  : Icon(Icons.group, color: theme.lime, size: 18),
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
                    border: Border.all(color: theme.surface, width: 2),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.nome,
                style: GoogleFonts.inter(
                  fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                  color: theme.text,
                ),
              ),
              const SizedBox(height: 3),
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
                    ? _adminMessagesLabel(unreadCount)
                    : 'Sem mensagens novas',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
                  color: hasUnread ? theme.lime : theme.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _adminMessagesLabel(int count) {
  if (count == 1) return '1 mensagem nova';
  return '$count mensagens novas';
}

/// Diálogo para criar um novo grupo.
Future<void> showCreateGroupDialog(BuildContext context, WidgetRef ref) async {
  final nomeCtrl = TextEditingController();
  // Aguarda os alunos do Firestore — o FutureProvider inline não bloqueava
  List<UserModel> alunos;
  try {
    alunos = await ref.read(userRepositoryProvider).getAllAlunos();
  } catch (_) {
    alunos = []; // fallback se Firestore falhar
  }
  final selectedIds = <String>{};

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AdminResponsiveAlertDialog(
        backgroundColor: AdminThemeColors.of(context).surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Criar Grupo',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AdminThemeColors.of(context).text,
          ),
        ),
        content: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCtrl,
                style: GoogleFonts.inter(
                  color: AdminThemeColors.of(context).text,
                ),
                decoration: InputDecoration(
                  labelText: 'Nome do grupo',
                  hintText: 'Ex: Turma Manhã',
                  labelStyle: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).muted,
                  ),
                  filled: true,
                  fillColor: AdminThemeColors.of(context).bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: AdminThemeColors.of(context).border,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Seleciona os membros:',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AdminThemeColors.of(context).muted,
                ),
              ),
              const SizedBox(height: 8),
              if (alunos.isEmpty)
                Text(
                  'Nenhum aluno disponível',
                  style: GoogleFonts.inter(
                    color: AdminThemeColors.of(context).muted,
                  ),
                )
              else
                SizedBox(
                  height: 200,
                  child: ListView(
                    shrinkWrap: true,
                    children: alunos
                        .map(
                          (a) => CheckboxListTile(
                            dense: true,
                            title: Text(
                              a.nome,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AdminThemeColors.of(context).text,
                              ),
                            ),
                            subtitle: Text(
                              a.email,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AdminThemeColors.of(context).muted,
                              ),
                            ),
                            value: selectedIds.contains(a.uid),
                            activeColor: AdminThemeColors.of(context).lime,
                            onChanged: (v) => setDialogState(() {
                              if (v == true) {
                                selectedIds.add(a.uid);
                              } else {
                                selectedIds.remove(a.uid);
                              }
                            }),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.inter(
                color: AdminThemeColors.of(context).muted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: selectedIds.isEmpty || nomeCtrl.text.trim().isEmpty
                ? null
                : () async {
                    try {
                      final selectedStudents = alunos.where(
                        (aluno) => selectedIds.contains(aluno.uid),
                      );
                      final adminUser = ref.read(authProvider).user;
                      final adminPhoto = adminUser?.fotoPerfil;
                      await ref.read(groupRepositoryProvider).createGroup({
                        'nome': nomeCtrl.text.trim(),
                        'membros': selectedIds.toList(),
                        'membrosNomes': {
                          for (final aluno in selectedStudents)
                            aluno.uid: aluno.nome,
                        },
                        'membrosFotos': {
                          for (final aluno in selectedStudents)
                            if (aluno.fotoPerfil != null &&
                                aluno.fotoPerfil!.isNotEmpty)
                              aluno.uid: aluno.fotoPerfil!,
                        },
                        'criadoPor':
                            FirebaseAuth.instance.currentUser?.uid ?? '',
                        'criadoPorNome': adminUser?.nome ?? 'Administrador',
                        if (adminPhoto != null && adminPhoto.isNotEmpty)
                          'criadoPorFoto': adminPhoto,
                        'createdAt': DateTime.now(),
                      });
                      ref.read(adminGroupsPagerProvider).refresh();
                      ref.invalidate(adminGroupsProvider);
                      if (context.mounted) Navigator.pop(ctx);
                    } catch (_) {}
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminThemeColors.of(context).lime,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Criar',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Preview de uma conversa.
class ConversationPreview {
  final UserModel aluno;
  final MessageModel? lastMessage;
  final String roomId;
  final int unreadCount;

  const ConversationPreview({
    required this.aluno,
    this.lastMessage,
    required this.roomId,
    this.unreadCount = 0,
  });

  ConversationPreview copyWith({int? unreadCount}) {
    return ConversationPreview(
      aluno: aluno,
      lastMessage: lastMessage,
      roomId: roomId,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

/// Tile de uma conversa na lista.
class _ConversationTile extends StatelessWidget {
  final ConversationPreview preview;
  final VoidCallback onTap;

  const _ConversationTile({required this.preview, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final aluno = preview.aluno;
    final lastMsg = preview.lastMessage;
    final hasUnread = preview.unreadCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AdminThemeColors.of(context).border.withValues(alpha: 0.7),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  StorageAvatar(
                    resource: aluno.fotoPerfil,
                    radius: 26,
                    backgroundColor: AdminThemeColors.of(context).surface2,
                    fallback: Text(
                      aluno.nome.isNotEmpty ? aluno.nome[0].toUpperCase() : '?',
                      style: GoogleFonts.montserrat(
                        color: AdminThemeColors.of(context).lime,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  if (hasUnread)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AdminThemeColors.of(context).lime,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AdminThemeColors.of(context).surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
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
                              fontSize: 15,
                              fontWeight: hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: AdminThemeColors.of(context).text,
                            ),
                          ),
                        ),
                        if (lastMsg != null)
                          Text(
                            _formatTime(lastMsg.timestamp),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AdminThemeColors.of(context).muted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastMsg == null
                          ? 'Inicia a conversa'
                          : (lastMsg.isAudio
                                ? 'Mensagem de áudio'
                                : lastMsg.isAttachment
                                ? 'Imagem anexada'
                                : lastMsg.texto),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
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
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: AdminThemeColors.of(context).muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}min';
    } else if (diff.inHours < 24) {
      return DateFormat('HH:mm').format(dt);
    } else if (diff.inDays < 7) {
      return DateFormat('EEE', 'pt').format(dt);
    } else {
      return DateFormat('dd/MM').format(dt);
    }
  }
}
