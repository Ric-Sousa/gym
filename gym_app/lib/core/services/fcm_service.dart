import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/config/app_colors.dart';
import '../../core/config/firebase_messaging_config.dart';
import '../../data/repositories/user_repository.dart';

/// Serviço de Firebase Cloud Messaging (FCM).
/// Responsável por:
/// - Pedir permissão de notificações
/// - Obter e registar o token FCM no Firestore
/// - Tratar mensagens recebidas (foreground/background)
/// - Lidar com refresh de tokens
class FCMService {
  final FirebaseMessaging _messaging;
  final UserRepository _userRepository;
  String? _currentUserId;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _initialized = false;

  // Callback para quando uma notificação é recebida em foreground.
  void Function(RemoteMessage)? onForegroundMessage;

  // Callback para abrir a área correspondente ao tocar numa notificação.
  void Function(RemoteMessage)? onNotificationOpened;

  FCMService({
    FirebaseMessaging? messaging,
    required UserRepository userRepository,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _userRepository = userRepository;

  /// Inicializa o serviço FCM para um utilizador específico.
  Future<void> initialize(String userId) async {
    if (_initialized && _currentUserId == userId) return;
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    _currentUserId = userId;

    // 1. Pedir permissão
    final permissionGranted = await _requestPermission();
    if (!permissionGranted) return;

    // 2. Obter e registar o token atual
    await _registerToken(userId);

    // 3. Escutar refresh de tokens
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((
      newToken,
    ) async {
      await _saveToken(userId, newToken);
    });

    // 4. Configurar handlers de mensagens
    _configureMessageHandlers();
    _initialized = true;
  }

  /// Pede permissão para notificações.
  Future<bool> _requestPermission() async {
    if (kIsWeb && fcmWebVapidKey.isEmpty) return false;

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  /// Obtém e guarda o token FCM no Firestore.
  Future<void> _registerToken(String userId) async {
    try {
      final token = await _messaging.getToken(
        vapidKey: kIsWeb && fcmWebVapidKey.isNotEmpty
            ? fcmWebVapidKey
            : null,
      );
      if (token != null) {
        await _saveToken(userId, token);
      }
    } catch (_) {
      // Silently fail — token será registado no próximo refresh
    }
  }

  /// Guarda o token FCM no documento do utilizador.
  Future<void> _saveToken(String userId, String token) async {
    try {
      await _userRepository.updateUser(userId, {'fcmToken': token});
    } catch (_) {
      // Ignorar falhas de rede
    }
  }

  /// Configura os handlers de mensagens.
  void _configureMessageHandlers() {
    // Foreground: mostra snackbar/toast local
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      onForegroundMessage?.call(message);
    });

    // Quando o utilizador toca numa notificação
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      onNotificationOpened?.call(message);
    });

    // Quando a app estava fechada e foi aberta por notificação.
    _messaging.getInitialMessage().then((message) {
      if (message != null) onNotificationOpened?.call(message);
    });
  }

  /// Mostra uma notificação local quando a app está em foreground.
  static void showLocalNotification(
    BuildContext context,
    RemoteMessage message,
  ) {
    final notification = message.notification;
    if (notification == null) return;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 12,
        right: 12,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            builder: (_, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, -20 * (1 - value)),
                child: child,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceHighest.withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.notifications,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          notification.title ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                        if (notification.body != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            notification.body!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (entry.mounted) entry.remove();
                    },
                    child: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }

  /// Apaga o token FCM (ao fazer logout).
  Future<void> removeToken() async {
    if (_currentUserId == null) return;
    try {
      await _messaging.deleteToken();
      await _userRepository.updateUser(_currentUserId!, {'fcmToken': null});
    } catch (_) {}
  }

  /// Liberta recursos.
  void dispose() {
    _foregroundSubscription?.cancel();
    _openedSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
  }
}
