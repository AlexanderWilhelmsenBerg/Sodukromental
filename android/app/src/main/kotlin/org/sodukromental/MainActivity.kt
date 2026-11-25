package org.sodukromental

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ResultReceiver
import android.provider.Settings
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var resumed = false
    private var pendingNotificationStart: Pair<Intent, MethodChannel.Result>? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canDrawOverlays" -> result.success(canDrawOverlays())
                    "requestOverlayPermission" -> result.success(requestOverlayAccess())
                    "isRoaming" -> result.success(CompanionRoamingService.isRoaming)
                    "startRoaming" -> askToStartRoaming(call, result)
                    "stopRoaming" -> {
                        stopService(Intent(this, CompanionRoamingService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onResume() {
        super.onResume()
        resumed = true
        CompanionRoamingService.isGameVisible = true
        if (!canDrawOverlays()) {
            stopService(Intent(this, CompanionRoamingService::class.java))
        }
        startAfterNotificationGrant()
    }

    override fun onPause() {
        resumed = false
        CompanionRoamingService.isGameVisible = false
        super.onPause()
    }

    override fun onDestroy() {
        pendingNotificationStart?.second?.success(false)
        pendingNotificationStart = null
        super.onDestroy()
    }

    private fun canDrawOverlays(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && Settings.canDrawOverlays(this)

    private fun requestOverlayAccess(): Boolean {
        if (!resumed || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        if (canDrawOverlays()) return true
        val settingsIntent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
        return runCatching { startActivity(settingsIntent) }.isSuccess
    }

    private fun askToStartRoaming(call: MethodCall, result: MethodChannel.Result) {
        if (!resumed || !canDrawOverlays() || pendingNotificationStart != null) {
            result.success(false)
            return
        }
        val sprite = call.argument<ByteArray>("sprite")
        val name = call.argument<String>("name")?.trim().orEmpty()
        val id = call.argument<String>("id")?.trim().orEmpty()
        if (sprite == null || sprite.isEmpty() || sprite.size > MAX_SPRITE_BYTES || name.isEmpty() || id.isEmpty()) {
            result.success(false)
            return
        }
        val outing = Intent(this, CompanionRoamingService::class.java)
            .putExtra(CompanionRoamingService.SPRITE, sprite)
            .putExtra(CompanionRoamingService.NAME, name.take(40))
            .putExtra(CompanionRoamingService.REDUCED_MOTION, call.argument<Boolean>("reducedMotion") ?: false)
            .putStringArrayListExtra(CompanionRoamingService.PHRASES, speech(call, "phrases"))
            .putStringArrayListExtra(CompanionRoamingService.GREETINGS, speech(call, "greetings"))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            pendingNotificationStart = outing to result
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_PERMISSION_REQUEST)
            return
        }
        startOuting(outing, result)
    }

    private fun speech(call: MethodCall, key: String): ArrayList<String> =
        ArrayList(call.argument<List<String>>(key).orEmpty().asSequence()
            .map { it.trim().take(80) }
            .filter { it.isNotEmpty() }
            .take(40)
            .toList())

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST) return
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            startAfterNotificationGrant()
        } else {
            pendingNotificationStart?.second?.success(false)
            pendingNotificationStart = null
        }
    }

    private fun startAfterNotificationGrant() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || !resumed ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        val (outing, result) = pendingNotificationStart ?: return
        pendingNotificationStart = null
        startOuting(outing, result)
    }

    private fun startOuting(outing: Intent, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || !resumed || !canDrawOverlays()) {
            result.success(false)
            return
        }
        val response = object : ResultReceiver(mainHandler) {
            override fun onReceiveResult(resultCode: Int, resultData: Bundle?) {
                result.success(resultCode == RESULT_OK)
            }
        }
        outing.putExtra(CompanionRoamingService.RESPONSE, response)
        if (runCatching { startForegroundService(outing) }.isFailure) result.success(false)
    }

    companion object {
        private const val CHANNEL = "org.sodukromental/companion"
        private const val NOTIFICATION_PERMISSION_REQUEST = 310
        private const val MAX_SPRITE_BYTES = 256 * 1024
    }
}
