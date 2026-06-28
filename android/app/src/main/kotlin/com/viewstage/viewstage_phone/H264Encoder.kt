package com.viewstage.viewstage_phone

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.hardware.camera2.*
import android.media.ImageReader
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.os.Handler
import android.os.HandlerThread
import android.util.Size
import android.view.Surface
import androidx.core.app.ActivityCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.util.concurrent.CountDownLatch
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/**
 * H.264 硬编码推流器
 * 使用 Camera2 + MediaCodec 进行 H.264 编码，输出 fMP4 segment
 */
class H264Encoder(private val context: Context, messenger: BinaryMessenger) {

    companion object {
        private const val METHOD_CHANNEL = "com.viewstage/h264_encoder"
        private const val EVENT_CHANNEL = "com.viewstage/h264_events"
        private const val WIDTH = 1920
        private const val HEIGHT = 1080
        private const val BITRATE = 4_000_000
        private const val FPS = 30
        private const val I_FRAME_INTERVAL = 2
    }

    // Frame type constants matching the WebSocket protocol
    private val TYPE_INIT: Byte = 0x01
    private val TYPE_VIDEO: Byte = 0x02

    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var mediaCodec: MediaCodec? = null
    private var cameraThread: HandlerThread? = null
    private var cameraHandler: Handler? = null
    private var encoderThread: HandlerThread? = null
    private var encoderHandler: Handler? = null

    private val isActive = AtomicBoolean(false)
    private var eventSink: EventChannel.EventSink? = null

    // Timing
    private var frameCount = 0L
    private var startTimeNs = 0L

    init {
        // Method Channel
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    start(result)
                }
                "stop" -> {
                    stop(result)
                }
                else -> result.notImplemented()
            }
        }

        // Event Channel (for sending encoded frames to Flutter)
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    private fun start(result: MethodChannel.Result) {
        if (isActive.getAndSet(true)) {
            result.success(true)
            return
        }

        try {
            startEncoder()
            startCamera()
            result.success(true)
        } catch (e: Exception) {
            isActive.set(false)
            result.error("START_ERROR", e.message, null)
        }
    }

    private fun stop(result: MethodChannel.Result) {
        if (!isActive.getAndSet(false)) {
            result.success(true)
            return
        }

        try {
            stopCamera()
            stopEncoder()
            eventSink?.endOfStream()
            eventSink = null
            result.success(true)
        } catch (e: Exception) {
            result.error("STOP_ERROR", e.message, null)
        }
    }

    // ===== Encoder =====

    private fun startEncoder() {
        encoderThread = HandlerThread("H264Encoder").also { it.start() }
        encoderHandler = Handler(encoderThread!!.looper)

        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, WIDTH, HEIGHT).apply {
            setInteger(MediaFormat.KEY_BIT_RATE, BITRATE)
            setInteger(MediaFormat.KEY_FRAME_RATE, FPS)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL)
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible)
            // Low latency settings
            setInteger(MediaFormat.KEY_LATENCY, 0)
            setInteger(MediaFormat.KEY_PRIORITY, 0) // realtime
        }

        mediaCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC).apply {
            configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            start()
        }

        // Start encoder output thread
        Thread({ drainEncoder() }, "EncoderDrain").start()
    }

    private fun stopEncoder() {
        try {
            mediaCodec?.stop()
            mediaCodec?.release()
        } catch (_: Exception) {}
        mediaCodec = null

        encoderThread?.quitSafely()
        encoderThread = null
        encoderHandler = null
    }

    private fun drainEncoder() {
        val bufferInfo = MediaCodec.BufferInfo()
        val codec = mediaCodec ?: return
        Fmp4Muxer.reset()
        frameCount = 0
        startTimeNs = 0

        while (isActive.get()) {
            val outputIndex = codec.dequeueOutputBuffer(bufferInfo, 10_000) // 10ms timeout
            when {
                outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    // Init Segment: codec.outputFormat contains SPS/PPS
                    val sps = codec.outputFormat.getByteBuffer("csd-0")
                    val pps = codec.outputFormat.getByteBuffer("csd-1")
                    if (sps != null && pps != null) {
                        val spsBytes = ByteArray(sps.remaining())
                        sps.get(spsBytes)
                        val ppsBytes = ByteArray(pps.remaining())
                        pps.get(ppsBytes)

                        val initSegment = Fmp4Muxer.buildInitSegment(spsBytes, ppsBytes)
                        sendFrame(TYPE_INIT, initSegment)
                    }
                }
                outputIndex >= 0 -> {
                    val outputBuffer = codec.getOutputBuffer(outputIndex) ?: continue
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                        // Skip codec config, already in init segment
                        codec.releaseOutputBuffer(outputIndex, false)
                        continue
                    }

                    if (bufferInfo.size > 0) {
                        val nalu = ByteArray(bufferInfo.size)
                        outputBuffer.position(bufferInfo.offset)
                        outputBuffer.get(nalu)

                        val isKeyFrame = (bufferInfo.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME) != 0
                        val dts = bufferInfo.presentationTimeUs * 90 / 1000 // us to 90kHz ticks
                        val pts = dts + (bufferInfo.presentationTimeUs * 90 / 1000 - dts)

                        val videoSegment = Fmp4Muxer.buildVideoSegment(nalu, isKeyFrame, dts, pts)
                        sendFrame(TYPE_VIDEO, videoSegment)
                    }

                    codec.releaseOutputBuffer(outputIndex, false)
                }
            }
        }
    }

    private fun sendFrame(type: Byte, data: ByteArray) {
        if (!isActive.get()) return

        // Prefix with type byte, then send as Flutter binary message
        val msg = ByteArray(1 + data.size)
        msg[0] = type
        data.copyInto(msg, 1)

        // Send to Flutter via EventChannel (as byte array)
        try {
            eventSink?.success(msg)
        } catch (_: Exception) {}
    }

    // ===== Camera2 =====

    private fun startCamera() {
        cameraThread = HandlerThread("CameraThread").also { it.start() }
        cameraHandler = Handler(cameraThread!!.looper)

        val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager

        // Find back camera
        val cameraId = findBackCamera(manager) ?: throw Exception("No back camera found")

        if (ActivityCompat.checkSelfPermission(context, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            throw Exception("Camera permission not granted")
        }

        val latch = CountDownLatch(1)
        var openError: Exception? = null

        manager.openCamera(cameraId, object : CameraDevice.StateCallback() {
            override fun onOpened(camera: CameraDevice) {
                cameraDevice = camera
                latch.countDown()
                createCaptureSession()
            }
            override fun onDisconnected(camera: CameraDevice) {
                camera.close()
                cameraDevice = null
                isActive.set(false)
            }
            override fun onError(camera: CameraDevice, error: Int) {
                camera.close()
                cameraDevice = null
                openError = Exception("Camera error: $error")
                isActive.set(false)
                latch.countDown()
            }
        }, cameraHandler)

        latch.await()
        openError?.let { throw it }
    }

    private fun findBackCamera(manager: CameraManager): String? {
        for (id in manager.cameraIdList) {
            val chars = manager.getCameraCharacteristics(id)
            val facing = chars.get(CameraCharacteristics.LENS_FACING)
            if (facing == CameraCharacteristics.LENS_FACING_BACK) {
                // Check if it supports our resolution
                val map = chars.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                if (map?.getOutputSizes(ImageFormat.YUV_420_888)?.any { it.width >= WIDTH && it.height >= HEIGHT } == true) {
                    return id
                }
            }
        }
        // Fallback to any back camera
        for (id in manager.cameraIdList) {
            val chars = manager.getCameraCharacteristics(id)
            if (chars.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK) {
                return id
            }
        }
        return null
    }

    private fun createCaptureSession() {
        val camera = cameraDevice ?: return
        val codec = mediaCodec ?: return

        // Use ImageReader to get YUV frames and feed to encoder
        val imageReader = ImageReader.newInstance(WIDTH, HEIGHT, ImageFormat.YUV_420_888, 2).apply {
            setOnImageAvailableListener({ reader ->
                val image = reader.acquireLatestImage() ?: return@setOnImageAvailableListener
                try {
                    feedEncoder(image)
                } finally {
                    image.close()
                }
            }, cameraHandler)
        }

        val surfaces = listOf(imageReader.surface)

        camera.createCaptureSession(surfaces, object : CameraCaptureSession.StateCallback() {
            override fun onConfigured(session: CameraCaptureSession) {
                captureSession = session

                val builder = camera.createCaptureRequest(CameraDevice.TEMPLATE_RECORD).apply {
                    addTarget(imageReader.surface)
                    set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
                    set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, android.util.Range(FPS, FPS))
                }

                session.setRepeatingRequest(builder.build(), null, cameraHandler)
            }
            override fun onConfigureFailed(session: CameraCaptureSession) {
                isActive.set(false)
            }
        }, cameraHandler)
    }

    private fun feedEncoder(image: android.media.Image) {
        val codec = mediaCodec ?: return
        if (!isActive.get()) return

        try {
            val inputIndex = codec.dequeueInputBuffer(10_000) // 10ms timeout
            if (inputIndex >= 0) {
                val inputBuffer = codec.getInputBuffer(inputIndex) ?: return

                // Convert YUV_420_888 to NV12 (required by most encoders)
                val yuvBytes = imageToNv12(image)
                inputBuffer.clear()
                inputBuffer.put(yuvBytes)

                val pts = System.nanoTime() / 1000 // ns to us
                codec.queueInputBuffer(inputIndex, 0, yuvBytes.size, pts, 0)
            }
        } catch (_: Exception) {}
    }

    private fun imageToNv12(image: android.media.Image): ByteArray {
        val width = image.width
        val height = image.height
        val ySize = width * height
        val uvSize = width * height / 2
        val nv12 = ByteArray(ySize + uvSize)

        // Y plane
        val yPlane = image.planes[0]
        val yBuffer = yPlane.buffer
        val yRowStride = yPlane.rowStride
        var pos = 0
        for (row in 0 until height) {
            yBuffer.position(row * yRowStride)
            yBuffer.get(nv12, pos, width)
            pos += width
        }

        // UV planes (interleave to NV12)
        val uPlane = image.planes[1]
        val vPlane = image.planes[2]
        val uBuffer = uPlane.buffer
        val vBuffer = vPlane.buffer
        val uvRowStride = uPlane.rowStride
        val uvPixelStride = uPlane.pixelStride

        for (row in 0 until height / 2) {
            for (col in 0 until width / 2) {
                val uvIndex = row * uvRowStride + col * uvPixelStride
                nv12[pos++] = vBuffer.get(uvIndex) // V
                nv12[pos++] = uBuffer.get(uvIndex) // U
            }
        }

        return nv12
    }

    private fun stopCamera() {
        try {
            captureSession?.close()
        } catch (_: Exception) {}
        captureSession = null

        try {
            cameraDevice?.close()
        } catch (_: Exception) {}
        cameraDevice = null

        cameraThread?.quitSafely()
        cameraThread = null
        cameraHandler = null
    }
}
