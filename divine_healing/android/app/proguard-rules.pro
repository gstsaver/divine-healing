# Release shrinking for the Play DEX-obfuscation check (25%+, flagged at 3%).
#
# R8 merges the consumer rules shipped inside each AAR (RevenueCat,
# Play Billing, Firebase, Gson, AndroidX). Those already keep the classes
# the libraries look up by reflection. The rules here name the entry points
# a missing or incomplete consumer file would strip, and silence the Play
# Core references Flutter's embedding keeps even though deferred components
# are not used.
#
# Whole-SDK keeps (`com.google.android.gms.**`, `com.google.firebase.**`)
# are intentionally absent. They would pin most of the DEX to its original
# names and the Play check would stay under 25%.

# ---- Flutter embedding (called from native code by name) ----
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Flutter references Play Core for deferred components. The dependency is
# not on the classpath, so a missing class must not fail the build.
-dontwarn com.google.android.play.core.**

# ---- App entry points named from the manifest ----
-keep class com.divinehealing.app.MainActivity { *; }
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.audio_session.** { *; }

# ---- RevenueCat (purchases_flutter) ----
# The SDK and the billing client it wraps reflect on their own model types
# and on Purchases / BillingClient. Keeping this surface is what their
# consumer rules do; it is restated so a later SDK drop does not silently
# ship a release that cannot complete a purchase.
-keep class com.revenuecat.purchases.** { *; }
-keep interface com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**

# ---- Google Play Billing ----
-keep class com.android.billingclient.api.** { *; }
-keep interface com.android.billingclient.api.** { *; }
-dontwarn com.android.billingclient.**
-keep class com.android.vending.billing.** { *; }

# ---- Firebase / GA4 ----
# firebase_analytics calls FirebaseAnalytics directly, so R8 sees that use.
# The attributes below are what Play services and Firebase read by
# reflection (generic signatures, @Keep, component metadata). The
# measurement and components packages are the ones GA4 looks up by name;
# the rest of com.google.android.gms is left for R8 to rename.
-keepattributes Signature,InnerClasses,EnclosingMethod,Exceptions,*Annotation*
-keep class com.google.firebase.analytics.** { *; }
-keep class com.google.firebase.components.** { *; }
-keep class com.google.firebase.provider.** { *; }
-keep class com.google.android.gms.measurement.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Gson decodes store and analytics payloads. Field names annotated
# @SerializedName must survive even when the enclosing class is renamed.
-keep class com.google.gson.** { *; }
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keepclassmembers class * {
    @androidx.annotation.Keep <methods>;
    @androidx.annotation.Keep <fields>;
    @androidx.annotation.Keep <init>(...);
}

# Kotlin metadata / coroutines used by Billing and RevenueCat.
-keepattributes RuntimeVisibleAnnotations,RuntimeVisibleParameterAnnotations
-keep class kotlin.Metadata { *; }
-dontwarn kotlinx.coroutines.**
-dontwarn kotlinx.serialization.**
-dontwarn org.jetbrains.annotations.**

# Parcelable creators and manifest receivers. R8 keeps a class named in
# the manifest, but not always the CREATOR field a framework parcel reads.
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
-keep class * extends android.content.BroadcastReceiver
