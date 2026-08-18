import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/config/app_colors.dart';
import 'core/config/app_strings.dart';
import 'core/config/admin_theme.dart';
import 'core/config/student_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/privacy_policy_screen.dart';
import 'features/auth/screens/questionnaire_screen.dart';
import 'features/auth/screens/payment_recovery_screen.dart';
import 'features/aluno/home/screens/aluno_home_screen.dart';
import 'features/aluno/nutricao/screens/nutrition_screen.dart';
import 'features/aluno/treino/screens/workout_screen.dart';
import 'features/aluno/chat/screens/chat_screen.dart';
import 'features/aluno/perfil/screens/profile_screen.dart';
import 'features/aluno/agenda/screens/calendar_screen.dart';
import 'features/admin/screens/admin_panel_screen.dart';
import 'shared/providers/admin_providers.dart';
import 'shared/providers/global_providers.dart';
import 'core/services/fcm_service.dart';
import 'shared/widgets/sound_preference_sync.dart';
import 'shared/widgets/app_page_frame.dart';
import 'shared/widgets/app_design_system.dart';
import 'shared/widgets/admin_design_system.dart';
import 'shared/widgets/app_notification.dart';

class _FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(opacity: curved, child: child);
  }
}

/// App root widget.
class PersonalFitApp extends ConsumerWidget {
  const PersonalFitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final adminThemeMode = ref.watch(adminThemeModeProvider);
    // Observa o género diretamente do Firestore — atualiza o tema sem reiniciar
    final generoAsync = ref.watch(currentUserGeneroProvider);
    final genero = generoAsync.asData?.value;
    final isAdmin = authState.isAdmin;
    // O género só personaliza a área do aluno. O painel admin mantém a sua
    // paleta própria, mesmo que exista um documento de utilizador sem género.
    final themeGenero = isAdmin ? null : genero;
    final studentColors = StudentThemeColors.forGenero(themeGenero);
    final lightAccent = isAdmin
        ? AppColors.adminLightLime
        : studentColors.primary;
    final lightAccentContainer = isAdmin
        ? AppColors.adminLightLimeDim
        : studentColors.primaryContainer;

    // Aplica a preferência de som do utilizador autenticado (admin/aluno)
    // assim que o perfil carrega e desbloqueia o áudio no primeiro gesto em
    // qualquer parte da app — não apenas no chat.
    final lightTheme = _buildKineticDarkTheme(themeGenero).copyWith(
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: lightAccent,
        onPrimary: AppColors.adminLightText,
        primaryContainer: lightAccentContainer,
        onPrimaryContainer: isAdmin
            ? AppColors.adminLightText
            : studentColors.primary,
        surface: AppColors.adminLightSurface,
        onSurface: AppColors.adminLightText,
        outline: AppColors.adminLightBorder,
      ),
      scaffoldBackgroundColor: AppColors.adminLightBg,
      appBarTheme: _buildKineticDarkTheme(themeGenero).appBarTheme.copyWith(
        backgroundColor: AppColors.adminLightSurface,
        foregroundColor: AppColors.adminLightText,
        titleTextStyle: GoogleFonts.montserrat(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.adminLightText,
        ),
        iconTheme: const IconThemeData(color: AppColors.adminLightText),
        actionsIconTheme: const IconThemeData(color: AppColors.adminLightMuted),
      ),
      cardTheme: CardThemeData(
        color: AppColors.adminLightSurface,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide.none,
        ),
        margin: const EdgeInsets.only(bottom: 16),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.adminLightSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.adminLightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.adminLightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: lightAccent, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(color: AppColors.adminLightMuted),
        floatingLabelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: lightAccent,
        ),
        hintStyle: GoogleFonts.inter(color: AppColors.adminLightMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightAccent,
          foregroundColor: AppColors.adminLightText,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.adminLightText,
          side: const BorderSide(color: AppColors.adminLightBorder),
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.adminLightSurface2,
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          color: AppColors.adminLightText,
        ),
        selectedColor: lightAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: AppColors.adminLightBorder),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: AppColors.adminLightSurface,
        textColor: AppColors.adminLightText,
        iconColor: AppColors.adminLightText,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minVerticalPadding: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.adminLightSurface,
        indicatorColor: lightAccentContainer,
        height: 78,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.adminLightText,
          ),
        ),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(color: AppColors.adminLightMuted),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.adminLightSurface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.adminLightSurface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
        titleTextStyle: GoogleFonts.montserrat(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.adminLightText,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          height: 1.45,
          color: AppColors.adminLightMuted,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.adminLightText,
        contentTextStyle: GoogleFonts.inter(
          color: AppColors.adminLightSurface,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      extensions: [AdminThemeColors.light, studentColors],
    );
    final darkTheme = _buildKineticDarkTheme(themeGenero).copyWith(
      extensions: [AdminThemeColors.dark, StudentThemeColors.forGenero(genero)],
    );
    // Apply the same workspace component rules to both areas. The color
    // extension remains the source of truth for each existing palette.
    final workspaceLightTheme = buildWorkspaceTheme(
      lightTheme,
      AdminThemeColors.light,
    );
    final workspaceDarkTheme = buildWorkspaceTheme(
      darkTheme,
      AdminThemeColors.dark,
    );

    return SoundPreferenceSync(
      child: MaterialApp(
        key: ValueKey(genero ?? 'default'),
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: workspaceLightTheme,
        darkTheme: workspaceDarkTheme,
        themeMode: adminThemeMode,
        home: _buildHome(
          authState,
          primaryColor: isAdmin
              ? (adminThemeMode == ThemeMode.light
                    ? AppColors.adminLightLime
                    : AppColors.primary)
              : studentColors.primary,
        ),
      ),
    );
  }

  Widget _buildHome(AuthState authState, {required Color primaryColor}) {
    // O portal de recuperação é público para permitir pagar mesmo quando o
    // login foi bloqueado por atraso. A query só é usada no Web.
    final recoveryToken = Uri.base.queryParameters['recoveryToken'];
    if (recoveryToken != null && recoveryToken.isNotEmpty) {
      return PaymentRecoveryScreen(token: recoveryToken);
    }

    switch (authState.status) {
      case AuthStatus.initial:
      case AuthStatus.loading:
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.fitness_center, size: 64, color: primaryColor),
                const SizedBox(height: 24),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'A carregar...',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      case AuthStatus.authenticated:
        if (authState.isAdmin) {
          return const AdminPanelScreen();
        }
        if (authState.needsPrivacyPolicy) {
          return PrivacyPolicyScreen(user: authState.user!);
        }
        if (authState.needsQuestionnaire) {
          return QuestionnaireScreen(user: authState.user!);
        }
        return _AlunoShell(
          // O Checkout volta à raiz da aplicação; levar o utilizador
          // diretamente ao Perfil evita que tenha de procurar o pagamento.
          initialIndex: Uri.base.queryParameters['destino'] == 'perfil'
              ? 5
              : Uri.base.queryParameters['destino'] == 'chat'
              ? 4
              : 0,
        );
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return const LoginScreen();
    }
  }

  ThemeData _buildKineticDarkTheme([String? genero]) {
    final studentColors = StudentThemeColors.forGenero(genero);
    final interTextTheme = GoogleFonts.interTextTheme();
    final montserratTextTheme = GoogleFonts.montserratTextTheme();

    return ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _FadePageTransitionsBuilder(),
          TargetPlatform.iOS: _FadePageTransitionsBuilder(),
          TargetPlatform.macOS: _FadePageTransitionsBuilder(),
          TargetPlatform.windows: _FadePageTransitionsBuilder(),
          TargetPlatform.linux: _FadePageTransitionsBuilder(),
          TargetPlatform.fuchsia: _FadePageTransitionsBuilder(),
        },
      ),
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      splashColor: studentColors.primary.withValues(alpha: 0.12),
      highlightColor: studentColors.primary.withValues(alpha: 0.06),
      colorScheme: ColorScheme.dark(
        primary: studentColors.primary,
        onPrimary: AppColors.textOnPrimary,
        primaryContainer: studentColors.primaryContainer,
        onPrimaryContainer: studentColors.primary,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
      ),

      // ── Typography ───────────────────────────────────────────
      textTheme: TextTheme(
        // Headlines → Montserrat
        displayLarge: montserratTextTheme.displayLarge?.copyWith(
          fontSize: 40,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.02,
          color: AppColors.onSurface,
        ),
        displayMedium: montserratTextTheme.displayMedium?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.01,
          color: AppColors.onSurface,
        ),
        displaySmall: montserratTextTheme.displaySmall?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
        headlineLarge: montserratTextTheme.headlineLarge?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
        headlineMedium: montserratTextTheme.headlineMedium?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
        headlineSmall: montserratTextTheme.headlineSmall?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        // Body → Inter
        bodyLarge: interTextTheme.bodyLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          height: 1.55,
          color: AppColors.onSurface,
        ),
        bodyMedium: interTextTheme.bodyMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: AppColors.onSurface,
        ),
        bodySmall: interTextTheme.bodySmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        // Labels → Inter bold/medium
        labelLarge: interTextTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.05,
          color: AppColors.onSurface,
        ),
        labelMedium: interTextTheme.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        labelSmall: interTextTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),

      // ── AppBar ───────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceLow,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 68,
        scrolledUnderElevation: 2,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.surfaceLowest.withValues(alpha: 0.45),
        titleSpacing: 20,
        iconTheme: const IconThemeData(size: 21, color: AppColors.onSurface),
        actionsIconTheme: const IconThemeData(
          size: 21,
          color: AppColors.onSurfaceVariant,
        ),
        titleTextStyle: GoogleFonts.montserrat(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
      ),

      // ── Cards (superfície + contorno subtil) ─────────────────
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide.none,
        ),
        margin: const EdgeInsets.only(bottom: 16),
      ),

      // ── Input fields (superfície preenchida + foco claro) ────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: studentColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        floatingLabelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: studentColors.primary,
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.outlineVariant,
        ),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
      ),

      // ── Buttons ──────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: studentColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          disabledBackgroundColor: studentColors.primary.withValues(
            alpha: 0.45,
          ),
          disabledForegroundColor: AppColors.textOnPrimary.withValues(
            alpha: 0.7,
          ),
          elevation: 0,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.02,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onSurface,
          side: const BorderSide(color: AppColors.outline),
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: studentColors.primary,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Chips ────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceHigh,
        labelStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurface),
        selectedColor: studentColors.primary,
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          color: AppColors.textOnPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: AppColors.outline),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      // ── Dividers ─────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.outline,
        thickness: 1,
        space: 1,
      ),

      // ── Bottom Navigation Bar ────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: studentColors.primaryFixed,
        unselectedItemColor: AppColors.secondaryFixedDim,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceLow.withValues(alpha: 0.94),
        indicatorColor: studentColors.primaryFixed.withValues(alpha: 0.12),
        height: 78,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.surfaceLowest.withValues(alpha: 0.45),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: studentColors.primaryFixed,
            );
          }
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.secondaryFixedDim,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: studentColors.primaryFixed);
          }
          return const IconThemeData(color: AppColors.secondaryFixedDim);
        }),
      ),

      // ── Tab Bar ──────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: studentColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: studentColors.primary,
        dividerColor: AppColors.outline,
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

      // ── Snackbar ─────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceHighest,
        contentTextStyle: GoogleFonts.inter(
          color: AppColors.onSurface,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Dialogs ──────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceHigh,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.outline),
        ),
        titleTextStyle: GoogleFonts.montserrat(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          height: 1.45,
          color: AppColors.onSurfaceVariant,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      ),

      // ── Bottom sheets ────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surfaceHigh,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // ── ExpansionTile (evita warning "ink splashes invisíveis") ─
      expansionTileTheme: const ExpansionTileThemeData(
        backgroundColor: AppColors.surface,
        collapsedBackgroundColor: AppColors.surface,
        iconColor: AppColors.onSurface,
        collapsedIconColor: AppColors.textSecondary,
      ),

      // ── ListTile (tileColor explícito para splash visível) ──
      listTileTheme: ListTileThemeData(
        tileColor: AppColors.surface,
        textColor: AppColors.onSurface,
        iconColor: AppColors.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minVerticalPadding: 8,
      ),
    );
  }
}

/// Shell para navegação do aluno com BottomNavigationBar.
class _AlunoShell extends ConsumerStatefulWidget {
  final int initialIndex;

  const _AlunoShell({this.initialIndex = 0});

  @override
  ConsumerState<_AlunoShell> createState() => _AlunoShellState();
}

class _AlunoShellState extends ConsumerState<_AlunoShell> {
  late int _currentIndex;
  late final List<Widget> _screens;
  bool _fcmInitialized = false;
  bool _paymentReturnNoticeShown = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _screens = [
      AlunoHomeScreen(onNavigate: _selectDestination),
      const NutritionScreen(),
      const WorkoutScreen(),
      const CalendarScreen(),
      const ChatScreen(trackChatPresence: false),
      const ProfileScreen(),
    ];
    _initFCMIfNeeded();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showPaymentReturnNotice(),
    );
  }

  void _showPaymentReturnNotice() {
    if (!mounted || _paymentReturnNoticeShown) return;
    final status = Uri.base.queryParameters['pagamento'];
    if (status != 'sucesso' &&
        status != 'cancelado' &&
        status != 'falhou' &&
        status != 'failed') {
      return;
    }

    _paymentReturnNoticeShown = true;
    final succeeded = status == 'sucesso';
    showAppNotification(
      context,
      succeeded
          ? 'Pagamento efetuado com sucesso.'
          : 'O pagamento falhou ou foi cancelado.',
      type: succeeded ? NotificationType.success : NotificationType.error,
      duration: const Duration(seconds: 5),
    );
  }

  void _initFCMIfNeeded() {
    if (_fcmInitialized) return;
    final authState = ref.read(authProvider);
    final userId = authState.user?.uid;
    if (userId != null && userId.isNotEmpty) {
      _fcmInitialized = true;
      final fcmService = ref.read(fcmServiceProvider);
      fcmService.onForegroundMessage = (message) {
        if (mounted) FCMService.showLocalNotification(context, message);
      };
      fcmService.onNotificationOpened = (message) {
        if (!mounted) return;
        if (message.data['type'] == 'chat') {
          _selectDestination(4);
        }
      };
      fcmService.initialize(userId);
    }
  }

  void _selectDestination(int index) {
    if (index < 0 || index >= _screens.length || !mounted) return;
    setState(() => _currentIndex = index);
    final inChat = index == 4;
    Future.microtask(() {
      if (mounted) {
        ref.read(isAlunoInChatProvider.notifier).state = inChat;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authProvider).user?.uid ?? '';
    final directChatUnread =
        ref.watch(alunoUnreadCountProvider(userId)).value ?? 0;
    final groupChatUnread =
        ref.watch(alunoGroupUnreadCountProvider(userId)).value ?? 0;
    final chatUnreadCount = directChatUnread + groupChatUnread;
    final chatPreview = ref.watch(latestChatPreviewProvider(userId));
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final navigationDestinations = const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: AppStrings.tabHome,
      ),
      NavigationDestination(
        icon: Icon(Icons.restaurant_outlined),
        selectedIcon: Icon(Icons.restaurant),
        label: AppStrings.tabNutrition,
      ),
      NavigationDestination(
        icon: Icon(Icons.fitness_center_outlined),
        selectedIcon: Icon(Icons.fitness_center),
        label: AppStrings.tabWorkout,
      ),
      NavigationDestination(
        icon: Icon(Icons.calendar_today_outlined),
        selectedIcon: Icon(Icons.calendar_today),
        label: AppStrings.tabAgenda,
      ),
      NavigationDestination(
        icon: Icon(Icons.chat_outlined),
        selectedIcon: Icon(Icons.chat),
        label: AppStrings.tabChat,
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: AppStrings.tabProfile,
      ),
    ];

    // Monta apenas a aba atual. O IndexedStack mantinha todos os ecrãs
    // vivos ao mesmo tempo e cada um abria listeners Firestore (diário,
    // agenda, chat, perfil e pagamentos), mesmo quando a aba não estava
    // visível. Isso criava dezenas de canais Listen simultâneos no Web.
    final content = AppPageFrame(
      maxWidth: isWide ? 1440 : double.infinity,
      padding: EdgeInsets.zero,
      child: Align(
        alignment: Alignment.topCenter,
        child: FadeSlideSwitcher(
          child: KeyedSubtree(
            key: ValueKey('aluno_tab_$_currentIndex'),
            child: _screens[_currentIndex],
          ),
        ),
      ),
    );

    return Scaffold(
      body: isWide
          ? Row(
              children: [
                StudentNavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: _selectDestination,
                  destinations: navigationDestinations,
                  chatUnreadCount: chatUnreadCount,
                  chatPreview: chatPreview,
                ),
                Expanded(child: content),
              ],
            )
          : content,
      bottomNavigationBar: isWide
          ? null
          : StudentFloatingDock(
              selectedIndex: _currentIndex,
              onDestinationSelected: _selectDestination,
              destinations: navigationDestinations,
              chatUnreadCount: chatUnreadCount,
              chatPreview: chatPreview,
            ),
    );
  }
}
