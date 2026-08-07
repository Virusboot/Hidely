# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }

# Google Play Services & Maps Rules
-keep class com.google.android.gms.maps.** { *; }
-keep interface com.google.android.gms.maps.** { *; }
-keep class com.google.android.gms.location.** { *; }

# Zego Cloud Rules
-keep class im.zego.** { *; }
-dontwarn im.zego.**
-dontwarn com.heytap.**
-dontwarn com.huawei.**
-dontwarn com.vivo.**
-dontwarn com.xiaomi.**
-dontwarn java.beans.**
-dontwarn org.conscrypt.**
-dontwarn com.fasterxml.jackson.**
-dontwarn okhttp3.internal.platform.**
