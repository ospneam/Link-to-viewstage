package com.viewstage.viewstage_phone

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiManager
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val MULTICAST_CHANNEL = "com.viewstage.multicast"
    private val FILE_PICKER_CHANNEL = "com.viewstage/file_picker"
    private var multicastLock: WifiManager.MulticastLock? = null
    private var filePickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Multicast channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MULTICAST_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquireMulticastLock" -> {
                    try {
                        acquireMulticastLock()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "获取 MulticastLock 失败: ${e.message}", null)
                    }
                }
                "releaseMulticastLock" -> {
                    try {
                        releaseMulticastLock()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "释放 MulticastLock 失败: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // File picker channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_PICKER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickFile" -> {
                    if (filePickerResult != null) {
                        result.error("BUSY", "文件选择器正忙", null)
                        return@setMethodCallHandler
                    }
                    filePickerResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                    }
                    startActivityForResult(intent, FILE_PICKER_REQUEST_CODE)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == FILE_PICKER_REQUEST_CODE) {
            val result = filePickerResult
            filePickerResult = null

            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri = data.data!!
                try {
                    val fileInfo = copyFileToCache(uri)
                    result?.success(fileInfo)
                } catch (e: Exception) {
                    result?.error("COPY_ERROR", "复制文件失败: ${e.message}", null)
                }
            } else {
                result?.success(null)
            }
        }
    }

    private fun copyFileToCache(uri: Uri): Map<String, String> {
        val fileName = getFileName(uri)
        val cacheFile = File(cacheDir, fileName)

        contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(cacheFile).use { output ->
                input.copyTo(output)
            }
        }

        return mapOf(
            "name" to fileName,
            "path" to cacheFile.absolutePath,
            "size" to cacheFile.length().toString()
        )
    }

    private fun getFileName(uri: Uri): String {
        var name = "unknown_file"
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (cursor.moveToFirst() && nameIndex >= 0) {
                name = cursor.getString(nameIndex)
            }
        }
        return name
    }

    private fun acquireMulticastLock() {
        if (multicastLock == null) {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            multicastLock = wifiManager.createMulticastLock("viewstage_multicast_lock")
            multicastLock?.setReferenceCounted(true)
            multicastLock?.acquire()
        }
    }

    private fun releaseMulticastLock() {
        multicastLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        multicastLock = null
    }

    override fun onDestroy() {
        releaseMulticastLock()
        super.onDestroy()
    }

    companion object {
        private const val FILE_PICKER_REQUEST_CODE = 1001
    }
}
