package com.shardfall.shardfall

import io.flutter.embedding.android.FlutterFragmentActivity

/// AdMob's UMP consent form and AdWidget both require a FragmentActivity.
/// FlutterActivity crashes on launch once ads/consent initialize.
class MainActivity : FlutterFragmentActivity()
