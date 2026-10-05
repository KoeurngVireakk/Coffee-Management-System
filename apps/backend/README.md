# Coffee Management API

Laravel 13 API scaffold. Follow the [root setup guide](../../README.md#run-the-backend) and [architecture rules](../../docs/architecture/README.md).

Business routes belong in `routes/api.php` under the existing `v1` group. There are no feature endpoints yet. `/up` checks framework startup; it is not a database readiness check. The default Laravel user model, factory, and infrastructure migrations are retained as framework scaffolding; the database seeder is empty.

Run `composer lint` and `composer test` before submitting a change. No frontend dependencies or Node runtime are required.
