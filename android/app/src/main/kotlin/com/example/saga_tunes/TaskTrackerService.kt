package com.example.saga_tunes

import android.app.Service
import android.content.Intent
import android.os.IBinder

class TaskTrackerService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        stopService(Intent(this, com.ryanheise.audioservice.AudioService::class.java))
        android.os.Process.killProcess(android.os.Process.myPid())
    }
}
