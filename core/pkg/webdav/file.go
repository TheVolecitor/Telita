package webdavfs

import (
	"io"
	"os"

	"golang.org/x/net/webdav"
)

// Streamer defines the methods we expect from our nntpstream streamers
type Streamer interface {
	io.Reader
	io.Seeker
	io.Closer
}

// NZBFile implements webdav.File for a specific virtual file in the NZB.
type NZBFile struct {
	streamer Streamer
	info     *VirtualFileInfo
}

var _ webdav.File = (*NZBFile)(nil)

func (f *NZBFile) Read(p []byte) (n int, err error) {
	return f.streamer.Read(p)
}

func (f *NZBFile) Seek(offset int64, whence int) (int64, error) {
	return f.streamer.Seek(offset, whence)
}

func (f *NZBFile) Close() error {
	// The streamer is persistent on the Session — do NOT shut it down here.
	// Each WebDAV GET request opens and closes this NZBFile, but the underlying
	// Streamer and its prefetch workers must keep running across all requests.
	return nil
}

func (f *NZBFile) Write(p []byte) (n int, err error) {
	return 0, webdav.ErrForbidden
}

func (f *NZBFile) Readdir(count int) ([]os.FileInfo, error) {
	// Readdir on a file is invalid
	return nil, os.ErrInvalid
}

func (f *NZBFile) Stat() (os.FileInfo, error) {
	return f.info, nil
}
