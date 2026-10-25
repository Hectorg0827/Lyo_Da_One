package com.lyo.app.ui.screens.auth

import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.NoCredentialException
import java.io.IOException
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import retrofit2.HttpException
import retrofit2.Response

/**
 * Continue with Google's failures, mirrored by web `google-sign-in.test.mjs`:
 * closing Google's sheet says nothing, everything else says what to do.
 */
class GoogleSignInMessagesTest {

    private fun http(code: Int) = HttpException(Response.error<Any>(code, "{}".toResponseBody(null)))

    @Test
    fun `closing Google's sheet shows no error`() {
        assertNull(googleSignInFailureMessage(GetCredentialCancellationException()))
    }

    @Test
    fun `a phone without a Google account is told to add one`() {
        assertEquals(
            "Add a Google account to this phone, or log in with your email.",
            googleSignInFailureMessage(NoCredentialException()),
        )
    }

    @Test
    fun `the API's refusals become plain messages`() {
        assertTrue(googleSignInFailureMessage(http(401))!!.contains("email is confirmed"))
        assertTrue(googleSignInFailureMessage(http(429))!!.startsWith("Too many attempts"))
        assertTrue(googleSignInFailureMessage(http(503))!!.contains("not available right now"))
        assertTrue(googleSignInFailureMessage(http(500))!!.contains("unavailable"))
        assertTrue(googleSignInFailureMessage(http(418))!!.contains("(418)"))
    }

    @Test
    fun `connection and unexpected failures say what to do`() {
        assertEquals("Check your connection and try again.", googleSignInFailureMessage(IOException("offline")))
        assertTrue(googleSignInFailureMessage(IllegalStateException("x"))!!.contains("log in with your email"))
    }
}
