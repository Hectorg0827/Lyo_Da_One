# Retrofit + Gson models
-keep class com.lyo.app.data.api.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn okhttp3.**
-dontwarn retrofit2.**

# Credential Manager reaches Google Play services by reflection (Continue with Google).
-if class androidx.credentials.CredentialManager
-keep class androidx.credentials.playservices.** {
  *;
}
