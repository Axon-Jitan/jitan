# Release builds are shrunk (R8). WorkManager, used by the background location
# plugins, creates its Room database by reflection (WorkDatabase_Impl()); without
# this rule the constructor is removed and the app stops at start
# (NoSuchMethodException, found 2026-11-13 in the first release APK).
-keep class * extends androidx.room.RoomDatabase { <init>(); }
