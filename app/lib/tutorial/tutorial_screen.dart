import 'package:flutter/material.dart';

import '../theme.dart';

class _TutorialPage {
  final IconData icon;
  final String title;
  final List<String> lines;
  final String? art; // background card art (assets/art/<id>.webp)
  final bool glossary;

  const _TutorialPage(this.icon, this.title, this.lines,
      {this.art, this.glossary = false});
}

const _pages = [
  _TutorialPage(Icons.auto_awesome, 'Welcome, Shardcaller', [
    'SHARDFALL is a duel of decks. Reduce your opponent\'s Health from 25 to 0 — or let them run out of cards.',
    'Your deck holds Units, spells, and Wellsprings, all drawn from one of the five Dominions.',
  ], art: 'SF001-101'),
  _TutorialPage(Icons.water_drop, 'Aether & Wellsprings', [
    'Wellsprings are your power source. Place ONE per turn from your hand — it\'s free.',
    'Cards cost Aether, shown as symbols in their top-right corner. Playing a card exerts your Wellsprings automatically to pay.',
    'Exerted Wellsprings refresh at the start of your next turn.',
  ], art: 'SF001-043'),
  _TutorialPage(Icons.style, 'Playing cards', [
    'Tap a glowing card in your hand to play it.',
    'Units stay in the Arena and fight. Rites are fast (instant-speed); Rituals are slower, main-phase-only.',
    'If a spell needs a target, the game enters aiming mode — tap a Unit or a player face. Long-press any card to inspect it.',
  ], art: 'SF001-221'),
  _TutorialPage(Icons.sports_kabaddi, 'Combat, like the classics', [
    'Your turn: Untap → Draw → Main 1 → Combat → Main 2 → End.',
    'In Combat, tap your Units to declare attackers, then Attack. Fresh Units have summoning fatigue — they can\'t attack the turn they arrive (unless they have Rush).',
    'Defending Units block. Damage heals off surviving Units at end of turn.',
  ], art: 'SF001-091'),
  _TutorialPage(Icons.shield_moon, 'Keywords', [], glossary: true),
  _TutorialPage(Icons.card_giftcard, 'Grow your collection', [
    'Win duels and story battles to earn Gold.',
    'Spend 100 Gold on a Sundering Shard Pack: 11 cards, a Rare or better guaranteed — and a Legendary once in a while.',
    'The Story of the five Dominions awaits. Begin with the Waking Grove.',
  ], art: 'SF001-063'),
];

// Only keywords the engine actually resolves are documented here.
const _keywords = <(String, IconData, String)>[
  ('Soar', Icons.flight, 'Only blockable by Soar or Intercept.'),
  ('Intercept', Icons.shield_outlined, 'Can block Soar. A vigilant guard.'),
  ('Rush', Icons.bolt, 'Can attack the turn it is summoned.'),
  ('Alert', Icons.visibility_outlined,
      'Attacking doesn\'t exert it — it can still block.'),
  ('Swiftstrike', Icons.flash_on,
      'Strikes first — can kill its blocker before taking damage back.'),
  ('Venom', Icons.science_outlined,
      'Any damage it deals to a Unit destroys that Unit.'),
  ('Rampage', Icons.double_arrow,
      'Damage beyond the blockers spills onto the player.'),
  ('Leech', Icons.favorite_outline, 'You heal for the damage it deals.'),
  ('Dread', Icons.warning_amber, 'Must be blocked by two or more Units, or none.'),
  ('Bulwark', Icons.security, 'Cannot attack — a pure defender.'),
  ('Aegis N', Icons.gpp_good_outlined, 'Prevents N combat damage each combat.'),
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Cross-fading art backdrop that follows the current page.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: _Backdrop(
              key: ValueKey(_pages[_page].art ?? 'glossary'),
              art: _pages[_page].art,
            ),
          ),
          SafeArea(
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
                    itemBuilder: (_, i) => _pages[i].glossary
                        ? _glossaryPage(_pages[i])
                        : _contentPage(_pages[i]),
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
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFFC9A86A)
                                  .withValues(alpha: 0.35),
                              blurRadius: 16),
                        ],
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
        ],
      ),
    );
  }

  Widget _contentPage(_TutorialPage p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.4),
              gradient: RadialGradient(colors: [
                const Color(0xFFC9A86A).withValues(alpha: 0.35),
                Colors.transparent
              ]),
              border: Border.all(color: const Color(0xFFC9A86A), width: 1.6),
            ),
            child: Icon(p.icon, color: const Color(0xFFE6CE96), size: 38),
          ),
          const SizedBox(height: 22),
          Text(p.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Cinzel',
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(color: Colors.black, blurRadius: 10)])),
          const SizedBox(height: 16),
          for (final line in p.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(line,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFDCD6C6),
                      fontSize: 14.5,
                      height: 1.5,
                      shadows: [Shadow(color: Colors.black, blurRadius: 8)])),
            ),
        ],
      ),
    );
  }

  Widget _glossaryPage(_TutorialPage p) {
    return Column(
      children: [
        const SizedBox(height: 6),
        Text(p.title,
            style: const TextStyle(
                fontFamily: 'Cinzel',
                color: AppTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                shadows: [Shadow(color: Colors.black, blurRadius: 10)])),
        const SizedBox(height: 4),
        const Text('The abilities your Units can carry',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: _keywords.length,
            itemBuilder: (_, i) {
              final (name, icon, desc) = _keywords[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFC9A86A).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: const Color(0xFFE6CE96)),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 78,
                      child: Text(name,
                          style: const TextStyle(
                              color: Color(0xFFE6CE96),
                              fontSize: 13,
                              fontWeight: FontWeight.w800)),
                    ),
                    Expanded(
                      child: Text(desc,
                          style: const TextStyle(
                              color: Color(0xFFCFC9BA),
                              fontSize: 12,
                              height: 1.3)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Full-bleed darkened art behind the onboarding text.
class _Backdrop extends StatelessWidget {
  final String? art;
  const _Backdrop({super.key, this.art});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (art != null)
          Image.asset('assets/art/$art.webp',
              fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox())
        else
          const ColoredBox(color: AppTheme.bgBottom),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3),
              radius: 1.4,
              colors: [Color(0xCC0B0D12), Color(0xF20B0D12)],
            ),
          ),
        ),
      ],
    );
  }
}
