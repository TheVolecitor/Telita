package nntpstream

import (
	"context"
	"crypto/tls"
	"fmt"
	"sync"

	"github.com/dustin/go-nntp/client"
)

type Config struct {
	Host        string
	Port        int
	Username    string
	Password    string
	Connections int
}

var GlobalPool *ConnectionPool

type ConnectionPool struct {
	config Config
	sem    *PrioritizedSemaphore

	mu    sync.Mutex
	conns []*nntpclient.Client
}

func InitGlobalPool(cfg Config) {
	if cfg.Connections <= 0 {
		cfg.Connections = 20
	}
	GlobalPool = &ConnectionPool{
		config: cfg,
		sem:    NewPrioritizedSemaphore(cfg.Connections),
	}
}

func (p *ConnectionPool) connect() (*nntpclient.Client, error) {
	addr := fmt.Sprintf("%s:%d", p.config.Host, p.config.Port)
	conn, err := nntpclient.NewTLS("tcp", addr, &tls.Config{InsecureSkipVerify: true})
	if err != nil {
		return nil, fmt.Errorf("nntp dial error: %w", err)
	}

	if p.config.Username != "" {
		_, err = conn.Authenticate(p.config.Username, p.config.Password)
		if err != nil {
			conn.Close()
			return nil, fmt.Errorf("nntp auth error: %w", err)
		}
	}
	return conn, nil
}

// Acquire gets a connection from the pool. If highPriority is true, it jumps ahead of pre-fetch workers.
func (p *ConnectionPool) Acquire(ctx context.Context, highPriority bool) (*nntpclient.Client, error) {
	err := p.sem.Wait(ctx, highPriority)
	if err != nil {
		return nil, err
	}

	// Try to get an idle connection
	p.mu.Lock()
	if len(p.conns) > 0 {
		conn := p.conns[len(p.conns)-1]
		p.conns = p.conns[:len(p.conns)-1]
		p.mu.Unlock()
		return conn, nil
	}
	p.mu.Unlock()

	// No idle connections, dial a new one
	conn, err := p.connect()
	if err != nil {
		p.sem.Release() // Release capacity if dial failed
		return nil, err
	}

	return conn, nil
}

func (p *ConnectionPool) Release(conn *nntpclient.Client, err error) {
	if err != nil {
		// If the connection had an error (e.g. timeout), destroy it
		if conn != nil {
			conn.Close()
		}
	} else {
		// Return healthy connection to the pool
		p.mu.Lock()
		p.conns = append(p.conns, conn)
		p.mu.Unlock()
	}
	
	p.sem.Release()
}
