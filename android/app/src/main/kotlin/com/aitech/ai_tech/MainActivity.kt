package com.aitech.ai_tech

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
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
}
