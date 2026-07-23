package com.lyo.app.data.api

import com.google.gson.Gson
import com.lyo.app.BuildConfig
import com.lyo.app.data.TokenManager
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
import java.util.concurrent.TimeUnit

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
            // Give up after one retry to avoid loops
            if (response.priorResponse != null) return null
            val refresh = TokenManager.refreshToken ?: return null

            val refreshed = try {
                val body = gson.toJson(mapOf("refresh_token" to refresh))
                    .toRequestBody("application/json".toMediaType())
                val refreshRequest = Request.Builder()
                    .url(BuildConfig.API_BASE_URL + "auth/refresh")
                    .post(body)
                    .build()
                // Plain client: no interceptor/authenticator recursion
                val plain = OkHttpClient()
                plain.newCall(refreshRequest).execute().use { r ->
                    if (!r.isSuccessful) return@use null
                    val json = gson.fromJson(r.body?.string(), Map::class.java) ?: return@use null
                    val access = json["access_token"] as? String ?: return@use null
                    TokenManager.setTokens(access, json["refresh_token"] as? String)
                    access
                }
            } catch (e: Exception) {
                null
            } ?: run {
                TokenManager.clear()
                return null
            }

            return response.request.newBuilder()
                .header("Authorization", "Bearer $refreshed")
                .build()
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
