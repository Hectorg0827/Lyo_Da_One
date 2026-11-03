package com.lyo.app.ui.classroom.catalog

import com.google.gson.JsonElement
import com.google.gson.JsonParser
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URI
import java.net.URLEncoder
import java.net.URL

/** Mirrors the existing Web classroom's free Wikimedia Commons image lookup. */
internal data class CommonsClassroomImage(val url: String, val attribution: String)

internal fun safeCommonsImageUrl(value: String?): String? {
    if (value.isNullOrBlank() || value.length > 1200) return null
    val uri = runCatching { URI(value) }.getOrNull() ?: return null
    return value.takeIf {
        uri.scheme == "https" &&
            uri.host == "upload.wikimedia.org" &&
            uri.userInfo == null &&
            !uri.path.isNullOrBlank() && uri.path != "/"
    }
}

/** Never trust arbitrary remote JSON URLs, and never send signed-in app tokens. */
internal fun parseCommonsClassroomImage(json: String): CommonsClassroomImage? = runCatching {
    val root = JsonParser.parseString(json).asJsonObject
    val pages = root.getAsJsonObject("query")?.getAsJsonObject("pages") ?: return@runCatching null
    val page = pages.entrySet().firstOrNull()?.value?.asJsonObject ?: return@runCatching null
    val imageInfo = page.getAsJsonArray("imageinfo") ?: return@runCatching null
    val info = imageInfo.firstOrNull()?.asJsonObject ?: return@runCatching null
    fun text(value: JsonElement?): String? =
        value?.takeIf { it.isJsonPrimitive && it.asJsonPrimitive.isString }?.asString
    val resultUrl = safeCommonsImageUrl(text(info.get("thumburl")))
        ?: safeCommonsImageUrl(text(info.get("url")))
        ?: return@runCatching null
    val title = text(page.get("title"))?.removePrefix("File:") ?: "Wikimedia Commons"
    CommonsClassroomImage(resultUrl, title.take(150))
}.getOrNull()

/** Search happens off the main thread and quietly falls back if Commons is offline. */
internal suspend fun lookupCommonsClassroomImage(query: String): CommonsClassroomImage? =
    withContext(Dispatchers.IO) {
        val topic = query.trim().take(180)
        if (topic.isBlank()) return@withContext null
        val encoded = URLEncoder.encode("filetype:bitmap $topic", "UTF-8")
        val url = "https://commons.wikimedia.org/w/api.php?action=query&generator=search" +
            "&gsrsearch=$encoded&gsrlimit=1&gsrnamespace=6&prop=imageinfo%7Cinfo" +
            "&inprop=url&iiprop=url%7Cextmetadata&iiurlwidth=760&format=json"
        runCatching {
            val conn = URL(url).openConnection() as HttpURLConnection
            conn.connectTimeout = 6500
            conn.readTimeout = 6500
            conn.setRequestProperty("User-Agent", "LYOClassroom/1.0 (educational media)")
            try {
                if (conn.responseCode !in 200..299) return@runCatching null
                val json = conn.inputStream.bufferedReader().use { it.readText() }
                parseCommonsClassroomImage(json)
            } finally {
                conn.disconnect()
            }
        }.getOrNull()
    }
