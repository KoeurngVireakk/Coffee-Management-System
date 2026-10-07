import 'catalog.dart';

abstract interface class CatalogRepository {
  Future<CatalogPage<CatalogCategory>> categories({int page = 1});
  Future<CatalogPage<CatalogProduct>> products({
    int page = 1,
    int? categoryId,
    String search = '',
  });
}

enum CatalogFailureKind {
  sessionExpired,
  forbidden,
  validation,
  network,
  server,
  rateLimited,
  invalidResponse,
}

class CatalogFailure implements Exception {
  const CatalogFailure(this.kind);
  final CatalogFailureKind kind;

  String get message => switch (kind) {
    CatalogFailureKind.sessionExpired =>
      'Your session has expired. Please sign in again.',
    CatalogFailureKind.forbidden =>
      'You do not have access to this catalog. Contact your manager.',
    CatalogFailureKind.validation =>
      'The catalog request was rejected. Clear the filters and retry.',
    CatalogFailureKind.network =>
      'Cannot reach the catalog. Check your connection and retry.',
    CatalogFailureKind.server =>
      'The catalog service is unavailable. Please retry shortly.',
    CatalogFailureKind.rateLimited =>
      'Too many catalog requests. Wait a moment and retry.',
    CatalogFailureKind.invalidResponse =>
      'The catalog response could not be read safely. Please retry.',
  };
}
