# Google ML Kit Text Recognition: plugin mereferensikan model non-Latin
# (Tiongkok, Devanagari, Jepang, Korea) yang sengaja tidak disertakan agar APK
# tetap kecil. Tanpa aturan ini, R8 gagal saat `flutter build apk --release`.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
