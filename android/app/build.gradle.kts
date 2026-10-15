import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Credenciais de assinatura do release. O arquivo NÃO é versionado (está no
// android/.gitignore) — localmente você o cria à mão, e no Codemagic o próprio
// build gera a partir das variáveis CM_KEYSTORE_* (ver codemagic.yaml).
//
// De propósito não existe fallback pra debug key aqui: se o arquivo faltar, o
// build de release falha em vez de gerar silenciosamente um APK com assinatura
// diferente — que é exatamente o que causava o "conflito de pacote" ao
// atualizar o app instalado.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.example.creaturesrogue"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.creaturesrogue"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // google_mobile_ads exige 24.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Só existe quando key.properties existe. O erro pra quando ele falta
        // fica no buildTypes.release abaixo, restrito ao build de release —
        // assim `flutter run` em debug continua funcionando sem keystore.
        if (keystorePropertiesFile.exists()) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // A checagem é presa às tasks de release: os blocos do Gradle são
            // avaliados em toda invocação, inclusive `flutter run` em debug, que
            // não precisa de keystore nenhuma.
            val buildingRelease = gradle.startParameter.taskNames.any {
                it.contains("release", ignoreCase = true)
            }
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else if (buildingRelease) {
                throw GradleException(
                    "android/key.properties não encontrado. Build de release precisa da " +
                        "keystore própria — sem ela o APK sairia com assinatura instável e o " +
                        "update sobre o app instalado falharia com conflito de pacote. Crie o " +
                        "arquivo com storeFile/storePassword/keyAlias/keyPassword."
                )
            }
        }
    }
}

flutter {
    source = "../.."
}
