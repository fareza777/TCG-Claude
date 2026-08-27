import 'package:flutter/services.dart';

/// Touch feedback for the moments that matter in a match.
///
/// A card game on a phone is played entirely through glass: nothing resists
/// the finger, nothing lands. Haptics are the only channel that can make a
/// summon feel placed and a hit feel taken, and Flutter ships them, so this
/// costs no dependency.
///
/// Deliberately coarse. Four levels, chosen so the hand can tell them apart
/// without looking — a phone that buzzes at every tap teaches the player to
/// stop noticing, which is worse than silence.
class Haptics {
  Haptics._();

  /// Off disables every call below. Persisted with the other audio-ish
  /// preferences, because it is the same kind of choice: feedback the player
  /// may simply not want.
  static bool enabled = true;

  /// Choosing something: a card picked up, a target selected, a tab changed.
  static void select() {
    if (!enabled) return;
    HapticFeedback.selectionClick();
  }

  /// Committing something: a card played, a turn ended.
  static void commit() {
    if (!enabled) return;
    HapticFeedback.lightImpact();
  }

  /// Force leaving or landing on the board: an attack, a unit dying.
  static void strike() {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
  }

  /// Damage to the player, and the end of the match. The heaviest cue the
  /// device has, reserved for the two things that change the game's outcome.
  static void blow() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
  }
}
