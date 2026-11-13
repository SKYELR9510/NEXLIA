plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nexlia.phone"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.nexlia.phone"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Android 10: mínimo para RoleManager (rol de marcador) y CallScreeningService actual.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Firma de las releases publicadas en GitHub. El flujo de publicación escribe
    // android/app/nexlia.keystore desde los secretos del repositorio (nunca se versiona).
    // Sin ese archivo (compilación local) se firma con la clave debug, igual que antes:
    // ese APK no se puede instalar encima de una release oficial.
    val nexliaKeystore = file("nexlia.keystore")
    val nexliaKeystorePass: String? = System.getenv("KEYSTORE_PASS")
    signingConfigs {
        create("nexlia") {
            storeFile = nexliaKeystore
            storePassword = nexliaKeystorePass
            keyAlias = "nexlia"
            keyPassword = nexliaKeystorePass
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (nexliaKeystore.exists() && nexliaKeystorePass != null) {
                    signingConfigs.getByName("nexlia")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }

    // El código Kotlin y sus pruebas viven en android/kotlin y android/test
    // (ubicación histórica del repositorio).
    sourceSets {
        getByName("main") {
            java.srcDir("../kotlin")
        }
        getByName("test") {
            java.srcDir("../test")
        }
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
