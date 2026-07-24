package com.lyo.app.ui.screens.auth

import android.util.Patterns
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lyo.app.data.Session
import com.lyo.app.ui.components.LyoBrandGradient
import com.lyo.app.ui.navigation.Routes
import com.lyo.app.ui.theme.BorderColor
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.LyoRed
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import java.io.IOException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import retrofit2.HttpException

@Composable
fun SignupScreen(nav: NavHostController) {
    var displayName by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var loading by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    fun submit() {
        if (loading) return

        val normalizedName = displayName.trim()
        val normalizedEmail = email.trim()
        when {
            normalizedName.isBlank() || normalizedEmail.isBlank() ||
                password.isBlank() || confirmPassword.isBlank() -> {
                error = "Please fill in all fields."
                return
            }
            normalizedName.length < 2 -> {
                error = "Enter a display name with at least 2 characters."
                return
            }
            !Patterns.EMAIL_ADDRESS.matcher(normalizedEmail).matches() -> {
                error = "Enter a valid email address."
                return
            }
            password.length < 8 -> {
                error = "Password must be at least 8 characters."
                return
            }
            password != confirmPassword -> {
                error = "Passwords do not match."
                return
            }
        }

        error = null
        loading = true
        scope.launch {
            try {
                Session.signup(normalizedEmail, password, normalizedName)
                nav.navigate(Routes.HOME) { popUpTo(0) }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Exception) {
                error = signupFailureMessage(failure)
            } finally {
                loading = false
            }
        }
    }

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp, vertical = 32.dp),
    ) {
        Text(
            text = "LYO",
            fontSize = 52.sp,
            fontWeight = FontWeight.Black,
            color = LyoPurple,
        )
        Text(
            text = "Create your account",
            style = MaterialTheme.typography.headlineMedium,
            color = TextPrimary,
            modifier = Modifier.padding(top = 12.dp),
        )
        Text(
            text = "Join LYO and start learning today",
            style = MaterialTheme.typography.bodyMedium,
            color = TextSecondary,
            modifier = Modifier.padding(top = 4.dp),
        )

        Spacer(Modifier.height(28.dp))

        error?.let { message ->
            Text(
                text = message,
                color = LyoRed,
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 12.dp),
            )
        }

        SignupField(
            value = displayName,
            onValueChange = {
                displayName = it
                error = null
            },
            label = "Display name",
            keyboardType = KeyboardType.Text,
            enabled = !loading,
        )
        Spacer(Modifier.height(14.dp))
        SignupField(
            value = email,
            onValueChange = {
                email = it
                error = null
            },
            label = "Email",
            keyboardType = KeyboardType.Email,
            enabled = !loading,
        )
        Spacer(Modifier.height(14.dp))
        SignupField(
            value = password,
            onValueChange = {
                password = it
                error = null
            },
            label = "Password (min 8 characters)",
            keyboardType = KeyboardType.Password,
            isPassword = true,
            enabled = !loading,
        )
        Spacer(Modifier.height(14.dp))
        SignupField(
            value = confirmPassword,
            onValueChange = {
                confirmPassword = it
                error = null
            },
            label = "Confirm password",
            keyboardType = KeyboardType.Password,
            isPassword = true,
            enabled = !loading,
        )

        Spacer(Modifier.height(24.dp))

        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(LyoBrandGradient)
                .clickable(enabled = !loading) { submit() },
        ) {
            if (loading) {
                CircularProgressIndicator(
                    color = Color.White,
                    strokeWidth = 2.dp,
                    modifier = Modifier.size(22.dp),
                )
            } else {
                Text(
                    text = "Sign Up",
                    color = Color.White,
                    style = MaterialTheme.typography.titleMedium,
                )
            }
        }

        Spacer(Modifier.height(24.dp))

        Text(
            text = "Already have an account? Log in",
            color = LyoPurple,
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier
                .clip(RoundedCornerShape(8.dp))
                .clickable(enabled = !loading) { nav.navigate(Routes.LOGIN) }
                .padding(8.dp),
        )
    }
}

@Composable
private fun SignupField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    keyboardType: KeyboardType,
    isPassword: Boolean = false,
    enabled: Boolean = true,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        singleLine = true,
        enabled = enabled,
        visualTransformation =
            if (isPassword) PasswordVisualTransformation()
            else VisualTransformation.None,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        shape = RoundedCornerShape(14.dp),
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = LyoPurple,
            unfocusedBorderColor = BorderColor,
            focusedLabelColor = LyoPurple,
            unfocusedLabelColor = TextSecondary,
            cursorColor = LyoPurple,
        ),
        modifier = Modifier.fillMaxWidth(),
    )
}

private fun signupFailureMessage(error: Throwable): String = when (error) {
    is HttpException -> when (error.code()) {
        400, 409, 422 -> "That email or account information cannot be used. Review it and try again."
        429 -> "Too many signup attempts. Wait a moment and try again."
        in 500..599 -> "LYO's account service is unavailable. Try again shortly."
        else -> "Account creation failed (${error.code()}). Please try again."
    }
    is IOException -> "Check your connection and try creating the account again."
    else -> error.localizedMessage ?: "Account creation could not be completed."
}
