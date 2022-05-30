package main

import (
	"flag"
	"github.com/cybwan/osm-edge-demo/pkg/server/http"
	"log"
)

// Config is configuration for Server
type Config struct {
	HTTPPort string
}

func main() {
	// get configuration
	var cfg Config
	flag.StringVar(&cfg.HTTPPort, "http-port", "20003", "http port to bind")
	flag.Parse()

	log.Printf("http RunServer port %s ... ", cfg.HTTPPort)
	if err := http.RunServer(http.NewServer(), cfg.HTTPPort); err != nil {
		panic(err)
	}
}
