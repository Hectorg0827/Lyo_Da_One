package com.lyo.app.ui.screens.auth

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.GoogleAuthProvider
import com.lyo.app.data.Session
import com.lyo.app.ui.theme.BorderColor
import com.lyo.app.ui.theme.TextSecondary
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

/**
 * The OAuth web client ID that google-services.json adds as a string resource,
 * or null while the app has no Firebase configuration (the button then hides).
 */
internal fun googleWebClientId(context: Context): String? {
    if (FirebaseApp.getApps(context).isEmpty()) return null
    // Looked up by name: the resource exists only when google-services.json does.
    @Suppress("DiscouragedApi")
    val id = context.resources.getIdentifier("default_web_client_id", "string", context.packageName)
    return if (id == 0) null else context.getString(id).takeIf { it.isNotBlank() }
}

/** Shows Google's account sheet and returns Firebase's ID token for the chosen account. */
internal suspend fun googleFirebaseIdToken(context: Context, webClientId: String): String {
    val request = GetCredentialRequest.Builder()
        .addCredentialOption(GetSignInWithGoogleOption.Builder(webClientId).build())
        .build()
    val credential = CredentialManager.create(context).getCredential(context, request).credential
    if (credential !is CustomCredential ||
        credential.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
    ) {
        throw IllegalStateException("Google returned an unexpected credential.")
    }
    val googleIdToken = GoogleIdTokenCredential.createFrom(credential.data).idToken
    val auth = FirebaseAuth.getInstance()
    try {
        val user = auth.signInWithCredential(GoogleAuthProvider.getCredential(googleIdToken, null)).await().user
            ?: throw IllegalStateException("Firebase did not return the account.")
        return user.getIdToken(false).await().token
            ?: throw IllegalStateException("Firebase did not return a token.")
    } finally {
        // LYO's session is the API's tokens; Firebase keeps none of its own.
        auth.signOut()
    }
}

/**
 * "Continue with Google", with an "or" line above it. Shows nothing until the
 * app is built with google-services.json.
 */
@Composable
internal fun GoogleSignInSection(
    enabled: Boolean,
    onBusyChange: (Boolean) -> Unit,
    onError: (String?) -> Unit,
    onSignedIn: () -> Unit,
) {
    val context = LocalContext.current
    val webClientId = remember(context) { googleWebClientId(context) } ?: return
    val scope = rememberCoroutineScope()

    Column(modifier = Modifier.fillMaxWidth().padding(top = 20.dp)) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            HorizontalDivider(modifier = Modifier.weight(1f), color = BorderColor)
            Text("or", color = TextSecondary, style = MaterialTheme.typography.bodySmall)
            HorizontalDivider(modifier = Modifier.weight(1f), color = BorderColor)
        }
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .padding(top = 20.dp)
                .fillMaxWidth()
                .height(52.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(Color.White)
                .clickable(enabled = enabled) {
                    scope.launch {
                        onBusyChange(true)
                        onError(null)
                        try {
                            Session.loginWithFirebase(googleFirebaseIdToken(context, webClientId))
                            onSignedIn()
                        } catch (cancelled: CancellationException) {
                            throw cancelled
                        } catch (failure: Exception) {
                            onError(googleSignInFailureMessage(failure))
                        } finally {
                            onBusyChange(false)
                        }
                    }
                },
        ) {
            Text(
                text = "Continue with Google",
                color = Color(0xFF1F1F1F),
                style = MaterialTheme.typography.titleMedium,
            )
        }
    }
}
