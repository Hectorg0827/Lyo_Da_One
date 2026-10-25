package com.lyo.app.ui.screens.auth

import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.NoCredentialException
import java.io.IOException
import retrofit2.HttpException

/**
 * What to tell the learner when Continue with Google fails; null when they
 * closed Google's account sheet themselves.
 */
internal fun googleSignInFailureMessage(error: Throwable): String? = when (error) {
    is GetCredentialCancellationException -> null
    is NoCredentialException -> "Add a Google account to this phone, or log in with your email."
    is HttpException -> when (error.code()) {
        401 -> "Google could not confirm this account. Make sure its email is confirmed, then try again."
        429 -> "Too many attempts. Wait a moment and try again."
        503 -> "Google sign-in is not available right now. Log in with your email for now."
        in 500..599 -> "LYO's sign-in service is unavailable. Try again shortly."
        else -> "Google sign-in failed (${error.code()}). Please try again."
    }
    is IOException -> "Check your connection and try again."
    else -> "Google sign-in didn't work. Try again, or log in with your email."
}
