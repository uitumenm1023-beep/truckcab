# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
# Keep app classes
-keep class com.NEPTUNE.truckcab.** { *; }
# Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
# Prevent stripping of important annotations
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
