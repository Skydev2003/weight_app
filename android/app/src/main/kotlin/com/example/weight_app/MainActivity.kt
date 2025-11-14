package com.example.weight_app

import android.hardware.usb.*
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {

    private val STREAM_CHANNEL = "scale_usb_stream"
    private var usbManager: UsbManager? = null
    private var readerThread: Thread? = null
    @Volatile private var running = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        usbManager = getSystemService(USB_SERVICE) as UsbManager

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STREAM_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    startReadLoop(events)
                }

                override fun onCancel(arguments: Any?) {
                    stopReadLoop()
                }
            })
    }

    private fun startReadLoop(events: EventChannel.EventSink?) {
        stopReadLoop()
        running = true

        readerThread = Thread {
            try {
                while (running) {
                    val device = findCh340Device()
                    if (device == null) {
                        // ไม่เจอเครื่องชั่ง
                        events?.success(null)
                        Thread.sleep(1000)
                        continue
                    }

                    // ขอ permission ถ้ายังไม่ได้
                    if (!usbManager!!.hasPermission(device)) {
                        // ปกติจะต้องใช้ PendingIntent ขอสิทธิ์
                        // แต่บน POS ส่วนมากให้สิทธิ์มาแล้ว
                        events?.success(null)
                        Thread.sleep(1000)
                        continue
                    }

                    val connection = usbManager!!.openDevice(device)
                    if (connection == null) {
                        events?.success(null)
                        Thread.sleep(1000)
                        continue
                    }

                    val intf = device.getInterface(0)
                    connection.claimInterface(intf, true)

                    val endpointIn = intf.endpoints.firstOrNull {
                        it.direction == UsbConstants.USB_DIR_IN
                    }

                    if (endpointIn == null) {
                        connection.close()
                        events?.success(null)
                        Thread.sleep(1000)
                        continue
                    }

                    val buffer = ByteArray(64)

                    while (running) {
                        val received = connection.bulkTransfer(endpointIn, buffer, buffer.size, 1000)
                        if (received > 0) {
                            val text = String(buffer, 0, received)
                            // ดึงตัวเลขทศนิยมจากสตริง
                            val regex = Regex("([0-9]+\\.[0-9]+)")
                            val match = regex.find(text)
                            val weight = match?.groups?.get(1)?.value
                            if (weight != null) {
                                events?.success(weight) // ส่งให้ Flutter
                            }
                        }
                    }

                    connection.releaseInterface(intf)
                    connection.close()
                }
            } catch (e: Exception) {
                events?.error("USB_ERROR", e.message, null)
            }
        }
        readerThread?.start()
    }

    private fun stopReadLoop() {
        running = false
        readerThread?.interrupt()
        readerThread = null
    }

    private fun findCh340Device(): UsbDevice? {
        val list = usbManager?.deviceList ?: return null
        for (device in list.values) {
            if (device.vendorId == 0x1A86 && device.productId == 0x7523) {
                return device
            }
        }
        return null
    }
}
