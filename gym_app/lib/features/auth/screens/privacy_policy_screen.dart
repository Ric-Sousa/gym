import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/config/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/providers/global_providers.dart';
import '../providers/auth_provider.dart';

class PrivacyPolicyScreen extends ConsumerStatefulWidget {
  final UserModel user;
  const PrivacyPolicyScreen({super.key, required this.user});

  static const version = 'privacy-2026-08-draft';

  @override
  ConsumerState<PrivacyPolicyScreen> createState() =>
      _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends ConsumerState<PrivacyPolicyScreen> {
  bool _accepted = false;
  bool _saving = false;

  Future<void> _accept() async {
    if (!_accepted) return;
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).updateUser(widget.user.uid, {
        'privacyPolicyAcceptedAt': FieldValue.serverTimestamp(),
        'privacyPolicyVersion': PrivacyPolicyScreen.version,
      });
      await ref.read(authProvider.notifier).refreshUser();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível guardar a aceitação. Tenta novamente.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 500;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.82,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Política de privacidade',
                          style: GoogleFonts.montserrat(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Versão ${PrivacyPolicyScreen.version}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              _draftPolicy,
                              style: GoogleFonts.inter(
                                color: AppColors.textSecondary,
                                height: 1.55,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        CheckboxListTile(
                          value: _accepted,
                          onChanged: _saving
                              ? null
                              : (value) =>
                                    setState(() => _accepted = value ?? false),
                          contentPadding: EdgeInsets.zero,
                          dense: isCompact,
                          visualDensity: isCompact
                              ? VisualDensity.compact
                              : VisualDensity.standard,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            'Li e aceito a política de privacidade.',
                            style: GoogleFonts.inter(
                              fontSize: isCompact ? 12 : 14,
                              height: 1.2,
                              color: AppColors.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            'Este texto é um rascunho e deve ser revisto antes de produção.',
                            style: GoogleFonts.inter(
                              fontSize: isCompact ? 10.5 : 12,
                              height: 1.25,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _saving || !_accepted ? null : _accept,
                          child: Text(
                            _saving ? 'A guardar...' : 'Aceitar e continuar',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _draftPolicy = '''RASCUNHO — REQUER REVISÃO LEGAL

Esta política descreve, de forma provisória, como a aplicação PersonalFit trata os dados necessários à prestação do serviço de acompanhamento de treino e nutrição.

1. Dados tratados
Podemos tratar dados de identificação e contacto, informação de perfil, dados de treino, nutrição, progresso físico, imagens e vídeos enviados pelo utilizador, marcações e informação de pagamentos.

2. Finalidades
Os dados são usados para gerir a conta, disponibilizar planos personalizados, acompanhar o progresso, comunicar com o personal trainer, gerir pagamentos e manter a segurança da aplicação.

3. Partilha e acesso
O aluno, os administradores autorizados e os personal trainers associados podem aceder aos dados necessários às finalidades do serviço. Não vendemos dados pessoais.

4. Armazenamento e segurança
Os dados são armazenados nos serviços Firebase configurados pela aplicação e protegidos por regras de acesso. Nenhum sistema elimina totalmente o risco, pelo que devem ser aplicadas boas práticas de segurança.

5. Direitos
O titular pode solicitar acesso, correção, eliminação ou esclarecimentos sobre os seus dados, nos limites legais aplicáveis, contactando o responsável pelo serviço.

6. Atualizações
Quando esta política for alterada, será publicada uma nova versão e poderá ser solicitada nova aceitação.

Este documento é um rascunho técnico e não substitui aconselhamento jurídico nem a política final do responsável pelo tratamento.''';
