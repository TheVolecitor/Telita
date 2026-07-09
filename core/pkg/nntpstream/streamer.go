package nntpstream

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"log"
	"strings"
	"sync"
	"time"

	"github.com/GJRTimmer/yenc"
)

// YencPartInfo holds the exact decoded byte range of one yEnc article.
// This is the key insight from nzbdav: every single yEnc article contains
// =ypart begin=XXX end=YYY in its header, which is the 100% authoritative
// byte range for that segment in the reconstructed file.
type YencPartInfo struct {
	// Begin is the 0-indexed start byte in the final file (=ypart begin - 1)
	Begin int64
	// End is the exclusive end byte in the final file (=ypart end)
	End int64
}

type SegmentResult struct {
	Index int
	Data  []byte
	Part  YencPartInfo
	Err   error
}

type Streamer struct {
	mediaFile *MediaFile
	session   *Session
	ctx       context.Context
	cancel    context.CancelFunc

	mu         sync.Mutex
	currSegIdx int
	buffer     *bytes.Reader

	// Pre-fetching
	results    map[int]*SegmentResult
	notifyCh   chan struct{}
	prefetchWG sync.WaitGroup

	// Seeking
	seekCh        chan int
	totalSize     int64
	absOffset     int64
	pendingOffset int64
	seekPending   bool
}

func NewStreamer(parentCtx context.Context, session *Session) *Streamer {
	ctx, cancel := context.WithCancel(parentCtx)
	s := &Streamer{
		mediaFile:  session.MediaFile,
		session:    session,
		ctx:        ctx,
		cancel:     cancel,
		currSegIdx: 0,
		results:    make(map[int]*SegmentResult),
		notifyCh:   make(chan struct{}, 1),
		seekCh:     make(chan int, 1),
		totalSize:  session.MediaFile.Size,
	}

	// === nzbdav-style exact size calculation ===
	// Don't assume segment sizes. Instead, fetch the LAST segment's yEnc
	// header to read its =ypart end value. That is the 100% exact file size.
	// This mirrors NntpClient.GetFileSizeAsync in nzbdav.
	if len(session.MediaFile.Segments) > 0 && !session.MediaFile.Interpolated {
		lastIdx := len(session.MediaFile.Segments) - 1
		log.Printf("[NNTP-Streamer] Fetching last segment yEnc headers to get exact file size...")
		lastPart, err := s.fetchYencOffsets(session.MediaFile.Segments[lastIdx].ID)
		if err == nil {
			exactSize := lastPart.End
			log.Printf("[NNTP-Streamer] Exact file size from last segment ypart: %d bytes (ypart end=%d)", exactSize, lastPart.End)
			session.MediaFile.Size = exactSize
			session.MediaFile.Interpolated = true
			s.totalSize = exactSize
		} else {
			log.Printf("[NNTP-Streamer] Could not fetch last segment headers (%v), falling back to NZB metadata size: %d", err, session.MediaFile.Size)
		}
	}

	// Spawn prefetch workers
	workers := 8
	workChan := make(chan int)

	// Prefetch manager goroutine
	s.prefetchWG.Add(1)
	go func() {
		defer s.prefetchWG.Done()

		idx := 0
		for {
			if idx >= len(session.MediaFile.Segments) {
				select {
				case <-s.ctx.Done():
					return
				case newIdx := <-s.seekCh:
					idx = newIdx
					continue
				}
			}

			// Throttle prefetching — keep at most 20 segments (~14MB) in RAM
			s.mu.Lock()
			for len(s.results) >= 20 {
				s.mu.Unlock()
				select {
				case <-s.ctx.Done():
					return
				case newIdx := <-s.seekCh:
					idx = newIdx
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
			case newIdx := <-s.seekCh:
				idx = newIdx
				continue
			case workChan <- idx:
				s.mu.Lock()
				ahead := idx - s.currSegIdx
				s.mu.Unlock()
				idx++

				// Stagger dispatches: give the first segment a clear head start
				// so the player gets bytes immediately rather than sharing bandwidth
				// with 7 parallel prefetch workers.
				if ahead == 0 {
					time.Sleep(150 * time.Millisecond)
				} else if ahead < 3 {
					time.Sleep(30 * time.Millisecond)
				}
			}

		nextIter:
		}
	}()

	s.prefetchWG.Add(workers)
	log.Printf("[NNTP-Streamer] Spawning %d prefetch workers for %d segments...", workers, len(session.MediaFile.Segments))
	for i := 0; i < workers; i++ {
		go s.worker(i, workChan)
	}

	return s
}

func (s *Streamer) worker(workerID int, workChan <-chan int) {
	defer s.prefetchWG.Done()
	log.Printf("[NNTP-Streamer] Worker %d started", workerID)
	for {
		select {
		case <-s.ctx.Done():
			log.Printf("[NNTP-Streamer] Worker %d shutting down (context cancelled)", workerID)
			return
		case idx, ok := <-workChan:
			if !ok {
				log.Printf("[NNTP-Streamer] Worker %d shutting down (no more segments)", workerID)
				return
			}
			seg := s.mediaFile.Segments[idx]

			s.mu.Lock()
			ahead := idx - s.currSegIdx
			s.mu.Unlock()
			isHighPriority := ahead <= 1

			data, part, err := s.fetchAndDecodeSegment(seg.ID, isHighPriority)

			if err != nil {
				log.Printf("[NNTP-Streamer] Worker %d failed to fetch segment %d: %v", workerID, idx, err)
			} else {
				log.Printf("[NNTP-Streamer] Worker %d fetched segment %d (%d bytes, ypart %d-%d)", workerID, idx, len(data), part.Begin, part.End)
			}

			s.mu.Lock()
			if idx >= s.currSegIdx {
				s.results[idx] = &SegmentResult{
					Index: idx,
					Data:  data,
					Part:  part,
					Err:   err,
				}
			}
			s.mu.Unlock()

			// Notify reader
			select {
			case s.notifyCh <- struct{}{}:
			default:
			}
		}
	}
}

func (s *Streamer) Read(p []byte) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.session != nil {
		s.session.UpdateLastUsed()
	}

	if s.seekPending {
		s.performLazySeek()
		s.seekPending = false
	}

	for {
		if s.buffer != nil && s.buffer.Len() > 0 {
			n, err := s.buffer.Read(p)
			s.absOffset += int64(n)
			if err != io.EOF {
				return n, err
			}
			if n > 0 {
				return n, nil
			}
		}

		if s.currSegIdx >= len(s.mediaFile.Segments) {
			return 0, io.EOF
		}

		// Wait for the next segment to be ready
		for s.results[s.currSegIdx] == nil {
			s.mu.Unlock()
			select {
			case <-s.ctx.Done():
				s.mu.Lock()
				return 0, s.ctx.Err()
			case <-s.notifyCh:
				s.mu.Lock()
			}
		}

		res := s.results[s.currSegIdx]
		delete(s.results, s.currSegIdx)
		s.currSegIdx++

		if res.Err != nil {
			// A missing/corrupt segment (e.g. 430 No Such Article) should NOT
			// crash the whole stream. Substitute zeros for the expected segment
			// size so the player sees a brief glitch and keeps going.
			// This matches the real-world behaviour of nzbdav and SABnzbd.
			log.Printf("[NNTP-Streamer] Segment %d unavailable (%v) — substituting %d zero bytes", res.Index, res.Err, res.Part.End-res.Part.Begin)
			estimatedSize := res.Part.End - res.Part.Begin
			if estimatedSize <= 0 {
				// Fall back to NZB-reported segment size
				if res.Index < len(s.mediaFile.Segments) {
					estimatedSize = int64(s.mediaFile.Segments[res.Index].Bytes)
				}
				if estimatedSize <= 0 {
					estimatedSize = 716800 // 700KB default segment size
				}
			}
			s.buffer = bytes.NewReader(make([]byte, estimatedSize))
			if s.pendingOffset > 0 {
				s.buffer.Seek(s.pendingOffset, io.SeekStart)
				s.pendingOffset = 0
			}
			continue
		}

		s.buffer = bytes.NewReader(res.Data)
		if s.pendingOffset > 0 {
			s.buffer.Seek(s.pendingOffset, io.SeekStart)
			s.pendingOffset = 0
		}
	}
}

// performLazySeek is the nzbdav-style interpolation search.
// When the player seeks to an arbitrary byte offset, we don't know which
// segment contains it. We use interpolation search (like nzbdav's
// InterpolationSearch.Find) to home in on the correct segment by fetching
// only the tiny yEnc headers (not the full body) of guessed segments.
func (s *Streamer) performLazySeek() {
	targetByte := s.absOffset
	segments := s.mediaFile.Segments
	nSegs := len(segments)

	if nSegs == 0 || targetByte == 0 {
		log.Printf("[NNTP-Seek] Jump to offset=0 → seg=0 offsetInSeg=0")
		s.buffer = nil
		s.currSegIdx = 0
		s.pendingOffset = 0
		s.drainAndSignalSeek(0)
		return
	}

	// First, check if the target is already in the currently buffered segment
	// (cheap path — no network call needed)
	if s.buffer != nil && s.currSegIdx > 0 {
		prevIdx := s.currSegIdx - 1
		if prevRes, ok := s.results[prevIdx]; !ok {
			// Segment is consumed, check position via absOffset arithmetic
			_ = prevRes
		}
	}

	// === nzbdav InterpolationSearch ===
	// We know: total file has nSegs segments, totalSize bytes.
	// Start with an interpolated guess of which segment contains targetByte.
	loIdx := 0
	hiIdx := nSegs - 1
	loByte := int64(0)
	hiByte := s.totalSize

	targetSegIdx := 0
	offsetInSeg := int64(0)

	maxIter := 20 // safety limit
	for iter := 0; iter < maxIter; iter++ {
		if loIdx > hiIdx || loByte >= hiByte {
			break
		}

		// Interpolation formula: guess proportionally where targetByte falls
		// in the remaining index range
		searchByteFromLo := targetByte - loByte
		bytesPerIndex := float64(hiByte-loByte) / float64(hiIdx-loIdx+1)
		guessFromLo := int64(float64(searchByteFromLo) / bytesPerIndex)
		guessIdx := loIdx + int(guessFromLo)
		if guessIdx < loIdx {
			guessIdx = loIdx
		}
		if guessIdx > hiIdx {
			guessIdx = hiIdx
		}

		// Check if we already have this segment's data cached
		var partBegin, partEnd int64
		if cached, ok := s.results[guessIdx]; ok && cached.Err == nil {
			partBegin = cached.Part.Begin
			partEnd = cached.Part.End
			log.Printf("[NNTP-Seek] iter=%d guess=%d (from cache): ypart %d-%d", iter, guessIdx, partBegin, partEnd)
		} else {
			// Fetch only yEnc headers (no body decoding) — very fast
			part, err := s.fetchYencOffsets(segments[guessIdx].ID)
			if err != nil {
				log.Printf("[NNTP-Seek] iter=%d could not fetch headers for seg %d: %v, falling back to NZB offsets", iter, guessIdx, err)
				// Fall back to NZB metadata offsets
				targetSegIdx, offsetInSeg = s.seekFromNZBOffsets(targetByte)
				goto applySeek
			}
			partBegin = part.Begin
			partEnd = part.End
			log.Printf("[NNTP-Seek] iter=%d guess=%d fetched: ypart %d-%d (target=%d)", iter, guessIdx, partBegin, partEnd, targetByte)
		}

		// Exact hit: targetByte is inside this segment
		if targetByte >= partBegin && targetByte < partEnd {
			targetSegIdx = guessIdx
			offsetInSeg = targetByte - partBegin
			log.Printf("[NNTP-Seek] Found! offset=%d → seg=%d offsetInSeg=%d (after %d iters)", targetByte, targetSegIdx, offsetInSeg, iter+1)
			goto applySeek
		}

		// Guessed too low: search higher
		if partEnd <= targetByte {
			loIdx = guessIdx + 1
			loByte = partEnd
		} else {
			// Guessed too high: search lower
			hiIdx = guessIdx - 1
			hiByte = partBegin
		}
	}

	// If we ran out of iterations, fall back to NZB offsets
	log.Printf("[NNTP-Seek] Interpolation exhausted, falling back to NZB offsets for target=%d", targetByte)
	targetSegIdx, offsetInSeg = s.seekFromNZBOffsets(targetByte)

applySeek:
	log.Printf("[NNTP-Seek] Applying jump: offset=%d → seg=%d offsetInSeg=%d", targetByte, targetSegIdx, offsetInSeg)

	// If the segment is already buffered in the current buffer, just seek within it
	if targetSegIdx == s.currSegIdx-1 && s.buffer != nil {
		s.buffer.Seek(offsetInSeg, io.SeekStart)
		return
	}

	s.buffer = nil
	s.currSegIdx = targetSegIdx
	s.pendingOffset = offsetInSeg

	// Discard all cached segments — they're now ahead of / behind us
	for k := range s.results {
		delete(s.results, k)
	}

	s.drainAndSignalSeek(targetSegIdx)
}

// seekFromNZBOffsets falls back to binary search over the NZB-provided
// cumulative byte offsets (less accurate but always available).
func (s *Streamer) seekFromNZBOffsets(targetByte int64) (segIdx int, offsetInSeg int64) {
	offsets := s.mediaFile.SegmentOffsets
	if len(offsets) == 0 {
		return 0, 0
	}
	lo, hi := 0, len(s.mediaFile.Segments)-1
	for lo < hi {
		mid := (lo + hi + 1) / 2
		if offsets[mid] <= targetByte {
			lo = mid
		} else {
			hi = mid - 1
		}
	}
	return lo, targetByte - offsets[lo]
}

// drainAndSignalSeek discards any pending seek signal and sends the new one.
func (s *Streamer) drainAndSignalSeek(segIdx int) {
	select {
	case s.seekCh <- segIdx:
	default:
		// Drain the old pending seek
		select {
		case <-s.seekCh:
		default:
		}
		s.seekCh <- segIdx
	}
}

func (s *Streamer) Seek(offset int64, whence int) (int64, error) {
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
	log.Printf("[NNTP-Seek] Scheduled lazy jump to offset=%d (totalSize=%d)", newOffset, s.totalSize)

	return s.absOffset, nil
}

func (s *Streamer) TotalSize() int64 {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.totalSize
}

// fetchYencOffsets fetches a raw NNTP article body and extracts ONLY the
// =ypart begin/end offsets WITHOUT decoding the full yEnc body.
// Retries once on transient network errors (wsasend/wsarecv, etc.).
func (s *Streamer) fetchYencOffsets(messageID string) (YencPartInfo, error) {
	var lastErr error
	for attempt := 0; attempt < 2; attempt++ {
		part, err := s.tryFetchYencOffsets(messageID)
		if err == nil {
			return part, nil
		}
		if !isTransientNetworkError(err) {
			return YencPartInfo{}, err // 430 or permanent — don't retry
		}
		log.Printf("[NNTP-Offsets] Transient error on %s (attempt %d): %v", messageID, attempt+1, err)
		lastErr = err
		time.Sleep(300 * time.Millisecond)
	}
	return YencPartInfo{}, lastErr
}

func (s *Streamer) tryFetchYencOffsets(messageID string) (YencPartInfo, error) {
	conn, err := GlobalPool.Acquire(s.ctx, true)
	if err != nil {
		return YencPartInfo{}, err
	}

	if len(s.mediaFile.Groups) > 0 {
		_, _ = conn.Group(s.mediaFile.Groups[0])
	}

	_, _, bodyReader, err := conn.Body("<" + messageID + ">")
	if err != nil {
		GlobalPool.Release(conn, err)
		return YencPartInfo{}, err
	}

	// We only need the first ~512 bytes to find the =ypart header
	buf := make([]byte, 512)
	headerBuf := &bytes.Buffer{}
	for {
		n, readErr := bodyReader.Read(buf)
		if n > 0 {
			headerBuf.Write(buf[:n])
		}
		if bytes.Contains(headerBuf.Bytes(), []byte("\n=ypart")) || headerBuf.Len() > 2048 {
			break
		}
		if readErr != nil {
			break
		}
	}

	GlobalPool.Release(conn, nil)

	part, err := extractYencOffsets(headerBuf.Bytes())
	if err != nil {
		return YencPartInfo{}, fmt.Errorf("extracting ypart from %s: %w", messageID, err)
	}
	return part, nil
}

// fetchAndDecodeSegment downloads and yEnc-decodes a full segment body.
// Retries once on transient network errors (wsasend/wsarecv, connection reset).
func (s *Streamer) fetchAndDecodeSegment(messageID string, isHighPriority bool) ([]byte, YencPartInfo, error) {
	var lastErr error
	for attempt := 0; attempt < 2; attempt++ {
		data, part, err := s.tryFetchAndDecodeSegment(messageID, isHighPriority)
		if err == nil {
			return data, part, nil
		}
		if !isTransientNetworkError(err) {
			return nil, YencPartInfo{}, err // 430 or context cancelled — don't retry
		}
		log.Printf("[NNTP-Streamer] Transient error for %s (attempt %d): %v — retrying...", messageID, attempt+1, err)
		lastErr = err
		time.Sleep(500 * time.Millisecond)
	}
	return nil, YencPartInfo{}, lastErr
}

func (s *Streamer) tryFetchAndDecodeSegment(messageID string, isHighPriority bool) ([]byte, YencPartInfo, error) {
	conn, err := GlobalPool.Acquire(s.ctx, isHighPriority)
	if err != nil {
		return nil, YencPartInfo{}, err
	}

	if len(s.mediaFile.Groups) > 0 {
		_, _ = conn.Group(s.mediaFile.Groups[0])
	}

	_, _, bodyReader, err := conn.Body("<" + messageID + ">")
	if err != nil {
		GlobalPool.Release(conn, err)
		return nil, YencPartInfo{}, err
	}

	raw, err := io.ReadAll(bodyReader)
	if err != nil {
		GlobalPool.Release(conn, err)
		return nil, YencPartInfo{}, err
	}

	GlobalPool.Release(conn, nil)

	part, _ := extractYencOffsets(raw)

	dec, _, err := yenc.Decode(raw)
	if err != nil && len(dec) == 0 {
		return nil, YencPartInfo{}, err
	}

	if s.ctx.Err() != nil {
		return nil, YencPartInfo{}, s.ctx.Err()
	}

	return dec, part, nil
}

// isTransientNetworkError returns true for errors that are worth retrying
// (TCP connection resets, wsasend/wsarecv failures) vs permanent errors
// like 430 article missing or context cancellation.
func isTransientNetworkError(err error) bool {
	if err == nil {
		return false
	}
	msg := err.Error()
	// Don't retry: article missing, context cancelled
	if strings.Contains(msg, "430") ||
		strings.Contains(msg, "context canceled") ||
		strings.Contains(msg, "context deadline") {
		return false
	}
	// Retry: TCP-level errors from Windows (wsasend, wsarecv, connection reset, EOF)
	return strings.Contains(msg, "wsasend") ||
		strings.Contains(msg, "wsarecv") ||
		strings.Contains(msg, "connection reset") ||
		strings.Contains(msg, "broken pipe") ||
		strings.Contains(msg, "EOF") ||
		strings.Contains(msg, "connection aborted")
}

// extractYencOffsets parses the =ypart begin=X end=Y header from raw yEnc article bytes.
// Returns 0-indexed begin (=ypart begin - 1) and exclusive end (=ypart end).
func extractYencOffsets(raw []byte) (YencPartInfo, error) {
	idx := bytes.Index(raw, []byte("=ypart "))
	if idx == -1 {
		return YencPartInfo{}, fmt.Errorf("no =ypart header")
	}

	lineEnd := bytes.IndexByte(raw[idx:], '\n')
	if lineEnd == -1 {
		lineEnd = len(raw) - idx
	}
	line := string(raw[idx : idx+lineEnd])

	beginIdx := strings.Index(line, "begin=")
	endIdx := strings.Index(line, " end=")
	if beginIdx == -1 || endIdx == -1 {
		return YencPartInfo{}, fmt.Errorf("malformed =ypart line: %q", line)
	}

	var begin, end int64
	_, err := fmt.Sscanf(line[beginIdx:], "begin=%d", &begin)
	if err != nil {
		return YencPartInfo{}, fmt.Errorf("parsing begin: %w", err)
	}
	_, err = fmt.Sscanf(line[endIdx+1:], "end=%d", &end)
	if err != nil {
		return YencPartInfo{}, fmt.Errorf("parsing end: %w", err)
	}
	// yEnc begin is 1-indexed, convert to 0-indexed
	return YencPartInfo{Begin: begin - 1, End: end}, nil
}

func (s *Streamer) Close() error {
	s.cancel()
	return nil
}
