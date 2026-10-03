package com.example.healthysv2

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "healthys_notifications",
                "HEALTH'YS",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            channel.description = "Notifications HEALTH'YS"
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
