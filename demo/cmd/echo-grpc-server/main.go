package main

import (
	"context"
	"flag"
	"log"

	"github.com/cybwan/osm-edge-demo/pkg/server/grpc"
)

// Config is configuration for Server
type Config struct {
	GRPCPort string
}

func main() {
	ctx := context.Background()

	// get configuration
	var cfg Config
	flag.StringVar(&cfg.GRPCPort, "grpc-port", "20001", "gRPC port to bind")
	flag.Parse()

	log.Printf("grpc RunServer port %s ... ", cfg.GRPCPort)
	if err := grpc.RunServer(ctx, grpc.NewServer(), cfg.GRPCPort); err != nil {
		panic(err)
	}
}
