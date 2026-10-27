import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

// Keep development builds usable until this app has a Firebase configuration.
if (file("google-services.json").exists()) { apply(plugin = "com.google.gms.google-services") }

// ── Build settings from outside the code ────────────────────────────────────
// Each setting below is read from a Gradle property (-PNAME=value, or
// ~/.gradle/gradle.properties) or, failing that, an environment variable of
// the same name. Nothing secret lives in this file. See android/RELEASE.md
// and docs/STAGING.md.
fun setting(name: String): String? =
    (providers.gradleProperty(name).orNull ?: providers.environmentVariable(name).orNull)
        ?.trim()
        ?.takeIf { it.isNotEmpty() }

// Retrofit needs a base URL ending in "/", and the code appends paths like
// "auth/refresh" to it directly.
fun apiBaseUrl(name: String, value: String): String {
    require(value.startsWith("https://") || value.startsWith("http://")) {
        "$name must start with https:// (got \"$value\")"
    }
    return value.trimEnd('/') + "/"
}

val productionApiUrl = "https://api.lyoai.app/"
// Release builds talk to production unless told otherwise.
val releaseApiUrl = apiBaseUrl("LYO_API_BASE_URL", setting("LYO_API_BASE_URL") ?: productionApiUrl)
// Debug and staging builds talk to staging once a staging URL is configured,
// and fall back to production (as before) until then.
val stagingApiUrl = setting("LYO_STAGING_API_BASE_URL")?.let { apiBaseUrl("LYO_STAGING_API_BASE_URL", it) }

// Release signing (Play Store upload key). Read from android/keystore.properties
// (gitignored) or environment variables; never committed. When absent, debug
// builds work as always and release builds stop with an explanation.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("keystore.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
fun signingSetting(propertyKey: String, envName: String): String? =
    (keystoreProperties.getProperty(propertyKey) ?: setting(envName))?.trim()?.takeIf { it.isNotEmpty() }

val uploadStoreFile = signingSetting("storeFile", "LYO_UPLOAD_STORE_FILE")
val uploadStorePassword = signingSetting("storePassword", "LYO_UPLOAD_STORE_PASSWORD")
val uploadKeyAlias = signingSetting("keyAlias", "LYO_UPLOAD_KEY_ALIAS")
val uploadKeyPassword = signingSetting("keyPassword", "LYO_UPLOAD_KEY_PASSWORD")
val hasReleaseSigning = listOf(uploadStoreFile, uploadStorePassword, uploadKeyAlias, uploadKeyPassword).all { it != null }

android {
    namespace = "com.lyo.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.lyo.app"
        minSdk = 26
        targetSdk = 35
        // Every Play upload needs a higher versionCode than the last one.
        // Override per build with LYO_VERSION_CODE / LYO_VERSION_NAME.
        versionCode = setting("LYO_VERSION_CODE")?.let {
            it.toIntOrNull() ?: throw GradleException("LYO_VERSION_CODE must be a whole number (got \"$it\")")
        } ?: 1
        versionName = setting("LYO_VERSION_NAME") ?: "1.0.0"
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(uploadStoreFile!!)
                storePassword = uploadStorePassword
                keyAlias = uploadKeyAlias
                keyPassword = uploadKeyPassword
            }
        }
    }

    // debug   — developer builds; staging server when configured.
    // staging — a release-like build (minified) for testers, on the staging
    //           server; signed with the debug key so anyone can install it.
    // release — the Play Store build; production server; upload key.
    buildTypes {
        debug {
            buildConfigField("String", "API_BASE_URL", "\"${stagingApiUrl ?: productionApiUrl}\"")
            buildConfigField("String", "API_ENVIRONMENT", "\"${if (stagingApiUrl != null) "staging" else "production"}\"")
        }
        create("staging") {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug")
            versionNameSuffix = "-staging"
            matchingFallbacks += listOf("release")
            buildConfigField("String", "API_BASE_URL", "\"${stagingApiUrl ?: productionApiUrl}\"")
            buildConfigField("String", "API_ENVIRONMENT", "\"${if (stagingApiUrl != null) "staging" else "production"}\"")
        }
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            if (hasReleaseSigning) signingConfig = signingConfigs.getByName("release")
            buildConfigField("String", "API_BASE_URL", "\"$releaseApiUrl\"")
            buildConfigField("String", "API_ENVIRONMENT", "\"${if (releaseApiUrl == productionApiUrl) "production" else "custom"}\"")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
        // firebase-auth (Continue with Google) is compiled by a newer Kotlin than
        // this project's 2.0.20, and the compiler refuses its metadata. Only its
        // Java API is used; drop this once the project's Kotlin is 2.2 or newer.
        freeCompilerArgs += "-Xskip-metadata-version-check"
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    sourceSets.getByName("test").resources.srcDir("../../Sources/Tests/Fixtures")
}

// A Play Store build without the upload key would be rejected; stop early
// and say what is missing instead of producing an unsigned bundle.
tasks.matching { it.name == "bundleRelease" || it.name == "assembleRelease" }.configureEach {
    doFirst {
        if (!hasReleaseSigning) {
            throw GradleException(
                "Release signing is not set up. Create android/keystore.properties or set " +
                    "LYO_UPLOAD_STORE_FILE, LYO_UPLOAD_STORE_PASSWORD, LYO_UPLOAD_KEY_ALIAS and " +
                    "LYO_UPLOAD_KEY_PASSWORD. Step-by-step: android/RELEASE.md"
            )
        }
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.19.0"))
    implementation("com.google.firebase:firebase-messaging")
    // Continue with Google: Credential Manager picks the account, Firebase turns
    // it into the ID token that POST /auth/firebase accepts.
    implementation("com.google.firebase:firebase-auth")
    implementation("androidx.credentials:credentials:1.3.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.3.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.8.1")
    val composeBom = platform("androidx.compose:compose-bom:2024.09.02")
    implementation(composeBom)

    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.6")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.6")
    // Screen state that survives opening a detail page (Community map, filters).
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.6")
    implementation("androidx.activity:activity-compose:1.9.2")

    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.navigation:navigation-compose:2.8.1")

    implementation("com.squareup.retrofit2:retrofit:2.11.0")
    implementation("com.squareup.retrofit2:converter-gson:2.11.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.google.code.gson:gson:2.11.0")

    implementation("io.coil-kt:coil-compose:2.7.0")

    // Decode and prebuffer adjacent Discover reels; VideoView cannot do this.
    implementation("androidx.media3:media3-exoplayer:1.4.1")
    implementation("androidx.media3:media3-ui:1.4.1")

    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.1")
}
