package com.purrfit.purrfit

import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Android 8 is the first version with dark navigation icons on light backgrounds.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowCompat.enableEdgeToEdge(window)
        }
    }

    override fun onPostResume() {
        super.onPostResume()
        // Flutter's edge-to-edge platform mode starts at API 29.
        if (Build.VERSION.SDK_INT in Build.VERSION_CODES.O until Build.VERSION_CODES.Q) {
            WindowCompat.enableEdgeToEdge(window)
        }
    }
}
