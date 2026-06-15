//go:build android
// +build android

package main

/*
#include <jni.h>
*/
import "C"

// Empty main function to satisfy c-shared requirement without blocking System.loadLibrary
func main() {}

//export Java_app_telita_player_MainActivity_startCore
func Java_app_telita_player_MainActivity_startCore(env *C.JNIEnv, class C.jclass) {
	// Start the server in a goroutine so it doesn't block the Android UI thread
	go RunServer()
}
