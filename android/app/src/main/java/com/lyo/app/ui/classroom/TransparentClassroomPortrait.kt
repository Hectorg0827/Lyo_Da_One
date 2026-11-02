package com.lyo.app.ui.classroom

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.annotation.DrawableRes
import androidx.compose.foundation.Image
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource

/**
 * Some of the legacy teacher PNGs include a white studio matte.
 * Convert near-white backdrop pixels to alpha at display time, keeping the
 * actual character artwork unchanged. This only affects classroom portraits.
 */
@Composable
fun TransparentClassroomPortrait(
    @DrawableRes drawableRes: Int,
    contentDescription: String,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val image = remember(drawableRes, context) {
        BitmapFactory.decodeResource(context.resources, drawableRes)?.let { original ->
            val bitmap = original.copy(Bitmap.Config.ARGB_8888, true)
            val width = bitmap.width
            val height = bitmap.height
            val pixels = IntArray(width * height)
            bitmap.getPixels(pixels, 0, width, 0, 0, width, height)
            for (i in pixels.indices) {
                val value = pixels[i]
                val red = (value shr 16) and 255
                val green = (value shr 8) and 255
                val blue = value and 255
                val low = minOf(red, green, blue)
                val high = maxOf(red, green, blue)
                // Only neutral, near-white matte. Never remove mascot highlights
                // that are saturated orange or purple.
                if (low >= 232 && high - low <= 18) {
                    val sourceAlpha = (value ushr 24) and 255
                    val matteAlpha = ((255 - low) * 255 / 23).coerceIn(0, 255)
                    pixels[i] = (sourceAlpha * matteAlpha / 255 shl 24) or (value and 0x00ffffff)
                }
            }
            bitmap.setPixels(pixels, 0, width, 0, 0, width, height)
            bitmap.asImageBitmap()
        }
    }
    if (image != null) {
        Image(
            bitmap = image,
            contentDescription = contentDescription,
            contentScale = ContentScale.Fit,
            modifier = modifier,
        )
    } else {
        Image(
            painter = painterResource(drawableRes),
            contentDescription = contentDescription,
            contentScale = ContentScale.Fit,
            modifier = modifier,
        )
    }
}
