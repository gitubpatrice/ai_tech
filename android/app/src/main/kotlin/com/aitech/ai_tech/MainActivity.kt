package com.aitech.ai_tech

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    /// v0.9.0 — channel mémoire pour le WatchDog Gemma 4 E2B (~530 Mo).
    /// Dart `Process.memoryUsage()` ne renvoie que la RAM du process Dart,
    /// pas la mémoire dispo système. On expose `getAvailableMemory` via
    /// `ActivityManager.MemoryInfo` qui inclut `availMem` et `totalMem`.
    private val memoryChannel = "com.aitech.ai_tech/memory"

    override fun onCreate(savedInstanceState: Bundle?) {
        // FLAG_SECURE :
        //  - bloque les screenshots utilisateur,
        //  - bloque l'enregistrement écran,
        //  - empêche que la fenêtre apparaisse dans l'aperçu des apps récentes.
        // Cohérence avec Pass Tech / Read Files Tech ; protège l'historique
        // de chat affiché en clair (mais chiffré sur disque).
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, memoryChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAvailableMemory" -> result.success(readMemoryInfo())
                    else -> result.notImplemented()
                }
            }
    }

    private fun readMemoryInfo(): Map<String, Any> {
        val activityManager =
            applicationContext.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val info = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(info)
        // `availMem` : mémoire actuellement disponible pour une app.
        // `totalMem` : RAM totale du device (Android 4.0+).
        // `lowMemory` : true si le système est sous pression mémoire.
        // `threshold` : seuil sous lequel `lowMemory` passe à true.
        val payload = mutableMapOf<String, Any>(
            "availMem" to info.availMem,
            "totalMem" to info.totalMem,
            "threshold" to info.threshold,
            "lowMemory" to info.lowMemory,
        )
        // `isLowRamDevice` (Android 4.4+) marque les téléphones <1 Go RAM
        // — utile pour adapter la posture sur Go Edition.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            payload["isLowRamDevice"] = activityManager.isLowRamDevice
        }
        return payload
    }
}
