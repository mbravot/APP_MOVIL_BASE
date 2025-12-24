# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep all native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep all classes that might be used by reflection
-keep class * extends java.lang.Exception

# Keep all classes in your package
-keep class cl.lahornilla.tarja.** { *; }

# Keep all classes that might be used by Flutter
-keep class androidx.** { *; }
-keep class android.** { *; }

# Keep all classes that might be used by plugins
-keep class * extends io.flutter.plugin.common.PluginRegistry$Registrar
-keep class * extends io.flutter.plugin.common.PluginRegistry$ActivityResultListener

# Keep all classes that might be used by the app
-keep class * extends java.lang.Object
-keep class * extends java.lang.Exception

# Keep all classes that might be used by the app's main activity
-keep class cl.lahornilla.tarja.MainActivity { *; }
