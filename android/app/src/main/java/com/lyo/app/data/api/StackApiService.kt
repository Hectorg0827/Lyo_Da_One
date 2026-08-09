package com.lyo.app.data.api

import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.PUT
import retrofit2.http.Path
import retrofit2.http.POST
import retrofit2.http.Query

/**
 * The real, backend-synced Stack Items API — `/api/v1/stack/items`
 * (`lyo_app/stack/routes.py`). See StackDtos.kt's doc comment for the
 * wire-shape source of truth. Auth-gated (real JWT `get_current_user`),
 * matching this app's other authenticated endpoints — never reachable by
 * a guest session, unlike the classroom's WS `api_key` guest path.
 */
interface StackApiService {
    @GET("api/v1/stack/items")
    suspend fun items(
        @Query("status") status: String? = null,
        @Query("item_type") itemType: String? = null,
        @Query("limit") limit: Int = 50,
        @Query("offset") offset: Int = 0,
    ): StackItemListResponse

    @POST("api/v1/stack/items")
    suspend fun createItem(@Body body: CreateStackItemRequest): StackItemDto

    @GET("api/v1/stack/items/{itemId}")
    suspend fun item(@Path("itemId") itemId: Int): StackItemDto

    @PUT("api/v1/stack/items/{itemId}")
    suspend fun updateItem(@Path("itemId") itemId: Int, @Body body: UpdateStackItemRequest): StackItemDto

    @DELETE("api/v1/stack/items/{itemId}")
    suspend fun deleteItem(@Path("itemId") itemId: Int)
}
