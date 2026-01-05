// Gradle init script для принудительной замены Maven репозиториев
allprojects {
    buildscript {
        repositories {
            // Очищаем существующие репозитории
            all { remove(this) }
            
            google()
            maven { url = uri("https://maven.aliyun.com/repository/public") }
            maven { url = uri("https://maven.aliyun.com/repository/google") }
            maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
            maven { url = uri("https://jitpack.io") }
            mavenCentral()
        }
    }
    
    repositories {
        // Очищаем существующие репозитории
        all { remove(this) }
        
        google()
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        maven { url = uri("https://jitpack.io") }
        mavenCentral()
    }
}

