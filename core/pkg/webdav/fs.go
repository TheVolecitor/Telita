package webdavfs

import (
	"context"
	"os"
	"strings"
	"time"

	"github.com/cinekernel/core/pkg/nntpstream"
	"golang.org/x/net/webdav"
)

// NZBFileSystem provides a read-only WebDAV view of an NZB stream.
type NZBFileSystem struct {
	Session *nntpstream.Session
}

var _ webdav.FileSystem = (*NZBFileSystem)(nil)

func (fs *NZBFileSystem) Mkdir(ctx context.Context, name string, perm os.FileMode) error {
	return webdav.ErrForbidden
}

func (fs *NZBFileSystem) RemoveAll(ctx context.Context, name string) error {
	return webdav.ErrForbidden
}

func (fs *NZBFileSystem) Rename(ctx context.Context, oldName, newName string) error {
	return webdav.ErrForbidden
}

func (fs *NZBFileSystem) Stat(ctx context.Context, name string) (os.FileInfo, error) {
	name = strings.TrimPrefix(name, "/")
	name = strings.TrimPrefix(name, "\\")

	// Root directory
	if name == "" || name == "." {
		return &VirtualFileInfo{
			name:  "/",
			size:  0,
			isDir: true,
		}, nil
	}

	fileName, fileSize := fs.getFileInfo()

	// Direct file match
	if name == fileName {
		return &VirtualFileInfo{
			name:  fileName,
			size:  fileSize,
			isDir: false,
		}, nil
	}

	return nil, os.ErrNotExist
}

func (fs *NZBFileSystem) OpenFile(ctx context.Context, name string, flag int, perm os.FileMode) (webdav.File, error) {
	name = strings.TrimPrefix(name, "/")

	// Root directory requested
	if name == "" || name == "." {
		return &VirtualDir{fs: fs}, nil
	}

	fileName, fileSize := fs.getFileInfo()

	if name != fileName {
		return nil, os.ErrNotExist
	}

	// For WebDAV writes/appends
	if flag&os.O_RDWR != 0 || flag&os.O_WRONLY != 0 {
		return nil, webdav.ErrForbidden
	}

	info := &VirtualFileInfo{
		name:  fileName,
		size:  fileSize,
		isDir: false,
	}

	// ── Reuse the persistent streamers stored on the Session.
	// NEVER create a new Streamer here — doing so spawns 8 new download workers,
	// fetches the last-segment header, and then immediately cancels everything
	// when the next WebDAV GET arrives (FFmpeg typically probes 3-5 times).
	if fs.Session.IsPacked && fs.Session.UnrarStreamer != nil {
		return &NZBFile{
			streamer: fs.Session.UnrarStreamer,
			info:     info,
		}, nil
	} else if fs.Session.Streamer != nil {
		return &NZBFile{
			streamer: fs.Session.Streamer,
			info:     info,
		}, nil
	}

	return nil, os.ErrNotExist
}

func (fs *NZBFileSystem) getFileInfo() (string, int64) {
	if fs.Session.IsPacked && fs.Session.RARMap != nil {
		name := fs.Session.CleanFilename()
		return name, fs.Session.RARMap.TotalSize
	} else if fs.Session.MediaFile != nil {
		name := fs.Session.CleanFilename()
		return name, fs.Session.MediaFile.Size
	}
	return "stream.bin", 0
}

// ---------------------------------------------------------
// VirtualFileInfo implements os.FileInfo
// ---------------------------------------------------------

type VirtualFileInfo struct {
	name  string
	size  int64
	isDir bool
}

func (i *VirtualFileInfo) Name() string      { return i.name }
func (i *VirtualFileInfo) Size() int64       { return i.size }
func (i *VirtualFileInfo) Mode() os.FileMode {
	if i.isDir {
		return os.ModeDir | 0555
	}
	return 0444
}
func (i *VirtualFileInfo) ModTime() time.Time { return time.Now() }
func (i *VirtualFileInfo) IsDir() bool        { return i.isDir }
func (i *VirtualFileInfo) Sys() interface{}   { return nil }

// ---------------------------------------------------------
// VirtualDir implements webdav.File for the root directory
// ---------------------------------------------------------

type VirtualDir struct {
	fs *NZBFileSystem
}

func (d *VirtualDir) Close() error                              { return nil }
func (d *VirtualDir) Read(p []byte) (n int, err error)         { return 0, os.ErrInvalid }
func (d *VirtualDir) Seek(offset int64, whence int) (int64, error) { return 0, os.ErrInvalid }
func (d *VirtualDir) Write(p []byte) (n int, err error)        { return 0, webdav.ErrForbidden }

func (d *VirtualDir) Readdir(count int) ([]os.FileInfo, error) {
	fileName, fileSize := d.fs.getFileInfo()

	if fileName == "" {
		return nil, nil
	}

	fi := &VirtualFileInfo{
		name:  fileName,
		size:  fileSize,
		isDir: false,
	}

	if count <= 0 {
		return []os.FileInfo{fi}, nil
	}

	// Quick hack for pagination - we only have 1 file anyway
	return []os.FileInfo{fi}, nil
}

func (d *VirtualDir) Stat() (os.FileInfo, error) {
	return &VirtualFileInfo{
		name:  "/",
		size:  0,
		isDir: true,
	}, nil
}
