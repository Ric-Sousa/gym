import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

/// Recurso persistido no Firestore para um ficheiro Storage.
///
/// Recursos novos são paths, por exemplo `users/uid/profile.jpg`. URLs HTTP
/// são aceites apenas para compatibilidade com documentos legados. A resolução
/// do path acontece em runtime, depois das Firebase Storage Rules verificarem
/// a sessão atual, e o URL temporário nunca é persistido no Firestore.
class StorageResource {
  const StorageResource._();

  static bool isLegacyUrl(String resource) {
    final uri = Uri.tryParse(resource.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'gs');
  }

  /// Verifica se o valor pode ser usado como path privado relativo ao bucket.
  static bool isPrivatePath(String resource) {
    final normalized = resource.trim();
    return normalized.isNotEmpty &&
        !isLegacyUrl(normalized) &&
        !normalized.startsWith('/') &&
        !normalized.contains('..') &&
        !normalized.contains('?') &&
        !normalized.contains('#');
  }

  /// Mantém o nome curto usado por código existente.
  static bool isPath(String resource) => isPrivatePath(resource);

  static Future<String> resolve(String resource) async {
    final normalized = resource.trim();
    if (normalized.isEmpty) throw StateError('Recurso Storage vazio.');

    // URLs bearer antigas continuam a funcionar apenas como fallback de
    // leitura. Nenhum upload novo deve persistir este formato.
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }

    final reference = normalized.startsWith('gs://')
        ? FirebaseStorage.instance.refFromURL(normalized)
        : FirebaseStorage.instance.ref().child(normalized);
    return reference.getDownloadURL();
  }
}

/// Imagem que aceita tanto paths privados como URLs legadas.
class StorageImage extends StatefulWidget {
  final String resource;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? error;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  const StorageImage(
    this.resource, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.error,
    this.loadingBuilder,
    this.errorBuilder,
  });

  @override
  State<StorageImage> createState() => _StorageImageState();
}

class _StorageImageState extends State<StorageImage> {
  late Future<String> _resolvedResource;

  @override
  void initState() {
    super.initState();
    _resolvedResource = StorageResource.resolve(widget.resource);
  }

  @override
  void didUpdateWidget(StorageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resource != widget.resource) {
      _resolvedResource = StorageResource.resolve(widget.resource);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _resolvedResource,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.placeholder ??
              const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snapshot.hasError || snapshot.data == null) {
          return widget.error ?? const SizedBox.shrink();
        }
        return Image.network(
          snapshot.data!,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          loadingBuilder: widget.loadingBuilder,
          errorBuilder: widget.errorBuilder ??
              (_, __, ___) => widget.error ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Avatar pequeno para paths Storage, sem usar NetworkImage de forma síncrona.
class StorageAvatar extends StatelessWidget {
  final String? resource;
  final double radius;
  final Color backgroundColor;
  final Widget? fallback;
  final VoidCallback? onTap;

  const StorageAvatar({
    super.key,
    required this.resource,
    this.radius = 20,
    this.backgroundColor = Colors.transparent,
    this.fallback,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final value = resource?.trim() ?? '';
    final fallbackWidget = fallback ?? const Icon(Icons.person_outline);
    final child = value.isEmpty
        ? fallbackWidget
        : StorageImage(
            value,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            placeholder: Center(
              child: SizedBox(
                width: radius * .65,
                height: radius * .65,
                child: const CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ),
            error: fallbackWidget,
          );
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: ClipOval(child: child),
    );
    return onTap == null ? avatar : GestureDetector(onTap: onTap, child: avatar);
  }
}
