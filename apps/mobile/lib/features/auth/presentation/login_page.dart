import 'package:flutter/material.dart';

import '../../../shared/theme/app_breakpoints.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/theme/cafe_theme_extension.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../domain/auth_failure.dart';
import 'auth_controller.dart';

/// Primary login screen for staff access to the Coffee Management System.
///
/// Implements the Premium Café OS aesthetic, 48px touch targets, Khmer-ready
/// bilingual typography, accessible form controls, and responsive layout.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.authController});

  final AuthController authController;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  String? _clientEmailError;
  String? _clientPasswordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _clientEmailError = null;
      _clientPasswordError = null;
    });

    var hasLocalError = false;
    if (email.isEmpty) {
      setState(() => _clientEmailError = 'Email is required.');
      hasLocalError = true;
    } else if (!email.contains('@')) {
      setState(() => _clientEmailError = 'Enter a valid email address.');
      hasLocalError = true;
    }

    if (password.isEmpty) {
      setState(() => _clientPasswordError = 'Password is required.');
      hasLocalError = true;
    }

    if (hasLocalError) return;

    final success = await widget.authController.login(email, password);
    if (mounted && success) {
      _passwordController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cafeExt = CafeThemeExtension.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final horizontalPadding = AppBreakpoints.horizontalPadding(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: AppSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440.0),
              child: ListenableBuilder(
                listenable: widget.authController,
                builder: (context, _) {
                  final state = widget.authController.state;
                  final isLoading = widget.authController.isAuthenticating;
                  final failure = state is Unauthenticated
                      ? state.failure
                      : null;

                  return AutofillGroup(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- Brand Header ---
                        _buildBrandHeader(context, cafeExt, isDark),
                        AppSpacing.gapVerticalXl,

                        // --- Login Card ---
                        AppCard(
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Staff Sign In',
                                style: AppTypography.title.copyWith(
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              AppSpacing.gapVerticalXs,
                              Text(
                                'Enter your assigned café credentials',
                                style: AppTypography.small.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              AppSpacing.gapVerticalLg,

                              // Failure Banner
                              if (failure != null) ...[
                                _buildErrorBanner(context, failure, cafeExt),
                                AppSpacing.gapVerticalLg,
                              ],

                              // Email Input
                              AppTextField(
                                label: 'Email',
                                controller: _emailController,
                                hintText: 'staff@example.test',
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                enabled: !isLoading,
                                prefixIcon: const Icon(Icons.mail_outline),
                                errorText:
                                    _clientEmailError ??
                                    (failure is ValidationFailure
                                        ? failure.firstErrorFor('email')
                                        : null),
                                onSubmitted: (_) =>
                                    _passwordFocus.requestFocus(),
                              ),
                              AppSpacing.gapVerticalMd,

                              // Password Input
                              AppTextField(
                                label: 'Password',
                                controller: _passwordController,
                                focusNode: _passwordFocus,
                                hintText: '••••••••••••',
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                enabled: !isLoading,
                                prefixIcon: const Icon(Icons.lock_outline),
                                errorText:
                                    _clientPasswordError ??
                                    (failure is ValidationFailure
                                        ? failure.firstErrorFor('password')
                                        : null),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 20.0,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                onSubmitted: (_) => _handleSubmit(),
                              ),
                              AppSpacing.gapVerticalXl,

                              // Sign In Button
                              AppButton(
                                label: 'Sign In',
                                isLoading: isLoading,
                                isFullWidth: true,
                                leadingIcon: Icons.login_rounded,
                                onPressed: isLoading ? null : _handleSubmit,
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.gapVerticalLg,

                        // --- Footer / Security Note ---
                        Center(
                          child: Text(
                            'Authorized Staff Only • Secured via Laravel Sanctum',
                            style: AppTypography.small.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader(
    BuildContext context,
    CafeThemeExtension cafeExt,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkElevated : AppColors.latte,
            shape: BoxShape.circle,
            border: Border.all(
              color: cafeExt.accentCaramel.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.local_cafe_rounded,
            size: 32,
            color: cafeExt.accentCaramel,
          ),
        ),
        AppSpacing.gapVerticalMd,
        Text(
          'Coffee Management System',
          style: AppTypography.h2.copyWith(color: theme.colorScheme.onSurface),
          textAlign: TextAlign.center,
        ),
        AppSpacing.gapVerticalXs,
        // Khmer bilingual line
        Text(
          'ប្រព័ន្ធគ្រប់គ្រងហាងកាហ្វេ',
          style: AppTypography.label.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildErrorBanner(
    BuildContext context,
    AuthFailure failure,
    CafeThemeExtension cafeExt,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cafeExt.errorSurface,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(
          color: cafeExt.errorOnSurface.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 20.0, color: cafeExt.errorOnSurface),
          AppSpacing.gapHorizontalSm,
          Expanded(
            child: Text(
              failure.userMessage,
              style: AppTypography.small.copyWith(
                color: cafeExt.errorOnSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
