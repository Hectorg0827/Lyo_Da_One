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
 * Teacher PNGs embed a pale checkerboard in RGB pixels rather than real alpha.
 * Flood-fill the two-tone background to alpha at display time, keeping the
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
            val cleaned = removeConnectedLightBackdrop(pixels, width, height)
            bitmap.setPixels(cleaned, 0, width, 0, 0, width, height)
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
