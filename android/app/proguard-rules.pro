# ─── Flutter engine ───────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**
-keep class io.flutter.plugins.** { *; }

# ─── Kotlin reflection (used by Supabase / RevenueCat) ───────────────────────
-keep class kotlin.** { *; }
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
-dontwarn kotlin.**

# ─── OkHttp / Okio (Supabase networking) ─────────────────────────────────────
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# ─── Supabase (realtime WebSocket, GoTrue auth) ───────────────────────────────
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# ─── RevenueCat ───────────────────────────────────────────────────────────────
-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**

# ─── Google Fonts (network font loading) ─────────────────────────────────────
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ─── Gson / JSON serialisation ────────────────────────────────────────────────
-keepattributes Signature
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# ─── Keep R8 from stripping data classes used in reflection ───────────────────
-keepclassmembers class * {
    @kotlinx.serialization.SerialName <fields>;
}
