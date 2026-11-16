
# flutter_local_notifications serialises notification details through Gson
# for the boot receiver; renaming/obfuscating those classes breaks alarm
# rescheduling after a device reboot (R8 is on by default in Flutter release builds).
-keep class com.dexterous.flutterlocalnotifications.** { *; }
