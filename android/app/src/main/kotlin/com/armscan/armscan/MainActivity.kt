package com.armscan.armscan

import android.content.pm.PackageManager
import android.os.Build
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "armscan/app")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "signatureHash" -> result.success(signatureHash())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Base64 SHA-1 of the certificate this installed copy is signed with:
     * the value Microsoft sign-in needs as the Android "Signature hash" in
     * Azure. When Google Play re-signs the app, this is Google's key.
     */
    private fun signatureHash(): String? {
        val pm = packageManager
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val info = pm.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
            info.signingInfo?.apkContentsSigners
        } else {
            @Suppress("DEPRECATION")
            pm.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures
        }
        val cert = signatures?.firstOrNull() ?: return null
        val sha1 = MessageDigest.getInstance("SHA-1").digest(cert.toByteArray())
        return Base64.encodeToString(sha1, Base64.NO_WRAP)
    }
}
