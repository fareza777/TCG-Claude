import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import '../duel/duel_controller.dart';
import '../duel/duel_screen.dart';
import '../duel/scenario.dart';
import '../services/audio_manager.dart';
import '../services/save_service.dart';
import '../theme.dart';
import 'arena_draft.dart';
import 'arena_draft_screen.dart';

/// The Proving Gauntlet: choose a deck, then fight an escalating run of AI
/// champions. Three losses ends the run; rewards scale with your win streak.
class ArenaScreen extends StatefulWidget {
  final CardLibrary library;
  final SaveService save;
  const ArenaScreen({super.key, required this.library, required this.save});

  @override
  State<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends State<ArenaScreen> {
  final _rng = Random();

  List<CardDef>? _deck;
  String _deckName = '';
  bool _runActive = false;
  int _wins = 0;
  int _losses = 0;
  int _runGold = 0;
  late Dominion _nextFoe;

  static const _maxLosses = 3;

  @override
  void initState() {
    super.initState();
    _nextFoe = _rollDominion();
  }

  Dominion _rollDominion() =>
      const [
        Dominion.verdance,
        Dominion.pyre,
        Dominion.tide,
        Dominion.dawn,
        Dominion.gloom,
      ][_rng.nextInt(5)];

  String _cap(String s) => s[0].toUpperCase() + s.substring(1);

  String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }

  /// The run gets genuinely hard at the far end rather than merely longer:
  /// Health climbs steadily, the AI sharpens twice, and from the sixth fight
  /// the champion opens with a board already deployed.
  int get _foeHealth => 25 + (_wins * 3).clamp(0, 27);

  AiTier get _foeTier => switch (_wins) {
        0 => AiTier.greedy,
        1 || 2 || 3 => AiTier.tactician,
        _ => AiTier.strategist,
      };

  /// Champions from the sixth fight onward start with units in the arena.
  int get _foeBoardSize => _wins >= 8
      ? 2
      : _wins >= 5
          ? 1
          : 0;

  int get _winReward => SaveService.arenaGoldForWin(_wins + 1);

  /// Take the fee, draft a deck, start the run.
  ///
  /// The fee is charged before the draft so a run cannot be started unpaid,
  /// and refunded in full if the player backs out of the draft — they got
  /// nothing for it, so charging them would be theft.
  Future<void> _enterGauntlet() async {
    AudioManager.instance.tap();
    if (!await widget.save.payArenaEntry()) return;
    if (!mounted) return;

    final deck = await Navigator.of(context).push<List<CardDef>>(
      MaterialPageRoute(
          builder: (_) => ArenaDraftScreen(library: widget.library)),
    );
    if (!mounted) return;

    if (deck == null) {
      await widget.save.addGold(SaveService.arenaEntryCost);
      return;
    }

    setState(() {
      _deck = deck;
      _deckName = _draftName(deck);
      _wins = 0;
      _losses = 0;
      _runGold = 0;
      _runActive = true;
      _nextFoe = _rollDominion();
    });
  }

  /// Name the run after the colours it was drafted in.
  String _draftName(List<CardDef> deck) {
    final seen = <Dominion>{};
    for (final card in deck) {
      seen.addAll(card.costDominion.keys);
    }
    if (seen.isEmpty) return 'Drafted deck';
    return seen.map((d) => _cap(d.name)).join(' · ');
  }

  Future<void> _fight() async {
    if (_deck == null) return;
    AudioManager.instance.attack();
    final foeKey = _nextFoe.name.toUpperCase();
    final foeDeck = widget.library.buildStarterDeck(foeKey);
    final foeUnits = [
      for (final c in foeDeck)
        if (c.type == CardType.unit) c,
    ];
    final scenario = BattleScenario(
      enemyHealth: _foeHealth,
      enemyBoard: [
        for (var i = 0; i < _foeBoardSize && foeUnits.isNotEmpty; i++)
          foeUnits[_rng.nextInt(foeUnits.length)],
      ],
      objective: 'Survive the ${_ordinal(_wins + 1)} champion.',
      specialRules: [
        if (_foeBoardSize > 0)
          'The champion opens with $_foeBoardSize '
              '${_foeBoardSize == 1 ? "unit" : "units"} already deployed.',
        'Worth $_winReward Gold.',
      ],
    );
    final controller = DuelController(
      playerDeck: _deck!,
      enemyDeck: widget.library.buildStarterDeck(foeKey),
      scenario: scenario,
      aiTier: _foeTier,
    );
    final won = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => DuelScreen(
          controller: controller,
          enemyName: '${_cap(_nextFoe.name)} Gauntlet'),
    ));
    if (!mounted) return;
    if (won == true) {
      _wins += 1;
      _runGold += _winReward;
      await widget.save.addGold(_winReward);
      await widget.save.trackQuest('duel_win');
      _nextFoe = _rollDominion();
    } else {
      _losses += 1;
    }
    if (_losses >= _maxLosses) {
      await _endRun();
    } else {
      setState(() {});
    }
  }

  Future<void> _endRun() async {
    final bonus = await widget.save.recordArenaRun(_wins);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RunOverDialog(
        wins: _wins,
        gold: _runGold,
        shardBonus: bonus,
        best: widget.save.arenaBestWins,
      ),
    );
    if (mounted) setState(() => _runActive = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.5,
            colors: [AppTheme.bgTop, AppTheme.bgBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 8, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back,
                          color: AppTheme.textPrimary),
                    ),
                    const Text('The Proving Gauntlet',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    const Icon(Icons.military_tech,
                        color: Color(0xFFE3B341), size: 18),
                    const SizedBox(width: 4),
                    Text('Best ${widget.save.arenaBestWins}',
                        style: const TextStyle(
                            color: Color(0xFFE3B341),
                            fontSize: 14,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              Expanded(
                  child: _runActive ? _runView() : _lobbyView()),
            ],
          ),
        ),
      ),
    );
  }

  // ── lobby: pay, then draft ────────────────────────────────────────────
  Widget _lobbyView() {
    final canPay = widget.save.canEnterArena;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 3 / 2,
              child: Image.asset('assets/art/ARENA-gauntlet.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink()),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'They keep no records here. No house, no dominion, no name you '
            'arrived with — only how many you put down before somebody put '
            'you down.',
            style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
                height: 1.5,
                fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFFE3B341).withValues(alpha: 0.14),
                Colors.black.withValues(alpha: 0.2),
              ]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.panelBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _rule('Pay ${SaveService.arenaEntryCost} Gold to enter.'),
                _rule('Draft a deck: ${ArenaDraft.picks} picks of one card '
                    'from three. Wellsprings are added for you.'),
                _rule('Every win pays more than the last. The third win '
                    'returns your entry; everything after it is profit.'),
                _rule('Champions sharpen as you climb, and from the sixth '
                    'they start with units already on the board.'),
                _rule('Three losses ends the run. Reach 3, 5 or 7 wins for '
                    'Shard bonuses.'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: canPay ? _enterGauntlet : null,
            child: Opacity(
              opacity: canPay ? 1 : 0.45,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 17),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    const Color(0xFFE3B341),
                    const Color(0xFFE3B341).withValues(alpha: 0.55),
                  ]),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.paid, color: Colors.black87, size: 20),
                    const SizedBox(width: 8),
                    Text('ENTER — ${SaveService.arenaEntryCost} GOLD',
                        style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 15,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              canPay
                  ? 'You hold ${widget.save.gold} Gold.'
                  : 'You hold ${widget.save.gold} Gold — '
                      '${SaveService.arenaEntryCost - widget.save.gold} short.',
              style: TextStyle(
                  color: canPay ? AppTheme.textMuted : AppTheme.danger,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 18),
          const Text('PAYOUT PER WIN',
              style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _payoutTable(),
        ],
      ),
    );
  }

  Widget _rule(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 5, right: 8),
              child: Icon(Icons.circle, size: 5, color: Color(0xFFE3B341)),
            ),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 12.5, height: 1.4)),
            ),
          ],
        ),
      );

  Widget _payoutTable() {
    var running = 0;
    final rows = <Widget>[];
    for (var win = 1; win <= SaveService.arenaWinGold.length; win++) {
      final pay = SaveService.arenaGoldForWin(win);
      running += pay;
      final profit = running - SaveService.arenaEntryCost;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              child: Text('Win $win',
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 12.5)),
            ),
            SizedBox(
              width: 56,
              child: Text('+$pay',
                  style: const TextStyle(
                      color: Color(0xFFE3B341),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800)),
            ),
            Expanded(
              child: Text(
                  profit == 0
                      ? 'breaks even'
                      : profit > 0
                          ? '+$profit net'
                          : '$profit net',
                  style: TextStyle(
                      color: profit >= 0
                          ? const Color(0xFF7FE0A8)
                          : AppTheme.textMuted,
                      fontSize: 12)),
            ),
            if (win == 3 || win == 5 || win == 7)
              Text('+${win >= 7 ? 300 : win >= 5 ? 150 : 60} Shards',
                  style: const TextStyle(
                      color: Color(0xFF9B6BD1),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800)),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }

  // ── active run ────────────────────────────────────────────────────────
  Widget _runView() {
    final style = DominionStyle.of(_nextFoe);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          // score row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, color: Color(0xFFE3B341)),
              const SizedBox(width: 6),
              Text('$_wins',
                  style: const TextStyle(
                      color: Color(0xFFE3B341),
                      fontSize: 30,
                      fontWeight: FontWeight.w900)),
              const SizedBox(width: 20),
              for (var i = 0; i < _maxLosses; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(
                      i < _losses ? Icons.favorite : Icons.favorite_border,
                      color: i < _losses
                          ? AppTheme.danger
                          : AppTheme.textMuted,
                      size: 22),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Deck: $_deckName',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          const SizedBox(height: 20),
          // next foe card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [style.frame[1], style.frame[2]],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: style.glow.withValues(alpha: 0.6)),
              boxShadow: [
                BoxShadow(
                    color: style.glow.withValues(alpha: 0.3), blurRadius: 20)
              ],
            ),
            child: Column(
              children: [
                const Text('NEXT CHALLENGER',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      style.glow.withValues(alpha: 0.45),
                      Colors.transparent
                    ]),
                    border: Border.all(color: style.glow, width: 2),
                  ),
                  child: Icon(style.icon, color: style.glow, size: 38),
                ),
                const SizedBox(height: 10),
                Text('${_cap(_nextFoe.name)} Gauntlet',
                    style: const TextStyle(
                        fontFamily: 'Cinzel',
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  children: [
                    _pill('$_foeHealth HP', AppTheme.health),
                    _pill(
                        _foeTier == AiTier.strategist ? 'Strategist' : 'Tactician',
                        const Color(0xFFB48AD1)),
                    _pill('Win: +$_winReward gold', const Color(0xFFE3B341)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _fight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 15),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppTheme.danger,
                  AppTheme.danger.withValues(alpha: 0.6)
                ]),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.danger.withValues(alpha: 0.45),
                      blurRadius: 20)
                ],
              ),
              child: const Text('FIGHT',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      letterSpacing: 5,
                      fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () async {
              // Retire: end the run, banking rewards for wins so far.
              await _endRun();
            },
            child: const Text('Retire run',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}

class _RunOverDialog extends StatelessWidget {
  final int wins;
  final int gold;
  final int shardBonus;
  final int best;
  const _RunOverDialog({
    required this.wins,
    required this.gold,
    required this.shardBonus,
    required this.best,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.panel,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('RUN COMPLETE',
                style: TextStyle(
                    color: Color(0xFFE3B341),
                    fontSize: 18,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            Text('$wins ${wins == 1 ? 'win' : 'wins'}',
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w900)),
            if (wins >= best && wins > 0)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text('New best!',
                    style: TextStyle(
                        color: Color(0xFF7FE0A8),
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 16),
            _rewardRow(Icons.monetization_on, const Color(0xFFE3B341),
                '+$gold gold'),
            if (shardBonus > 0)
              _rewardRow(Icons.diamond, const Color(0xFF8FE3FF),
                  '+$shardBonus shards (milestone)'),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFC9A86A), Color(0xFF8A713A)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('CONTINUE',
                    style: TextStyle(
                        color: Color(0xFF1C1508),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rewardRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
