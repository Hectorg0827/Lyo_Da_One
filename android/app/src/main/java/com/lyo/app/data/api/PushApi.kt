package com.lyo.app.data.api

import retrofit2.http.*

data class PushRegistration(val device_token: String, val device_type: String = "android",
    val app_version: String, val os_version: String)
data class RegisteredPushDevice(val id: String, val is_active: Boolean, val delivery_enabled: Boolean = false)

interface PushApi {
    @POST("api/v1/push/devices/register")
    suspend fun register(@Body body: PushRegistration): RegisteredPushDevice
    @DELETE("api/v1/push/devices/{id}") suspend fun unregister(@Path("id") id: String)
}
