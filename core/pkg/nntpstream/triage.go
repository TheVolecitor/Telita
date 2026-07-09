package nntpstream

import (
	"context"
	"fmt"
	"log"
	"math/rand"
	"time"
)

// TriageResult contains the outcome of the triage
type TriageResult struct {
	IsHealthy      bool
	Message        string
	MissingPercent float64
}

// TriageNZB evaluates the health of an NZB by STAT-checking a random sample of segments.
//
// Design philosophy:
//   - Select the correct newsgroup before STATting (many servers give false 430 without it)
//   - Never hard-reject on individual missing segments — the streamer substitutes zeros
//   - Only hard-reject if >20% of a random sample is missing (truly broken NZB)
//   - If we can't get a connection or SELECT a group, assume healthy and let it try
func TriageNZB(ctx context.Context, nzb *NZBResult, sampleSize int) TriageResult {
	if nzb == nil || GlobalPool == nil {
		return TriageResult{IsHealthy: false, Message: "invalid nzb or pool"}
	}

	// Collect all segments and their newsgroups from the primary file
	var allSegments []NZBSegment
	var groups []string

	if nzb.MediaFile != nil {
		allSegments = nzb.MediaFile.Segments
		groups = nzb.MediaFile.Groups
	} else if len(nzb.RARVolumes) > 0 {
		for _, vol := range nzb.RARVolumes {
			allSegments = append(allSegments, vol.Segments...)
		}
		if len(nzb.RARVolumes) > 0 {
			groups = nzb.RARVolumes[0].Groups
		}
	}

	if len(allSegments) == 0 {
		return TriageResult{IsHealthy: false, Message: "no segments found in NZB"}
	}

	// Pick a random sample spread across the whole file
	sample := randomSample(allSegments, sampleSize)

	conn, err := GlobalPool.Acquire(ctx, true)
	if err != nil {
		log.Printf("[NNTP-Triage] Pool error, skipping triage: %v", err)
		return TriageResult{IsHealthy: true, Message: "skipped triage (pool error)"}
	}
	defer GlobalPool.Release(conn, nil)

	// Select the newsgroup FIRST — without this, many servers return false 430
	if len(groups) > 0 {
		code, msg, err := conn.Command(fmt.Sprintf("GROUP %s", groups[0]), 211)
		if err != nil {
			log.Printf("[NNTP-Triage] GROUP %s failed (code=%d, msg=%s, err=%v) — continuing anyway", groups[0], code, msg, err)
			// Don't abort triage if GROUP fails — just log and proceed without it.
			// Some servers don't require GROUP for STAT via message-id.
		} else {
			log.Printf("[NNTP-Triage] Selected group %s", groups[0])
		}
	}

	// STAT each sampled segment
	missing := 0
	for _, seg := range sample {
		code, _, statErr := conn.Command(fmt.Sprintf("STAT <%s>", seg.ID), 223)
		if statErr != nil && code == 430 {
			missing++
			log.Printf("[NNTP-Triage] Missing segment: %s", seg.ID)
		}
	}

	checked := len(sample)
	var missingPct float64
	if checked > 0 {
		missingPct = float64(missing) / float64(checked) * 100
	}

	// Only hard-reject if a large fraction is missing — this means the NZB is
	// truly incomplete (e.g. bad indexer, wrong server, purged old post).
	// A few missing articles are normal and the streamer handles them gracefully.
	const hardRejectThreshold = 20.0
	if missingPct > hardRejectThreshold {
		log.Printf("[NNTP-Triage] Rejecting NZB: %.1f%% missing (%d/%d sampled)", missingPct, missing, checked)
		return TriageResult{
			IsHealthy:      false,
			MissingPercent: missingPct,
			Message:        fmt.Sprintf("%.1f%% of sampled segments missing (>%.0f%% threshold)", missingPct, hardRejectThreshold),
		}
	}

	if missing > 0 {
		log.Printf("[NNTP-Triage] NZB OK with %d/%d missing (%.1f%%) — allowing with graceful degradation", missing, checked, missingPct)
	} else {
		log.Printf("[NNTP-Triage] NZB fully healthy (%d/%d segments OK)", checked, checked)
	}

	return TriageResult{
		IsHealthy:      true,
		MissingPercent: missingPct,
		Message:        fmt.Sprintf("OK (%.1f%% missing in %d-segment sample)", missingPct, checked),
	}
}

// randomSample picks up to n random elements spread across the whole slice.
func randomSample(segs []NZBSegment, n int) []NZBSegment {
	if len(segs) == 0 || n == 0 {
		return nil
	}
	if n >= len(segs) {
		return segs
	}
	r := rand.New(rand.NewSource(time.Now().UnixNano()))
	shuffled := make([]NZBSegment, len(segs))
	copy(shuffled, segs)
	r.Shuffle(len(shuffled), func(i, j int) { shuffled[i], shuffled[j] = shuffled[j], shuffled[i] })
	return shuffled[:n]
}
