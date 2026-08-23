//go:build windows

package server

import (
	"syscall"
)

func getShortPathName(longPath string) (string, error) {
	p, err := syscall.UTF16PtrFromString(longPath)
	if err != nil {
		return "", err
	}
	b := make([]uint16, syscall.MAX_PATH)
	n, err := syscall.GetShortPathName(p, &b[0], uint32(len(b)))
	if err != nil {
		return "", err
	}
	if n > uint32(len(b)) {
		b = make([]uint16, n)
		n, err = syscall.GetShortPathName(p, &b[0], uint32(len(b)))
		if err != nil {
			return "", err
		}
	}
	return syscall.UTF16ToString(b[:n]), nil
}
