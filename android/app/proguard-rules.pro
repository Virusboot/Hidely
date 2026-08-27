# ============================================================================
# HIDELY PRODUCTION SECURITY & PROGUARD OBFUSCATION RULES
# Robust ProGuard rules keeping Flutter, JNI, Plugins, and Native Channels safe
# ============================================================================

# Obfuscation & Keep Directives
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,Exceptions

# Strip native Android Log calls in release builds for security
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Flutter Core Engine & Embedding Rules (CRITICAL for TextInput, Navigation, Platform Channels)
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.embedding.engine.plugins.** { *; }
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.plugin.editing.** { *; }
-keep class io.flutter.provider.** { *; }

# Keep all Flutter Plugin Native Classes
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Isar Database Rules
-keep class io.isar.** { *; }
-dontwarn io.isar.**

# Google Play Services & Maps Rules
-keep class com.google.android.gms.maps.** { *; }
-keep interface com.google.android.gms.maps.** { *; }
-keep class com.google.android.gms.location.** { *; }
-keep class com.google.android.gms.** { *; }

# Google Play Core & Deferred Components Rules
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-keep class com.google.android.play.core.** { *; }
-keep class io.flutter.app.FlutterPlayStoreSplitApplication { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# Zego Cloud Rules
-keep class im.zego.** { *; }
-keep class com.zego.** { *; }
-dontwarn im.zego.**
-dontwarn com.zego.**
-dontwarn com.heytap.**
-dontwarn com.huawei.**
-dontwarn com.vivo.**
-dontwarn com.xiaomi.**
-dontwarn java.beans.**
-dontwarn org.conscrypt.**
-dontwarn com.fasterxml.jackson.**
-dontwarn okhttp3.internal.platform.**

# Keep Native JNI Methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Serializable & Model Classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

