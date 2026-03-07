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
