# pgadvisor

A CLI that connects to PostgreSQL and prints practical tuning suggestions:

- tables with high dead-tuple ratios that likely need vacuum attention
- indexes that appear unused and might be candidates for removal

The tool is read-only. It does **not** execute `VACUUM` or `DROP INDEX`; it only suggests commands.

## What it checks

### 1. Vacuum pressure (`checkVaccum`)

Queries `pg_stat_user_tables` and reports tables where:

- `n_live_tup > 0`
- `n_dead_tup > n_live_tup * 0.1` (more than 10% dead tuples)
- `last_autovacuum` is `NULL` or older than 1 day

Severity:

- `warning`: dead/live ratio > 10%
- `critical`: dead/live ratio > 50%

Suggested action format:

```sql
VACUUM ANALYZE schema.table;
```

### 2. Unused indexes (`checkUnusedIndexes`)

Before checking indexes, the tool verifies PostgreSQL statistics reset time:

- if stats are younger than 7 days, it skips the check and prints an info message
- otherwise, it inspects `pg_stat_user_indexes` for indexes with `idx_scan = 0`

Severity by index size:

- `info`: <= 10 MB
- `warning`: > 10 MB
- `critical`: > 100 MB

Suggested action format:

```sql
DROP INDEX schema.index_name;
```

## Requirements

- Go `1.25+`
- PostgreSQL instance reachable via connection string

## Usage

Run with a PostgreSQL connection string:

```bash
go run . "postgres://user:password@host:5432/dbname?sslmode=disable"
```

Or build and run:

```bash
go build -o pgadvisor .
./pgadvisor "postgres://user:password@host:5432/dbname?sslmode=disable"
```

If no argument is provided:

```text
Usage: pgadvisor <connection-string>
```

## Local test environment (Docker)

This repo includes a ready-to-use PostgreSQL + pgAdmin setup under `test/`.

From the `test/` directory:

```bash
docker compose up -d --build
```

Services:

- PostgreSQL: `localhost:5432` (`dev/dev`, database `test`)
- pgAdmin: `http://localhost:5050` (`admin@admin.com` / `admin`)

Connection string for local testing:

```text
postgres://dev:dev@localhost:5432/test?sslmode=disable
```

Run the advisor against that database:

```bash
go run . "postgres://dev:dev@localhost:5432/test?sslmode=disable"
```

The database is seeded by [`test/init.sql`](test/init.sql) with customers/products/orders/events data and starter indexes.

## Notes and limitations

- This is a lightweight heuristic tool, not a full performance analyzer.
- Unused index suggestions rely on accumulated statistics; recent restarts/resets can hide true usage.
- Always validate recommendations against query patterns before applying them in production.

## License

MIT. See [`LICENSE`](LICENSE).
