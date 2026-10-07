import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/catalog.dart';
import '../domain/catalog_repository.dart';
import 'catalog_dto.dart';

class ApiCatalogRepository implements CatalogRepository {
  ApiCatalogRepository({required this.client, required this.token});
  final ApiClient client;
  final String token;
  static const productPageSize = 25;
  static const categoryPageSize = 50;

  @override
  Future<CatalogPage<CatalogCategory>> categories({int page = 1}) async {
    return _read(
      '/categories',
      {'page': '$page', 'per_page': '$categoryPageSize'},
      CatalogDto.category,
      page,
      categoryPageSize,
      (item) => item.isActive,
      (item) => item.id,
    );
  }

  @override
  Future<CatalogPage<CatalogProduct>> products({
    int page = 1,
    int? categoryId,
    String search = '',
  }) async {
    if (search.runes.length > 80 || (categoryId != null && categoryId <= 0)) {
      throw const CatalogFailure(CatalogFailureKind.validation);
    }
    return _read(
      '/products',
      {
        'page': '$page',
        'per_page': '$productPageSize',
        if (categoryId != null) 'category_id': '$categoryId',
        if (search.isNotEmpty) 'search': search,
      },
      CatalogDto.product,
      page,
      productPageSize,
      (item) => item.isSellable,
      (item) => item.id,
    );
  }

  Future<CatalogPage<T>> _read<T>(
    String path,
    Map<String, String> query,
    T Function(Object?) decode,
    int page,
    int size,
    bool Function(T) allowed,
    int Function(T) id,
  ) async {
    if (page < 1 || page > 10000) {
      throw const CatalogFailure(CatalogFailureKind.validation);
    }
    try {
      final json = await client.get(path, token: token, queryParameters: query);
      final result = CatalogDto.page(
        json,
        decode,
        requestedPage: page,
        requestedPerPage: size,
      );
      final ids = <int>{};
      if (result.items.any((item) => !allowed(item) || !ids.add(id(item)))) {
        throw const FormatException('Invalid active catalog.');
      }
      return result;
    } on UnauthorizedException {
      throw const CatalogFailure(CatalogFailureKind.sessionExpired);
    } on ForbiddenException {
      throw const CatalogFailure(CatalogFailureKind.forbidden);
    } on ValidationException {
      throw const CatalogFailure(CatalogFailureKind.validation);
    } on RateLimitedException {
      throw const CatalogFailure(CatalogFailureKind.rateLimited);
    } on NetworkException {
      throw const CatalogFailure(CatalogFailureKind.network);
    } on ServerException {
      throw const CatalogFailure(CatalogFailureKind.server);
    } on ApiException {
      throw const CatalogFailure(CatalogFailureKind.invalidResponse);
    } on FormatException {
      throw const CatalogFailure(CatalogFailureKind.invalidResponse);
    } on ArgumentError {
      throw const CatalogFailure(CatalogFailureKind.invalidResponse);
    }
  }
}
