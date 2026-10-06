import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config/app_config.dart';
import 'core/network/api_client.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/auth_token_store.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/shell/presentation/adaptive_app_shell.dart';
import 'shared/theme/app_spacing.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/app_typography.dart';
import 'shared/widgets/app_button.dart';
import 'shared/widgets/app_card.dart';
import 'shared/widgets/app_loading_indicator.dart';

/// Root application widget for the Coffee Management System mobile & tablet client.
///
/// Implements feature-first composition root, dependency injection for testing,
/// and reactive session routing between initializing, login, and authenticated states.
class CoffeeManagementApp extends StatefulWidget {
  const CoffeeManagementApp({
    super.key,
    this.authController,
    this.initialThemeMode = ThemeMode.light,
  });

  /// Injected controller for test isolation and custom mock setups.
  final AuthController? authController;
  final ThemeMode initialThemeMode;

  @override
  State<CoffeeManagementApp> createState() => _CoffeeManagementAppState();
}

class _CoffeeManagementAppState extends State<CoffeeManagementApp> {
  late final AuthController _authController;
  late final http.Client? _ownedHttpClient;
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;

    if (widget.authController != null) {
      _authController = widget.authController!;
      _ownedHttpClient = null;
    } else {
      final client = http.Client();
      _ownedHttpClient = client;
      final apiClient = ApiClient(
        client: client,
        baseUrl: AppConfig.apiBaseUrl,
      );
      final tokenStore = AuthTokenStore.create();
      final authApi = AuthApi(client: apiClient);
      final authRepository = AuthRepository(
        api: authApi,
        tokenStore: tokenStore,
      );
      _authController = AuthController(repository: authRepository);
      _authController.restoreSession();
    }
  }

  @override
  void dispose() {
    if (_ownedHttpClient != null) {
      _authController.dispose();
      _ownedHttpClient.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coffee Management System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildLightTheme(),
      darkTheme: AppTheme.buildDarkTheme(),
      themeMode: _themeMode,
      home: ListenableBuilder(
        listenable: _authController,
        builder: (context, _) {
          final state = _authController.state;

          if (state is AuthInitializing) {
            return const Scaffold(
              body: Center(
                child: AppLoadingIndicator(
                  size: 36.0,
                  message: 'Verifying session...',
                ),
              ),
            );
          }

          if (state is Authenticated) {
            return AdaptiveAppShell(
              authController: _authController,
              currentThemeMode: _themeMode,
              onToggleTheme: () {
                setState(() {
                  _themeMode = _themeMode == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
                });
              },
            );
          }

          if (state is SessionVerificationFailed) {
            return _buildVerificationFailedScreen(context, state);
          }

          return LoginPage(authController: _authController);
        },
      ),
    );
  }

  Widget _buildVerificationFailedScreen(
    BuildContext context,
    SessionVerificationFailed state,
  ) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440.0),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 48.0,
                      color: theme.colorScheme.error,
                    ),
                    AppSpacing.gapVerticalMd,
                    Text(
                      'Session Verification Failed',
                      style: AppTypography.title.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.gapVerticalSm,
                    Text(
                      state.message,
                      style: AppTypography.body.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.gapVerticalXl,
                    AppButton(
                      label: 'Retry Connection',
                      isFullWidth: true,
                      leadingIcon: Icons.refresh_rounded,
                      onPressed: () => _authController.restoreSession(),
                    ),
                    AppSpacing.gapVerticalSm,
                    AppButton(
                      label: 'Sign In As Different Staff',
                      variant: AppButtonVariant.outline,
                      isFullWidth: true,
                      onPressed: () {
                        // Clear transient error and allow re-login
                        _authController.clearError();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
