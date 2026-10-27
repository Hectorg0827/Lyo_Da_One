package com.lyo.app.data

import java.io.IOException
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import retrofit2.HttpException
import retrofit2.Response

/** Mirrors web `account-deletion.test.mjs`: same contract, same messages. */
class AccountDeletionTest {

    @Test
    fun `the contract is DELETE auth-me and only 200 or 204 count as deleted`() {
        assertEquals("auth/me", ACCOUNT_DELETION_PATH)
        assertTrue(accountDeletionSucceeded(200))
        assertTrue(accountDeletionSucceeded(204))
        for (code in listOf(0, 201, 202, 400, 401, 404, 500)) {
            assertFalse("$code", accountDeletionSucceeded(code))
        }
    }

    @Test
    fun `failures say the account still exists and what to do`() {
        assertTrue(accountDeletionFailureMessage(500).contains("not deleted"))
        assertTrue(accountDeletionFailureMessage(401).contains("Log in again"))
        assertTrue(accountDeletionFailureMessage(429).startsWith("Too many attempts"))
        assertTrue(accountDeletionFailureMessage(IOException()).contains("connection"))
        val http = HttpException(Response.error<Any>(503, "{}".toResponseBody(null)))
        assertTrue(accountDeletionFailureMessage(http).contains("error 503"))
    }
}
