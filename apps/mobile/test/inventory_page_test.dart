import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coffee_management_mobile/features/auth/domain/auth_session.dart';
import 'package:coffee_management_mobile/features/auth/domain/auth_user.dart';
import 'package:coffee_management_mobile/features/auth/domain/staff_role.dart';
import 'package:coffee_management_mobile/features/auth/presentation/auth_controller.dart';
import 'package:coffee_management_mobile/features/inventory/domain/exact_quantity.dart';
import 'package:coffee_management_mobile/features/inventory/domain/inventory_filter.dart';
import 'package:coffee_management_mobile/features/inventory/domain/inventory_item.dart';
import 'package:coffee_management_mobile/features/inventory/domain/inventory_repository.dart'
    hide InventoryPage;
import 'package:coffee_management_mobile/features/inventory/domain/inventory_repository.dart'
    as inv
    show InventoryPage;
import 'package:coffee_management_mobile/features/inventory/domain/product_recipe.dart';
import 'package:coffee_management_mobile/features/inventory/domain/stock_movement.dart';
import 'package:coffee_management_mobile/features/inventory/presentation/inventory_controller.dart';
import 'package:coffee_management_mobile/features/inventory/presentation/inventory_detail_page.dart';
import 'package:coffee_management_mobile/features/inventory/presentation/inventory_page.dart';
import 'package:coffee_management_mobile/features/inventory/presentation/recipe_editor_page.dart';
import 'package:coffee_management_mobile/features/inventory/presentation/widgets/inventory_item_form_dialog.dart';
import 'package:coffee_management_mobile/features/inventory/presentation/widgets/stock_movement_dialog.dart';
import 'package:coffee_management_mobile/shared/theme/app_theme.dart';

import 'auth_controller_test.dart';
import 'pos_test_support.dart';

ExactQuantity _qty(int units) =>
    ExactQuantity.fromSubunits(units * ExactQuantity.scale);

InventoryItem _testItem({
  int id = 1,
  String sku = 'BEAN-ARABICA',
  String name = 'Arabica Beans',
  BaseUnit baseUnit = BaseUnit.g,
  ExactQuantity? onHand,
  ExactQuantity? reserved,
  ExactQuantity? available,
  ExactQuantity? reorderLevel,
  bool isActive = true,
  bool lowStock = false,
}) {
  return InventoryItem(
    id: id,
    sku: sku,
    name: name,
    baseUnit: baseUnit,
    onHand: onHand ?? _qty(1000),
    reserved: reserved ?? _qty(100),
    available: available ?? _qty(900),
    reorderLevel: reorderLevel ?? _qty(200),
    isActive: isActive,
    lowStock: lowStock,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

class FakeInventoryRepo implements InventoryRepository {
  List<InventoryItem> itemsList = [
    _testItem(id: 1, sku: 'BEAN-ARABICA', name: 'Arabica Beans'),
    _testItem(
      id: 2,
      sku: 'MILK-OAT',
      name: 'Oat Milk',
      baseUnit: BaseUnit.ml,
      onHand: _qty(50),
      available: _qty(50),
      reorderLevel: _qty(100),
      lowStock: true,
    ),
  ];

  @override
  Future<inv.InventoryPage> getItems(InventoryFilter filter) async {
    var result = List<InventoryItem>.from(itemsList);
    if (filter.search != null && filter.search!.isNotEmpty) {
      final q = filter.search!.toLowerCase();
      result = result
          .where(
            (i) =>
                i.name.toLowerCase().contains(q) ||
                i.sku.toLowerCase().contains(q),
          )
          .toList();
    }
    if (filter.lowStock == true) {
      result = result.where((i) => i.lowStock).toList();
    }
    if (filter.status != 'all') {
      final active = filter.status == 'active';
      result = result.where((i) => i.isActive == active).toList();
    }

    return inv.InventoryPage(
      items: result,
      currentPage: filter.page,
      lastPage: 1,
      perPage: filter.perPage,
      total: result.length,
    );
  }

  @override
  Future<InventoryItem> getItem(int id) async {
    return itemsList.firstWhere(
      (i) => i.id == id,
      orElse: () => _testItem(id: id),
    );
  }

  @override
  Future<InventoryItem> createItem({
    required String sku,
    required String name,
    required BaseUnit baseUnit,
    ExactQuantity? reorderLevel,
    bool isActive = true,
  }) async {
    final newItem = _testItem(
      id: itemsList.length + 1,
      sku: sku,
      name: name,
      baseUnit: baseUnit,
      reorderLevel: reorderLevel,
      isActive: isActive,
    );
    itemsList.insert(0, newItem);
    return newItem;
  }

  @override
  Future<InventoryItem> updateItem(
    int id, {
    String? sku,
    String? name,
    ExactQuantity? reorderLevel,
    bool? isActive,
  }) async {
    final index = itemsList.indexWhere((i) => i.id == id);
    if (index >= 0) {
      final existing = itemsList[index];
      final updated = existing.copyWith(
        sku: sku,
        name: name,
        reorderLevel: reorderLevel,
        isActive: isActive,
      );
      itemsList[index] = updated;
      return updated;
    }
    return _testItem(id: id, sku: sku ?? 'SKU-$id', name: name ?? 'Item $id');
  }

  @override
  Future<StockMovement> createMovement(StockMovementIntent intent) async {
    return StockMovement(
      id: 99,
      inventoryItemId: intent.inventoryItemId,
      quantityDelta: intent.quantityDelta,
      reason: intent.reason,
      note: intent.note,
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  Future<StockMovementPage> getMovements(
    int itemId, {
    int page = 1,
    int perPage = 25,
  }) async {
    return StockMovementPage(
      items: [
        StockMovement(
          id: 1,
          inventoryItemId: itemId,
          quantityDelta: _qty(500),
          reason: StockMovementReason.receipt,
          note: 'Initial batch',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ],
      currentPage: page,
      lastPage: 1,
      perPage: perPage,
      total: 1,
    );
  }

  @override
  Future<ProductRecipe> getRecipe(int productId) async {
    return ProductRecipe(
      productId: productId,
      ingredients: [
        RecipeIngredient(
          inventoryItemId: 1,
          sku: 'BEAN-ARABICA',
          name: 'Arabica Beans',
          baseUnit: BaseUnit.g,
          isActive: true,
          quantity: _qty(18),
        ),
      ],
    );
  }

  @override
  Future<ProductRecipe> replaceRecipe(
    int productId,
    List<RecipeIngredientPayload> ingredients,
  ) async {
    return ProductRecipe(
      productId: productId,
      ingredients: ingredients
          .map(
            (p) => RecipeIngredient(
              inventoryItemId: p.inventoryItemId,
              sku: 'SKU-${p.inventoryItemId}',
              name: 'Item ${p.inventoryItemId}',
              baseUnit: BaseUnit.g,
              isActive: true,
              quantity: p.quantity,
            ),
          )
          .toList(),
    );
  }
}

void main() {
  const cashierUser = AuthUser(
    id: 1,
    name: 'Cashier Sophea',
    email: 'sophea@example.test',
    role: StaffRole.cashier,
    permissions: ['view-inventory'],
  );

  const managerUser = AuthUser(
    id: 2,
    name: 'Manager Vibol',
    email: 'vibol@example.test',
    role: StaffRole.manager,
    permissions: ['view-inventory', 'adjust-inventory', 'manage-catalog'],
  );

  AuthSession makeSession(AuthUser user) {
    return AuthSession(
      user: user,
      token: 'test-sanctum-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 8)),
    );
  }

  late FakeInventoryRepo inventoryRepo;
  late InventoryController inventoryController;
  late FakeCatalogRepository catalogRepo;

  setUp(() {
    inventoryRepo = FakeInventoryRepo();
    inventoryController = InventoryController(
      repository: inventoryRepo,
      keyGenerator: () => 'fixed-key-00001',
    );
    catalogRepo = FakeCatalogRepository();
  });

  tearDown(() {
    inventoryController.dispose();
  });

  Future<void> pumpInventoryApp(
    WidgetTester tester, {
    required AuthUser user,
    Size size = const Size(390, 844),
    double textScale = 1.0,
    bool dark = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeAuthRepo = FakeAuthRepository(initialSession: makeSession(user));
    final authController = AuthController(repository: fakeAuthRepo);
    await authController.restoreSession();

    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.buildDarkTheme() : AppTheme.buildLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: InventoryPage(
          controller: inventoryController,
          authController: authController,
          catalogRepository: catalogRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('InventoryPage - Compact Phone Layout (<600dp)', () {
    testWidgets(
      'renders inventory title, search bar, filter chips, and stock items',
      (tester) async {
        await pumpInventoryApp(tester, user: cashierUser);

        expect(find.text('Inventory'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('All'), findsOneWidget);
        expect(find.widgetWithText(ChoiceChip, 'Low Stock'), findsOneWidget);
        expect(find.text('Active'), findsOneWidget);
        expect(find.text('Inactive'), findsOneWidget);

        expect(find.text('Arabica Beans'), findsOneWidget);
        expect(find.text('Oat Milk'), findsOneWidget);
        expect(find.text('Low Stock'), findsWidgets);
      },
    );

    testWidgets('Cashier role cannot see New Item button', (tester) async {
      await pumpInventoryApp(tester, user: cashierUser);

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('New Item'), findsNothing);
    });

    testWidgets(
      'Manager role sees New Item button and tapping it opens create dialog',
      (tester) async {
        await pumpInventoryApp(tester, user: managerUser);

        final fab = find.byType(FloatingActionButton);
        expect(fab, findsOneWidget);

        await tester.tap(fab);
        await tester.pumpAndSettle();

        expect(find.byType(InventoryItemFormDialog), findsOneWidget);
        expect(find.text('New Inventory Item'), findsOneWidget);
      },
    );

    testWidgets('tapping item card opens InventoryDetailPage on phone layout', (
      tester,
    ) async {
      await pumpInventoryApp(tester, user: managerUser);

      await tester.tap(find.text('Arabica Beans'));
      await tester.pumpAndSettle();

      expect(find.byType(InventoryDetailPage), findsOneWidget);
      expect(find.text('Arabica Beans'), findsWidgets);
      expect(find.text('Available Stock'), findsOneWidget);
      expect(find.text('On Hand'), findsOneWidget);
      expect(find.text('Reserved (in active cart/order)'), findsOneWidget);
      expect(find.text('Reorder Threshold'), findsOneWidget);

      // Manager can see Record Stock Movement and Edit
      expect(find.text('Record Stock Movement'), findsOneWidget);
      expect(find.text('Edit Item'), findsOneWidget);

      // Tap Record Stock Movement opens StockMovementDialog
      await tester.tap(find.text('Record Stock Movement'));
      await tester.pumpAndSettle();

      expect(find.byType(StockMovementDialog), findsOneWidget);
      expect(find.text('Record Stock Movement'), findsWidgets);
    });

    testWidgets(
      'Cashier in InventoryDetailPage does not see Adjust Stock action',
      (tester) async {
        await pumpInventoryApp(tester, user: cashierUser);

        await tester.tap(find.text('Arabica Beans'));
        await tester.pumpAndSettle();

        expect(find.byType(InventoryDetailPage), findsOneWidget);
        expect(find.text('Record Stock Movement'), findsNothing);
        expect(find.text('Edit Item'), findsNothing);
      },
    );

    testWidgets(
      'Manager sees Product Recipes action in AppBar and tapping opens RecipeEditorPage',
      (tester) async {
        await pumpInventoryApp(tester, user: managerUser);

        final recipeBtn = find.byTooltip('Product Recipes');
        expect(recipeBtn, findsOneWidget);

        await tester.tap(recipeBtn);
        await tester.pumpAndSettle();

        expect(find.byType(RecipeEditorPage), findsOneWidget);
        expect(find.text('Product Recipes'), findsOneWidget);
      },
    );

    testWidgets('Cashier does NOT see Product Recipes action in AppBar', (
      tester,
    ) async {
      await pumpInventoryApp(tester, user: cashierUser);

      expect(find.byTooltip('Product Recipes'), findsNothing);
    });
  });

  group('InventoryPage - Tablet Split Master-Detail Layout (≥600dp)', () {
    testWidgets(
      'renders split layout with placeholder initially, and updates right pane on tap',
      (tester) async {
        await pumpInventoryApp(
          tester,
          user: managerUser,
          size: const Size(1024, 768),
        );

        // Master list visible
        expect(find.text('Arabica Beans'), findsOneWidget);
        expect(find.text('Oat Milk'), findsOneWidget);

        // Right detail pane initially shows selection placeholder
        expect(find.text('No Item Selected'), findsOneWidget);

        // Tap Arabica Beans in master list
        await tester.tap(find.text('Arabica Beans'));
        await tester.pumpAndSettle();

        // Right pane now shows Arabica Beans details in-place without pushing route
        expect(find.byType(InventoryDetailPage), findsNothing);
        expect(find.text('No Item Selected'), findsNothing);
        expect(find.text('Record Stock Movement'), findsOneWidget);
        expect(find.text('Movement History'), findsOneWidget);
      },
    );
  });

  group('InventoryPage - Search and Filtering', () {
    testWidgets('filtering by Low Stock shows only low stock items', (
      tester,
    ) async {
      await pumpInventoryApp(tester, user: cashierUser);

      expect(find.text('Arabica Beans'), findsOneWidget);
      expect(find.text('Oat Milk'), findsOneWidget);

      // Tap Low Stock chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Low Stock'));
      await tester.pumpAndSettle();

      expect(find.text('Arabica Beans'), findsNothing);
      expect(find.text('Oat Milk'), findsOneWidget);
    });

    testWidgets('entering query in search bar filters list', (tester) async {
      await pumpInventoryApp(tester, user: cashierUser);

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Arabica');
      // Await 350ms for debounce
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Arabica Beans'), findsOneWidget);
      expect(find.text('Oat Milk'), findsNothing);
    });
  });

  group('InventoryPage - Responsiveness & Accessibility (2.0x Text Scale)', () {
    testWidgets(
      'renders without overflow at 2.0x text scaling on compact 320x720 phone',
      (tester) async {
        await pumpInventoryApp(
          tester,
          user: managerUser,
          size: const Size(320, 720),
          textScale: 2.0,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Inventory'), findsOneWidget);
      },
    );

    testWidgets(
      'renders without overflow at 2.0x text scaling on tablet 1024x768',
      (tester) async {
        await pumpInventoryApp(
          tester,
          user: managerUser,
          size: const Size(1024, 768),
          textScale: 2.0,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Inventory'), findsOneWidget);
      },
    );
  });
}
