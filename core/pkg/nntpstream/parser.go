package nntpstream

import (
	"encoding/xml"
	"errors"
	"io"
	"regexp"
	"sort"
	"strconv"
	"strings"

	"golang.org/x/net/html/charset"
)

type NZBSegment struct {
	Bytes  int    `xml:"bytes,attr"`
	Number int    `xml:"number,attr"`
	ID     string `xml:",chardata"`
}

type NZBGroup struct {
	Name string `xml:",chardata"`
}

type NZBFile struct {
	Subject  string       `xml:"subject,attr"`
	Poster   string       `xml:"poster,attr"`
	Date     int          `xml:"date,attr"`
	Groups   []NZBGroup   `xml:"groups>group"`
	Segments []NZBSegment `xml:"segments>segment"`
}

type NZB struct {
	XMLName xml.Name  `xml:"nzb"`
	Files   []NZBFile `xml:"file"`
}

type MediaFile struct {
	Name           string
	Segments       []NZBSegment
	SegmentOffsets []int64 // cumulative byte offset of each segment start
	Groups         []string
	Size           int64
	Interpolated   bool
}

// NZBResult holds the full parsed output from an NZB file.
type NZBResult struct {
	// Direct media file (.mkv, .mp4, .avi) if found — nil if packed in RAR
	MediaFile *MediaFile
	// Ordered RAR volumes if the NZB contains a multi-volume archive
	RARVolumes []*MediaFile
	// True if the content is packed inside RAR archives
	IsPacked bool
}

// partNumberRegex extracts the part number from filenames like:
// "movie.part01.rar", "movie.part1.rar", "movie.part001.rar"
var partNumberRegex = regexp.MustCompile(`\.part(\d+)\.rar`)

// extractPartNumber returns the RAR volume part number from a subject string.
// Returns 0 for a .rar without .partXX (meaning it's the root volume).
// Returns -1 if not a RAR file.
func extractPartNumber(subject string) int {
	lower := strings.ToLower(subject)
	if !strings.Contains(lower, ".rar") {
		return -1
	}
	matches := partNumberRegex.FindStringSubmatch(lower)
	if matches != nil {
		n, err := strconv.Atoi(matches[1])
		if err == nil {
			return n
		}
	}
	// It's a .rar file but without .partXX — this is the root volume (part 0)
	if strings.Contains(lower, ".rar") && !strings.Contains(lower, ".part") {
		return 0
	}
	return -1
}

// buildMediaFile creates a MediaFile from an NZBFile, sorting segments and
// computing cumulative byte offsets.
func buildMediaFile(file NZBFile) *MediaFile {
	groups := make([]string, len(file.Groups))
	for i, g := range file.Groups {
		groups[i] = g.Name
	}

	// Sort segments by their actual NZB number to handle obfuscated out-of-order files
	sort.Slice(file.Segments, func(i, j int) bool {
		return file.Segments[i].Number < file.Segments[j].Number
	})

	// Precompute cumulative byte offsets from NZB segment byte counts.
	segments := file.Segments
	offsets := make([]int64, len(segments)+1)
	offsets[0] = 0
	var totalSize int64
	for i, seg := range segments {
		offsets[i+1] = offsets[i] + int64(seg.Bytes)
		totalSize += int64(seg.Bytes)
	}

	return &MediaFile{
		Name:           file.Subject,
		Segments:       segments,
		SegmentOffsets: offsets,
		Groups:         groups,
		Size:           totalSize,
	}
}

// ParseNZBFull parses an NZB and returns either a direct media file or
// an ordered list of RAR volumes ready for on-the-fly un-rarring.
func ParseNZBFull(r io.Reader) (*NZBResult, error) {
	decoder := xml.NewDecoder(r)
	decoder.CharsetReader = charset.NewReaderLabel

	var allFiles []NZBFile

	for {
		t, err := decoder.Token()
		if err != nil {
			if err == io.EOF {
				break
			}
			return nil, err
		}

		switch se := t.(type) {
		case xml.StartElement:
			if se.Name.Local == "file" {
				var file NZBFile
				if err := decoder.DecodeElement(&file, &se); err != nil {
					return nil, err
				}
				allFiles = append(allFiles, file)
			}
		}
	}

	if len(allFiles) == 0 {
		return nil, errors.New("no files found in nzb")
	}

	// First pass: look for direct media files (.mkv, .mp4, .avi)
	var bestMedia NZBFile
	var bestMediaSize int64
	for _, file := range allFiles {
		name := strings.ToLower(file.Subject)
		isMedia := strings.Contains(name, ".mkv") || strings.Contains(name, ".mp4") || strings.Contains(name, ".avi")
		if !isMedia {
			continue
		}
		var size int64
		for _, seg := range file.Segments {
			size += int64(seg.Bytes)
		}
		if size > bestMediaSize {
			bestMediaSize = size
			bestMedia = file
		}
	}

	// If we found a direct media file, use it (no un-rarring needed)
	if bestMediaSize > 0 {
		mf := buildMediaFile(bestMedia)
		return &NZBResult{
			MediaFile: mf,
			IsPacked:  false,
		}, nil
	}

	// Second pass: collect all RAR volumes
	type rarEntry struct {
		file    NZBFile
		partNum int
	}
	var rarFiles []rarEntry
	for _, file := range allFiles {
		pn := extractPartNumber(file.Subject)
		if pn >= 0 {
			rarFiles = append(rarFiles, rarEntry{file: file, partNum: pn})
		}
	}

	if len(rarFiles) == 0 {
		// Fallback: no media, no RARs — just pick the largest file
		var largest NZBFile
		var largestSize int64
		for _, file := range allFiles {
			var size int64
			for _, seg := range file.Segments {
				size += int64(seg.Bytes)
			}
			if size > largestSize {
				largestSize = size
				largest = file
			}
		}
		mf := buildMediaFile(largest)
		return &NZBResult{
			MediaFile: mf,
			IsPacked:  false,
		}, nil
	}

	// Sort RAR volumes by part number
	sort.Slice(rarFiles, func(i, j int) bool {
		return rarFiles[i].partNum < rarFiles[j].partNum
	})

	// Build MediaFile for each volume
	volumes := make([]*MediaFile, len(rarFiles))
	for i, rf := range rarFiles {
		volumes[i] = buildMediaFile(rf.file)
	}

	return &NZBResult{
		RARVolumes: volumes,
		IsPacked:   true,
	}, nil
}

// ParseNZB is a backward-compatible wrapper that returns a single MediaFile.
// It prefers direct media files, then falls back to the first RAR volume.
func ParseNZB(r io.Reader) (*MediaFile, error) {
	result, err := ParseNZBFull(r)
	if err != nil {
		return nil, err
	}
	if result.MediaFile != nil {
		return result.MediaFile, nil
	}
	if len(result.RARVolumes) > 0 {
		return result.RARVolumes[0], nil
	}
	return nil, errors.New("no files found in nzb")
}
