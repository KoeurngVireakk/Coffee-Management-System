# Database setup and conventions

The application targets MySQL 8.0+. The example environment uses `127.0.0.1:3306`, database `coffee_management`, and a dedicated `coffee_management` account. No real credentials are committed.

Connect as your local database administrator (`mysql -u root -p`, adjusting host/port if needed). For a new local development database, run the following after replacing the example password locally:

```sql
CREATE DATABASE coffee_management
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'coffee_management'@'127.0.0.1'
  IDENTIFIED BY 'REPLACE_WITH_YOUR_LOCAL_PASSWORD';
GRANT ALL PRIVILEGES ON coffee_management.*
  TO 'coffee_management'@'127.0.0.1';
```

Use the account host appropriate for your MySQL installation; Docker/network connections may require a different host rule. For an existing database/account, use the existing configuration instead of recreating it. These grants support local migrations; restrict runtime privileges separately in production.

Set `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, and `DB_PASSWORD` in ignored `apps/backend/.env`. Quote passwords with spaces or special dotenv characters. Then, in `apps/backend`:

```sh
php artisan config:clear
php artisan migrate
php artisan migrate:status
```

Only Laravel's default users/password reset/session, cache, and jobs infrastructure migrations exist. The default user model/factory are retained; no authentication endpoint, role table, product table, order table, or payment schema exists. The root seeder creates no accounts. File cache/session drivers and synchronous queues do not use their database tables yet.

Use migrations as the schema source of truth. Future schema changes should define foreign keys, indexes for real query patterns, and transaction boundaries. Represent monetary amounts consistently using decimal values or integer minor units after deciding supported currencies; do not use floating-point amounts. Plan immutable order price snapshots and auditable stock/payment records when those features begin.

PHPUnit uses an in-memory SQLite database for fast bootstrap tests; CI also runs the default migrations against MySQL. Later MySQL-specific behavior needs tests against MySQL. Never run destructive test/migration reset commands against a developer's shared database.
