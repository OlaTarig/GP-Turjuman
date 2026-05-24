# Suppress warnings for annotation processor classes not needed at runtime
-dontwarn javax.lang.model.SourceVersion
-dontwarn javax.lang.model.element.Element
-dontwarn javax.lang.model.element.ElementKind
-dontwarn javax.lang.model.type.TypeMirror
-dontwarn javax.lang.model.type.TypeVisitor
-dontwarn javax.lang.model.util.SimpleTypeVisitor8

# ── Zego Express Engine ───────────────────────────────────────────────────────
# Zego uses JNI and reflection — all classes must be kept with original names
-keep class im.zego.** { *; }
-keep interface im.zego.** { *; }
-dontwarn im.zego.**

# ── TFLite ────────────────────────────────────────────────────────────────────
-keep class org.tensorflow.** { *; }
-keep interface org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

# ── MediaPipe ─────────────────────────────────────────────────────────────────
-keep class com.google.mediapipe.** { *; }
-keep interface com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# ── Google Speech (gRPC / protobuf) ──────────────────────────────────────────
-keep class com.google.cloud.speech.** { *; }
-keep class io.grpc.** { *; }
-keep class com.google.protobuf.** { *; }
-dontwarn io.grpc.**
-dontwarn com.google.protobuf.**

# ── Firebase ──────────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep interface com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
