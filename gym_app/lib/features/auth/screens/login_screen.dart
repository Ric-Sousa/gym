import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/config/app_colors.dart';
import '../../../core/config/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../../shared/widgets/app_notification.dart';
import '../../../shared/widgets/app_page_frame.dart';
import '../providers/auth_provider.dart';

const _loginBackground = AppColors.background;
const _loginPanel = AppColors.surfaceLow;
const _loginField = AppColors.surface;
const _loginBorder = AppColors.outline;
const _loginMuted = AppColors.textSecondary;
const _loginAccent = AppColors.onSurface;
const _loginAccentSoft = AppColors.outlineVariant;
const _loginFocusBorder = AppColors.outline;
const _loginButtonBackground = AppColors.surfaceHighest;
const _loginButtonText = AppColors.onSurface;
const _loginError = AppColors.onSurface;

/// Ecrã de login — Kinetic Dark.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSendingPasswordReset = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authProvider.notifier)
        .signIn(_emailController.text.trim(), _passwordController.text);
  }

  Future<void> _handleForgotPassword() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _PasswordResetDialog(
        initialEmail: _emailController.text.trim(),
      ),
    );

    if (result == null || result.isEmpty || !mounted) return;

    setState(() => _isSendingPasswordReset = true);
    final error = await ref
        .read(authProvider.notifier)
        .sendPasswordResetEmail(result);
    if (!mounted) return;
    setState(() => _isSendingPasswordReset = false);
    showAppNotification(
      context,
      error ?? AppStrings.passwordResetSent,
      type: error != null ? NotificationType.error : NotificationType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    final theme = Theme.of(context);
    final loginTheme = theme.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _loginBackground,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      colorScheme: theme.colorScheme.copyWith(
        primary: _loginButtonBackground,
        onPrimary: _loginButtonText,
        primaryContainer: AppColors.surfaceHighest,
        onPrimaryContainer: AppColors.onSurface,
        surface: _loginPanel,
        onSurface: Colors.white,
        outline: _loginBorder,
        outlineVariant: AppColors.outlineVariant,
        error: _loginError,
        onError: _loginButtonText,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: _loginBorder,
        selectionColor: _loginBorder.withValues(alpha: 0.28),
        selectionHandleColor: _loginBorder,
      ),
      cardTheme: theme.cardTheme.copyWith(
        color: _loginPanel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide.none,
        ),
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: _loginField,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _loginBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _loginBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _loginFocusBorder, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _loginError),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _loginError, width: 1.4),
        ),
        labelStyle: GoogleFonts.inter(color: _loginMuted),
        floatingLabelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: _loginMuted,
        ),
        hintStyle: GoogleFonts.inter(color: _loginMuted),
        prefixIconColor: _loginMuted,
        suffixIconColor: _loginMuted,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _loginButtonBackground,
          foregroundColor: _loginButtonText,
          disabledBackgroundColor: _loginAccentSoft,
          disabledForegroundColor: _loginButtonText.withValues(alpha: 0.7),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _loginAccent),
      ),
      dialogTheme: theme.dialogTheme.copyWith(
        backgroundColor: _loginPanel,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.montserrat(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFFD0D0D0),
        ),
      ),
    );

    return Theme(
      data: loginTheme,
      child: Scaffold(
        backgroundColor: _loginBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: AppPageFrame(
              maxWidth: 480,
              padding: EdgeInsets.zero,
              child: Card(
                color: _loginPanel,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo — brilho neutro em cinza
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _loginAccent.withValues(alpha: 0.1),
                            border: Border.all(
                              color: _loginAccent.withValues(alpha: 0.35),
                              width: 2,
                            ),
                            boxShadow: const [],
                          ),
                          child: const Icon(
                            Icons.fitness_center,
                            size: 36,
                            color: _loginAccent,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          AppStrings.appName,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.01,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppStrings.appTagline,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 48),

                        // E-mail
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: GoogleFonts.inter(color: AppColors.onSurface),
                          decoration: const InputDecoration(
                            labelText: AppStrings.email,
                            hintText: AppStrings.emailHint,
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: Validators.email,
                        ),
                        const SizedBox(height: 20),

                        // Password
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleLogin(),
                          style: GoogleFonts.inter(color: AppColors.onSurface),
                          decoration: InputDecoration(
                            labelText: AppStrings.password,
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: Validators.password,
                        ),
                        const SizedBox(height: 4),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isSendingPasswordReset
                                ? null
                                : _handleForgotPassword,
                            child: Text(
                              AppStrings.forgotPassword,
                              style: GoogleFonts.inter(
                                color: _loginAccent,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Login button
                        LoadingButton(
                          label: AppStrings.login,
                          isLoading: authState.status == AuthStatus.loading,
                          onPressed: _handleLogin,
                          icon: Icons.login,
                        ),

                        // Error message
                        if (authState.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _loginAccentSoft.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _loginAccent.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: _loginAccent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    authState.errorMessage!,
                                    style: GoogleFonts.inter(
                                      color: _loginAccent,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
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

class _PasswordResetDialog extends StatefulWidget {
  final String initialEmail;

  const _PasswordResetDialog({required this.initialEmail});

  @override
  State<_PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<_PasswordResetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final dialogTheme = baseTheme.copyWith(
      brightness: Brightness.dark,
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: _loginButtonBackground,
        onPrimary: _loginButtonText,
        surface: _loginPanel,
        onSurface: AppColors.onSurface,
        outline: _loginBorder,
        outlineVariant: AppColors.outlineVariant,
        error: _loginError,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: _loginBorder,
        selectionColor: _loginBorder.withValues(alpha: 0.28),
        selectionHandleColor: _loginBorder,
      ),
      dialogTheme: baseTheme.dialogTheme.copyWith(
        backgroundColor: _loginPanel,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: _loginField,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _loginBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _loginBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _loginFocusBorder, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _loginError),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _loginError, width: 1),
        ),
        labelStyle: GoogleFonts.inter(color: _loginMuted),
        floatingLabelStyle: GoogleFonts.inter(color: _loginMuted),
        hintStyle: GoogleFonts.inter(color: _loginMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _loginButtonBackground,
          foregroundColor: _loginButtonText,
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _loginAccent),
      ),
    );

    return Theme(
      data: dialogTheme,
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      title: Text(
        AppStrings.forgotPassword,
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          cursorColor: _loginBorder,
          style: GoogleFonts.inter(color: _loginButtonText),
          decoration: InputDecoration(
            hintText: AppStrings.emailHint,
            labelText: AppStrings.email,
            filled: true,
            fillColor: _loginField,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _loginBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _loginBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _loginFocusBorder, width: 1),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _loginError),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _loginError, width: 1),
            ),
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          validator: Validators.email,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(onPressed: _submit, child: const Text('Enviar')),
        ],
      ),
    );
  }
}
