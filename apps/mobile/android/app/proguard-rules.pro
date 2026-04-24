# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep models and data classes (เพื่อไม่ให้ JSON parsing พัง)
-keep class com.xparq.xparq_app.models.** { *; }
-keepclassmembers class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Flutter Background Service
-keep class id.flutter.flutter_background_service.** { *; }

# Firebase / Google Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
