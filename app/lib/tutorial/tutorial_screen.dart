import 'package:flutter/material.dart';

import '../theme.dart';

class _TutorialPage {
  final IconData icon;
  final String title;
  final List<String> lines;

  const _TutorialPage(this.icon, this.title, this.lines);
}

const _pages = [
  _TutorialPage(Icons.auto_awesome, 'Welcome, Shardcaller', [
    'SHARDFALL is a duel of decks. Reduce your opponent\'s Health from 25 to 0 — or let them run out of cards.',
    'Your deck holds Units, spells, and Wellsprings, all drawn from one of the five Dominions.',
  ]),
  _TutorialPage(Icons.water_drop, 'Aether & Wellsprings', [
    'Wellsprings are your power source. Place ONE per turn from your hand — it\'s free.',
    'Cards cost Aether, shown as symbols in their top-right corner. When you play a card, your Wellsprings exert (turn sideways) automatically to pay.',
    'Exerted Wellsprings refresh at the start of your next turn.',
  ]),
  _TutorialPage(Icons.style, 'Playing cards', [
    'Tap a glowing card in your hand to play it.',
    'Units stay in the Arena and fight. Rites are fast spells; Rituals are slower, main-phase-only.',
    'If a spell needs a target, the game enters aiming mode — tap a Unit or a player face to choose. Long-press any card to inspect it and its keywords.',
  ]),
  _TutorialPage(Icons.sports_kabaddi, 'Combat, like the classics', [
    'Your turn follows the classic structure: Untap → Draw → Main 1 → Combat → Main 2 → End.',
    'Press Combat, tap your Units to declare attackers, then Attack. New Units have summoning fatigue — they can\'t attack the turn they arrive (unless they have Rush).',
    'Defending Units block. Damage heals off Units at end of turn.',
  ]),
  _TutorialPage(Icons.card_giftcard, 'Grow your collection', [
    'Win duels and story battles to earn Gold.',
    'Spend 100 Gold on a Sundering Shard Pack: 11 cards, with a Rare or better guaranteed — and a Legendary once in a while.',
    'The Story of the five Dominions awaits. Begin with the Waking Grove.',
  ]),
];

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _controller = PageController();
  int _page = 0;

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
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Skip',
                      style: TextStyle(color: AppTheme.textMuted)),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) {
                    final p = _pages[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 34),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                const Color(0xFFC9A86A)
                                    .withValues(alpha: 0.35),
                                Colors.transparent
                              ]),
                              border: Border.all(
                                  color: const Color(0xFFC9A86A), width: 1.6),
                            ),
                            child: Icon(p.icon,
                                color: const Color(0xFFE6CE96), size: 38),
                          ),
                          const SizedBox(height: 22),
                          Text(p.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 16),
                          for (final line in p.lines)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(line,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 14,
                                      height: 1.5)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: i == _page ? 20 : 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: i == _page
                            ? const Color(0xFFC9A86A)
                            : AppTheme.panelBorder,
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: GestureDetector(
                  onTap: () {
                    if (_page < _pages.length - 1) {
                      _controller.nextPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic);
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFC9A86A), Color(0xFF8A713A)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _page < _pages.length - 1 ? 'NEXT' : 'BEGIN',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFF1C1508),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
