import 'package:flutter/material.dart';

/// Abre uma visualização imersiva da foto de perfil.
///
/// O diálogo não cria um painel/quadrado: a imagem fica recortada num círculo
/// e o fundo é suavemente escurecido. Tocar fora da imagem fecha a vista.
Future<void> showProfilePhotoViewer({
  required BuildContext context,
  required String? photoUrl,
  required String name,
  Color accentColor = Colors.white,
}) {
  final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar foto de perfil',
    barrierColor: Colors.black.withValues(alpha: 0.78),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final diameter = (MediaQuery.sizeOf(dialogContext).shortestSide * 0.72)
          .clamp(180.0, 360.0)
          .toDouble();

      return SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(dialogContext).pop(),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: diameter,
                    height: diameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.75),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: photoUrl != null && photoUrl.trim().isNotEmpty
                        ? Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _FallbackAvatar(
                              initial: initial,
                              accentColor: accentColor,
                            ),
                          )
                        : _FallbackAvatar(
                            initial: initial,
                            accentColor: accentColor,
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                if (name.trim().isNotEmpty)
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.86, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _FallbackAvatar extends StatelessWidget {
  final String initial;
  final Color accentColor;

  const _FallbackAvatar({required this.initial, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: accentColor.withValues(alpha: 0.14),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: accentColor,
            fontSize: 64,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
