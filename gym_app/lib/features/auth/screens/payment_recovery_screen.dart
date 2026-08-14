import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/app_colors.dart';
import '../../../shared/providers/global_providers.dart';

class PaymentRecoveryScreen extends ConsumerStatefulWidget {
  final String token;

  const PaymentRecoveryScreen({super.key, required this.token});

  @override
  ConsumerState<PaymentRecoveryScreen> createState() =>
      _PaymentRecoveryScreenState();
}

class _PaymentRecoveryScreenState
    extends ConsumerState<PaymentRecoveryScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _openCheckout() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = await ref
          .read(paymentRepositoryProvider)
          .createRecoveryCheckoutSession(token: widget.token);
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('Não foi possível abrir o Stripe.');
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_open_rounded,
                        color: AppColors.primary,
                        size: 48,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Regularizar pagamento',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'O teu acesso está temporariamente bloqueado por uma mensalidade em atraso. Podes pagar de forma segura através do Stripe, sem iniciar sessão.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (_error != null) ...[
                        Text(
                          'Não foi possível preparar o pagamento. O link pode ter expirado.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: AppColors.error),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _openCheckout,
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.payment_outlined),
                          label: Text(
                            _loading ? 'A preparar...' : 'Pagar com Stripe',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Depois da confirmação do Stripe, o acesso será reativado automaticamente.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
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
    );
  }
}
