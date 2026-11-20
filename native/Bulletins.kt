package uz.havola.havola

import org.json.JSONObject

object Bulletins {
    private val topics = linkedMapOf(
        "dars" to listOf("dars", "mashg‘ulot", "para ", "лекци", "расписани", "imtihon", "semestr"),
        "hakaton" to listOf("hakaton", "hackathon", "хакатон"),
        "tanlov" to listOf("tanlov", "конкурс", "competition"),
        "musobaqa" to listOf("musobaqa", "olimpiada", "олимпиад"),
        "grant" to listOf("grant", "stipendiya", "стипенди"),
        "tadbir" to listOf("tadbir", "seminar", "trening", "uchrashuv", "konferensiya", "forum"),
        "universitet" to listOf("universitet", "talaba", "dekanat")
    )
    private val timing = Regex("""(?iu)\b(?:[01]?\d|2[0-3]):[0-5]\d\b|\b\d{1,2}[./-]\d{1,2}[./-]\d{2,4}\b|\b\d{1,2}[-\s]+(?:yanvar|fevral|mart|aprel|may|iyun|iyul|avgust|sentabr|sentyabr|oktabr|oktyabr|noyabr|dekabr)\w*|\b(?:dushanba|seshanba|chorshanba|payshanba|juma|shanba|yakshanba|bugun|ertaga)\w*|\bsoat\s+\d{1,2}\b""")
    fun enrich(event: JSONObject): JSONObject {
        val body = event.optString("text")
        val lower = body.lowercase().replace('’','‘').replace('\'','‘')
        val topic = topics.entries.firstOrNull { (_, words) -> words.any { lower.contains(it) } }?.key
        event.put("category", if (topic == "dars") topic else event.optString("category").ifBlank { topic ?: "boshqa" })
        val lines = body.split(Regex("""\n+|(?<=[.!?])\s+""")).map { it.trim() }
            .filter { it.isNotBlank() && !it.startsWith("http") && !it.startsWith("@") }.distinct()
        val important = lines.filter { timing.containsMatchIn(it) || it.contains("muddat", true) || it.contains("manzil", true) }
        val summary = (lines.take(1) + important.take(3) + lines.drop(1).take(1)).distinct().joinToString("\n")
        return event.put("summary",summary.ifBlank { body }.take(460))
            .put("schedule", timing.findAll(body).map { it.value }.distinct().take(12).joinToString(" · "))
    }
}
