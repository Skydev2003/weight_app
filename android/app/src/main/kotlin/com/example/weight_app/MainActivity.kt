package com.example.weight_app

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.*
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {

    private val STREAM_CHANNEL = "scale_usb_stream"
    private val ACTION_USB_PERMISSION = "com.example.weight_app.USB_PERMISSION"
    private var usbManager: UsbManager? = null
    private var readerThread: Thread? = null
    @Volatile private var running = false
    private var permissionIntent: PendingIntent? = null
    
    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (ACTION_USB_PERMISSION == intent.action) {
                synchronized(this) {
                    val device: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                        android.util.Log.d("USB_DEBUG", "Permission granted for device $device")
                    } else {
                        android.util.Log.d("USB_DEBUG", "Permission denied for device $device")
                    }
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        usbManager = getSystemService(USB_SERVICE) as UsbManager
        
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        permissionIntent = PendingIntent.getBroadcast(this, 0, Intent(ACTION_USB_PERMISSION), flags)
        
        val filter = IntentFilter(ACTION_USB_PERMISSION)
        registerReceiver(usbReceiver, filter)

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
    
    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(usbReceiver)
        } catch (e: Exception) {
            // Receiver already unregistered
        }
    }

    private fun startReadLoop(events: EventChannel.EventSink?) {
        stopReadLoop()
        running = true
        
        android.util.Log.d("USB_DEBUG", "startReadLoop called")

        readerThread = Thread {
            try {
                while (running) {
                    android.util.Log.d("USB_DEBUG", "Loop iteration started")
                    val device = findCh340Device()
                    if (device == null) {
                        // ไม่เจอเครื่องชั่ง
                        android.util.Log.d("USB_DEBUG", "No CH340 device found")
                        events?.success(null)
                        Thread.sleep(1000)
                        continue
                    }
                    
                    android.util.Log.d("USB_DEBUG", "CH340 device found!")

                    // ขอ permission ถ้ายังไม่ได้
                    if (!usbManager!!.hasPermission(device)) {
                        android.util.Log.d("USB_DEBUG", "Requesting permission for device")
                        usbManager!!.requestPermission(device, permissionIntent)
                        events?.success(null)
                        Thread.sleep(2000)
                        continue
                    }
                    
                    android.util.Log.d("USB_DEBUG", "Permission granted, opening device")

                    val connection = usbManager!!.openDevice(device)
                    if (connection == null) {
                        events?.success(null)
                        Thread.sleep(1000)
                        continue
                    }

                    val intf = device.getInterface(0)
                    connection.claimInterface(intf, true)
                    
                    // ตั้งค่า serial parameters (9600 baud, 8 data bits, 1 stop bit, no parity)
                    try {
                        connection.controlTransfer(0x21, 0x22, 0, 0, null, 0, 0) // Set control line state
                        val baudRate = 9600
                        val lineCoding = byteArrayOf(
                            (baudRate and 0xff).toByte(),
                            (baudRate shr 8 and 0xff).toByte(),
                            (baudRate shr 16 and 0xff).toByte(),
                            (baudRate shr 24 and 0xff).toByte(),
                            0, // 1 stop bit
                            0, // no parity
                            8  // 8 data bits
                        )
                        connection.controlTransfer(0x21, 0x20, 0, 0, lineCoding, lineCoding.size, 0)
                        android.util.Log.d("USB_DEBUG", "Serial parameters set: 9600 8N1")
                    } catch (e: Exception) {
                        android.util.Log.e("USB_DEBUG", "Failed to set serial parameters: ${e.message}")
                    }

                    var endpointIn: UsbEndpoint? = null
                    for (i in 0 until intf.endpointCount) {
                        val ep = intf.getEndpoint(i)
                        android.util.Log.d("USB_DEBUG", "Endpoint $i: Address=0x${ep.address.toString(16)}, Type=${ep.type}, Direction=${if (ep.direction == UsbConstants.USB_DIR_IN) "IN" else "OUT"}")
                        
                        // ใช้ Bulk IN endpoint (address 0x82)
                        if (ep.direction == UsbConstants.USB_DIR_IN && ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK) {
                            endpointIn = ep
                            android.util.Log.d("USB_DEBUG", "Selected endpoint: 0x${ep.address.toString(16)}")
                            break
                        }
                    }

                    if (endpointIn == null) {
                        connection.close()
                        events?.success(null)
                        Thread.sleep(1000)
                        continue
                    }

                    val buffer = ByteArray(64)
                    android.util.Log.d("USB_DEBUG", "Starting to read data...")

                    while (running) {
                        val received = connection.bulkTransfer(endpointIn, buffer, buffer.size, 1000)
                        if (received > 0) {
                            val text = String(buffer, 0, received)
                            android.util.Log.d("USB_DEBUG", "Received: $text")
                            
                            // ดึงตัวเลขทศนิยมจากสตริง (รองรับทั้ง 0.000 และ 123.456)
                            val regex = Regex("(\\d+\\.\\d+)")
                            val match = regex.find(text)
                            val weight = match?.value
                            if (weight != null) {
                                android.util.Log.d("USB_DEBUG", "Weight found: $weight")
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
        
        // Debug: แสดงอุปกรณ์ทั้งหมดที่เจอ
        android.util.Log.d("USB_DEBUG", "Found ${list.size} USB devices")
        for (device in list.values) {
            android.util.Log.d("USB_DEBUG", "Device: VID=${String.format("0x%04X", device.vendorId)} PID=${String.format("0x%04X", device.productId)} Name=${device.deviceName}")
            
            // รองรับ CH340 หลายรุ่น
            if (device.vendorId == 0x1A86) {
                when (device.productId) {
                    0x7523, 0x7522, 0x5523 -> return device
                }
            }
        }
        return null
    }
}
