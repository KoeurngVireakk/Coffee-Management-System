/// Mobile/tablet fixture preview entrypoint. NOT imported by lib/main.dart.
///
/// All requests use an in-process MockClient. There is no live API access,
/// persistent token storage, or successful write/payment operation.
/// Run: `flutter run -d DEVICE_ID -t tool/luna_audit_preview.dart`
/// Defines: AUDIT_ROLE=cashier|manager|admin|login, AUDIT_THEME=light|dark,
/// AUDIT_STATE=data|empty|error|loading. Query overrides are for debug tooling.
library;

import 'dart:async';
import 'dart:convert';

import 'package:coffee_management_mobile/app.dart';
import 'package:coffee_management_mobile/core/network/api_client.dart';
import 'package:coffee_management_mobile/features/auth/data/auth_api.dart';
import 'package:coffee_management_mobile/features/auth/data/auth_repository.dart';
import 'package:coffee_management_mobile/features/auth/data/auth_token_store.dart';
import 'package:coffee_management_mobile/features/auth/presentation/auth_controller.dart';
import 'package:coffee_management_mobile/features/inventory/data/api_inventory_repository.dart';
import 'package:coffee_management_mobile/features/orders/data/api_order_history_repository.dart';
import 'package:coffee_management_mobile/features/pos/data/api_catalog_repository.dart';
import 'package:coffee_management_mobile/features/pos/data/api_checkout_repository.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _token = 'synthetic-audit-token-never-sent-to-a-server';
const _permissions = <String, List<String>>{
  'cashier': [
    'view-catalog',
    'process-pos',
    'view-own-orders',
    'view-inventory',
  ],
  'manager': [
    'view-catalog',
    'process-pos',
    'view-own-orders',
    'view-all-orders',
    'view-inventory',
    'manage-catalog',
    'adjust-inventory',
    'view-reports',
    'view-settings',
  ],
  'admin': [
    'view-catalog',
    'process-pos',
    'view-own-orders',
    'view-all-orders',
    'view-inventory',
    'manage-catalog',
    'adjust-inventory',
    'view-reports',
    'view-settings',
    'manage-staff',
    'manage-settings',
  ],
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Browser audit automation needs the same semantics tree used by assistive technology.
  WidgetsBinding.instance.ensureSemantics();
  final query = Uri.base.queryParameters;
  final preview = await createAuditPreview(
    requestedRole:
        query['role'] ??
        const String.fromEnvironment('AUDIT_ROLE', defaultValue: 'cashier'),
    theme:
        query['theme'] ??
        const String.fromEnvironment('AUDIT_THEME', defaultValue: 'light'),
    mode:
        query['state'] ??
        const String.fromEnvironment('AUDIT_STATE', defaultValue: 'data'),
  );
  runApp(preview.widget);
}

Future<({Widget widget, VoidCallback dispose})> createAuditPreview({
  String requestedRole = 'cashier',
  String theme = 'light',
  String mode = 'data',
}) async {
  final role = _permissions.containsKey(requestedRole)
      ? requestedRole
      : 'cashier';
  final pendingFixtures = <Completer<http.Response>>[];
  final transport = MockClient((request) async {
    if (request.method != 'GET') {
      return _response({
        'message':
            'Read-only audit preview. No operation was sent to a server.',
      }, 403);
    }
    final path = request.url.path;
    if (path.endsWith('/auth/me')) {
      return _response({
        'data': {
          'id': 1,
          'name': 'Audit ${role[0].toUpperCase()}${role.substring(1)}',
          'email': 'audit@example.test',
          'role': role,
          'permissions': _permissions[role],
        },
      });
    }
    if (mode == 'loading') {
      final pending = Completer<http.Response>();
      pendingFixtures.add(pending);
      return pending.future;
    }
    if (mode == 'error') {
      return _response({'message': 'Synthetic service outage for audit.'}, 503);
    }
    List<Map<String, Object?>> rows;
    if (path.endsWith('/categories')) {
      rows = _categories;
    } else if (path.endsWith('/products')) {
      rows = _products;
      final category = request.url.queryParameters['category_id'];
      if (category != null) {
        rows = rows
            .where((row) => '${row['category_id']}' == category)
            .toList();
      }
    } else if (path.endsWith('/inventory/items')) {
      rows = _inventory;
    } else if (path.endsWith('/orders')) {
      rows = [_order];
      final status = request.url.queryParameters['status'];
      if (status != null && status != _order['status']) rows = [];
    } else if (path.endsWith('/ORD-01K6WY00000000000000000000')) {
      return _response({'data': _order});
    } else if (path.endsWith('/payments') || path.endsWith('/movements')) {
      rows = [];
    } else {
      return _response({'message': 'No synthetic fixture for this path.'}, 404);
    }
    if (mode == 'empty') rows = [];
    final search = request.url.queryParameters['search']?.toLowerCase();
    if (search != null && search.isNotEmpty) {
      rows = rows
          .where((row) => '${row['name']}'.toLowerCase().contains(search))
          .toList();
    }
    final page = int.parse(request.url.queryParameters['page'] ?? '1');
    final size = int.parse(request.url.queryParameters['per_page'] ?? '25');
    final total = rows.length;
    final last = total == 0 ? 1 : (total - 1) ~/ size + 1;
    final offset = (page - 1) * size;
    final slice = rows.skip(offset).take(size).toList();
    final url = request.url.replace(query: '').toString();
    return _response({
      'data': slice,
      'links': {
        'first': '$url?page=1',
        'last': '$url?page=$last',
        'prev': page > 1 ? '$url?page=${page - 1}' : null,
        'next': page < last ? '$url?page=${page + 1}' : null,
      },
      'meta': {
        'current_page': page,
        'last_page': last,
        'per_page': size,
        'total': total,
        'from': slice.isEmpty ? null : offset + 1,
        'to': slice.isEmpty ? null : offset + slice.length,
      },
    });
  });
  final client = ApiClient(
    client: transport,
    baseUrl: 'https://audit.invalid/api/v1',
  );
  final store = InMemoryAuthTokenStore();
  if (requestedRole != 'login') {
    await store.writeSession(
      token: _token,
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 4)),
    );
  }
  final auth = AuthController(
    repository: AuthRepository(
      api: AuthApi(client: client),
      tokenStore: store,
    ),
  );
  await auth.restoreSession();
  return (
    dispose: () {
      for (final pending in pendingFixtures) {
        if (!pending.isCompleted) {
          pending.complete(_response({'message': 'Fixture closed'}, 503));
        }
      }
      auth.dispose();
      transport.close();
    },
    widget: Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          ColoredBox(
            color: const Color(0xFF2B1B0F),
            child: SizedBox(
              height: 28,
              width: double.infinity,
              child: Center(
                child: Text(
                  'AUDIT FIXTURES · $requestedRole · $mode · NO LIVE DATA',
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: CoffeeManagementApp(
              authController: auth,
              catalogRepository: ApiCatalogRepository(
                client: client,
                token: _token,
              ),
              checkoutRepository: ApiCheckoutRepository(
                client: client,
                token: _token,
              ),
              orderHistoryRepository: ApiOrderHistoryRepository(
                client: client,
                token: _token,
              ),
              inventoryRepository: ApiInventoryRepository(
                client: client,
                token: _token,
              ),
              initialThemeMode: theme == 'dark'
                  ? ThemeMode.dark
                  : ThemeMode.light,
            ),
          ),
        ],
      ),
    ),
  );
}

http.Response _response(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _categories = <Map<String, Object?>>[
  {
    'id': 1,
    'name': 'Coffee',
    'is_active': true,
    'created_at': null,
    'updated_at': null,
  },
  {
    'id': 2,
    'name': 'Tea',
    'is_active': true,
    'created_at': null,
    'updated_at': null,
  },
  {
    'id': 3,
    'name': 'Bakery',
    'is_active': true,
    'created_at': null,
    'updated_at': null,
  },
];
final _products = <Map<String, Object?>>[
  for (final (index, name, category, cents) in [
    (1, 'Cappuccino', 1, 325),
    (2, 'Iced Americano', 1, 250),
    (3, 'Latte', 1, 350),
    (4, 'កាហ្វេទឹកដោះគោ', 1, 300),
    (5, 'Matcha', 2, 400),
    (6, 'Lemon Tea', 2, 275),
    (7, 'Croissant', 3, 225),
    (8, 'Chocolate Cake', 3, 450),
  ])
    {
      'id': index,
      'category_id': category,
      'category': _categories[category - 1],
      'sku': 'AUDIT-$index',
      'name': name,
      'description': 'Synthetic visual fixture',
      'price_minor': '$cents',
      'currency': 'USD',
      'is_active': true,
      'is_sellable': true,
      'created_at': null,
      'updated_at': null,
    },
];
const _inventory = <Map<String, Object?>>[
  {
    'id': 1,
    'sku': 'AUDIT-BEANS',
    'name': 'Coffee Beans',
    'base_unit': 'g',
    'on_hand': '5000.0000',
    'reserved': '250.0000',
    'available': '4750.0000',
    'reorder_level': '1000.0000',
    'is_active': true,
    'low_stock': false,
    'created_at': '2026-10-15T00:00:00+00:00',
    'updated_at': '2026-10-15T00:00:00+00:00',
  },
  {
    'id': 2,
    'sku': 'AUDIT-MILK',
    'name': 'Oat Milk',
    'base_unit': 'ml',
    'on_hand': '750.0000',
    'reserved': '500.0000',
    'available': '250.0000',
    'reorder_level': '500.0000',
    'is_active': true,
    'low_stock': true,
    'created_at': '2026-10-15T00:00:00+00:00',
    'updated_at': '2026-10-15T00:00:00+00:00',
  },
];
const _order = <String, Object?>{
  'public_reference': 'ORD-01K6WY00000000000000000000',
  'status': 'pending_payment',
  'currency': 'USD',
  'subtotal_minor': '325',
  'discount_minor': '0',
  'tax_minor': '0',
  'total_minor': '325',
  'inventory_tracked': false,
  'created_at': '2026-10-15T00:00:00+00:00',
  'creator': {'id': 1, 'name': 'Audit Cashier'},
  'items': [
    {
      'line_number': 1,
      'product_id': 1,
      'product_name': 'Cappuccino',
      'product_sku': 'AUDIT-1',
      'unit_price_minor': '325',
      'quantity': 1,
      'subtotal_minor': '325',
      'discount_minor': '0',
      'tax_minor': '0',
      'line_total_minor': '325',
    },
  ],
};
