import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shardfall/duel/duel_controller.dart';
import 'package:shardfall/duel/scenario.dart';
import 'package:shardfall/story/story_data.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

/// A few story fights hand the player the second turn: the foe opens, and the
/// player draws an extra card. That path had no coverage, and it is the one
/// most able to hang -- in these fights the foe starts with units on the board,
/// so its opening turn includes an attack, and the game then waits on the
/// player to choose blocks. If that wait were wrong the fight would never reach
/// the player's first turn at all.
void main() {
  final library = CardLibrary.fromJsonString(
      File('assets/data/set01.json').readAsStringSync());

  /// Plays the foe's opening turn to its end, answering whatever it asks of
  /// the player. Returns how many of those questions there were.
  Future<int> playFoeOpening(
      WidgetTester tester, DuelController controller) async {
    var prompts = 0;
    unawaited(controller.confirmHand());
    // Done means the player is in their first main phase and the controller has
    // released its lock -- not merely that the turn changed hands, because the
    // controller still walks the player from refresh to main after that.
    bool settled() =>
        controller.state.activePlayer == PlayerId.p1 &&
        controller.state.phase == Phase.main1 &&
        !controller.busy;

    for (var i = 0; i < 400 && !settled(); i++) {
      if (controller.ui == DuelUiState.playerBlocking) {
        prompts++;
        controller.confirmBlocks(); // no blocks: take it
      }
      if (controller.ui == DuelUiState.playerResponse) {
        prompts++;
        controller.passResponse();
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    return prompts;
  }

  testWidgets('the foe opens, attacks with what it started with, and the '
      'turn comes back to the player', (tester) async {
    final controller = DuelController(
      playerDeck: library.buildStarterDeck('VERDANCE'),
      enemyDeck: library.buildStarterDeck('GLOOM'),
      seed: 7,
      firstPlayer: PlayerId.p2,
      scenario: BattleScenario(
        enemyBoard: [library.card('SF001-084')], // Venom Stalker
        playerBoard: [library.card('SF001-003')], // Rootwall Guardian
      ),
    );
    addTearDown(controller.dispose);

    // The player on the draw opens with the extra card.
    expect(controller.state.activePlayer, PlayerId.p2);
    expect(controller.me.hand, hasLength(6));

    final prompts = await playFoeOpening(tester, controller);
    expect(prompts, greaterThan(0),
        reason: 'the foe never attacked, so the block wait went untested');

    expect(controller.state.activePlayer, PlayerId.p1,
        reason: 'the turn never came back to the player');
    expect(controller.state.phase, Phase.main1,
        reason: 'the player must start in their first main phase');
    expect(controller.isGameOver, isFalse);
    expect(controller.busy, isFalse,
        reason: 'the controller is still locked after the foe finished');
  });

  testWidgets('the player draws on their first turn after moving second',
      (tester) async {
    final controller = DuelController(
      playerDeck: library.buildStarterDeck('TIDE'),
      enemyDeck: library.buildStarterDeck('GLOOM'),
      seed: 11,
      firstPlayer: PlayerId.p2,
    );
    addTearDown(controller.dispose);

    final opening = controller.me.hand.length;
    await playFoeOpening(tester, controller);

    expect(controller.me.hand.length, opening + 1,
        reason: 'the second player draws on turn one; only the first skips it');
  });

  test('every fight that gives up the first turn says so', () {
    // A player who did not expect the foe to move first would take it for a
    // bug. The sentence also tells them what they got in exchange.
    var seen = 0;
    for (final chapter in storyChapters) {
      for (final stage in chapter.stages) {
        final battle = stage.battle;
        if (battle == null || battle.playerFirst) continue;
        seen++;
        expect(
            battle.specialRules
                .any((r) => r.startsWith('The foe takes the first turn')),
            isTrue,
            reason: '${chapter.id} "${battle.enemyName}" moves the foe first '
                'without telling the player');
      }
    }
    expect(seen, greaterThan(0),
        reason: 'no fight uses the second turn, so this guards nothing');
  });
}
