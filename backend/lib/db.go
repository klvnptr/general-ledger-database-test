package lib

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"go.uber.org/zap"
)

type DB struct {
	conn   *pgx.Conn
	logger *zap.SugaredLogger
}

func NewDB(logger *zap.SugaredLogger, conn *pgx.Conn) *DB {
	return &DB{
		conn:   conn,
		logger: logger,
	}
}

func (db *DB) AddRows(totalRecords int, period int, done <-chan bool) error {
	ctx := context.Background()

	debitAccounts := []int{1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 5400}
	creditAccounts := []int{2000, 2100, 2200, 2300, 3000, 3100, 3200, 4000, 4100, 4200}

	// Retrieve the max(id) from the transactions table to determine current_start
	var currentStart int
	err := db.conn.QueryRow(ctx, "select coalesce(max(id) + 1, 1) from transactions").Scan(&currentStart)
	if err != nil {
		return fmt.Errorf("failed to retrieve max id from transactions table: %v", err)
	}

	// log the current_start value
	db.logger.Infof("  current_start: %d", currentStart)

	// get max created_at
	var maxCreatedAt time.Time
	err = db.conn.QueryRow(ctx, "select coalesce(max(created_at), '2019-01-01') from transactions").Scan(&maxCreatedAt)

	if err != nil {
		return fmt.Errorf("failed to retrieve max created_at from transactions table: %v", err)
	}

	// log the max created_at value
	db.logger.Infof("  max_created_at: %s", maxCreatedAt)

	// create a periodic 100ms timer to simulate a pause between inserts
	timer := time.NewTicker(time.Duration(period) * time.Millisecond)

	for {
		select {
		case <-done:
			return nil
		case <-timer.C:
			start := time.Now() // Start timing

			_, err = db.conn.Exec(ctx, `
				insert into transactions (id, debit_account_id, credit_account_id, amount, created_at)
				select 
					gs.i, 
					($1::integer[])[floor(random()*11)::int + 1] as debit_account_id,
					($2::integer[])[floor(random()*10)::int + 1] as credit_account_id,
					(random() * 10000)::bigint + 1 as amount,
					$5::date + interval '1 hour' * gs.i / $4 as created_at
				from generate_series($3::int, $4::int) as gs(i);
    `, debitAccounts, creditAccounts, currentStart, currentStart+totalRecords, maxCreatedAt)

			if err != nil {
				db.logger.Errorf("error inserting rows: %v", err)
				return err
			}

			duration := time.Since(start)
			db.logger.Infof("execution time: %v ms (maxCreatedAt: %+v)", duration.Milliseconds(), maxCreatedAt)

			currentStart += totalRecords
			maxCreatedAt = maxCreatedAt.Add(time.Hour)
		}
	}
}
