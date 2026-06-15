package torrent

import (
	"context"
	"io"
	"sync"

	"github.com/anacrolix/torrent/metainfo"
	"github.com/anacrolix/torrent/storage"
	"github.com/anacrolix/generics"
)

type MemoryStorage struct {
	mu          sync.Mutex
	Pieces      map[metainfo.Hash]map[int]*RAMPiece
	MaxCapacity int64
	UsedBytes   int64
	AccessOrder []*RAMPiece
}

func NewMemoryStorage(maxBytes int64) *MemoryStorage {
	return &MemoryStorage{
		Pieces:      make(map[metainfo.Hash]map[int]*RAMPiece),
		MaxCapacity: maxBytes,
		AccessOrder: make([]*RAMPiece, 0),
	}
}

func (m *MemoryStorage) OpenTorrent(ctx context.Context, info *metainfo.Info, infoHash metainfo.Hash) (storage.TorrentImpl, error) {
	m.mu.Lock()
	if _, ok := m.Pieces[infoHash]; !ok {
		m.Pieces[infoHash] = make(map[int]*RAMPiece)
	}
	m.mu.Unlock()

	return storage.TorrentImpl{
		PieceWithHash: func(p metainfo.Piece, _ generics.Option[[]byte]) storage.PieceImpl {
			m.mu.Lock()
			defer m.mu.Unlock()

			tPieces := m.Pieces[infoHash]
			rp, ok := tPieces[p.Index()]
			if !ok {
				rp = &RAMPiece{
					store: m,
					hash:  infoHash,
					index: p.Index(),
					data:  make([]byte, p.Length()),
					comp:  storage.Completion{Complete: false, Ok: true},
				}
				tPieces[p.Index()] = rp
				m.UsedBytes += p.Length()
				m.AccessOrder = append(m.AccessOrder, rp)

				// Evict old pieces if we exceed capacity (LRU), but keep first/last few pieces (indexes)
				if m.UsedBytes > m.MaxCapacity {
					m.evictOldPieces(info)
				}
			} else {
				// Move to back of access order (most recently used)
				for i, pPtr := range m.AccessOrder {
					if pPtr == rp {
						m.AccessOrder = append(m.AccessOrder[:i], m.AccessOrder[i+1:]...)
						m.AccessOrder = append(m.AccessOrder, rp)
						break
					}
				}
			}
			return rp
		},
		Close: func() error { return nil },
	}, nil
}

func (m *MemoryStorage) evictOldPieces(info *metainfo.Info) {
	if len(m.AccessOrder) == 0 {
		return
	}
	// Try to find the oldest piece that isn't at the very start or very end of the torrent
	// (Start and end usually contain the moov/mkv indexes)
	for i := 0; i < len(m.AccessOrder); i++ {
		rp := m.AccessOrder[i]
		
		isIndexPiece := false
		if info != nil {
			isIndexPiece = rp.index < 5 || rp.index > (info.NumPieces() - 5)
		}

		if !isIndexPiece {
			// Evict!
			m.UsedBytes -= int64(len(rp.data))
			delete(m.Pieces[rp.hash], rp.index)
			m.AccessOrder = append(m.AccessOrder[:i], m.AccessOrder[i+1:]...)
			break
		}
	}
}

type RAMPiece struct {
	store *MemoryStorage
	hash  metainfo.Hash
	index int
	data  []byte
	comp  storage.Completion
	mu    sync.RWMutex
}

func (rp *RAMPiece) Completion() storage.Completion {
	rp.mu.RLock()
	defer rp.mu.RUnlock()
	return rp.comp
}

func (rp *RAMPiece) MarkComplete() error {
	rp.mu.Lock()
	defer rp.mu.Unlock()
	rp.comp.Complete = true
	rp.comp.Ok = true
	return nil
}

func (rp *RAMPiece) MarkNotComplete() error {
	rp.mu.Lock()
	defer rp.mu.Unlock()
	rp.comp.Complete = false
	return nil
}

func (rp *RAMPiece) ReadAt(p []byte, off int64) (n int, err error) {
	rp.mu.RLock()
	defer rp.mu.RUnlock()
	if off >= int64(len(rp.data)) {
		return 0, io.EOF
	}
	n = copy(p, rp.data[off:])
	if n < len(p) {
		return n, io.EOF
	}
	return n, nil
}

func (rp *RAMPiece) WriteAt(p []byte, off int64) (n int, err error) {
	rp.mu.Lock()
	defer rp.mu.Unlock()
	if off >= int64(len(rp.data)) {
		return 0, io.ErrShortWrite
	}
	n = copy(rp.data[off:], p)
	return n, nil
}
