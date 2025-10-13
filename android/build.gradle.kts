// D:\RMapp\ProjectRMApp\android\build.gradle.kts
// ไฟล์นี้ใช้ Kotlin DSL (.kts)

import org.gradle.api.tasks.Delete
import org.gradle.api.tasks.compile.JavaCompile
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

// 1. ประกาศตัวแปร (ใช้ val)
val kotlin_version = "1.9.0" 

// 2. buildscript block (ต้องอยู่ด้านบนสุด และใช้ไวยากรณ์ Kotlin DSL ที่ถูกต้อง)
buildscript {
    // ⚠️ ประกาศตัวแปรไว้ที่นี่
    val kotlin_version = "1.9.0" 

    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.4.1") 
        
        // ตอนนี้ kotlin_version ถูกรู้จักแล้ว
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version") 
    }
}


// 3. กำหนดค่า repositories ทั่วไป
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 4. บังคับทุก subproject ให้ใช้ JVM 17 (ตามโค้ดที่คุณต้องการ)
subprojects {
    tasks.withType<JavaCompile>().configureEach {
        // กำหนด Java Target เป็น 17
        options.release.set(17)
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }

    tasks.withType<KotlinCompile>().configureEach {
        // กำหนด Kotlin Target เป็น 17
        kotlinOptions.jvmTarget = "17"
    }
}

// 5. task clean ตามธรรมเนียม
tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}