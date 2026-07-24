package com.lyo.app.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.LoginRequest
import com.lyo.app.data.api.RegisterRequest
import com.lyo.app.data.api.UserDto
import com.lyo.app.data.sync.SyncClient
import java.io.IOException
import kotlinx.coroutines.CancellationException
import retrofit2.HttpException
import kotlin.random.Random

/**
 * Global auth/session state, the Compose analogue of the web app's
 * Zustand auth store (login / signup / logout / hydrate).
 *
 * A stored token is not treated as an authenticated session until `/me`
 * resolves successfully. Transient hydration failures preserve the token so
 * the user can retry; only a confirmed authorization failure clears it.
 */
object Session {

    var user by mutableStateOf<UserDto?>(null)
        private set
    var isLoading by mutableStateOf(true)
        private set
    var isAuthenticated by mutableStateOf(false)
        private set
    var hydrationError by mutableStateOf<String?>(null)
        private set

    suspend fun hydrate() {
        isLoading = true
        hydrationError = null
        user = null
        isAuthenticated = false

        if (!TokenManager.hasToken) {
            isLoading = false
            return
        }

        try {
            val resolvedUser = ApiClient.api.me()
            user = resolvedUser
            isAuthenticated = true
            SyncClient.connect()
        } catch (error: CancellationException) {
            throw error
        } catch (error: Exception) {
            SyncClient.disconnect()
            user = null
            isAuthenticated = false

            if (error is HttpException && error.code() in setOf(401, 403)) {
                TokenManager.clear()
            } else {
                hydrationError = hydrationFailureMessage(error)
            }
        } finally {
            isLoading = false
        }
    }

    suspend fun login(email: String, password: String) {
        val response = ApiClient.api.login(LoginRequest(email, password))
        val accessToken = response.accessToken
            ?: throw IllegalStateException("The server did not return an access token.")

        establishSession(
            accessToken = accessToken,
            refreshToken = response.refreshToken,
            providedUser = response.user,
        )
    }

    suspend fun signup(email: String, password: String, displayName: String) {
        val parts = displayName.trim().split(Regex("\\s+")).filter { it.isNotBlank() }
        val usernameBase = displayName
            .lowercase()
            .replace(Regex("[^a-z0-9]"), "")
            .ifBlank { "learner" }
        val username = usernameBase + Random.nextInt(1000, 10000)

        val response = ApiClient.api.register(
            RegisterRequest(
                email = email,
                username = username,
                password = password,
                confirmPassword = password,
                firstName = parts.firstOrNull() ?: displayName,
                lastName = parts.drop(1).joinToString(" ").ifBlank { null },
            )
        )
        val accessToken = response.accessToken
            ?: throw IllegalStateException("The server did not return an access token.")

        establishSession(
            accessToken = accessToken,
            refreshToken = response.refreshToken,
            providedUser = response.user,
        )
    }

    private suspend fun establishSession(
        accessToken: String,
        refreshToken: String?,
        providedUser: UserDto?,
    ) {
        hydrationError = null
        user = null
        isAuthenticated = false
        SyncClient.disconnect()
        TokenManager.setTokens(accessToken, refreshToken)

        try {
            val resolvedUser = providedUser ?: ApiClient.api.me()
            user = resolvedUser
            isAuthenticated = true
            isLoading = false
            SyncClient.connect()
        } catch (error: CancellationException) {
            clearLocalSession()
            throw error
        } catch (error: Exception) {
            clearLocalSession()
            throw error
        }
    }

    suspend fun logout() {
        SyncClient.disconnect()
        try {
            ApiClient.api.logout()
        } catch (_: Exception) {
            // Server logout is best-effort; local credentials must always clear.
        } finally {
            clearLocalSession()
        }
    }

    private fun clearLocalSession() {
        SyncClient.disconnect()
        TokenManager.clear()
        user = null
        isAuthenticated = false
        hydrationError = null
        isLoading = false
    }

    fun updateUserLocally(updated: UserDto) {
        user = updated
    }

    private fun hydrationFailureMessage(error: Throwable): String = when (error) {
        is IOException -> "LYO could not verify your saved session. Check your connection and retry."
        is HttpException -> "LYO could not verify your saved session (${error.code()}). Retry or sign out."
        else -> error.localizedMessage
            ?: "LYO could not verify your saved session. Retry or sign out."
    }
}
