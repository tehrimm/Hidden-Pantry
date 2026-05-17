# TensorFlow Lite keep rules
-keep class org.tensorflow.lite.** { *; }
-keep interface org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# GPU Delegate rules
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.gpu.**
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options

# Also keep the Google Play Services TFLite if used
-keep class com.google.android.gms.tflite.** { *; }
-dontwarn com.google.android.gms.tflite.**

# Google Sign-In & Firebase rules
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**
-dontwarn com.google.mlkit.vision.text.**
