package org.sodukromental

import android.app.Activity
import android.app.AppOpsManager
import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.ResultReceiver
import android.os.SystemClock
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Toast
import kotlin.math.roundToInt

class CompanionRoamingService : Service() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var windows: WindowManager
    private lateinit var appOps: AppOpsManager
    private lateinit var notifications: NotificationManager
    private var creatureView: View? = null
    private var windowParams: WindowManager.LayoutParams? = null
    private var speech: List<String> = emptyList()
    private var spokenAt: Long? = null
    private var reducedMotion = false
    private var waypoint = 0
    private var nextMoveAt = 0L

    private val screenOff = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            hideCompanion()
            stopSelf()
        }
    }
    private val overlayAccess = AppOpsManager.OnOpChangedListener { _, _ ->
        mainHandler.post { if (isRoaming && !mayRoam()) stopOuting() }
    }
    private val supervise = object : Runnable {
        override fun run() {
            if (!mayRoam()) {
                stopOuting()
                return
            }
            val view = creatureView ?: return
            view.visibility = if (isGameVisible) View.INVISIBLE else View.VISIBLE
            val now = SystemClock.elapsedRealtime()
            if (!isGameVisible && !reducedMotion && now >= nextMoveAt) {
                waypoint = (waypoint + 1) % WAYPOINTS.size
                nextMoveAt = now + MOVE_INTERVAL
                val params = windowParams ?: return
                position(params)
                if (runCatching { windows.updateViewLayout(view, params) }.isFailure) {
                    stopOuting()
                    return
                }
            }
            mainHandler.postDelayed(this, 250)
        }
    }

    override fun onCreate() {
        super.onCreate()
        windows = requireNotNull(getSystemService(WindowManager::class.java))
        appOps = requireNotNull(getSystemService(AppOpsManager::class.java))
        notifications = requireNotNull(getSystemService(NotificationManager::class.java))
        val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenOff, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(screenOff, filter)
        }
        appOps.startWatchingMode(AppOpsManager.OPSTR_SYSTEM_ALERT_WINDOW, packageName, overlayAccess)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null || intent.action == STOP) {
            stopOuting()
            return START_NOT_STICKY
        }
        val response = response(intent)
        val sprite = decodeSprite(intent.getByteArrayExtra(SPRITE))
        val name = intent.getStringExtra(NAME)
        val started = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && mayRoam() && sprite != null &&
            name != null && runCatching { showCompanion(sprite, name, intent) }.isSuccess
        response?.send(if (started) Activity.RESULT_OK else Activity.RESULT_CANCELED, null)
        if (!started) stopOuting()
        return START_NOT_STICKY
    }

    @Suppress("DEPRECATION")
    private fun response(intent: Intent): ResultReceiver? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(RESPONSE, ResultReceiver::class.java)
        } else {
            intent.getParcelableExtra(RESPONSE)
        }

    private fun notification(name: String): Notification {
        notifications.createNotificationChannel(NotificationChannel(
            NOTIFICATION_CHANNEL, "Companion visits", NotificationManager.IMPORTANCE_LOW
        ))
        val returnIntent = Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val stopIntent = Intent(this, CompanionRoamingService::class.java).setAction(STOP)
        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val returnToGame = PendingIntent.getActivity(this, 1, returnIntent, pendingFlags)
        val stop = PendingIntent.getService(this, 2, stopIntent, pendingFlags)
        return Notification.Builder(this, NOTIFICATION_CHANNEL)
            .setSmallIcon(R.drawable.ic_companion_notification)
            .setContentTitle("$name is roaming")
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setOngoing(true)
            .setContentIntent(returnToGame)
            .addAction(Notification.Action.Builder(null, "Return to game", returnToGame).build())
            .addAction(Notification.Action.Builder(null, "Stop roaming", stop).build())
            .build()
    }

    private fun showCompanion(sprite: Bitmap, name: String, intent: Intent) {
        hideCompanion()
        val foreground = notification(name)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, foreground, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, foreground)
        }

        // The activity supplies greetings and only the phrases approved for this outing.
        speech = intent.getStringArrayListExtra(GREETINGS).orEmpty() + intent.getStringArrayListExtra(PHRASES).orEmpty()
        spokenAt = null
        reducedMotion = intent.getBooleanExtra(REDUCED_MOTION, false)
        waypoint = 0
        nextMoveAt = SystemClock.elapsedRealtime() + MOVE_INTERVAL
        val width = dp(56)
        val height = (width * sprite.height / sprite.width).coerceIn(dp(32), dp(56))
        val params = WindowManager.LayoutParams(
            width, height, WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.LEFT
            title = "Sodukromental companion"
        }
        position(params)
        val creature = object : View(this) {
            private val pixels = Paint().apply { isFilterBitmap = false }

            override fun onDraw(canvas: Canvas) {
                val ratio = minOf(this.width.toFloat() / sprite.width, this.height.toFloat() / sprite.height)
                val wide = (sprite.width * ratio).roundToInt()
                val high = (sprite.height * ratio).roundToInt()
                val x = (this.width - wide) / 2
                val y = (this.height - high) / 2
                canvas.drawBitmap(sprite, null, Rect(x, y, x + wide, y + high), pixels)
            }
        }.apply {
            contentDescription = name
            visibility = if (isGameVisible) View.INVISIBLE else View.VISIBLE
            if (speech.isNotEmpty()) setOnClickListener { speak() }
        }
        windows.addView(creature, params)
        creatureView = creature
        windowParams = params
        isRoaming = true
        mainHandler.post(supervise)
    }

    private fun position(params: WindowManager.LayoutParams) {
        val (x, y) = WAYPOINTS[waypoint]
        val metrics = resources.displayMetrics
        val horizontal = (metrics.widthPixels - params.width - dp(24)).coerceAtLeast(0)
        val vertical = (metrics.heightPixels - params.height - dp(96)).coerceAtLeast(0)
        params.x = dp(12) + (horizontal * x).roundToInt()
        params.y = dp(48) + (vertical * y).roundToInt()
    }

    private fun speak() {
        val now = SystemClock.elapsedRealtime()
        if (spokenAt?.let { now - it < SPEECH_INTERVAL } == true || !mayRoam() || isGameVisible) return
        speech.randomOrNull()?.let {
            Toast.makeText(this, it, Toast.LENGTH_SHORT).show()
            spokenAt = now
        }
    }

    private fun mayRoam(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            Settings.canDrawOverlays(this) &&
            notifications.areNotificationsEnabled() &&
            notifications.getNotificationChannel(NOTIFICATION_CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE &&
            getSystemService(PowerManager::class.java)?.isInteractive == true &&
            getSystemService(KeyguardManager::class.java)?.isKeyguardLocked == false

    private fun decodeSprite(bytes: ByteArray?): Bitmap? {
        if (bytes == null) return null
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        if (bounds.outMimeType != "image/png" || bounds.outWidth !in 1..512 || bounds.outHeight !in 1..512) return null
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
    }

    private fun dp(value: Int): Int = (resources.displayMetrics.density * value).roundToInt()

    private fun hideCompanion() {
        mainHandler.removeCallbacks(supervise)
        creatureView?.let { runCatching { windows.removeViewImmediate(it) } }
        creatureView = null
        windowParams = null
        speech = emptyList()
        isRoaming = false
    }

    private fun stopOuting() {
        hideCompanion()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        hideCompanion()
        unregisterReceiver(screenOff)
        appOps.stopWatchingMode(overlayAccess)
        super.onDestroy()
    }

    companion object {
        const val SPRITE = "sprite"
        const val NAME = "name"
        const val REDUCED_MOTION = "reducedMotion"
        const val PHRASES = "phrases"
        const val GREETINGS = "greetings"
        const val RESPONSE = "response"
        private const val STOP = "org.sodukromental.STOP_COMPANION_ROAMING"
        private const val NOTIFICATION_CHANNEL = "companion_roaming"
        private const val NOTIFICATION_ID = 730
        private const val MOVE_INTERVAL = 6_000L
        private const val SPEECH_INTERVAL = 90_000L
        private val WAYPOINTS = listOf(0f to 0.28f, 1f to 0.35f, 1f to 0.68f, 0f to 0.62f)
        var isRoaming = false
            private set
        var isGameVisible = false
    }
}
