package com.sarisupply.sarisupply_pos

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build
import android.os.SystemClock
import android.provider.Settings

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sarisupply/offline_clock")
            .setMethodCallHandler { call, result ->
                if (call.method != "read") {
                    result.notImplemented()
                } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
                    result.success(null)
                } else {
                    val bootCount = Settings.Global.getInt(
                        contentResolver, Settings.Global.BOOT_COUNT, -1
                    )
                    if (bootCount < 0) {
                        result.success(null)
                    } else {
                        result.success(mapOf(
                            "bootCount" to bootCount,
                            "elapsedRealtimeMs" to SystemClock.elapsedRealtime()
                        ))
                    }
                }
            }
    }
}
