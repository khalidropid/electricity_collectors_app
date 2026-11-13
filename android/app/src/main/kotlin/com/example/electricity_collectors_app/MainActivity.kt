package com.example.electricity_collectors_app

import android.telephony.SmsManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.alhasn.station/sms"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendDirectSMS") {
                val phone = call.argument<String>("phone")
                val message = call.argument<String>("message")

                try {
                    val smsManager = SmsManager.getDefault()
                    
                    // 🌟 التعديل هنا: تقسيم الرسالة الطويلة (مهم جداً للغة العربية)
                    val parts = smsManager.divideMessage(message)
                    smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
                    
                    result.success("تم الإرسال بنجاح")
                } catch (e: Exception) {
                    result.error("FAILED", "فشل الإرسال: ${e.message}", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}