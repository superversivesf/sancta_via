# Sancta Via Bible - ProGuard Rules

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.** { *; }

# Preserve the line number information for debugging stack traces
-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to hide the original source file name
#-renamesourcefileattribute SourceFile

# Keep native methods
-keepclassmembers class * {
    native <methods>;
}

# Keep custom serialization/deserialization classes if any
-keep class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}


# App-specific rules
-keep class net.superversive.bible_reading_app.** { *; }

# Flutter's embedding references Play Core's deferred-components API, which this
# app does not depend on. The io.flutter.** keeps above keep the referencing
# classes alive, so R8 reports them as fatal missing classes.
-dontwarn com.google.android.play.core.**
