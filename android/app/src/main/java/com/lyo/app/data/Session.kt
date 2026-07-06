package com.lyo.app.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.LoginRequest
import com.lyo.app.data.api.RegisterRequest
import com.lyo.app.data.api.UserDto
import kotlin.random.Random

/**
 * Global auth/session state, the Compose analogue of the web app's
 * Zustand auth store (login / signup / logout / hydrate).
 */
object Session {

    var user by mutableStateOf<UserDto?>(null)
        private set
    var isLoading by mutableStateOf(true)
        private set
    var isAuthenticated by mutableStateOf(false)
        private set

    suspend fun hydrate() {
        if (!TokenManager.hasToken) {
            isLoading = false
            isAuthenticated = false
            return
        }
        try {
            user = ApiClient.api.me()
            isAuthenticated = true
        } catch (e: Exception) {
            TokenManager.clear()
            user = null
            isAuthenticated = false
        } finally {
            isLoading = false
        }
    }

    suspend fun login(email: String, password: String) {
        val resp = ApiClient.api.login(LoginRequest(email, password))
        val access = resp.accessToken ?: throw IllegalStateException("No access token returned")
        TokenManager.setTokens(access, resp.refreshToken)
        user = resp.user ?: ApiClient.api.me()
        isAuthenticated = true
        isLoading = false
    }

    suspend fun signup(email: String, password: String, displayName: String) {
        val parts = displayName.trim().split(" ")
        val username = displayName.lowercase().replace(Regex("[^a-z0-9]"), "") +
            Random.nextInt(1000)
        val resp = ApiClient.api.register(
            RegisterRequest(
                email = email,
                username = username,
                password = password,
                confirmPassword = password,
                firstName = parts.firstOrNull() ?: displayName,
                lastName = parts.drop(1).joinToString(" ").ifBlank { null },
            )
        )
        val access = resp.accessToken ?: throw IllegalStateException("No access token returned")
        TokenManager.setTokens(access, resp.refreshToken)
        user = resp.user ?: ApiClient.api.me()
        isAuthenticated = true
        isLoading = false
    }

    suspend fun logout() {
        try {
            ApiClient.api.logout()
        } catch (e: Exception) {
            // best-effort server logout
        }
        TokenManager.clear()
        user = null
        isAuthenticated = false
    }

    fun updateUserLocally(updated: UserDto) {
        user = updated
    }
}
