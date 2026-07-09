package com.faster.app

import android.content.Context
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader

class SecurityPlugin(private val context: Context, private val engine: FlutterEngine) {
    companion object {
        private const val CHANNEL = "com.faster.app/security"
        private const val TAG = "SecurityPlugin"

        fun register(context: Context, engine: FlutterEngine) {
            val plugin = SecurityPlugin(context, engine)
            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            channel.setMethodCallHandler { call, result ->
                if (call.method == "checkIntegrity") {
                    result.success(plugin.checkIntegrity())
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    private fun checkIntegrity(): Map<String, Any> {
        return mapOf(
            "isRooted" to isDeviceRooted(),
            "isJailbroken" to false,
            "isEmulator" to isEmulator(),
            "isDebugger" to isDebuggerConnected()
        )
    }

    private fun isDeviceRooted(): Boolean {
        if (isMagiskPresent()) return true
        if (hasRootBinary()) return true
        if (hasRootPackages()) return true
        if (isTestKeysBuild()) return true
        return false
    }

    private fun isMagiskPresent(): Boolean {
        return try {
            val magiskPaths = listOf(
                "/data/adb/magisk",
                "/data/adb/magisk.db",
                "/cache/magisk.log",
                "/data/data/com.topjohnwu.magisk"
            )
            magiskPaths.any { File(it).exists() }
        } catch (e: Exception) {
            false
        }
    }

    private fun hasRootBinary(): Boolean {
        val rootPaths = listOf(
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su"
        )
        return try {
            if (rootPaths.any { File(it).exists() }) return true
            val process = Runtime.getRuntime().exec(arrayOf("which", "su"))
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val line = reader.readLine()
            process.destroy()
            line != null && line.isNotEmpty()
        } catch (e: Exception) {
            false
        }
    }

    private fun hasRootPackages(): Boolean {
        val rootPackages = listOf(
            "com.noshufou.android.su",
            "com.thirdparty.superuser",
            "eu.chainfire.supersu",
            "com.koushikdutta.superuser",
            "com.topjohnwu.magisk"
        )
        val pm = context.packageManager
        return try {
            rootPackages.any { pkg ->
                try {
                    pm.getPackageInfo(pkg, 0)
                    true
                } catch (e: Exception) {
                    false
                }
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun isTestKeysBuild(): Boolean {
        return try {
            Build.TAGS != null && Build.TAGS.contains("test-keys")
        } catch (e: Exception) {
            false
        }
    }

    private fun isEmulator(): Boolean {
        return try {
            val googleSdk = Build.PRODUCT?.contains("sdk") == true
            val emulatorBuild = Build.MODEL?.contains("Emulator") == true
            val genericBuild = Build.BRAND?.startsWith("generic") == true
            val androidBuild = Build.MANUFACTURER?.contains("Android") == true
            googleSdk || emulatorBuild || genericBuild || androidBuild
        } catch (e: Exception) {
            false
        }
    }

    private fun isDebuggerConnected(): Boolean {
        return try {
            android.os.Debug.isDebuggerConnected()
        } catch (e: Exception) {
            false
        }
    }
}
