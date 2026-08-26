import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_config.dart';

/// One row of the Proving Gauntlet standings.
class ArenaStanding {
  final String name;
  final int bestWins;
  final int bestGold;
  final int runs;
  final bool isYou;

  const ArenaStanding({
    required this.name,
    required this.bestWins,
    required this.bestGold,
    required this.runs,
    required this.isYou,
  });
}

/// Arena standings and the ladder, backed by the project's own Supabase.
///
/// Signed-in players only, by design: a device id is trivially forged, and a
/// leaderboard nobody trusts is worse than no leaderboard. Guests keep their
/// local best and simply do not appear until they link an account.
///
/// Every call fails soft. A leaderboard that is unreachable must cost the
/// player nothing — their run still paid out from local storage.
class LeaderboardService {
  LeaderboardService._();
  static final LeaderboardService instance = LeaderboardService._();

  SupabaseClient? get _client {
    if (!BackendConfig.hasBackend) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  User? get _user => _client?.auth.currentUser;

  /// True when this player can appear on the board at all.
  bool get canRank => _user != null;

  String get _displayName {
    final metadata = _user?.userMetadata;
    final name = (metadata?['full_name'] ?? metadata?['name']) as String?;
    final email = _user?.email;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'Caller';
  }

  /// Record a finished run. The database keeps the better of the two, so
  /// submitting a worse run is harmless and retries are safe.
  Future<void> submitArenaRun({required int wins, required int gold}) async {
    final client = _client;
    if (client == null || _user == null) return;
    try {
      await client.rpc('submit_arena_run', params: {
        'p_display_name': _displayName,
        'p_wins': wins,
        'p_gold': gold,
      });
    } catch (error) {
      debugPrint('Arena standing not submitted: $error');
    }
  }

  /// The top of the board, with the player's own row marked.
  Future<List<ArenaStanding>> topArena({int limit = 50}) async {
    final client = _client;
    if (client == null) return const [];
    try {
      final rows = await client
          .from('arena_leaderboard')
          .select('user_id, display_name, best_wins, best_gold, runs')
          .order('best_wins', ascending: false)
          .order('best_gold', ascending: false)
          .limit(limit);
      final me = _user?.id;
      return [
        for (final row in rows as List)
          ArenaStanding(
            name: (row['display_name'] as String?) ?? 'Caller',
            bestWins: (row['best_wins'] as num?)?.toInt() ?? 0,
            bestGold: (row['best_gold'] as num?)?.toInt() ?? 0,
            runs: (row['runs'] as num?)?.toInt() ?? 0,
            isYou: me != null && row['user_id'] == me,
          ),
      ];
    } catch (error) {
      debugPrint('Arena standings unavailable: $error');
      return const [];
    }
  }

  /// Update the ladder after a PvP match.
  ///
  /// Deliberately additive: this reads and writes one rating row and never
  /// touches the match flow or the PvP server, which are working and are not
  /// mine to disturb.
  ///
  /// The step is Elo against a fixed 1000-rated field rather than the real
  /// opponent, because the client is not told the opponent's rating and must
  /// not be trusted with it. It is a ladder, not a rating system — good enough
  /// to give winning a reason, honest about what it is.
  Future<void> recordPvpResult({required bool won}) async {
    final client = _client;
    final user = _user;
    if (client == null || user == null) return;
    try {
      final existing = await client
          .from('pvp_ratings')
          .select('rating, wins, losses, streak')
          .eq('user_id', user.id)
          .maybeSingle();

      final rating = (existing?['rating'] as num?)?.toInt() ?? 1000;
      final wins = (existing?['wins'] as num?)?.toInt() ?? 0;
      final losses = (existing?['losses'] as num?)?.toInt() ?? 0;
      final streak = (existing?['streak'] as num?)?.toInt() ?? 0;

      // A win high on the ladder is worth less than a win climbing out of the
      // basement, so the curve flattens as rating rises.
      final step = won ? (24 - (rating - 1000) ~/ 100).clamp(8, 32) : -16;
      final next = (rating + step).clamp(0, 4000);

      await client.from('pvp_ratings').upsert({
        'user_id': user.id,
        'display_name': _displayName,
        'rating': next,
        'wins': wins + (won ? 1 : 0),
        'losses': losses + (won ? 0 : 1),
        'streak': won ? (streak < 0 ? 1 : streak + 1) : (streak > 0 ? -1 : streak - 1),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (error) {
      debugPrint('Ladder not updated: $error');
    }
  }
}
