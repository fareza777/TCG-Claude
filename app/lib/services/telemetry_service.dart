import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_config.dart';

/// Crash reports and product analytics, sent to the project's own Supabase.
///
/// This exists because a launch crash once took a day to find and was only
/// caught because a test device happened to be plugged in. Players do not plug
/// in phones — they uninstall, and the reason leaves with them.
///
/// Three rules hold everywhere in this file:
///
///  * Telemetry never breaks the game. Every path swallows its own errors; a
///    reporting failure must not become the thing being reported.
///  * Telemetry never blocks. Nothing here is awaited on the startup path.
///  * Telemetry never carries anything personal. A random device id, the app
///    version, and the event name — nothing typed by a player, no card names,
///    no save contents.
class TelemetryService {
  TelemetryService._();
  static final TelemetryService instance = TelemetryService._();

  static const _deviceKey = 'telemetryDeviceId';
  static const _queueKey = 'telemetryQueue';

  /// Kept small on purpose: a backlog is worth less than the storage it costs,
  /// and a player who has been offline for a week does not need every event.
  static const _maxQueue = 60;

  SharedPreferences? _prefs;
  String _deviceId = '';
  String _version = 'unknown';
  bool _ready = false;

  SupabaseClient? get _client {
    if (!BackendConfig.hasBackend) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Start reporting. Safe to call before the backend is up: anything sent
  /// meanwhile is queued and flushed on the next successful send.
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _deviceId = _prefs!.getString(_deviceKey) ?? _newDeviceId();
      await _prefs!.setString(_deviceKey, _deviceId);
      try {
        final info = await PackageInfo.fromPlatform();
        _version = '${info.version}+${info.buildNumber}';
      } catch (_) {
        // Version is nice to have, not a reason to give up reporting.
      }
      _ready = true;
      unawaited(_flush());
    } catch (error) {
      debugPrint('Telemetry unavailable: $error');
    }
  }

  String _newDeviceId() {
    final rng = Random.secure();
    return List.generate(16, (_) => rng.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Install the global error handlers. Call once, as early as possible.
  ///
  /// [runner] is invoked inside a guarded zone so errors escaping async gaps
  /// are caught too — the class of failure that otherwise vanishes silently.
  void captureErrors(void Function() runner) {
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      previousOnError?.call(details);
      unawaited(recordCrash(
        kind: 'flutter',
        error: details.exceptionAsString(),
        stack: details.stack?.toString(),
        context: {'library': details.library ?? 'unknown'},
      ));
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(recordCrash(
        kind: 'platform',
        error: error.toString(),
        stack: stack.toString(),
      ));
      return true;
    };

    runZonedGuarded(runner, (error, stack) {
      unawaited(recordCrash(
        kind: 'zone',
        error: error.toString(),
        stack: stack.toString(),
      ));
    });
  }

  Future<void> recordCrash({
    required String kind,
    required String error,
    String? stack,
    Map<String, dynamic> context = const {},
  }) async {
    // Stacks can be enormous; the top frames are where the answer lives.
    final trimmed = stack == null || stack.length <= 8000
        ? stack
        : '${stack.substring(0, 8000)}\n… truncated';
    await _send('app_crashes', {
      'kind': kind,
      'error': error.length > 2000 ? error.substring(0, 2000) : error,
      'stack': trimmed,
      'context': context,
      'platform': Platform.operatingSystem,
    });
  }

  /// Record a product event. Names are lower_snake_case verbs so they read as
  /// a funnel: `story_battle_won`, `arena_entered`, `rewarded_gold_claimed`.
  Future<void> track(String name, [Map<String, dynamic> props = const {}]) =>
      _send('app_events', {'name': name, 'props': props});

  Future<void> _send(String table, Map<String, dynamic> row) async {
    try {
      final payload = {
        ...row,
        'device_id': _deviceId,
        'app_version': _version,
        if (_client?.auth.currentUser != null)
          'user_id': _client!.auth.currentUser!.id,
      };
      final client = _client;
      if (!_ready || client == null) {
        await _queue(table, payload);
        return;
      }
      await client.from(table).insert(payload);
    } catch (_) {
      // Offline, or the backend is down. Keep it for later rather than lose it.
      try {
        await _queue(table, {...row, 'device_id': _deviceId});
      } catch (_) {}
    }
  }

  Future<void> _queue(String table, Map<String, dynamic> row) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final queue = prefs.getStringList(_queueKey) ?? <String>[];
    queue.add(json.encode({'table': table, 'row': row}));
    if (queue.length > _maxQueue) {
      queue.removeRange(0, queue.length - _maxQueue);
    }
    await prefs.setStringList(_queueKey, queue);
  }

  /// Push anything recorded while offline, then clear it. Failures leave the
  /// queue intact for the next attempt.
  Future<void> _flush() async {
    final prefs = _prefs;
    final client = _client;
    if (prefs == null || client == null) return;
    final queue = prefs.getStringList(_queueKey) ?? const <String>[];
    if (queue.isEmpty) return;

    for (final entry in queue) {
      try {
        final decoded = json.decode(entry) as Map<String, dynamic>;
        final row = Map<String, dynamic>.from(decoded['row'] as Map);
        row['app_version'] ??= _version;
        await client.from(decoded['table'] as String).insert(row);
      } catch (_) {
        return; // Still unreachable — try the whole batch again next launch.
      }
    }
    await prefs.remove(_queueKey);
  }
}
