package main

import (
	"context"
	"os"
	"os/signal"
	"syscall"

	"github.com/jackc/pgx/v5"
	"github.com/klvnptr/timescaledb-test/lib"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

func main() {
	// logger, _ := zap.NewProduction()

	config := zap.NewDevelopmentConfig()
	config.EncoderConfig.EncodeLevel = zapcore.CapitalColorLevelEncoder
	logger, _ := config.Build()

	defer logger.Sync()
	sugar := logger.Sugar()

	host := os.Getenv("POSTGRES_HOSTNAME")
	if host == "" {
		sugar.Fatal("POSTGRES_HOSTNAME environment variable is required")
	}

	password := os.Getenv("POSTGRES_PASSWORD")
	if password == "" {
		sugar.Fatal("POSTGRES_PASSWORD environment variable is required")
	}

	user := os.Getenv("POSTGRES_USER")
	if user == "" {
		sugar.Fatal("POSTGRES_USER environment variable is required")
	}

	dbName := os.Getenv("POSTGRES_DB")
	if dbName == "" {
		sugar.Fatal("POSTGRES_DB environment variable is required")
	}

	port := os.Getenv("POSTGRES_PORT")
	if port == "" {
		port = "5432"
	}

	connStr := "postgres://" + user + ":" + password + "@" + host + ":" + port + "/" + dbName
	sugar.Infof("Connection string: %s", connStr)

	ctx := context.Background()

	conn, err := pgx.Connect(ctx, connStr)
	if err != nil {
		sugar.Fatalf("Unable to connect to database: %v", err)
	}
	defer conn.Close(ctx)

	var greeting string
	err = conn.QueryRow(ctx, "select 'Hello, Timescale!'").Scan(&greeting)
	if err != nil {
		sugar.Fatalf("QueryRow failed: %v", err)
	}
	sugar.Infof("Received greeting: %s", greeting)

	db := lib.NewDB(sugar, conn)

	// Set up signal capturing
	sigs := make(chan os.Signal, 1)
	done := make(chan bool, 1)

	signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		<-sigs
		done <- true
	}()

	err = db.AddRows(5000, 100, done)
	if err != nil {
		sugar.Fatalf("AddRows failed: %v", err)
	}

}
