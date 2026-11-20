package uz.havola.havola

import android.app.*
import android.app.job.*
import android.content.*
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

object SyncEngine {
    @Volatile var spokenPending=""
    fun request(context: Context,path: String,method: String="GET",body: String?=null): String {
        val config=JSONObject(context.getSharedPreferences("havola",Context.MODE_PRIVATE).getString("config","{}")!!)
        val base=config.optString("url").trimEnd('/')
        require(base.startsWith("https://")) { "HTTPS kuzatuvchi serverni sozlang." }
        require(path.startsWith("/") && !path.startsWith("//"))
        val connection=URL(base+path).openConnection() as HttpURLConnection
        try {
            connection.instanceFollowRedirects=false
            connection.connectTimeout=15000;connection.readTimeout=20000;connection.requestMethod=method
            connection.setRequestProperty("Authorization","Bearer "+config.optString("token"))
            if(body!=null) { connection.doOutput=true;connection.setRequestProperty("Content-Type","application/json");connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) } }
            val code=connection.responseCode
            if(code !in 200..299) throw IllegalStateException(if(code==401) "Server kirish tokeni noto‘g‘ri." else "Server xatosi: HTTP $code")
            return connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
        } finally { connection.disconnect() }
    }
    fun combined(context: Context): String {
        val remote = JSONArray(context.getSharedPreferences("havola",Context.MODE_PRIVATE).getString("events","[]"))
        val items = PublicSources.events(context)
        for (i in 0 until remote.length()) items.put(Bulletins.enrich(remote.getJSONObject(i)))
        return items.toString()
    }
    @Synchronized fun sync(context: Context): String {
        val prefs=context.getSharedPreferences("havola",Context.MODE_PRIVATE)
        val config=JSONObject(prefs.getString("config","{}")!!)
        var cursor=prefs.getLong("cursor",0)
        val cache=JSONArray(prefs.getString("events","[]"))
        val fresh=mutableListOf<JSONObject>()
        fresh.addAll(PublicSources.refresh(context))
        // Bounded catch-up, next periodic run continues from the saved cursor.
        for(page in 0 until 5) {
            if(config.optString("url").isBlank()) break
            val batch = try { JSONArray(request(context,"/events?after=$cursor")) } catch(e: Exception) {
                if (PublicSources.sources(context).length()==0) throw e
                break
            }
            if(batch.length()==0) break
            for(i in 0 until batch.length()) {
                val event=Bulletins.enrich(batch.getJSONObject(i))
                val id=event.getLong("id")
                if(id>cursor) { cache.put(event); fresh.add(event);cursor=id }
            }
            // Persist data and cursor together; retries cannot lose newly fetched posts.
            val kept=JSONArray()
            for(i in maxOf(0,cache.length()-1000) until cache.length()) kept.put(cache.getJSONObject(i))
            prefs.edit().putLong("cursor",cursor).putString("events",kept.toString()).apply()
        }
        val selected = config.optString("category","all")
        val relevant = fresh.filter { selected == "all" || it.optString("category") == selected }
        for(event in relevant) {
            try { notify(context,(event.getLong("id")%Int.MAX_VALUE).toInt(),"Habarnoma • "+event.optString("category"),event.optString("summary").take(460),config.optBoolean("sound",true)) } catch(_: Exception) { /* Cache still contains the unread announcement. */ }
        }
        spokenPending=if(relevant.isEmpty()) "" else relevant.takeLast(3).joinToString(". ") { it.optString("summary").take(500) }
        return combined(context)
    }
    fun notify(context: Context,id: Int,title: String,text: String,sound: Boolean) {
        val manager=context.getSystemService(NotificationManager::class.java)
        check(manager.areNotificationsEnabled()) { "Telefon sozlamalarida bildirishnomaga ruxsat bering." }
        val custom = context.getSharedPreferences("havola",Context.MODE_PRIVATE).getString("musicUri",null)
        val tone = custom?.let { android.net.Uri.parse(it) } ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val channelId = when {
            !sound -> "havola_silent_v1"
            custom == null -> "havola_sound_v1"
            else -> "music_" + java.util.UUID.nameUUIDFromBytes(custom.toByteArray())
        }
        if(Build.VERSION.SDK_INT>=26) {
            val channel=NotificationChannel(channelId,if(sound) "Ovozli e’lonlar" else "Ovozsiz e’lonlar",NotificationManager.IMPORTANCE_DEFAULT)
            if(sound) channel.setSound(tone,AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).build()) else channel.setSound(null,null)
            manager.createNotificationChannel(channel)
        }
        val pending=PendingIntent.getActivity(context,0,Intent(context,MainActivity::class.java),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder=if(Build.VERSION.SDK_INT>=26) Notification.Builder(context,channelId) else Notification.Builder(context)
        builder.setSmallIcon(android.R.drawable.ic_dialog_info).setContentTitle(title).setContentText(text).setStyle(Notification.BigTextStyle().bigText(text)).setContentIntent(pending).setAutoCancel(true)
        if(Build.VERSION.SDK_INT<26 && sound) builder.setSound(tone)
        manager.notify(id,builder.build())
    }
}
class SyncJob: JobService() {
    @Volatile private var cancelled=false
    override fun onStartJob(params: JobParameters): Boolean {
        cancelled=false
        Thread {
            var retry=false
            try { SyncEngine.sync(this) } catch(_: Exception) { retry=true }
            if(!cancelled) jobFinished(params,retry)
        }.start()
        return true
    }
    override fun onStopJob(params: JobParameters): Boolean {cancelled=true;return true}
}
