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
import '../../../data/models/group_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/providers/global_providers.dart';
import '../../../shared/providers/admin_providers.dart';
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

/// View de mensagens do admin — lista de conversas + gestão de grupos.
class AdminMessagesView extends ConsumerWidget {
  final Function(UserModel) onSelect;
  const AdminMessagesView({required this.onSelect, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(adminConversationsProvider);
    final groupsAsync = ref.watch(adminGroupsProvider);
    final isMobile = MediaQuery.of(context).size.width < 900;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Grupos ──
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GRUPOS DE ALUNOS', style: GoogleFonts.barlowCondensed(fontSize: isMobile ? 18 : 24, fontWeight: FontWeight.w900, letterSpacing: -0.01, color: AdminThemeColors.of(context).text)),
                    const SizedBox(height: 4),
                    Text('Grupos para troca de horários e blocos',
                        style: GoogleFonts.inter(fontSize: 13, color: AdminThemeColors.of(context).muted)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateGroupDialog(context, ref),
                icon: const Icon(Icons.add, size: 16),
                label: Text('CRIAR GRUPO', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.04)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminThemeColors.of(context).lime,
                  foregroundColor: AdminThemeColors.of(context).bg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          groupsAsync.when(
            data: (groups) {
              if (groups.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AdminThemeColors.of(context).surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AdminThemeColors.of(context).border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.group_outlined, size: 18, color: AdminThemeColors.of(context).muted),
                        const SizedBox(width: 8),
                        Text('Nenhum grupo criado', style: GoogleFonts.inter(fontSize: 13, color: AdminThemeColors.of(context).muted)),
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
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AdminThemeColors.of(context).surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AdminThemeColors.of(context).border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: AdminThemeColors.of(context).limeDim,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.group, color: AdminThemeColors.of(context).lime, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(g.nome, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AdminThemeColors.of(context).text)),
                                  Text('${g.membros.length} membros',
                                      style: GoogleFonts.inter(fontSize: 11, color: AdminThemeColors.of(context).muted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // ── Conversas Individuais ──
          Text('CONVERSAS', style: GoogleFonts.barlowCondensed(fontSize: isMobile ? 18 : 24, fontWeight: FontWeight.w900, letterSpacing: -0.01, color: AdminThemeColors.of(context).text)),
          const SizedBox(height: 12),
          conversationsAsync.when(
            data: (conversations) {
              if (conversations.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AdminThemeColors.of(context).surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminThemeColors.of(context).border),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.chat_outlined, size: 36, color: AdminThemeColors.of(context).muted),
                        const SizedBox(height: 8),
                        Text('Nenhuma conversa', style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted)),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: conversations.map((c) => _ConversationTile(preview: c, onTap: () => onSelect(c.aluno))).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (_, __) => Center(child: Text('Erro', style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted))),
          ),
        ],
      ),
    );
  }
}

/// Diálogo para criar um novo grupo.
Future<void> _showCreateGroupDialog(BuildContext context, WidgetRef ref) async {
  final nomeCtrl = TextEditingController();
  final alunosAsync = ref.read(
    FutureProvider<List<UserModel>>((ref) async {
      final snap = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .where('role', isEqualTo: AppConstants.roleAluno)
          .get();
      return snap.docs.map((d) => UserModel.fromMap(d.id, d.data())).toList();
    }),
  );
  final alunos = alunosAsync.valueOrNull ?? [];
  final selectedIds = <String>{};

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: AdminThemeColors.of(context).surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AdminThemeColors.of(context).border)),
        title: Text('Criar Grupo', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AdminThemeColors.of(context).text)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCtrl,
                style: GoogleFonts.inter(color: AdminThemeColors.of(context).text),
                decoration: InputDecoration(
                  labelText: 'Nome do grupo',
                  hintText: 'Ex: Turma Manhã',
                  labelStyle: GoogleFonts.inter(color: AdminThemeColors.of(context).muted),
                  filled: true,
                  fillColor: AdminThemeColors.of(context).bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AdminThemeColors.of(context).border)),
                ),
              ),
              const SizedBox(height: 12),
              Text('Seleciona os membros:', style: GoogleFonts.inter(fontSize: 12, color: AdminThemeColors.of(context).muted)),
              const SizedBox(height: 8),
              if (alunos.isEmpty)
                Text('Nenhum aluno disponível', style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted))
              else
                Flexible(
                  child: SizedBox(
                    height: 200,
                    child: ListView(
                      shrinkWrap: true,
                      children: alunos.map((a) => CheckboxListTile(
                        dense: true,
                        title: Text(a.nome, style: GoogleFonts.inter(fontSize: 13, color: AdminThemeColors.of(context).text)),
                        subtitle: Text(a.email, style: GoogleFonts.inter(fontSize: 11, color: AdminThemeColors.of(context).muted)),
                        value: selectedIds.contains(a.uid),
                        activeColor: AdminThemeColors.of(context).lime,
                        onChanged: (v) => setDialogState(() {
                          if (v == true) { selectedIds.add(a.uid); } else { selectedIds.remove(a.uid); }
                        }),
                      )).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: GoogleFonts.inter(color: AdminThemeColors.of(context).muted))),
          ElevatedButton(
            onPressed: selectedIds.isEmpty || nomeCtrl.text.trim().isEmpty
                ? null
                : () async {
                    try {
                      await ref.read(groupRepositoryProvider).createGroup({
                        'nome': nomeCtrl.text.trim(),
                        'membros': selectedIds.toList(),
                        'criadoPor': FirebaseAuth.instance.currentUser?.uid ?? '',
                        'createdAt': DateTime.now(),
                      });
                      ref.invalidate(adminGroupsProvider);
                      if (context.mounted) Navigator.pop(ctx);
                    } catch (_) {}
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminThemeColors.of(context).lime,
              foregroundColor: AdminThemeColors.of(context).bg,
            ),
            child: Text('Criar', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ),
  );
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
