import 'package:shardfall_engine/shardfall_engine.dart';

/// How long each decision window lasts, and what happens when it runs out.
///
/// A timer that only counts is decoration: an opponent who stalls simply stalls
/// with a number on screen. So the deadline is decided and enforced by the
/// server. A client cannot be trusted with it — a player who force-quits would
/// never pass their own turn, and a modified client could ignore it outright.
///
/// The budgets are per decision, not per turn, so thinking hard about blockers
/// does not eat the time to then play a card.
abstract final class TurnClock {
  static const waitingForReady = Duration(seconds: 60);
  static const mulligan = Duration(seconds: 45);
  static const main = Duration(seconds: 75);
  static const attackDeclaration = Duration(seconds: 45);
  static const blockDeclaration = Duration(seconds: 45);
  static const chainPriority = Duration(seconds: 30);

  /// A small allowance for the round trip, so a player who answers just in time
  /// is not overruled by their own network latency.
  static const grace = Duration(seconds: 3);

  static Duration budgetFor(PvpStage stage) {
    switch (stage) {
      case PvpStage.waitingForReady:
        return waitingForReady;
      case PvpStage.mulligan:
        return mulligan;
      case PvpStage.main:
        return main;
      case PvpStage.attackDeclaration:
        return attackDeclaration;
      case PvpStage.blockDeclaration:
        return blockDeclaration;
      case PvpStage.chainPriority:
        return chainPriority;
      case PvpStage.finished:
        return Duration.zero;
    }
  }

  static DateTime? deadlineFor(PvpSession session, DateTime now) {
    if (session.stage == PvpStage.finished) return null;
    return now.add(budgetFor(session.stage)).add(grace);
  }

  /// Who owes the decision the clock is running on.
  ///
  /// Returns every player still holding things up — during the ready and
  /// mulligan windows that can be both of them at once.
  static List<PlayerId> owedBy(PvpSession session) {
    switch (session.stage) {
      case PvpStage.waitingForReady:
      case PvpStage.mulligan:
        return [
          for (final seat in PlayerId.values)
            if (!session.isReady(seat)) seat,
        ];
      case PvpStage.main:
      case PvpStage.attackDeclaration:
        return [session.game.activePlayer];
      case PvpStage.blockDeclaration:
        return [_other(session.game.activePlayer)];
      case PvpStage.chainPriority:
        return [session.priority];
      case PvpStage.finished:
        return const [];
    }
  }

  /// The command applied on their behalf when the clock runs out.
  ///
  /// Always the most passive legal move: confirm, decline to attack, decline to
  /// block, yield priority. Running out of time never spends a card or commits
  /// an attack the player did not choose.
  static PvpCommandType? forfeitActionFor(PvpStage stage) {
    switch (stage) {
      case PvpStage.waitingForReady:
      case PvpStage.mulligan:
        return PvpCommandType.ready;
      case PvpStage.main:
        return PvpCommandType.nextPhase;
      case PvpStage.attackDeclaration:
        return PvpCommandType.declareAttackers;
      case PvpStage.blockDeclaration:
        return PvpCommandType.declareBlocks;
      case PvpStage.chainPriority:
        return PvpCommandType.passPriority;
      case PvpStage.finished:
        return null;
    }
  }

  static Map<String, dynamic> forfeitPayloadFor(PvpStage stage) {
    switch (stage) {
      case PvpStage.attackDeclaration:
        return const {'attackerIds': <int>[]};
      case PvpStage.blockDeclaration:
        return const {'blocks': <Map<String, dynamic>>[]};
      default:
        return const {};
    }
  }

  static PlayerId _other(PlayerId id) =>
      id == PlayerId.p1 ? PlayerId.p2 : PlayerId.p1;
}
