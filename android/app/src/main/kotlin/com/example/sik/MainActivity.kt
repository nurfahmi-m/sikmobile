package com.example.sik

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sik/mock_location")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isMockLocation" -> {
                        try {
                            val isMock = isDeviceMockLocation()
                            result.success(isMock)
                        } catch (e: Exception) {
                            result.error("ERR", e.message, null)
                        }
                    }
                    "isDeveloperMode" -> {
                        try {
                            val isDev = isDeveloperModeEnabled()
                            result.success(isDev)
                        } catch (e: Exception) {
                            result.error("ERR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isDeveloperModeEnabled(): Boolean {
        return try {
            val enabled = Settings.Global.getInt(contentResolver, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0)
            enabled != 0
        } catch (e: Exception) {
            false
        }
    }

    private fun isDeviceMockLocation(): Boolean {
        // If we don't have location permission, we cannot determine reliably
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            return false
        }

        val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val providers = lm.getProviders(true)

        for (provider in providers) {
            try {
                val l: Location? = lm.getLastKnownLocation(provider)
                if (l != null) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
                        if (l.isFromMockProvider) return true
                    }
                }
            } catch (_: SecurityException) {
                // ignore
            } catch (_: Exception) {
                // ignore
            }
        }

        // Fallback: check global ALLOW_MOCK_LOCATION (older devices)
        try {
            val allowMock = Settings.Secure.getInt(contentResolver, Settings.Secure.ALLOW_MOCK_LOCATION)
            if (allowMock != 0) return true
        } catch (_: Exception) {
            // ignore
        }

        return false
    }
}
