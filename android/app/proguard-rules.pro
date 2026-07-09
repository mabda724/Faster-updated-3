# ══════════════════════════════════════════════════════════════════════════════
# ProGuard / R8 Obfuscation Rules — Faster Demo
# ══════════════════════════════════════════════════════════════════════════════
# These rules make the demo build difficult to reverse-engineer.
# ══════════════════════════════════════════════════════════════════════════════

# ─── Obfuscate all application code ───
-keep class !com.faster.app.demo.** { *; }

# ─── Keep Flutter engine classes (required) ───
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ─── Keep only entry points that Flutter needs ───
-keep class com.faster.app.MainActivity { *; }
-keep class com.faster.app.FlutterActivity { *; }

# ─── Remove all logging / debug info ───
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
}

-assumenosideeffects class java.io.PrintStream {
    public void println(...);
}

# ─── Obfuscate string literals ───
-optimizationpasses 5
-overloadaggressively
-repackageclasses ''

# ─── Remove source file names from stack traces ───
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable

# ─── Strip all debug metadata ───
-dontwarn
-ignorewarnings

# ─── Keep only demo package structure visible ───
-keep class com.faster.app.demo.** { *; }
