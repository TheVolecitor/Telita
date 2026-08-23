//go:build !windows

package server

func getShortPathName(longPath string) (string, error) {
	return longPath, nil
}
