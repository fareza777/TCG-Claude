import 'package:shardfall_engine/shardfall_engine.dart';

import 'pvp_models.dart';

/// Rebuilds an engine [GameState] from a server [PvpProjection].
///
/// This exists so the online match can be drawn by the same battle screen as
/// the single-player duel, without that screen — or anything else in the PvE
/// path — being modified.
///
/// Two things make the mapping more than a field copy:
///
///  * **The viewer always becomes p1.** The duel screen is written around
///    `human = PlayerId.p1`. In PvP you may be seated as p2, so seats are
///    swapped when needed and every id that names a seat is swapped with them.
///    Card instance ids are global, so commands still address the right card.
///  * **Hidden cards get placeholders.** The server deliberately withholds the
///    opponent's hand and both libraries, sending only counts. Those become
///    face-down filler instances so the screen can draw the right number of
///    card backs. [hiddenCard] is never a real card, so a rendering mistake
///    shows an obvious blank rather than leaking a real one.
abstract final class PvpGameState {
  /// Filler for a card the server did not reveal.
  static const hiddenCard = CardDef(
    id: '__hidden__',
    name: '',
    dominions: <Dominion>[],
    type: CardType.unit,
  );

  static GameState fromProjection(
    PvpProjection projection,
    CardLibrary library,
  ) {
    // The viewer is drawn as p1 no matter which seat the server gave them.
    final swap = projection.viewer == PlayerId.p2;
    PlayerId seat(PlayerId id) => swap ? _other(id) : id;

    final self = _playerState(
      projection.self,
      seat: PlayerId.p1,
      library: library,
      revealed: true,
    );
    final opponent = _playerState(
      projection.opponent,
      seat: PlayerId.p2,
      library: library,
      revealed: false,
    );

    return GameState(
      p1: self,
      p2: opponent,
      activePlayer: seat(projection.activePlayer),
      phase: projection.phase,
      turnNumber: projection.turnNumber,
      // Only ever grows, and only used by the engine when creating cards. The
      // server owns creation, so any value above the visible ids is safe.
      nextInstanceId: _highestInstanceId(projection) + 1,
      // The client never simulates, so the seed is inert here.
      rngSeed: 0,
      winner: projection.winner == null ? null : seat(projection.winner!),
      chain: const [],
      firstPlayer: PlayerId.p1,
    );
  }

  static PlayerState _playerState(
    PvpPlayerView view, {
    required PlayerId seat,
    required CardLibrary library,
    required bool revealed,
  }) {
    final hand = revealed
        ? [for (final card in view.hand) _instance(card, seat, library)]
        : _hidden(count: view.handCount, seat: seat, offset: _handIdBase);

    return PlayerState(
      id: seat,
      health: view.health,
      deck: _hidden(count: view.deckCount, seat: seat, offset: _deckIdBase),
      hand: hand,
      arena: [for (final card in view.arena) _instance(card, seat, library)],
      ruins: _hidden(count: view.ruinsCount, seat: seat, offset: _ruinsIdBase),
      voidZone: _hidden(count: view.voidCount, seat: seat, offset: _voidIdBase),
      aetherPool: view.aetherPool,
      playedWellspringThisTurn: view.playedWellspringThisTurn,
      usedAttuneThisTurn: view.usedAttuneThisTurn,
    );
  }

  static CardInstance _instance(
    PvpCardView card,
    PlayerId seat,
    CardLibrary library,
  ) {
    return CardInstance(
      instanceId: card.instanceId,
      def: _definition(card, library),
      owner: seat,
      exerted: card.exerted,
      damage: card.damage,
      plusCounters: card.plusCounters,
      summonedThisTurn: card.summonedThisTurn,
    );
  }

  /// A card the server named but this build does not know.
  ///
  /// Falling back keeps a match playable after a card set update reaches the
  /// server before it reaches the player's app.
  static CardDef _definition(PvpCardView card, CardLibrary library) {
    final def = library.byId[card.cardId];
    if (def != null) return def;
    return CardDef(
      id: card.cardId,
      name: card.name,
      dominions: card.dominions,
      type: card.type ?? CardType.unit,
      subtype: card.subtype,
      might: card.might,
      guard: card.guard,
    );
  }

  // Placeholder ids live far above anything the server issues, so they can
  // never collide with a real instance id and be mistaken for a live card.
  static const _deckIdBase = 900000;
  static const _handIdBase = 910000;
  static const _ruinsIdBase = 920000;
  static const _voidIdBase = 930000;

  static List<CardInstance> _hidden({
    required int count,
    required PlayerId seat,
    required int offset,
  }) {
    final seatOffset = seat == PlayerId.p1 ? 0 : 1000;
    return [
      for (var i = 0; i < count; i++)
        CardInstance(
          instanceId: offset + seatOffset + i,
          def: hiddenCard,
          owner: seat,
        ),
    ];
  }

  static int _highestInstanceId(PvpProjection projection) {
    var highest = 0;
    for (final view in [projection.self, projection.opponent]) {
      for (final card in [...view.hand, ...view.arena]) {
        if (card.instanceId > highest) highest = card.instanceId;
      }
    }
    return highest;
  }

  static PlayerId _other(PlayerId id) =>
      id == PlayerId.p1 ? PlayerId.p2 : PlayerId.p1;
}
