package app.telita.player

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle

class MainActivity: FlutterActivity() {
    private val CHANNEL = "app.telita.core/engine"

    external fun startCore()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        System.loadLibrary("core")
        Thread {
            startCore()
        }.start()
    }
}
