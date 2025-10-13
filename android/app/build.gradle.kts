plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.rmapp"

    // ค่ามาตรฐานจาก Flutter (เวอร์ชันของคุณ)
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.rmapp"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // หากใช้ multidex (โปรเจ็กต์ใหญ่/ปลั๊กอินเยอะ) ให้เปิดบรรทัดนี้
        // multiDexEnabled = true
    }

    buildTypes {
        release {
            // ใช้ debug keystore ชั่วคราวเพื่อให้ `flutter run --release` ทำงานได้
            signingConfig = signingConfigs.getByName("debug")
            // เปิด R8/Proguard ตามต้องการ
            isMinifyEnabled = false
            // proguardFiles(
            //     getDefaultProguardFile("proguard-android-optimize.txt"),
            //     "proguard-rules.pro"
            // )
        }
        debug {
            // ตัวเลือก debug เพิ่มเติมใส่ได้ที่นี่
        }
    }

    // ให้ Java เป็น 17
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // ให้ Kotlin เป็น 17
    kotlinOptions {
        jvmTarget = "17"
    }

    // (ถ้าเจอปัญหาไฟล์ซ้ำจากปลั๊กอินบางตัว)
    // packaging {
    //     resources {
    //         excludes += "/META-INF/{AL2.0,LGPL2.1}"
    //     }
    // }
}

// ยืนยันใช้ toolchain 17 (กันปลั๊กอินตั้งเป็น 21 เอง)
kotlin {
    jvmToolchain(17)
}

flutter {
    source = "../.."
}

dependencies {
    // ส่วนใหญ่ Flutter จัดการให้แล้ว อันนี้เผื่อบางปลั๊กอินต้องการ stdlib ชัดเจน
    implementation("org.jetbrains.kotlin:kotlin-stdlib")
    // ถ้าใช้ Firebase (ผ่าน FlutterFire) ปกติจะจัดการผ่าน pub ได้เลย ไม่ต้องเพิ่มที่นี่
    // ถ้าเจอเวอร์ชัน conflict ค่อยเพิ่ม BOM ภายหลัง เช่น:
    // implementation(platform("com.google.firebase:firebase-bom:33.5.1"))
}
