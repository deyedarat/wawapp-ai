import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.wawapp.driver"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        // Support for Java 8+ APIs
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.wawapp.driver"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
		
		testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    val hasKeystore = keystorePropertiesFile.exists()
    if (hasKeystore) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    if (hasKeystore) {
        signingConfigs {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (hasKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring for flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // Firebase Messaging — required by MyFirebaseMessagingService.kt
    implementation("com.google.firebase:firebase-messaging:24.1.0")

    // Firebase Firestore — required by MyFirebaseMessagingService.kt for order status verification
    implementation("com.google.firebase:firebase-firestore:25.1.1")

    // Firebase Auth — required by MyFirebaseMessagingService.kt for driver UID in rejection writes
    implementation("com.google.firebase:firebase-auth:23.1.0")

    // Firebase Functions — required by MyFirebaseMessagingService.kt for rejectOffer call
    implementation("com.google.firebase:firebase-functions:21.1.0")

    // CRITICAL FIX: Force upgrade play-services-auth to fix SignInHubActivity NullPointerException
    // Root cause: Firebase Auth pulls in play-services-auth:20.7.0 transitively
    // Version 20.7.0 has known NPE issues in SignInHubActivity.onCreate() when Intent extras are null
    // Version 21.2.0 has improved null safety and error handling
    // See: SIGNIN_HUB_CRASH_RCA.md for full analysis
    implementation("com.google.android.gms:play-services-auth:21.2.0")

    // CardView for activity_full_screen_notification.xml
    implementation("androidx.cardview:cardview:1.0.0")

    // ProcessLifecycleOwner — used by MyFirebaseMessagingService to detect foreground
    // state using the same mechanism as Firebase SDK (aligns isAppInForeground() with onMessage)
    implementation("androidx.lifecycle:lifecycle-process:2.8.7")

    // ─── AndroidX Test: Force versions in main configurations ───────────────────
    // The integration_test Flutter plugin declares open-ended ranges (1.2+) which
    // resolve to 1.2.0 in debugRuntimeClasspath. AGP consistent resolution then
    // forces {strictly 1.2.0} onto androidTest configurations, conflicting with
    // the newer versions we need. Fix: declare constraints so the main classpath
    // resolves to the same versions we use in androidTest.
    constraints {
        implementation("androidx.test:runner:1.6.2")
        implementation("androidx.test:rules:1.6.1")
        implementation("androidx.test:monitor:1.7.2")
        implementation("androidx.test:core:1.6.1")
        implementation("androidx.test.ext:junit:1.2.1")
        implementation("androidx.test.services:storage:1.5.0")
        implementation("androidx.test.espresso:espresso-core:3.6.1")
    }

    // ─── Instrumentation Test Dependencies ──────────────────────────────────────
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:rules:1.6.1")
    androidTestImplementation("androidx.test:core:1.6.1")
}
