package com.lyo.app.ui.screens.clips

import com.google.gson.Gson
import com.lyo.app.data.api.ClipAttributionDto
import com.lyo.app.data.api.ClipDto
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * The credit line a library video must show. `discover-attribution.test.mjs`
 * asserts the same rules for the web.
 */
class ClipAttributionTest {

    @Test
    fun `the server's credit is shown as it is`() {
        val credit = ClipAttributionDto(credit = "NASA/JPL-Caltech · Public domain", license = "Public domain")
        assertEquals("NASA/JPL-Caltech · Public domain", credit.displayLine)
    }

    @Test
    fun `the licence is added when the credit does not name it`() {
        assertEquals("Jane Doe · CC BY 4.0", ClipAttributionDto(credit = "Jane Doe", license = "CC BY 4.0").displayLine)
    }

    @Test
    fun `without a credit the source and licence still show`() {
        val credit = ClipAttributionDto(sourceName = "Wikimedia Commons", license = "CC BY-SA 4.0")
        assertEquals("Wikimedia Commons · CC BY-SA 4.0", credit.displayLine)
    }

    @Test
    fun `nothing to credit shows nothing`() {
        assertNull(ClipAttributionDto(credit = "  ").displayLine)
    }

    @Test
    fun `only https source links are opened`() {
        assertNull(ClipAttributionDto(sourceUrl = "javascript:alert(1)").sourceLink)
        assertNull(ClipAttributionDto(sourceUrl = "http://example.com").sourceLink)
        assertEquals("https://images.nasa.gov/details/X", ClipAttributionDto(sourceUrl = "https://images.nasa.gov/details/X").sourceLink)
    }

    @Test
    fun `the clips API payload decodes its attribution`() {
        val json = """{"id":"7","title":"Rover landing","attribution":{"credit":"NASA/JPL","sourceName":"NASA Image and Video Library",
            "sourceURL":"https://images.nasa.gov/details/X","license":"Public domain","licenseURL":"https://www.nasa.gov/"}}"""
        val clip = Gson().fromJson(json, ClipDto::class.java)
        assertEquals("NASA/JPL · Public domain", clip.attribution?.displayLine)
        assertEquals("https://images.nasa.gov/details/X", clip.attribution?.sourceLink)
        assertNull(Gson().fromJson("""{"id":"8","attribution":null}""", ClipDto::class.java).attribution)
    }
}
