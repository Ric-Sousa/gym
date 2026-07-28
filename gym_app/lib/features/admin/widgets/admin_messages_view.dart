import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_colors.dart';
import '../../../core/config/admin_theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/message_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/empty_state.dart';

/// Provider que obtém a última mensagem de cada conversa do admin com alunos.
final adminConversationsProvider =
    StreamProvider<List<_ConversationPreview>>((ref) {
  final authState = ref.watch(authProvider);
  final adminId = authState.user?.uid ?? '';

  if (adminId.isEmpty) return const Stream.empty();

  final firestore = FirebaseFirestore.instance;
  return firestore
      .collection(AppConstants.chatCollection)
      .where(FieldPath.documentId, isGreaterThanOrEqualTo: 'chat_')
      .where(FieldPath.documentId, isLessThanOrEqualTo: 'chat_\uf8ff')
      .snapshots()
      .asyncMap((snapshot) async {
    final conversations = <_ConversationPreview>[];
    for (final doc in snapshot.docs) {
      final roomId = doc.id;
      final parts = roomId.split('_');
      if (parts.length < 3) continue;

      // Determinar qual é o aluno
      final uid1 = parts[1];
      final uid2 = parts[2];
      final isParticipant =
          uid1 == adminId || uid2 == adminId;
      if (!isParticipant) continue;

      final alunoId = uid1 == adminId ? uid2 : uid1;

      // Obter info do aluno
      try {
        final alunoDoc = await firestore
            .collection(AppConstants.usersCollection)
            .doc(alunoId)
            .get();
        if (!alunoDoc.exists) continue;
        final aluno =
            UserModel.fromMap(alunoId, alunoDoc.data()!);

        // Obter ultima mensagem da subcolecao
        MessageModel? lastMessage;
        try {
          final lastMsgSnap = await firestore
              .collection(AppConstants.chatCollection)
              .doc(roomId)
              .collection(AppConstants.messagesSubcollection)
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

          if (lastMsgSnap.docs.isNotEmpty) {
            lastMessage = MessageModel.fromMap(
                lastMsgSnap.docs.first.id, lastMsgSnap.docs.first.data());
          }
        } catch (_) {
          // Se falhar a query da subcolecao (ex: indice em falta),
          // usa os metadados do documento pai como fallback.
          final data = doc.data();
          if (data['lastMessage'] != null) {
            DateTime ts;
            try {
              ts = (data['lastTimestamp'] as dynamic).toDate() as DateTime;
            } catch (_) {
              ts = DateTime.now();
            }
            lastMessage = MessageModel(
              id: roomId,
              remetenteId: data['lastSenderId'] as String? ?? '',
              texto: data['lastMessage'] as String? ?? '',
              timestamp: ts,
            );
          }
        }

        conversations.add(_ConversationPreview(
          aluno: aluno,
          lastMessage: lastMessage,
          roomId: roomId,
        ));
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

/// View de mensagens do admin — lista de conversas.
class AdminMessagesView extends ConsumerWidget {
  final Function(UserModel) onSelect;
  const AdminMessagesView({required this.onSelect, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(adminConversationsProvider);

    return conversationsAsync.when(
      data: (conversations) {
        if (conversations.isEmpty) {
          return Center(
            child: EmptyState(
              icon: Icons.chat_outlined,
              title: 'Nenhuma conversa',
              subtitle: 'Quando um aluno enviar uma mensagem, aparece aqui.',
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: conversations.length,
          itemBuilder: (_, i) => _ConversationTile(
            preview: conversations[i],
            onTap: () => onSelect(conversations[i].aluno),
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (_, __) => Center(
        child: Text(
          'Erro ao carregar conversas',
          style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted),
        ),
      ),
    );
  }
}

/// Preview de uma conversa.
class _ConversationPreview {
  final UserModel aluno;
  final MessageModel? lastMessage;
  final String roomId;

  const _ConversationPreview({
    required this.aluno,
    this.lastMessage,
    required this.roomId,
  });
}

/// Tile de uma conversa na lista.
class _ConversationTile extends StatelessWidget {
  final _ConversationPreview preview;
  final VoidCallback onTap;

  const _ConversationTile({required this.preview, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final aluno = preview.aluno;
    final lastMsg = preview.lastMessage;
    final hasUnread = lastMsg != null && !lastMsg.lida;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AdminThemeColors.of(context).surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminThemeColors.of(context).border),
        boxShadow: [
          BoxShadow(
            color: AdminThemeColors.of(context).shadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
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
                              fontSize: 18,
                            ),
                          )
                        : null,
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
                              fontWeight:
                                  hasUnread ? FontWeight.w700 : FontWeight.w600,
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
                      lastMsg?.texto ?? 'Inicia a conversa',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight:
                            hasUnread ? FontWeight.w500 : FontWeight.w400,
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
