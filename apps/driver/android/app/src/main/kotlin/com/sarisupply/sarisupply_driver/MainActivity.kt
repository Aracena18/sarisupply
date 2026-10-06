package com.sarisupply.sarisupply_driver

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.SystemClock
import android.provider.Settings

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sarisupply/offline_clock")
            .setMethodCallHandler { call, result ->
                if (call.method != "read") result.notImplemented()
                else {
                    val boot = Settings.Global.getInt(contentResolver, Settings.Global.BOOT_COUNT, -1)
                    if (boot < 0) result.success(null)
                    else result.success(mapOf("bootCount" to boot, "elapsedRealtimeMs" to SystemClock.elapsedRealtime()))
                }
            }
    }
}
