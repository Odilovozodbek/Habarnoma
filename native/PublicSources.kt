package uz.havola.havola

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import org.jsoup.Jsoup
import org.jsoup.nodes.Document
import org.jsoup.nodes.Element
import java.net.URI
import java.security.MessageDigest

object PublicSources {
    private val handle = Regex("[A-Za-z][A-Za-z0-9_]{3,31}")
    private fun prefs(c: Context) = c.getSharedPreferences("public_sources", Context.MODE_PRIVATE)
    fun sources(c: Context) = JSONArray(prefs(c).getString("sources","[]"))
    fun events(c: Context) = JSONArray(prefs(c).getString("items","[]"))
    private fun objects(a: JSONArray) = (0 until a.length()).map { a.getJSONObject(it) }
    private fun key(s: String) = MessageDigest.getInstance("SHA-256").digest(s.toByteArray()).take(12).joinToString("") { "%02x".format(it) }

    internal fun canonical(input: String): String {
        val value = input.trim()
        val uri = URI(when {
            value.startsWith("@") -> "https://t.me/" + value.drop(1)
            !value.contains("://") -> "https://$value"
            else -> value
        })
        require(uri.scheme == "https" && !uri.host.isNullOrBlank() && uri.userInfo == null) { "Ochiq HTTPS havolasini kiriting." }
        if (uri.host.lowercase() in listOf("t.me","telegram.me","www.t.me")) {
            val parts = uri.path.trim('/').removePrefix("s/").split('/')
            require(handle.matches(parts.first()) && (parts.size == 1 || parts.size == 2 && parts[1].toLongOrNull() != null)) { "Ochiq Telegram kanalining havolasini kiriting." }
            return "https://t.me/s/" + parts.first().lowercase()
        }
        return uri.toASCIIString().substringBefore('#')
    }

    @Synchronized fun add(c: Context, input: String, filter: String) {
        val url = canonical(input)
        val list = sources(c)
        require(objects(list).none { it.getString("url") == url }) { "Bu manba allaqachon qo‘shilgan." }
        require(list.length() < 24) { "24 ta manba qo‘shilgan." }
        val name = if (url.startsWith("https://t.me/s/")) "@"+url.substringAfterLast('/') else URI(url).host
        list.put(JSONObject().put("url",url).put("name",name).put("filter",filter).put("status","Tekshirilmoqda"))
        prefs(c).edit().putString("sources",list.toString()).apply()
    }
    @Synchronized fun remove(c: Context, url: String) {
        prefs(c).edit().putString("sources",JSONArray(objects(sources(c)).filter { it.optString("url") != url }).toString()).apply()
    }
    internal data class Post(val url: String, val text: String)
    private fun fetch(url: String): Document = Jsoup.connect(url).userAgent("Mozilla/5.0 (compatible; Habarnoma/0.3)")
        .timeout(9000).maxBodySize(1500000).get()

    private fun feed(doc: Document): List<Post> = doc.select("item, entry").take(40).mapNotNull { item ->
        val link = item.selectFirst("link[rel=alternate], link[href], link")
        val url = link?.absUrl("href").orEmpty().ifBlank { link?.text().orEmpty() }.ifBlank { doc.location() }
        val description = item.selectFirst("description, summary, content")?.text().orEmpty()
        val text = listOf(item.selectFirst("title")?.text().orEmpty(), Jsoup.parse(description).text()).filter { it.isNotBlank() }.joinToString("\n")
        if (text.isEmpty()) null else Post(url,text)
    }
    private fun article(node: Element, fallback: String): Post? {
        val title = node.selectFirst("h1,h2,h3")?.text().orEmpty()
        val body = node.select("p,li").map { it.text() }.filter { it.isNotBlank() }.take(24)
        val text = (listOf(title) + body).filter { it.isNotBlank() }.joinToString("\n").ifBlank { node.text() }
        val link = node.selectFirst("h1 a[href],h2 a[href],h3 a[href]")?.absUrl("href").orEmpty()
        return if(text.isBlank()) null else Post(link.ifBlank { fallback }, text.take(10000))
    }
    internal fun parse(doc: Document, url: String): List<Post> {
        if (url.startsWith("https://t.me/s/")) {
            val nodes = doc.select(".tgme_widget_message[data-post]")
            require(nodes.isNotEmpty()) { "Kanalning ochiq ko‘rinishi mavjud emas." }
            return nodes.mapNotNull { post ->
                val text = post.selectFirst(".tgme_widget_message_text")?.wholeText()?.trim().orEmpty()
                if (text.isEmpty()) null else Post("https://t.me/"+post.attr("data-post"),text)
            }
        }
        if (doc.selectFirst("rss,feed,rdf|RDF") != null) return feed(doc).reversed()
        val alternate = doc.select("link[rel=alternate][href]").firstOrNull { it.attr("type").contains("rss") || it.attr("type").contains("atom") }
        if (alternate != null && alternate.absUrl("href").startsWith("https://")) {
            runCatching { feed(fetch(alternate.absUrl("href"))) }.getOrNull()?.takeIf { it.isNotEmpty() }?.let { return it.reversed() }
        }
        val articles = doc.select("article")
        if (articles.isNotEmpty()) return articles.take(25).mapNotNull { article(it,doc.location()) }.reversed()
        val main = doc.selectFirst("main,[role=main]") ?: doc.body()
        main.select("nav,footer,header,aside,script,style").remove()
        return listOfNotNull(article(main,doc.location()))
    }
    @Synchronized fun refresh(c: Context): List<JSONObject> {
        val list = sources(c)
        val p = prefs(c)
        val cache = objects(events(c)).toMutableList()
        var id = p.getLong("lastId",0L)
        val fresh = mutableListOf<JSONObject>()
        val editor = p.edit()
        for (source in objects(list)) {
            val url = source.getString("url")
            try {
                val seen = JSONArray(p.getString("seen_"+key(url),"[]"))
                val keys = (0 until seen.length()).map { seen.getString(it) }.toMutableSet()
                for (post in parse(fetch(url),url)) {
                    val fingerprint = key(post.url+"\n"+post.text)
                    if (fingerprint in keys) continue
                    val event = Bulletins.enrich(JSONObject().put("text",post.text.take(12000)).put("url",post.url).put("source",source.getString("name")))
                    if (source.optString("filter") !in listOf("all",event.getString("category"))) continue
                    keys.add(fingerprint)
                    event.put("id",--id)
                    cache.add(event)
                    if (p.contains("seen_"+key(url))) fresh.add(event)
                }
                editor.putString("seen_"+key(url),JSONArray(keys.toList().takeLast(500)).toString())
                source.put("status","Tekshirildi")
            } catch (e: Exception) { source.put("status","O‘qib bo‘lmadi: "+(e.message ?: "Tarmoq xatosi").take(100)) }
        }
        editor.putString("items",JSONArray(cache.takeLast(800)).toString()).putLong("lastId",id).putString("sources",list.toString()).apply()
        return fresh
    }
}
