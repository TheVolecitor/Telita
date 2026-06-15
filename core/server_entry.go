package main

import (
	"log"

	"github.com/cinekernel/core/pkg/server"
)

func RunServer() {
	log.Println("Starting CineKernel Core...")

	// Initialize the local REST API server for the UI clients to connect to
	srv := server.NewServer("127.0.0.1:8081")
	if err := srv.Start(); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
