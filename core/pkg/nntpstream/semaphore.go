package nntpstream

import (
	"context"
	"sync"
)

// PrioritizedSemaphore is a Go port of nzbdav's PrioritizedSemaphore.
// It maintains two separate queues for waiters (High and Low priority).
type PrioritizedSemaphore struct {
	mu           sync.Mutex
	enteredCount int
	maxAllowed   int
	
	highWaiters []*waiter
	lowWaiters  []*waiter
}

type waiter struct {
	ready chan struct{}
}

func NewPrioritizedSemaphore(maxAllowed int) *PrioritizedSemaphore {
	return &PrioritizedSemaphore{
		maxAllowed: maxAllowed,
	}
}

func (s *PrioritizedSemaphore) Wait(ctx context.Context, isHighPriority bool) error {
	s.mu.Lock()
	if s.enteredCount < s.maxAllowed {
		s.enteredCount++
		s.mu.Unlock()
		return nil
	}

	w := &waiter{ready: make(chan struct{}, 1)}
	if isHighPriority {
		s.highWaiters = append(s.highWaiters, w)
	} else {
		s.lowWaiters = append(s.lowWaiters, w)
	}
	s.mu.Unlock()

	select {
	case <-w.ready:
		return nil
	case <-ctx.Done():
		s.mu.Lock()
		defer s.mu.Unlock()
		// Remove from queues if it timed out before getting selected
		s.removeWaiter(&s.highWaiters, w)
		s.removeWaiter(&s.lowWaiters, w)
		return ctx.Err()
	}
}

func (s *PrioritizedSemaphore) removeWaiter(queue *[]*waiter, w *waiter) {
	for i, existing := range *queue {
		if existing == w {
			*queue = append((*queue)[:i], (*queue)[i+1:]...)
			return
		}
	}
}

func (s *PrioritizedSemaphore) Release() {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.enteredCount > s.maxAllowed {
		// Capacity was reduced dynamically
		s.enteredCount--
		return
	}

	var w *waiter
	if len(s.highWaiters) > 0 {
		w = s.highWaiters[0]
		s.highWaiters = s.highWaiters[1:]
	} else if len(s.lowWaiters) > 0 {
		w = s.lowWaiters[0]
		s.lowWaiters = s.lowWaiters[1:]
	} else {
		// Nobody is waiting
		s.enteredCount--
		return
	}

	w.ready <- struct{}{}
}
