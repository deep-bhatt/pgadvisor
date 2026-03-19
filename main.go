package main

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/jackc/pgx/v5"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: pgadvisor <connection-string>")
		os.Exit(1)
	}

	connStr := os.Args[1]
	ctx := context.Background()

	conn, err := pgx.Connect(ctx, connStr)
	if err != nil {
		fmt.Printf("Failed to connect: %v\n", err)
		os.Exit(1)
	}
	defer conn.Close(ctx)
	fmt.Printf("Connected to Postgres.\n")

	if err := checkVaccum(ctx, conn); err != nil {
		fmt.Printf("Vaccum check: %v\n", err)
		os.Exit(1)
	}
}

func checkVaccum(ctx context.Context, conn *pgx.Conn) error {
	query := `
  SELECT schemaname, relname, n_live_tup, n_dead_tup, last_autovacuum
  FROM pg_stat_user_tables
  WHERE n_live_tup > 0
  AND n_dead_tup > n_live_tup * 0.1
  AND (last_autovacuum IS NULL OR last_autovacuum < now() - interval '1 day')`

	rows, err := conn.Query(ctx, query)
	if err != nil {
		return fmt.Errorf("vaccum check query failed: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var schema, table string
		var liveTup, deadTup int64
		var lastAutoVaccum *time.Time

		err := rows.Scan(&schema, &table, &liveTup, &deadTup, &lastAutoVaccum)
		if err != nil {
			return fmt.Errorf("scanning vaccum row: %w", err)
		}

		ratio := float64(deadTup) / float64(liveTup)
		severity := "warning"
		if ratio > 0.5 {
			severity = "critical"
		}

		vacuumStatus := "never"
		if lastAutoVaccum != nil {
			vacuumStatus = lastAutoVaccum.Format(time.RFC3339)
		}

		fmt.Printf("[%s] %s.%s: %.0f%% dead tuples (%d dead / %d live), last autovacuum: %s. Suggest: VACUUM ANALYZE %s.%s;\n",
			severity, schema, table, ratio*100, deadTup, liveTup, vacuumStatus, schema, table)
	}

	return rows.Err()
}
