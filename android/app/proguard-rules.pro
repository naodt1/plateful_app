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

# ─── Firebase (Auth + Firestore) ──────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.firestore.** { *; }
-dontwarn com.google.firestore.**
# Firestore transport: gRPC + protobuf (reflection-heavy)
-keep class io.grpc.** { *; }
-dontwarn io.grpc.**
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**
# Google Sign-In credential APIs
-keep class com.google.android.gms.auth.** { *; }
-dontwarn com.google.android.gms.auth.**

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
