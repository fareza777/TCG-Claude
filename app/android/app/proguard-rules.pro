# Room looks up its generated implementations by literal class name at runtime
# (Class.forName on "<Database>_Impl"), so R8 renaming them turns startup into a
# crash rather than a missing feature.
#
# This bit us for real: WorkManager's WorkDatabase is built by
# androidx.startup.InitializationProvider before any Flutter code runs, so a
# renamed WorkDatabase_Impl killed the process on launch with
# "Failed to create an instance of androidx.work.impl.WorkDatabase" — long
# before MainActivity or main() existed to catch anything.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keepnames class * extends androidx.room.RoomDatabase
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-dontwarn androidx.room.paging.**

# androidx.startup discovers initialisers by name from the merged manifest.
-keep class * implements androidx.startup.Initializer { *; }
-keep class androidx.startup.InitializationProvider { *; }

# Play Billing and the ads SDK both cross the JNI/reflection boundary.
-keep class com.android.vending.billing.** { *; }
-dontwarn com.google.android.gms.**
