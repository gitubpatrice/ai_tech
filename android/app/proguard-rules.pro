# AI Tech — Règles ProGuard / R8
# Conservation des points d'entrée Flutter et plugins critiques.

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Kotlin
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

# AndroidX
-dontwarn androidx.**

# MediaPipe (flutter_gemma) — appels JNI vers les libs natives, classes
# référencées dynamiquement, ne pas obfusquer/stripper.
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# flutter_gemma plugin
-keep class dev.flutterberlin.flutter_gemma.** { *; }
-dontwarn dev.flutterberlin.flutter_gemma.**

# background_downloader (transitive de flutter_gemma — non utilisé mais
# conservé pour éviter un crash si une classe est touchée par réflexion).
-keep class com.bbflight.background_downloader.** { *; }
-dontwarn com.bbflight.background_downloader.**

# flutter_secure_storage — Keystore-bound key.
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# pointycastle (AES-GCM côté Dart, pas direct ProGuard, mais ceinture)
-dontwarn org.bouncycastle.**

# Préserver les attributs utiles aux stack traces et exceptions Dart.
-keepattributes Exceptions, InnerClasses, Signature, Deprecated, SourceFile, LineNumberTable, *Annotation*
