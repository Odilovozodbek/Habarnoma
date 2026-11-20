package uz.havola.havola

import org.json.JSONObject
import org.jsoup.Jsoup
import org.jsoup.parser.Parser
import org.junit.Assert.*
import org.junit.Test

class PublicSourcesTest {
    @Test fun telegramPreviewPreservesTheLessonTime() {
        val url = PublicSources.canonical("https://t.me/sample_channel/46")
        assertEquals("https://t.me/s/sample_channel",url)
        val html = """<div class="tgme_widget_message" data-post="sample_channel/46"><div class="tgme_widget_message_text">Matematika darsi<br>Dushanba 08:30, 215-xona</div></div>"""
        val post = PublicSources.parse(Jsoup.parse(html,url),url).single()
        val result = Bulletins.enrich(JSONObject().put("text",post.text))
        assertEquals("https://t.me/sample_channel/46",post.url)
        assertEquals("dars",result.getString("category"))
        assertTrue(result.getString("summary").contains("215-xona"))
        assertTrue(result.getString("schedule").contains("08:30"))
    }
    @Test fun feedAndWebArticleRetainTheirSources() {
        val url = "https://example.org/news"
        val rss = "<rss><channel><item><title>Tanlov</title><link>https://example.org/contest</link><description>20-noyabr soat 15:00</description></item></channel></rss>"
        val post = PublicSources.parse(Jsoup.parse(rss,url,Parser.xmlParser()),url).single()
        assertEquals("https://example.org/contest",post.url)
        val result = Bulletins.enrich(JSONObject().put("text",post.text))
        assertEquals("tanlov",result.getString("category"))
        assertTrue(result.getString("schedule").contains("20-noyabr"))
        val html = "<article><h2><a href='/seminar'>Seminar</a></h2><p>Soat 13:00</p></article>"
        assertEquals("https://example.org/seminar",PublicSources.parse(Jsoup.parse(html,url),url).single().url)
    }
}
