package com.lyo.app.data.classroom

import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl

internal fun classroomConnectionUrl(apiBaseUrl: String): HttpUrl =
    (apiBaseUrl.trimEnd('/') + "/api/v1/classroom/ws/connect").toHttpUrl()
