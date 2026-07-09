package nntpstream

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"log"
	"sync"
	"time"

	"github.com/GJRTimmer/yenc"
)

// UnrarStreamer implements io.ReadSeeker over a virtual MKV file that is
// reconstructed on-the-fly by stripping RAR headers from multi-volume
// Store-mode archives. It translates video byte offsets to specific
// NNTP segments across multiple RAR volumes.
type UnrarStreamer struct {
	session    *Session
	rarMap     *RARMap
	volumes    []*MediaFile
	ctx        context.Context
	cancel     context.CancelFunc

	mu          sync.Mutex
	absOffset   int64 // position in virtual MKV
	totalSize   int64 // total uncompressed video size
	buffer      *bytes.Reader
	seekPending bool

	// Prefetching: keyed by "volIdx:segIdx"
	results    map[string]*SegmentResult
	notifyCh   chan struct{}
	prefetchWG sync.WaitGroup
	seekCh     chan seekTarget
}

type seekTarget struct {
	volIdx int
	segIdx int
}

func NewUnrarStreamer(parentCtx context.Context, session *Session) *UnrarStreamer {
	ctx, cancel := context.WithCancel(parentCtx)
	s := &UnrarStreamer{
		session:   session,
		rarMap:    session.RARMap,
		volumes:   session.RARVolumes,
		ctx:       ctx,
		cancel:    cancel,
		totalSize: session.RARMap.TotalSize,
		absOffset: 0,
		results:   make(map[string]*SegmentResult),
		notifyCh:  make(chan struct{}, 1),
		seekCh:    make(chan seekTarget, 1),
	}

	// In the global pool model, we spawn workers and rely on Semaphores to throttle
	workers := 8

	type workItem struct {
		volIdx int
		segIdx int
	}
	workChan := make(chan workItem)

	// Prefetch manager: dispatches segments sequentially across all volumes
	s.prefetchWG.Add(1)
	go func() {
		defer s.prefetchWG.Done()
		volIdx := 0
		segIdx := 0
		for {
			if volIdx >= len(s.volumes) {
				select {
				case <-s.ctx.Done():
					return
				case t := <-s.seekCh:
					volIdx, segIdx = t.volIdx, t.segIdx
					continue
				}
			}
			if segIdx >= len(s.volumes[volIdx].Segments) {
				volIdx++
				segIdx = 0
				continue
			}

			// Throttle: max 20 segments buffered
			s.mu.Lock()
			for len(s.results) >= 20 {
				s.mu.Unlock()
				select {
				case <-s.ctx.Done():
					return
				case t := <-s.seekCh:
					volIdx, segIdx = t.volIdx, t.segIdx
					s.mu.Lock()
					goto nextIter
				case <-time.After(100 * time.Millisecond):
					s.mu.Lock()
				}
			}
			s.mu.Unlock()

			select {
			case <-s.ctx.Done():
				return
			case t := <-s.seekCh:
				volIdx, segIdx = t.volIdx, t.segIdx
				continue
			case workChan <- workItem{volIdx, segIdx}:
				segIdx++
			}
		nextIter:
		}
	}()

	// Workers
	s.prefetchWG.Add(workers)
	log.Printf("[UnRAR-Streamer] Spawning %d prefetch workers for %d volumes (%d total extents)",
		workers, len(s.volumes), len(s.rarMap.Extents))
	for i := 0; i < workers; i++ {
		go func(id int) {
			defer s.prefetchWG.Done()
			log.Printf("[UnRAR-Worker] Worker %d started", id)
			for {
				select {
				case <-s.ctx.Done():
					return
				case item, ok := <-workChan:
					if !ok {
						return
					}
					vol := s.volumes[item.volIdx]
					seg := vol.Segments[item.segIdx]
					// We consider it high priority if there are less than 2 items in the buffer
					s.mu.Lock()
					isHighPriority := len(s.results) <= 1
					s.mu.Unlock()
					
					data, err := s.fetchSegment(seg.ID, vol.Groups, isHighPriority)
					if err != nil {
						log.Printf("[UnRAR-Worker] Worker %d failed vol=%d seg=%d: %v", id, item.volIdx, item.segIdx, err)
					} else {
						log.Printf("[UnRAR-Worker] Worker %d fetched vol=%d seg=%d (%d bytes)", id, item.volIdx, item.segIdx, len(data))
					}
					key := segKey(item.volIdx, item.segIdx)
					s.mu.Lock()
					s.results[key] = &SegmentResult{Index: item.segIdx, Data: data, Err: err}
					s.mu.Unlock()
					select {
					case s.notifyCh <- struct{}{}:
					default:
					}
				}
			}
		}(i)
	}

	return s
}

func segKey(volIdx, segIdx int) string {
	return fmt.Sprintf("%d:%d", volIdx, segIdx)
}

func (s *UnrarStreamer) fetchSegment(messageID string, groups []string, isHighPriority bool) ([]byte, error) {
	var lastErr error
	for attempt := 0; attempt < 2; attempt++ {
		data, err := s.tryFetchSegment(messageID, groups, isHighPriority)
		if err == nil {
			return data, nil
		}
		if !isTransientNetworkError(err) {
			return nil, err // 430 or context cancelled — don't retry
		}
		log.Printf("[UnRAR-Streamer] Transient error for %s (attempt %d): %v — retrying...", messageID, attempt+1, err)
		lastErr = err
		time.Sleep(500 * time.Millisecond)
	}
	return nil, lastErr
}

func (s *UnrarStreamer) tryFetchSegment(messageID string, groups []string, isHighPriority bool) ([]byte, error) {
	conn, err := GlobalPool.Acquire(s.ctx, isHighPriority)
	if err != nil {
		return nil, err
	}
	if len(groups) > 0 {
		_, _ = conn.Group(groups[0])
	}
	_, _, bodyReader, err := conn.Body("<" + messageID + ">")
	if err != nil {
		GlobalPool.Release(conn, err)
		return nil, err
	}
	raw, err := io.ReadAll(bodyReader)
	if err != nil {
		GlobalPool.Release(conn, err)
		return nil, err
	}
	GlobalPool.Release(conn, nil)
	dec, _, err := yenc.Decode(raw)
	if err != nil && len(dec) == 0 {
		return nil, err
	}
	if s.ctx.Err() != nil {
		return nil, s.ctx.Err()
	}
	return dec, nil
}

// Read implements io.Reader for the virtual MKV file.
// It reads sequentially across volumes, stripping RAR headers on the fly.
func (s *UnrarStreamer) Read(p []byte) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.session != nil {
		s.session.UpdateLastUsed()
	}

	if s.seekPending {
		s.performLazySeek()
		s.seekPending = false
	}

	if s.absOffset >= s.totalSize {
		return 0, io.EOF
	}

	totalRead := 0

	for totalRead < len(p) && s.absOffset < s.totalSize {
		// Drain any buffered data first
		if s.buffer != nil && s.buffer.Len() > 0 {
			n, err := s.buffer.Read(p[totalRead:])
			totalRead += n
			s.absOffset += int64(n)
			if err == io.EOF {
				s.buffer = nil
				continue
			}
			if err != nil {
				return totalRead, err
			}
			continue
		}
		s.buffer = nil

		// Determine which volume and where in the volume our current offset maps to
		extIdx, offsetInExtent := s.rarMap.FindExtent(s.absOffset)
		ext := s.rarMap.Extents[extIdx]
		volIdx := ext.VolumeIndex

		if volIdx >= len(s.volumes) {
			return totalRead, io.EOF
		}

		vol := s.volumes[volIdx]

		// The byte position within the RAR volume file where our data lives
		volumeFileOffset := ext.DataStart + offsetInExtent

		// Find which NNTP segment contains that byte position
		segIdx := int(volumeFileOffset / s.rarMap.SegmentSize)
		if segIdx >= len(vol.Segments) {
			segIdx = len(vol.Segments) - 1 // Handle edge cases for the last segment
		}
		segFileOffset := int64(segIdx) * s.rarMap.SegmentSize

		// Wait for this segment to be fetched
		key := segKey(volIdx, segIdx)
		for s.results[key] == nil {
			s.mu.Unlock()
			select {
			case <-s.ctx.Done():
				s.mu.Lock()
				return totalRead, s.ctx.Err()
			case <-s.notifyCh:
				s.mu.Lock()
			}
		}

		res := s.results[key]
		delete(s.results, key)

		if res.Err != nil {
			log.Printf("[UnRAR-Streamer] Segment vol=%d seg=%d unavailable (%v) — substituting %d zero bytes", volIdx, segIdx, res.Err, s.rarMap.SegmentSize)
			res.Data = make([]byte, s.rarMap.SegmentSize)
			res.Err = nil
		}

		// LAZY HEADER PARSING: if this is the first segment of the volume and we haven't
		// accurately parsed the RAR header yet, do it now.
		if segIdx == 0 && !ext.Parsed {
			info, err := ParseRARHeaders(res.Data)
			if err == nil && info.DataOffset != ext.DataStart {
				diff := info.DataOffset - ext.DataStart
				
				s.rarMap.mu.Lock()
				// Re-fetch in case it changed while waiting
				ext = s.rarMap.Extents[extIdx]
				
				if !ext.Parsed {
					log.Printf("[UnRAR-Lazy] Correcting vol %d DataOffset: %d -> %d (diff: %d)", volIdx, ext.DataStart, info.DataOffset, diff)
					ext.DataStart = info.DataOffset
					ext.DataLength -= diff
					ext.Parsed = true
					s.rarMap.Extents[extIdx] = ext
					
					// Shift all subsequent extents
					for i := extIdx + 1; i < len(s.rarMap.Extents); i++ {
						s.rarMap.Extents[i].VideoByteStart -= diff
					}
					s.totalSize -= diff
					s.rarMap.TotalSize -= diff
				}
				s.rarMap.mu.Unlock()
			} else if err == nil {
				s.rarMap.mu.Lock()
				s.rarMap.Extents[extIdx].Parsed = true
				ext = s.rarMap.Extents[extIdx] // update local copy
				s.rarMap.mu.Unlock()
			}
		}

		// Extract only the video data bytes from this segment.
		// The segment contains raw decoded bytes corresponding to positions
		// [segFileOffset .. segFileOffset+len(data)) within the RAR volume file.
		//
		// The video data block in this volume occupies positions
		// [ext.DataStart .. ext.DataStart+ext.DataLength) within the RAR volume file.
		//
		// We need the intersection, then further offset by where we currently are.

		segData := res.Data
		segStart := segFileOffset                       // volume-file position of segment start
		segEnd := segFileOffset + int64(len(segData))   // volume-file position of segment end
		dataStart := ext.DataStart                      // volume-file position of video data start
		dataEnd := ext.DataStart + ext.DataLength       // volume-file position of video data end

		// Overlap between segment and video data block
		overlapStart := max64(segStart, dataStart)
		overlapEnd := min64(segEnd, dataEnd)

		if overlapStart >= overlapEnd {
			// No video data in this segment (pure header), advance offset
			s.absOffset = ext.VideoByteStart + (overlapEnd - ext.DataStart)
			continue
		}

		// Where does our current read position fall within this overlap?
		readPosInVolume := volumeFileOffset
		if readPosInVolume > overlapStart {
			overlapStart = readPosInVolume
		}

		if overlapStart >= overlapEnd {
			// Already past the useful data in this segment
			s.absOffset = ext.VideoByteStart + (segEnd - ext.DataStart)
			if s.absOffset > ext.VideoByteStart+ext.DataLength {
				s.absOffset = ext.VideoByteStart + ext.DataLength
			}
			continue
		}

		// Convert to local offsets within segData
		localStart := overlapStart - segStart
		localEnd := overlapEnd - segStart

		videoData := segData[localStart:localEnd]
		if len(videoData) > 0 {
			s.buffer = bytes.NewReader(videoData)
		}
	}

	if totalRead == 0 && s.absOffset >= s.totalSize {
		return 0, io.EOF
	}
	return totalRead, nil
}

func (s *UnrarStreamer) performLazySeek() {
	if s.absOffset >= s.totalSize {
		return
	}

	extIdx, offsetInExtent := s.rarMap.FindExtent(s.absOffset)
	ext := s.rarMap.Extents[extIdx]
	volIdx := ext.VolumeIndex
	volumeFileOffset := ext.DataStart + offsetInExtent

	// Find the NNTP segment for this position
	vol := s.volumes[volIdx]
	segIdx := int(volumeFileOffset / s.rarMap.SegmentSize)
	if segIdx >= len(vol.Segments) {
		segIdx = len(vol.Segments) - 1
	}

	log.Printf("[UnRAR-Seek] Executing jump: offset=%d → vol=%d seg=%d", s.absOffset, volIdx, segIdx)

	s.buffer = nil

	for k := range s.results {
		delete(s.results, k)
	}

	target := seekTarget{volIdx: volIdx, segIdx: segIdx}
	select {
	case s.seekCh <- target:
	default:
		select {
		case <-s.seekCh:
		default:
		}
		s.seekCh <- target
	}
}

// Seek implements io.Seeker for http.ServeContent.
func (s *UnrarStreamer) Seek(offset int64, whence int) (int64, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	var newOffset int64
	switch whence {
	case io.SeekStart:
		newOffset = offset
	case io.SeekCurrent:
		newOffset = s.absOffset + offset
	case io.SeekEnd:
		newOffset = s.totalSize + offset
	default:
		return s.absOffset, fmt.Errorf("invalid whence")
	}

	if newOffset < 0 {
		newOffset = 0
	}
	if newOffset > s.totalSize {
		newOffset = s.totalSize
	}

	if s.absOffset == newOffset {
		return s.absOffset, nil
	}

	s.absOffset = newOffset
	s.seekPending = true
	log.Printf("[UnRAR-Seek] Scheduled lazy jump to offset=%d", newOffset)

	return s.absOffset, nil
}

func (s *UnrarStreamer) TotalSize() int64 {
	return s.totalSize
}

func (s *UnrarStreamer) Close() error {
	s.cancel()
	return nil
}

func max64(a, b int64) int64 {
	if a > b {
		return a
	}
	return b
}

func min64(a, b int64) int64 {
	if a < b {
		return a
	}
	return b
}
