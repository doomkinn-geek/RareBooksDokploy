package com.depesha

import android.content.Context
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val AUDIO_CHANNEL = "ru.rare_books.messenger/audio_routing"
    private var audioManager: AudioManager? = null
    private var savedAudioMode: Int = AudioManager.MODE_NORMAL
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setAudioRouteEarpiece" -> {
                    try {
                        setAudioRouteToEarpiece()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("AUDIO_ERROR", "Failed to set earpiece: ${e.message}", null)
                    }
                }
                "setAudioRouteSpeaker" -> {
                    try {
                        setAudioRouteToSpeaker()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("AUDIO_ERROR", "Failed to set speaker: ${e.message}", null)
                    }
                }
                "restoreAudioRoute" -> {
                    try {
                        restoreAudioRoute()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("AUDIO_ERROR", "Failed to restore audio: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun setAudioRouteToEarpiece() {
        audioManager?.let { am ->
            android.util.Log.d("MainActivity", "===== setAudioRouteToEarpiece called =====")
            android.util.Log.d("MainActivity", "Current mode: ${am.mode}")
            android.util.Log.d("MainActivity", "Speaker on: ${am.isSpeakerphoneOn}")
            
            // Сохраняем текущий режим
            savedAudioMode = am.mode
            
            // Устанавливаем режим разговора для маршрутизации на earpiece
            am.mode = AudioManager.MODE_IN_COMMUNICATION
            android.util.Log.d("MainActivity", "Set mode to MODE_IN_COMMUNICATION")
            
            // Отключаем громкую связь (КРИТИЧНО!)
            am.isSpeakerphoneOn = false
            android.util.Log.d("MainActivity", "Disabled speakerphone (set to false)")
            
            // Устанавливаем маршрут на встроенный наушник (earpiece)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                android.util.Log.d("MainActivity", "Android 12+, using setCommunicationDevice")
                // На Android 12+ используем setCommunicationDevice
                val devices = am.availableCommunicationDevices
                android.util.Log.d("MainActivity", "Available devices: ${devices.size}")
                devices.forEachIndexed { index, device ->
                    android.util.Log.d("MainActivity", "Device $index: type=${device.type}, name=${device.productName}")
                }
                val earpiece = devices.firstOrNull { 
                    it.type == android.media.AudioDeviceInfo.TYPE_BUILTIN_EARPIECE 
                }
                if (earpiece != null) {
                    val result = am.setCommunicationDevice(earpiece)
                    android.util.Log.d("MainActivity", "setCommunicationDevice(earpiece) result: $result")
                    // Повторно убеждаемся, что speakerphone выключен
                    am.isSpeakerphoneOn = false
                    android.util.Log.d("MainActivity", "Force disabled speakerphone after setCommunicationDevice")
                } else {
                    android.util.Log.w("MainActivity", "Earpiece device not found!")
                }
            } else {
                android.util.Log.d("MainActivity", "Android <12, relying on MODE_IN_COMMUNICATION")
                // На более старых версиях просто выключаем громкую связь в режиме IN_COMMUNICATION
                // это автоматически маршрутизирует на earpiece
            }
            
            android.util.Log.d("MainActivity", "Final speaker state: ${am.isSpeakerphoneOn}")
            android.util.Log.d("MainActivity", "Final mode: ${am.mode}")
            android.util.Log.d("MainActivity", "===== setAudioRouteToEarpiece complete =====")
        } ?: android.util.Log.e("MainActivity", "AudioManager is null!")
    }
    
    private fun setAudioRouteToSpeaker() {
        audioManager?.let { am ->
            android.util.Log.d("MainActivity", "===== setAudioRouteToSpeaker called =====")
            android.util.Log.d("MainActivity", "Current mode: ${am.mode}")
            android.util.Log.d("MainActivity", "Speaker on: ${am.isSpeakerphoneOn}")
            
            // На Android 12+ сначала очищаем коммуникационное устройство
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                android.util.Log.d("MainActivity", "Android 12+, clearing communication device")
                am.clearCommunicationDevice()
            }
            
            // Для media usage используем MODE_NORMAL - аудио автоматически идет на speaker
            am.mode = AudioManager.MODE_NORMAL
            android.util.Log.d("MainActivity", "Set mode to MODE_NORMAL")
            
            // Выключаем speakerphone (в MODE_NORMAL это не нужно)
            am.isSpeakerphoneOn = false
            android.util.Log.d("MainActivity", "Disabled speakerphone (not needed in MODE_NORMAL)")
            
            android.util.Log.d("MainActivity", "Final speaker state: ${am.isSpeakerphoneOn}")
            android.util.Log.d("MainActivity", "Final mode: ${am.mode}")
            android.util.Log.d("MainActivity", "===== setAudioRouteToSpeaker complete =====")
        } ?: android.util.Log.e("MainActivity", "AudioManager is null!")
    }
    
    private fun restoreAudioRoute() {
        audioManager?.let { am ->
            android.util.Log.d("MainActivity", "===== restoreAudioRoute called =====")
            android.util.Log.d("MainActivity", "Current mode: ${am.mode}")
            android.util.Log.d("MainActivity", "Speaker on: ${am.isSpeakerphoneOn}")
            
            // На Android 12+ очищаем коммуникационное устройство
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                am.clearCommunicationDevice()
                android.util.Log.d("MainActivity", "Cleared communication device")
            }
            
            // Восстанавливаем исходный режим
            am.mode = AudioManager.MODE_NORMAL
            android.util.Log.d("MainActivity", "Set mode to MODE_NORMAL")
            
            // Выключаем громкую связь
            am.isSpeakerphoneOn = false
            android.util.Log.d("MainActivity", "Disabled speakerphone")
            
            android.util.Log.d("MainActivity", "Final speaker state: ${am.isSpeakerphoneOn}")
            android.util.Log.d("MainActivity", "Final mode: ${am.mode}")
            android.util.Log.d("MainActivity", "===== restoreAudioRoute complete =====")
        } ?: android.util.Log.e("MainActivity", "AudioManager is null!")
    }
}

