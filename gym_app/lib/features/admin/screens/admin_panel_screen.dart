import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../data/models/user_model.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/providers/global_providers.dart';
import '../../../../shared/widgets/empty_state.dart';
import 'student_detail_screen.dart';

/// Provider da lista de alunos (admin).
final alunosListProvider = FutureProvider<List<UserModel>>((ref) {
  return ref.read(userRepositoryProvider).getAllAlunos();
});

/// Provider de pesquisa de alunos.
final alunosSearchProvider =
    FutureProvider.family<List<UserModel>, String>((ref, query) {
  if (query.isEmpty) {
    return ref.read(userRepositoryProvider).getAllAlunos();
  }
  return ref.read(userRepositoryProvider).searchAlunos(query);
});

/// Painel de administração (lista de alunos).
class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alunosAsync = ref.watch(alunosSearchProvider(_searchQuery));

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.adminPanel),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
            tooltip: AppStrings.logout,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de pesquisa
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _searchQuery = value.trim()),
              decoration: InputDecoration(
                hintText: AppStrings.searchStudent,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.backgroundLight,
              ),
            ),
          ),
          // Lista
          Expanded(
            child: alunosAsync.when(
              data: (alunos) {
                if (alunos.isEmpty) {
                  return const EmptyState(
                    icon: Icons.people_outline,
                    title: AppStrings.noStudents,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(alunosSearchProvider(_searchQuery)),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: alunos.length,
                    itemBuilder: (_, index) {
                      final aluno = alunos[index];
                      return _StudentListTile(aluno: aluno);
                    },
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('Erro ao carregar alunos')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tile de aluno na lista.
class _StudentListTile extends ConsumerWidget {
  final UserModel aluno;

  const _StudentListTile({required this.aluno});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primaryLight,
          backgroundImage:
              aluno.fotoPerfil != null ? NetworkImage(aluno.fotoPerfil!) : null,
          child: aluno.fotoPerfil == null
              ? Text(
                  aluno.nome.isNotEmpty
                      ? aluno.nome[0].toUpperCase()
                      : '?',
                  style: const TextStyle(color: Colors.white),
                )
              : null,
        ),
        title: Text(
          aluno.nome,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(aluno.email, style: const TextStyle(fontSize: 12)),
            if (aluno.ultimaAtividade != null)
              Text(
                'Ativo: ${_formatDate(aluno.ultimaAtividade!)}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentDetailScreen(aluno: aluno),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Hoje';
    if (diff.inDays == 1) return 'Ontem';
    return '${diff.inDays} dias atrás';
  }
}
