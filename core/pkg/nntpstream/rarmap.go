package nntpstream

import (
	"context"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"log"
	"strings"
	"sync"
	"unicode"
	"unicode/utf8"

	"github.com/GJRTimmer/yenc"
)

// RAR5 signature: Rar!\x1a\x07\x01\x00
var rar5Sig = []byte{0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00}

// RAR5 block header types
const (
	rarBlockMain    = 1
	rarBlockFile    = 2
	rarBlockService = 3
	rarBlockEnd     = 5
)

// RAR5 header flags
const (
	rarFlagExtraArea = 0x0001
	rarFlagDataArea  = 0x0002
)

// RAR5 file header flags
const (
	rarFileFlagSplitBefore = 0x0001 // file continues from previous volume
	rarFileFlagSplitAfter  = 0x0002 // file continues in next volume
)

type RARDataExtent struct {
	VolumeIndex    int   // which .rar volume (0 = part01, 1 = part02, ...)
	DataStart      int64 // byte offset within the RAR volume where raw data begins
	DataLength     int64 // length of the raw data block in this volume
	VideoByteStart int64 // corresponding start offset in the virtual video file
	Parsed         bool  // true if DataStart was accurately parsed from headers
}

type RARMap struct {
	mu          sync.RWMutex
	Filename    string          // archived filename (e.g. "movie.mkv")
	TotalSize   int64           // total uncompressed video file size
	Extents     []RARDataExtent // ordered list mapping video bytes → volume positions
	IsStoreMode bool            // true if compression method = 0 (no compression)
	SegmentSize int64           // actual decoded byte size of a typical segment (e.g. 768000)
}

// readVint reads a RAR5 variable-length integer from a byte slice starting
// at position pos. Returns the decoded value and the number of bytes consumed.
func readVint(data []byte, pos int) (uint64, int) {
	var result uint64
	var shift uint
	consumed := 0
	for {
		if pos+consumed >= len(data) {
			return result, consumed
		}
		b := data[pos+consumed]
		consumed++
		result |= uint64(b&0x7F) << shift
		shift += 7
		if b&0x80 == 0 {
			break
		}
		if shift >= 64 {
			break // overflow protection
		}
	}
	return result, consumed
}

// VolumeHeaderInfo holds the parsed RAR header information from a single volume.
type VolumeHeaderInfo struct {
	ArchivedFilename string
	DataOffset       int64  // byte offset in the volume where file data begins
	PackedSize       int64  // size of data area in this volume
	UnpackedSize     int64  // full unpacked size (only meaningful in first volume)
	CompressionInfo  uint64 // raw compression info field
	FileFlags        uint64 // file-specific flags (split before/after)
	IsStoreMode      bool   // compression method == 0
	HasFileHeader    bool   // whether we found a file header at all
	SegmentSize      int64  // actual length of decoded segment data
}

// ParseRARHeaders parses the RAR block headers (RAR4 or RAR5) from the first segment of a
// volume and extracts the file header information needed for byte mapping.
func ParseRARHeaders(data []byte) (*VolumeHeaderInfo, error) {
	info, err := ParseRAR5Headers(data)
	if err != nil {
		info, err = ParseRAR4Headers(data)
	}
	return info, err
}

// ParseRAR4Headers parses older RAR4 format block headers
func ParseRAR4Headers(data []byte) (*VolumeHeaderInfo, error) {
	if len(data) < 7 {
		return nil, errors.New("data too short for RAR4 signature")
	}

	rar4Sig := []byte{0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00}
	sigPos := -1
	for i := 0; i <= len(data)-7; i++ {
		match := true
		for j := 0; j < 7; j++ {
			if data[i+j] != rar4Sig[j] {
				match = false
				break
			}
		}
		if match {
			sigPos = i
			break
		}
	}
	if sigPos < 0 {
		return nil, errors.New("RAR4 signature not found")
	}

	pos := sigPos + 7
	info := &VolumeHeaderInfo{}

	for pos < len(data)-7 {
		blockStart := pos
		// CRC: 2 bytes, Type: 1 byte, Flags: 2 bytes, Size: 2 bytes
		headerType := data[pos+2]
		flags := binary.LittleEndian.Uint16(data[pos+3 : pos+5])
		headerSize := binary.LittleEndian.Uint16(data[pos+5 : pos+7])

		var packSize int64
		// If ADD_SIZE flag is set, read PackSize
		if flags&0x8000 != 0 {
			if pos+11 > len(data) {
				break
			}
			packSize = int64(binary.LittleEndian.Uint32(data[pos+7 : pos+11]))
		}

		if headerType == 0x74 { // File Header
			if pos+32 > len(data) {
				break
			}
			unpackedSize := int64(binary.LittleEndian.Uint32(data[pos+11 : pos+15]))
			method := data[pos+25]
			nameSize := int(binary.LittleEndian.Uint16(data[pos+26 : pos+28]))

			// If High Size flag is set
			if flags&0x0100 != 0 {
				if pos+32+8 > len(data) {
					break
				}
				highPackSize := int64(binary.LittleEndian.Uint32(data[pos+32 : pos+36]))
				highUnpackSize := int64(binary.LittleEndian.Uint32(data[pos+36 : pos+40]))
				packSize = (highPackSize << 32) | packSize
				unpackedSize = (highUnpackSize << 32) | unpackedSize

				if pos+40+nameSize <= len(data) {
					info.ArchivedFilename = sanitizeRARFilename(string(data[pos+40 : pos+40+nameSize]))
				}
			} else {
				if pos+32+nameSize <= len(data) {
					info.ArchivedFilename = sanitizeRARFilename(string(data[pos+32 : pos+32+nameSize]))
				}
			}

			if info.ArchivedFilename == "" || unpackedSize > info.UnpackedSize {
				info.DataOffset = int64(blockStart) + int64(headerSize)
				info.PackedSize = packSize
				info.UnpackedSize = unpackedSize
				info.IsStoreMode = method == 0x30 // 0x30 (48) is Store mode in RAR4
				info.HasFileHeader = true
			}
		}

		nextBlock := int64(blockStart) + int64(headerSize)
		if flags&0x8000 != 0 {
			nextBlock += packSize
		}
		if nextBlock <= int64(blockStart) {
			break
		}
		pos = int(nextBlock)
	}

	if !info.HasFileHeader {
		return nil, errors.New("no file header found in RAR4 data")
	}

	log.Printf("[RAR-Parse] RAR4 Selected largest file: %s, packed=%d, unpacked=%d, store=%v, dataOffset=%d",
		info.ArchivedFilename, info.PackedSize, info.UnpackedSize, info.IsStoreMode, info.DataOffset)

	return info, nil
}

// ParseRAR5Headers parses the RAR5 block headers from the first segment of a
// volume and extracts the file header information needed for byte mapping.
func ParseRAR5Headers(data []byte) (*VolumeHeaderInfo, error) {
	if len(data) < 8 {
		return nil, errors.New("data too short for RAR signature")
	}

	// Find RAR5 signature
	sigPos := -1
	for i := 0; i <= len(data)-8; i++ {
		match := true
		for j := 0; j < 8; j++ {
			if data[i+j] != rar5Sig[j] {
				match = false
				break
			}
		}
		if match {
			sigPos = i
			break
		}
	}
	if sigPos < 0 {
		return nil, errors.New("RAR5 signature not found")
	}

	pos := sigPos + 8 // skip signature
	info := &VolumeHeaderInfo{}

	// Walk through blocks until we find a File header
	for pos < len(data)-10 {
		blockStart := pos

		// Header CRC32 (4 bytes)
		if pos+4 > len(data) {
			break
		}
		pos += 4 // skip CRC32

		// Header size (vint)
		headerSize, n := readVint(data, pos)
		if n == 0 {
			break
		}
		headerDataStart := pos + n // this is where "header type" begins
		pos += n

		// Header type (vint)
		headerType, n := readVint(data, pos)
		if n == 0 {
			break
		}
		pos += n

		// Header flags (vint)
		headerFlags, n := readVint(data, pos)
		if n == 0 {
			break
		}
		pos += n

		// Extra area size (vint, optional)
		var extraAreaSize uint64
		if headerFlags&rarFlagExtraArea != 0 {
			extraAreaSize, n = readVint(data, pos)
			if n == 0 {
				break
			}
			pos += n
			_ = extraAreaSize
		}

		// Data area size (vint, optional)
		var dataAreaSize uint64
		if headerFlags&rarFlagDataArea != 0 {
			dataAreaSize, n = readVint(data, pos)
			if n == 0 {
				break
			}
			pos += n
		}

		if headerType == rarBlockFile || headerType == rarBlockService {
			// Parse file header fields
			// File flags (vint)
			fileFlags, fn := readVint(data, pos)
			if fn == 0 {
				break
			}
			pos += fn

			// Unpacked size (vint)
			unpackedSize, fn := readVint(data, pos)
			if fn == 0 {
				break
			}
			pos += fn

			// Attributes (vint)
			_, fn = readVint(data, pos)
			if fn == 0 {
				break
			}
			pos += fn

			// mtime (uint32) — only present if fileFlags & 0x0002 is set
			if fileFlags&0x0002 != 0 {
				if pos+4 > len(data) {
					break
				}
				pos += 4 // skip mtime
			}

			// Data CRC32 (uint32) — only if flag 0x0004 is set? Always present for file headers
			if fileFlags&0x0004 != 0 {
				if pos+4 > len(data) {
					break
				}
				pos += 4 // skip data CRC32
			}

			// Compression information (vint)
			compressionInfo, fn := readVint(data, pos)
			if fn == 0 {
				break
			}
			pos += fn

			// Host OS (vint)
			_, fn = readVint(data, pos)
			if fn == 0 {
				break
			}
			pos += fn

			// Name length (vint)
			nameLength, fn := readVint(data, pos)
			if fn == 0 {
				break
			}
			pos += fn

			// Name (nameLength bytes, UTF-8)
			if pos+int(nameLength) > len(data) {
				break
			}
			rawName := data[pos : pos+int(nameLength)]
			filename := sanitizeRARFilename(string(rawName))
			pos += int(nameLength)

			// Only process File headers (not Service headers like CMT, QO)
			if headerType == rarBlockFile {
				// Compression method is bits 8-10 (0x0380 mask)
				compMethod := (compressionInfo >> 7) & 0x07

				// The data area starts right after the full header
				dataOffset := int64(headerDataStart) + int64(headerSize)

				// We do NOT return immediately! A RAR file may contain an .nfo first and then the .mkv.
				// We want to find the largest file (typically the video file) in the archive.
				// We only replace the current info if the newly found file is larger.
				if info.ArchivedFilename == "" || int64(unpackedSize) > info.UnpackedSize {
					info.ArchivedFilename = filename
					info.DataOffset = dataOffset
					info.PackedSize = int64(dataAreaSize)
					info.UnpackedSize = int64(unpackedSize)
					info.CompressionInfo = compressionInfo
					info.FileFlags = fileFlags
					info.IsStoreMode = compMethod == 0
					info.HasFileHeader = true
				}
			}
		}

		// Skip to next block: header data starts at headerDataStart,
		// header content is headerSize bytes, then dataAreaSize bytes of data
		nextBlock := int64(headerDataStart) + int64(headerSize) + int64(dataAreaSize)
		if nextBlock <= int64(blockStart) {
			break // prevent infinite loop
		}
		pos = int(nextBlock)
	}

	if !info.HasFileHeader {
		return nil, errors.New("no file header found in RAR data")
	}

	log.Printf("[RAR-Parse] Selected largest file: %s, packed=%d, unpacked=%d, store=%v, dataOffset=%d",
		info.ArchivedFilename, info.PackedSize, info.UnpackedSize, info.IsStoreMode, info.DataOffset)

	return info, nil
}

// BuildRARMap constructs a complete byte map from the parsed headers of all
// RAR volumes. It requires the first segment data from each volume.
//
// volumeHeaders[i] corresponds to RARVolumes[i].
func BuildRARMap(volumeHeaders []*VolumeHeaderInfo) (*RARMap, error) {
	if len(volumeHeaders) == 0 {
		return nil, errors.New("no volume headers provided")
	}

	// Find the archived filename from the first volume that has one
	filename := ""
	for _, vh := range volumeHeaders {
		if vh.ArchivedFilename != "" {
			filename = vh.ArchivedFilename
			break
		}
	}

	// Verify all volumes use Store mode
	allStore := true
	for _, vh := range volumeHeaders {
		if !vh.IsStoreMode {
			allStore = false
			break
		}
	}

	if !allStore {
		// Find what compression is used
		return nil, fmt.Errorf("RAR volumes use compression (not Store mode) — cannot stream directly")
	}

	// Build extents: each volume contributes one contiguous data extent
	var extents []RARDataExtent
	var videoOffset int64

	for i, vh := range volumeHeaders {
		if vh.PackedSize <= 0 {
			log.Printf("[RAR-Map] Warning: volume %d has zero packed size, skipping", i)
			continue
		}

		extent := RARDataExtent{
			VolumeIndex:    i,
			DataStart:      vh.DataOffset,
			DataLength:     vh.PackedSize,
			VideoByteStart: videoOffset,
			Parsed:         (i == 0 || i == len(volumeHeaders)-1), // First and last were actually parsed
		}
		extents = append(extents, extent)
		videoOffset += vh.PackedSize

		log.Printf("[RAR-Map] Volume %d: videoBytes[%d..%d] → RAR offset %d, length %d",
			i, extent.VideoByteStart, extent.VideoByteStart+extent.DataLength, extent.DataStart, extent.DataLength)
	}

	totalSize := videoOffset

	// Cross-check: the first volume's UnpackedSize should equal totalSize for Store mode
	if volumeHeaders[0].UnpackedSize > 0 && volumeHeaders[0].UnpackedSize != totalSize {
		log.Printf("[RAR-Map] Note: first volume reports unpackedSize=%d but sum of packed sizes=%d (expected for multi-vol Store)",
			volumeHeaders[0].UnpackedSize, totalSize)
		// For Store mode, the first volume's UnpackedSize is the total file size
		// while PackedSize is only the data in that specific volume.
		// So use UnpackedSize as the authoritative total.
		totalSize = volumeHeaders[0].UnpackedSize
	}

	// Detect media type from filename
	lowerName := strings.ToLower(filename)
	isMedia := strings.Contains(lowerName, ".mkv") || strings.Contains(lowerName, ".mp4") ||
		strings.Contains(lowerName, ".avi") || strings.Contains(lowerName, ".m4v")

	if !isMedia {
		log.Printf("[RAR-Map] Warning: archived file '%s' doesn't look like a video file", filename)
	}

	rarMap := &RARMap{
		Filename:    filename,
		TotalSize:   totalSize,
		Extents:     extents,
		IsStoreMode: true,
		SegmentSize: volumeHeaders[0].SegmentSize,
	}

	log.Printf("[RAR-Map] Built map: file=%s, totalSize=%d bytes (%.1f MB), %d extents across %d volumes",
		filename, totalSize, float64(totalSize)/1024/1024, len(extents), len(volumeHeaders))

	return rarMap, nil
}

// FindExtent finds the extent containing the given video byte offset using
// binary search. Returns the extent index and the offset within that extent.
func (m *RARMap) FindExtent(videoOffset int64) (extentIdx int, offsetInExtent int64) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	// Binary search: find the last extent where VideoByteStart <= videoOffset
	lo, hi := 0, len(m.Extents)-1
	for lo < hi {
		mid := (lo + hi + 1) / 2
		if m.Extents[mid].VideoByteStart <= videoOffset {
			lo = mid
		} else {
			hi = mid - 1
		}
	}
	return lo, videoOffset - m.Extents[lo].VideoByteStart
}

// TranslateVideoOffset converts a video byte offset to a volume index and
// byte offset within that volume's raw data stream.
func (m *RARMap) TranslateVideoOffset(videoOffset int64) (volumeIdx int, volumeDataOffset int64) {
	extIdx, offsetInExtent := m.FindExtent(videoOffset)
	m.mu.RLock()
	ext := m.Extents[extIdx]
	m.mu.RUnlock()
	return ext.VolumeIndex, ext.DataStart + offsetInExtent
}

// ScanRARHeaders fetches the first segment of the FIRST and LAST RAR volumes to establish
// the total unpacked size and verify the format. It skips scanning intermediate volumes
// to prevent massive network delays, relying on interpolation instead.
func ScanRARHeaders(ctx context.Context, volumes []*MediaFile) ([]*VolumeHeaderInfo, error) {
	if len(volumes) == 0 {
		return nil, fmt.Errorf("no volumes to scan")
	}

	headers := make([]*VolumeHeaderInfo, len(volumes))
	
	// Scan only first and last volume
	indicesToScan := []int{0}
	if len(volumes) > 1 {
		indicesToScan = append(indicesToScan, len(volumes)-1)
	}

	type result struct {
		index int
		info  *VolumeHeaderInfo
		err   error
	}

	results := make(chan result, len(indicesToScan))

	// Fetch required volumes concurrently
	for _, idx := range indicesToScan {
		go func(idx int, v *MediaFile) {
			if len(v.Segments) == 0 {
				results <- result{idx, nil, fmt.Errorf("volume %d has no segments", idx)}
				return
			}

			seg := v.Segments[0]
			conn, err := GlobalPool.Acquire(ctx, false) // False = low priority (background pre-fetch)
			if err != nil {
				results <- result{idx, nil, fmt.Errorf("acquire conn for volume %d: %w", idx, err)}
				return
			}

			if len(v.Groups) > 0 {
				conn.Group(v.Groups[0])
			}

			_, _, bodyReader, err := conn.Body("<" + seg.ID + ">")
			if err != nil {
				GlobalPool.Release(conn, err)
				results <- result{idx, nil, fmt.Errorf("fetch segment 0 of volume %d: %w", idx, err)}
				return
			}

			raw, err := io.ReadAll(bodyReader)
			GlobalPool.Release(conn, nil)
			if err != nil {
				results <- result{idx, nil, fmt.Errorf("read segment 0 of volume %d: %w", idx, err)}
				return
			}

			// Decode yEnc
			dec, _, err := yenc.Decode(raw)
			if err != nil && len(dec) == 0 {
				results <- result{idx, nil, fmt.Errorf("yenc decode volume %d: %w", idx, err)}
				return
			}

			// Parse RAR headers
			info, err := ParseRARHeaders(dec)
			if err != nil {
				results <- result{idx, nil, fmt.Errorf("parse RAR headers volume %d: %w", idx, err)}
				return
			}
			info.SegmentSize = int64(len(dec))

			log.Printf("[RAR-Scan] Volume %d/%d scanned: file=%s, dataOffset=%d, packedSize=%d",
				idx+1, len(volumes), info.ArchivedFilename, info.DataOffset, info.PackedSize)

			results <- result{idx, info, nil}
		}(idx, volumes[idx])
	}

	// Collect results
	for i := 0; i < len(indicesToScan); i++ {
		r := <-results
		if r.err != nil {
			return nil, r.err
		}
		headers[r.index] = r.info
	}

	// For all intermediate volumes (1 to N-2), we interpolate the header info.
	// Volume 1+ almost always has exactly 1 extra byte in the header for the "SplitBefore" flag.
	vol0 := headers[0]
	estimatedDataOffset := vol0.DataOffset + 1 
	if len(volumes) > 1 {
		// Just in case vol0 had SplitBefore anyway
		if vol0.FileFlags&rarFileFlagSplitBefore != 0 {
			estimatedDataOffset = vol0.DataOffset
		}
	}

	for i := 1; i < len(volumes)-1; i++ {
		// Calculate total bytes in this volume from NZB segments
		var volTotalSize int64
		for _, seg := range volumes[i].Segments {
			volTotalSize += int64(seg.Bytes)
		}

		headers[i] = &VolumeHeaderInfo{
			ArchivedFilename: vol0.ArchivedFilename,
			DataOffset:       estimatedDataOffset,
			PackedSize:       volTotalSize - estimatedDataOffset,
			UnpackedSize:     0, // Only matters for Vol 0
			IsStoreMode:      true,
			HasFileHeader:    true,
			SegmentSize:      vol0.SegmentSize,
		}
	}

	return headers, nil
}

// readUint32LE reads a little-endian uint32 from a byte slice.
func readUint32LE(data []byte, pos int) uint32 {
	return binary.LittleEndian.Uint32(data[pos : pos+4])
}

// sanitizeRARFilename strips non-printable and non-UTF8 characters from
// RAR filenames. Some RAR headers include trailing binary data or NUL bytes
// that can corrupt the filename string.
func sanitizeRARFilename(s string) string {
	// Find the first NUL byte or non-printable character and truncate
	var clean strings.Builder
	for i := 0; i < len(s); {
		r, size := utf8.DecodeRuneInString(s[i:])
		if r == utf8.RuneError && size <= 1 {
			break // invalid UTF-8, stop here
		}
		if r == 0 {
			break // NUL terminator
		}
		if !unicode.IsPrint(r) && r != '/' && r != '\\' {
			break // non-printable character
		}
		clean.WriteRune(r)
		i += size
	}
	return clean.String()
}
