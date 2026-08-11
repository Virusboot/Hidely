# ============================================================================
# HIDELY PRODUCTION SECURITY & PROGUARD OBFUSCATION RULES
# Prevents reverse engineering, decompiler code theft, and APK tampering
# ============================================================================

# Obfuscation & Shrinking Directives
-repackageclasses ''
-allowaccessmodification
-renamesourcefileattribute ""
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Strip native Android Log calls in release builds for security
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Flutter Core Rules
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

# Google Play Core & Deferred Components Rules
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-keep class com.google.android.play.core.** { *; }
-keep class io.flutter.app.FlutterPlayStoreSplitApplication { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

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
