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
    private var musicResult: MethodChannel.Result? = null
    private fun scheduleSync() {
        val scheduler = getSystemService(JobScheduler::class.java)
        val config = JSONObject(getSharedPreferences("havola",MODE_PRIVATE).getString("config","{}")!!)
        if (config.optString("url").isNotBlank() || PublicSources.sources(this).length() > 0) {
            scheduler.schedule(JobInfo.Builder(71,ComponentName(this,SyncJob::class.java))
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                .setPeriodic(15*60*1000L).setPersisted(true).build())
        } else scheduler.cancel(71)
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode,resultCode,data)
        if (requestCode != 82) return
        val result = musicResult ?: return
        musicResult = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) { result.success(null); return }
        try {
            contentResolver.takePersistableUriPermission(uri,Intent.FLAG_GRANT_READ_URI_PERMISSION)
            val name = contentResolver.query(uri,arrayOf(android.provider.OpenableColumns.DISPLAY_NAME),null,null,null)?.use {
                if(it.moveToFirst()) it.getString(0) else null
            } ?: "Tanlangan musiqa"
            val prefs = getSharedPreferences("havola",MODE_PRIVATE)
            val old = prefs.getString("musicUri",null)
            prefs.edit().putString("musicUri",uri.toString()).putString("musicName",name).apply()
            if(old != null && old != uri.toString()) releaseMusic(old)
            result.success(name)
        } catch(e: Exception) { result.error("MUSIC","Musiqa faylini ochib bo‘lmadi.",null) }
    }
    private fun releaseMusic(uri: String) {
        runCatching { contentResolver.releasePersistableUriPermission(android.net.Uri.parse(uri),Intent.FLAG_GRANT_READ_URI_PERMISSION) }
    }
    private var permissionResult: MethodChannel.Result? = null
    override fun onCreate(savedInstanceState: Bundle?) { super.onCreate(savedInstanceState); tts = TextToSpeech(this,this) }
    override fun onInit(status: Int) { ttsReady = status == TextToSpeech.SUCCESS }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"uz.havola/native").setMethodCallHandler { call, result ->
            val prefs = getSharedPreferences("havola",Context.MODE_PRIVATE)
            when(call.method) {
                "read" -> result.success(prefs.getString("config","{}"))
                "cached" -> result.success(SyncEngine.combined(this))
                "localSources" -> result.success(PublicSources.sources(this).toString())
                "openPost" -> try {
                    val link = android.net.Uri.parse(call.argument<String>("url"))
                    require(link.scheme in listOf("https","http") && !link.host.isNullOrBlank())
                    startActivity(Intent(Intent.ACTION_VIEW,link))
                    result.success(null)
                } catch(e: Exception) { result.error("LINK","Havolani ochib bo‘lmadi.",null) }
                "musicName" -> result.success(prefs.getString("musicName","Telefonning standart signali"))
                "resetMusic" -> {
                    prefs.getString("musicUri",null)?.let { releaseMusic(it) }
                    prefs.edit().remove("musicUri").remove("musicName").apply()
                    result.success(null)
                }
                "pickMusic" -> {
                    if (musicResult != null) { result.error("BUSY","Fayl tanlash oynasi ochiq.",null) }
                    else try {
                        musicResult = result
                        startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
                            .setType("audio/*").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION),82)
                    } catch(e: Exception) { musicResult=null; result.error("MUSIC","Fayl tanlash oynasini ochib bo‘lmadi.",null) }
                }
                "addLocal", "removeLocal" -> Thread {
                    try {
                        val link = call.argument<String>("url")!!
                        if(call.method=="addLocal") PublicSources.add(this,link,call.argument<String>("filter") ?: "all")
                        else PublicSources.remove(this,link)
                        scheduleSync()
                        runOnUiThread { result.success(null) }
                    } catch(e: Exception) { runOnUiThread { result.error("SOURCE",e.message,null) } }
                }.start()
                "configure" -> {
                    val raw = call.argument<String>("json") ?: "{}"
                    val config = JSONObject(raw)
                    val previous = JSONObject(prefs.getString("config","{}")!!)
                    if(config.optString("url") != previous.optString("url") || config.optString("token") != previous.optString("token")) {
                        prefs.edit().remove("cursor").remove("events").apply()
                    }
                    prefs.edit().putString("config",raw).apply()
                    scheduleSync()
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
