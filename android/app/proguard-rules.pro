# WorkManager creates its Room database through AndroidX Startup reflection.
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
