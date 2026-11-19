package uz.havola.havola

import android.Manifest
import android.app.*
import android.app.job.*
import android.content.*
import android.content.pm.PackageManager
import android.os.*
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.Locale

class MainActivity: FlutterActivity(), TextToSpeech.OnInitListener {
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var permissionResult: MethodChannel.Result? = null
    override fun onCreate(savedInstanceState: Bundle?) { super.onCreate(savedInstanceState); tts = TextToSpeech(this,this) }
    override fun onInit(status: Int) { ttsReady = status == TextToSpeech.SUCCESS }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"uz.havola/native").setMethodCallHandler { call, result ->
            val prefs = getSharedPreferences("havola",Context.MODE_PRIVATE)
            when(call.method) {
                "read" -> result.success(prefs.getString("config","{}"))
                "cached" -> result.success(prefs.getString("events","[]"))
                "configure" -> {
                    val raw = call.argument<String>("json") ?: "{}"
                    val config = JSONObject(raw)
                    val previous = JSONObject(prefs.getString("config","{}")!!)
                    if(config.optString("url") != previous.optString("url") || config.optString("token") != previous.optString("token")) {
                        prefs.edit().remove("cursor").remove("events").apply()
                    }
                    prefs.edit().putString("config",raw).apply()
                    val scheduler = getSystemService(JobScheduler::class.java)
                    if(config.optString("url").isNotBlank()) {
                        scheduler.schedule(JobInfo.Builder(71,ComponentName(this,SyncJob::class.java))
                            .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                            .setPeriodic(15*60*1000L).setPersisted(true).build())
                    } else scheduler.cancel(71)
                    result.success(null)
                }
                "permission" -> {
                    val manager=getSystemService(NotificationManager::class.java)
                    if(Build.VERSION.SDK_INT>=33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED) {
                        if(permissionResult!=null) result.error("BUSY","Ruxsat so‘rovi allaqachon ochiq",null)
                        else { permissionResult=result; requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS),81) }
                    } else result.success(manager.areNotificationsEnabled())
                }
                "sync", "api" -> Thread {
                    try {
                        val body = if(call.method=="sync") SyncEngine.sync(this) else SyncEngine.request(this,call.argument<String>("path")!!,call.argument<String>("method")?:"GET",call.argument<String>("body"))
                        runOnUiThread {
                            if(call.method=="sync" && SyncEngine.spokenPending.isNotBlank()) {
                                val config=JSONObject(prefs.getString("config","{}")!!)
                                if(config.optBoolean("voice")) speak(SyncEngine.spokenPending,null)
                                SyncEngine.spokenPending=""
                            }
                            result.success(body)
                        }
                    } catch(e: Exception) { runOnUiThread { result.error("NETWORK",e.message?:"Serverga ulanish xatosi",null) } }
                }.start()
                "testNotification" -> {
                    try { SyncEngine.notify(this,101,"Havola","Bu bildirishnoma signali tekshiruvi.",call.argument<Boolean>("sound")?:true);result.success(null) }
                    catch(e: Exception) { result.error("NOTIFICATION",e.message,null) }
                }
                "speak" -> speak(call.argument<String>("text")?:"",result)
                else -> result.notImplemented()
            }
        }
    }
    private fun speak(text: String, result: MethodChannel.Result?) {
        val engine=tts
        if(!ttsReady || engine==null) { result?.error("TTS","Telefon ovoz tizimi hali tayyor emas.",null);return }
        val lang=Locale.forLanguageTag("uz-UZ")
        if(engine.isLanguageAvailable(lang)<TextToSpeech.LANG_AVAILABLE) { result?.error("LANGUAGE","Telefoningizda o‘zbekcha TTS ovozi mavjud emas. Telefon ovoz sozlamalarida uni o‘rnating.",null);return }
        engine.language=lang
        val accepted=engine.speak(text.take(1800),TextToSpeech.QUEUE_ADD,null,"havola-${System.currentTimeMillis()}")
        if(accepted==TextToSpeech.ERROR) result?.error("TTS","Ovozda o‘qish boshlanmadi.",null) else result?.success(null)
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode,permissions,grantResults)
        if(requestCode==81) { permissionResult?.success(grantResults.firstOrNull()==PackageManager.PERMISSION_GRANTED);permissionResult=null }
    }
    override fun onDestroy(){tts?.stop();tts?.shutdown();super.onDestroy()}
}
