import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config/app_config.dart';
import 'core/network/api_client.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/auth_token_store.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/inventory/data/api_inventory_repository.dart';
import 'features/inventory/domain/inventory_repository.dart';
import 'features/inventory/presentation/inventory_controller.dart';
import 'features/orders/data/api_order_history_repository.dart';
import 'features/orders/domain/order_history_repository.dart';
import 'features/orders/presentation/orders_controller.dart';
import 'features/pos/data/api_catalog_repository.dart';
import 'features/pos/data/api_checkout_repository.dart';
import 'features/pos/domain/catalog_repository.dart';
import 'features/pos/domain/checkout_repository.dart';
import 'features/pos/presentation/pos_controller.dart';
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
    this.catalogRepository,
    this.checkoutRepository,
    this.orderHistoryRepository,
    this.inventoryRepository,
    this.initialThemeMode = ThemeMode.light,
  });

  /// Injected controller for test isolation and custom mock setups.
  final AuthController? authController;
  final CatalogRepository? catalogRepository;
  final CheckoutRepository? checkoutRepository;
  final OrderHistoryRepository? orderHistoryRepository;
  final InventoryRepository? inventoryRepository;
  final ThemeMode initialThemeMode;

  @override
  State<CoffeeManagementApp> createState() => _CoffeeManagementAppState();
}

class _CoffeeManagementAppState extends State<CoffeeManagementApp> {
  late final AuthController _authController;
  late final http.Client? _ownedHttpClient;
  late ThemeMode _themeMode;
  ApiClient? _apiClient;
  PosController? _posController;
  String? _posToken;
  OrdersController? _ordersController;
  String? _ordersToken;
  InventoryController? _inventoryController;
  String? _inventoryToken;
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;

    if (widget.authController == null ||
        widget.catalogRepository == null ||
        widget.checkoutRepository == null ||
        widget.orderHistoryRepository == null ||
        widget.inventoryRepository == null) {
      final client = http.Client();
      _ownedHttpClient = client;
      _apiClient = ApiClient(client: client, baseUrl: AppConfig.apiBaseUrl);
    } else {
      _ownedHttpClient = null;
    }
    if (widget.authController != null) {
      _authController = widget.authController!;
    } else {
      final tokenStore = AuthTokenStore.create();
      final authApi = AuthApi(client: _apiClient!);
      final authRepository = AuthRepository(
        api: authApi,
        tokenStore: tokenStore,
      );
      _authController = AuthController(repository: authRepository);
    }
    _authController.addListener(_syncSessions);
    _syncSessions();
    if (widget.authController == null) _authController.restoreSession();
  }

  void _syncSessions() {
    final state = _authController.state;
    final token = state is Authenticated ? state.session.token : null;

    // --- POS Session Sync ---
    if (_posToken != token) {
      _posController?.dispose();
      _posToken = token;
      _posController =
          token == null ||
              (state is Authenticated &&
                  !state.user.hasPermission('process-pos'))
          ? null
          : PosController(
              checkoutRepository:
                  widget.checkoutRepository ??
                  ApiCheckoutRepository(client: _apiClient!, token: token),
              repository:
                  widget.catalogRepository ??
                  ApiCatalogRepository(client: _apiClient!, token: token),
              onSessionExpired: () =>
                  _authController.invalidateSession(token: token),
            );
    }

    // --- Orders Session Sync ---
    if (_ordersToken != token) {
      _ordersController?.dispose();
      _ordersToken = token;
      final canViewOrders =
          state is Authenticated &&
          (state.user.hasPermission('view-own-orders') ||
              state.user.hasPermission('view-all-orders'));
      _ordersController = token == null || !canViewOrders
          ? null
          : OrdersController(
              repository:
                  widget.orderHistoryRepository ??
                  ApiOrderHistoryRepository(client: _apiClient!, token: token),
              onSessionExpired: () =>
                  _authController.invalidateSession(token: token),
            );
    }

    // --- Inventory Session Sync ---
    if (_inventoryToken != token) {
      _inventoryController?.dispose();
      _inventoryToken = token;
      final canViewInventory =
          state is Authenticated && state.user.hasPermission('view-inventory');
      _inventoryController = token == null || !canViewInventory
          ? null
          : InventoryController(
              repository:
                  widget.inventoryRepository ??
                  ApiInventoryRepository(client: _apiClient!, token: token),
              catalogRepository:
                  widget.catalogRepository ??
                  ApiCatalogRepository(client: _apiClient!, token: token),
              onSessionExpired: () =>
                  _authController.invalidateSession(token: token),
            );
    }

    // Session boundaries also dismiss any POS sheets/dialogs from the old user.
    _navigatorKey = GlobalKey<NavigatorState>();
    setState(() {});
  }

  @override
  void dispose() {
    _authController.removeListener(_syncSessions);
    _posController?.dispose();
    _ordersController?.dispose();
    _inventoryController?.dispose();
    if (widget.authController == null) _authController.dispose();
    _ownedHttpClient?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
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
              posController: _posController,
              ordersController: _ordersController,
              inventoryController: _inventoryController,
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
