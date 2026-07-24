package com.lyo.app.data.api

import com.google.gson.Gson
import com.lyo.app.BuildConfig
import com.lyo.app.data.TokenManager
import java.io.IOException
import java.util.concurrent.TimeUnit
import okhttp3.Authenticator
import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import okhttp3.Route
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory

/**
 * Singleton API client: Bearer-token injection plus automatic refresh on 401
 * (same flow as the web client's tryRefreshToken()).
 */
object ApiClient {

    val gson: Gson = Gson()

    private val authInterceptor = Interceptor { chain ->
        val token = TokenManager.accessToken
        val request = if (token != null) {
            chain.request().newBuilder()
                .header("Authorization", "Bearer $token")
                .build()
        } else {
            chain.request()
        }
        chain.proceed(request)
    }

    private val tokenAuthenticator = object : Authenticator {
        override fun authenticate(route: Route?, response: Response): Request? {
            // Give up after one retry to avoid loops.
            if (response.priorResponse != null) return null
            val refresh = TokenManager.refreshToken ?: return null

            val body = gson.toJson(mapOf("refresh_token" to refresh))
                .toRequestBody("application/json".toMediaType())
            val refreshRequest = Request.Builder()
                .url(BuildConfig.API_BASE_URL + "auth/refresh")
                .post(body)
                .build()

            val refreshedAccess = try {
                // Plain client: no interceptor/authenticator recursion.
                OkHttpClient().newCall(refreshRequest).execute().use { refreshResponse ->
                    when {
                        refreshResponse.isSuccessful -> {
                            val json = refreshResponse.body?.string()
                                ?.let { gson.fromJson(it, Map::class.java) }
                                ?: throw IOException("The token refresh response was empty.")
                            val access = json["access_token"] as? String
                                ?: throw IOException("The token refresh response did not include an access token.")
                            val rotatedRefresh = json["refresh_token"] as? String
                            // Refresh endpoints may rotate the refresh token or return only a new access token.
                            TokenManager.setTokens(access, rotatedRefresh ?: refresh)
                            access
                        }

                        refreshResponse.code in setOf(400, 401, 403) -> {
                            // The server definitively rejected the stored refresh credential.
                            TokenManager.clear()
                            null
                        }

                        else -> throw IOException(
                            "Token refresh is temporarily unavailable (${refreshResponse.code}).",
                        )
                    }
                }
            } catch (error: IOException) {
                // Propagate connectivity and upstream failures so callers can preserve the session
                // and show a recoverable verification state instead of treating them as logout.
                throw error
            } catch (error: Exception) {
                throw IOException("Token refresh could not be completed.", error)
            }

            return refreshedAccess?.let { access ->
                response.request.newBuilder()
                    .header("Authorization", "Bearer $access")
                    .build()
            }
        }
    }

    val okHttp: OkHttpClient = OkHttpClient.Builder()
        .addInterceptor(authInterceptor)
        .authenticator(tokenAuthenticator)
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    private val retrofit: Retrofit = Retrofit.Builder()
        .baseUrl(BuildConfig.API_BASE_URL)
        .client(okHttp)
        .addConverterFactory(GsonConverterFactory.create(gson))
        .build()

    val api: LyoApiService = retrofit.create(LyoApiService::class.java)
    val learning: LearningProgressApiService = retrofit.create(LearningProgressApiService::class.java)
}
