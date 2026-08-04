import '../model/enums.dart';
import '../model/game_state.dart';

/// The server-side stage around the pure rules engine.
enum PvpStage {
  waitingForReady,
  mulligan,
  main,
  attackDeclaration,
  blockDeclaration,
  chainPriority,
  finished,
}

/// Durable state that is needed to resume an online match in addition to the
/// card game's immutable [GameState].
class PvpSession {
  final GameState game;
  final PvpStage stage;
  final Map<PlayerId, bool> ready;
  final Map<PlayerId, bool> mulliganUsed;
  final PlayerId priority;
  final int passCount;
  final PvpStage resumeStage;
  final List<int> pendingAttackers;
  final int revision;

  const PvpSession({
    required this.game,
    required this.stage,
    required this.ready,
    required this.mulliganUsed,
    required this.priority,
    required this.passCount,
    required this.resumeStage,
    required this.pendingAttackers,
    required this.revision,
  });

  PvpSession copyWith({
    GameState? game,
    PvpStage? stage,
    Map<PlayerId, bool>? ready,
    Map<PlayerId, bool>? mulliganUsed,
    PlayerId? priority,
    int? passCount,
    PvpStage? resumeStage,
    List<int>? pendingAttackers,
    int? revision,
  }) =>
      PvpSession(
        game: game ?? this.game,
        stage: stage ?? this.stage,
        ready: ready ?? this.ready,
        mulliganUsed: mulliganUsed ?? this.mulliganUsed,
        priority: priority ?? this.priority,
        passCount: passCount ?? this.passCount,
        resumeStage: resumeStage ?? this.resumeStage,
        pendingAttackers: pendingAttackers ?? this.pendingAttackers,
        revision: revision ?? this.revision,
      );

  bool isReady(PlayerId player) => ready[player] ?? false;

  bool usedMulligan(PlayerId player) => mulliganUsed[player] ?? false;
}
