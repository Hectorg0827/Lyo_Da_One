package com.lyo.app.data

import java.io.IOException
import retrofit2.HttpException

/*
 * Deleting a learner's account. The contract agreed with the backend, and
 * shared with web (account-deletion.mjs) and iOS: DELETE /auth/me with the
 * bearer token and no body; 200 or 204 means the account is gone.
 * scripts/verify-account-deletion.mjs keeps the clients in step.
 */

internal const val ACCOUNT_DELETION_PATH = "auth/me"

/** True only for the statuses the backend promised for a completed deletion. */
internal fun accountDeletionSucceeded(code: Int): Boolean = code == 200 || code == 204

/** What to tell the learner when deletion did not happen. They stay signed in. */
internal fun accountDeletionFailureMessage(code: Int): String = when (code) {
    401, 403 -> "Your session has expired. Log in again, then delete your account."
    429 -> "Too many attempts. Please wait a few minutes and try again."
    else -> "Your account was not deleted (error $code). Please try again, or email support@lyoai.app."
}

internal fun accountDeletionFailureMessage(error: Throwable): String = when (error) {
    is HttpException -> accountDeletionFailureMessage(error.code())
    is IOException -> "Your account was not deleted. Check your connection and try again."
    else -> "Your account was not deleted. Please try again, or email support@lyoai.app."
}
