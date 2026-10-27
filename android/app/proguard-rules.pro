# Retrofit + Gson models. Gson reads fields by name, so minified (release
# and staging) builds must keep every class it parses: the API DTOs, the AI
# Classroom wire models (ClassroomWireModels.kt, read with ApiClient.gson),
# and the A2UI messages.
-keep class com.lyo.app.data.api.** { *; }
-keep class com.lyo.app.data.classroom.** { *; }
-keep class com.lyo.app.data.a2ui.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn okhttp3.**
-dontwarn retrofit2.**

# Credential Manager reaches Google Play services by reflection (Continue with Google).
-if class androidx.credentials.CredentialManager
-keep class androidx.credentials.playservices.** {
  *;
}
