import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import '../services/auth_service.dart';
import '../services/backend_config.dart';
import '../services/save_service.dart';
import '../theme.dart';
import 'pvp_controller.dart';
import 'pvp_battle_screen.dart';
import 'pvp_duel_controller.dart';
import 'pvp_models.dart';
import 'pvp_service.dart';

class PvpLobbyScreen extends StatefulWidget {
  final CardLibrary library;
  final SaveService save;
  final AuthService auth;

  const PvpLobbyScreen({
    super.key,
    required this.library,
    required this.save,
    required this.auth,
  });

  @override
  State<PvpLobbyScreen> createState() => _PvpLobbyScreenState();
}

class _PvpLobbyScreenState extends State<PvpLobbyScreen> {
  PvpController? _controller;
  int _selected = 0;
  bool _controllerListening = false;

  /// The match the battle screen was already opened for. Guards the
  /// auto-navigation against pushing a second battle screen for the same
  /// pairing every time the controller notifies.
  String? _openedMatchId;

  List<_PvpDeckOption> get _options {
    final options = <_PvpDeckOption>[];
    widget.save.decks.forEach((name, ids) {
      if (ids.length == 40) {
        options.add(_PvpDeckOption(name: name, cardIds: ids));
      }
    });
    for (final key in const ['VERDANCE', 'PYRE', 'TIDE', 'DAWN', 'GLOOM']) {
      options.add(
        _PvpDeckOption(
          name: '${key[0]}${key.substring(1).toLowerCase()} Starter',
          cardIds: [
            for (final card in widget.library.buildStarterDeck(key)) card.id,
          ],
        ),
      );
    }
    return options;
  }

  @override
  void initState() {
    super.initState();
    if (widget.auth.isSignedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resumeIfInMatch());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  PvpController _ensureController(String userId) {
    final controller = _controller ??= PvpController(
      gateway: PvpService(),
      userId: userId,
    );
    if (!_controllerListening) {
      controller.addListener(_refresh);
      _controllerListening = true;
    }
    return controller;
  }

  /// A match survives closing the app, but the id that points at it does not.
  /// Without this the lobby offers to queue and the server answers
  /// "already in match", with no way back to the game in progress.
  Future<void> _resumeIfInMatch() async {
    final user = widget.auth.user;
    if (user == null) return;

    final controller = _ensureController(user.id);
    if (!await controller.resumeActiveMatch()) return;
    if (!mounted) return;

    setState(() {});
    _snack('Rejoining your match in progress.');
    // The controller listener opens the battle screen.
  }

  /// Opens the online match on the same battle screen the story duels use.
  ///
  /// The deck here only satisfies the inherited constructor; the board is
  /// replaced by the server's first projection before anything is drawn.
  Future<void> _openMatch(PvpController controller) async {
    final options = _options;
    final deck = options.isEmpty
        ? const <CardDef>[]
        : [
            for (final id
                in options[_selected.clamp(0, options.length - 1)].cardIds)
              widget.library.card(id),
          ];

    final duel = PvpDuelController(
      pvp: controller,
      library: widget.library,
      deck: deck,
    );

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PvpBattleScreen(controller: duel),
      ),
    );
    duel.dispose();
    if (!mounted) return;
    // A finished match is done for good; leaving it resets the lobby so the
    // next queue starts clean. A live match stays attached so the REJOIN
    // button can take the player back after an accidental back-out.
    if (controller.state == PvpConnectionState.finished) {
      await controller.leave();
    }
    if (mounted) setState(() {});
  }

  Future<void> _signIn() async {
    final signedIn = await widget.auth.signIn();
    if (!mounted) return;
    setState(() {});
    if (!signedIn && widget.auth.message != null) {
      _snack(widget.auth.message!);
      return;
    }
    if (signedIn) {
      // Remember the link so the next launch can re-auth silently instead
      // of asking again.
      await widget.save.setAccountLinked(true);
      widget.auth.accountLinked = true;
      await _resumeIfInMatch();
    }
  }

  Future<void> _join() async {
    if (!widget.auth.isSignedIn) {
      _snack('Sign in first to play online.');
      return;
    }
    final options = _options;
    if (options.isEmpty) {
      _snack('No valid 40-card deck is available.');
      return;
    }
    final user = widget.auth.user;
    if (user == null) return;
    final controller = _ensureController(user.id);
    setState(() {});
    await controller.join(
      options[_selected.clamp(0, options.length - 1)].cardIds,
    );
    // The controller listener opens the battle screen once the pairing
    // lands, whether that is instantly or after a wait in the queue.
  }

  /// Keeps the lobby in sync with the controller and opens the battle
  /// screen for every path that reaches a live match.
  ///
  /// The controller becomes active from several directions: an instant
  /// match from join, the realtime queue watcher for the player who waited,
  /// or a resume. Only the first one used to open the battle screen, which
  /// stranded the player who had queued first on the lobby until they
  /// tapped FIND OPPONENT a second time.
  void _refresh() {
    if (!mounted) return;
    setState(() {});
    final controller = _controller;
    if (controller == null) return;
    final id = controller.matchId;
    final live = controller.state == PvpConnectionState.active ||
        controller.state == PvpConnectionState.finished;
    if (id != null && live && _openedMatchId != id) {
      _openedMatchId = id;
      unawaited(_openMatch(controller));
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!BackendConfig.pvpAvailable) return _unavailableScreen();
    final options = _options;
    final controller = _controller;
    final signedIn = widget.auth.isSignedIn;
    final selected = options.isEmpty
        ? null
        : options[_selected.clamp(0, options.length - 1)];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.5),
            radius: 1.5,
            colors: [AppTheme.bgTop, AppTheme.bgBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
                  children: [
                    _introCard(),
                    const SizedBox(height: 16),
                    if (!signedIn) _accountCard(),
                    if (!signedIn) const SizedBox(height: 16),
                    const Text(
                      'CHOOSE YOUR DECK',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (options.isEmpty)
                      _emptyDeckCard()
                    else
                      for (var i = 0; i < options.length; i++)
                        _deckTile(options[i], i == _selected, () {
                          setState(() => _selected = i);
                        }),
                    const SizedBox(height: 14),
                    if (controller?.state == PvpConnectionState.queued)
                      _queueCard(controller!)
                    else if (controller != null &&
                        controller.matchId != null &&
                        (controller.state == PvpConnectionState.starting ||
                            controller.state ==
                                PvpConnectionState.reconnecting))
                      _connectingCard()
                    else if (controller != null &&
                        controller.matchId != null &&
                        controller.state == PvpConnectionState.active)
                      _rejoinButton(controller)
                    else
                      _joinButton(selected),
                    if (controller?.lastError != null) ...[
                      const SizedBox(height: 12),
                      _errorCard(controller!.lastError!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _unavailableScreen() => Scaffold(
    backgroundColor: AppTheme.bgBottom,
    appBar: AppBar(
      title: const Text('PLAYER VS PLAYER'),
      backgroundColor: Colors.transparent,
      foregroundColor: AppTheme.textPrimary,
    ),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          'PvP is not enabled in this build yet. Please use the closed-test '
          'build after the backend service has been staged.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textMuted, height: 1.4),
        ),
      ),
    ),
  );

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(6, 8, 16, 4),
    child: Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
        ),
        const Icon(Icons.sports_esports, color: Color(0xFF8FE3FF), size: 20),
        const SizedBox(width: 8),
        const Text(
          'PLAYER VS PLAYER',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
      ],
    ),
  );

  Widget _introCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          const Color(0xFF8FE3FF).withValues(alpha: 0.15),
          Colors.black.withValues(alpha: 0.2),
        ],
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0x558FE3FF)),
    ),
    child: const Text(
      'Face another closed-test player in an authoritative match. Your '
      'opponent\'s hand and deck order stay hidden; the server validates '
      'every move and lets you reconnect after a short disconnect.',
      style: TextStyle(color: AppTheme.textMuted, fontSize: 12.5, height: 1.4),
    ),
  );

  Widget _accountCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.panelBorder),
    ),
    child: Row(
      children: [
        const Icon(Icons.lock_outline, color: Color(0xFFE3B341)),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Sign in with Google to join PvP and keep your match identity.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ),
        TextButton(onPressed: _signIn, child: const Text('SIGN IN')),
      ],
    ),
  );

  Widget _emptyDeckCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.24),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.panelBorder),
    ),
    child: const Text(
      'Build a 40-card deck in DECKS before entering the queue.',
      style: TextStyle(color: AppTheme.textMuted),
    ),
  );

  Widget _deckTile(_PvpDeckOption option, bool selected, VoidCallback onTap) {
    final dominions = <Dominion>{};
    for (final id in option.cardIds) {
      dominions.addAll(widget.library.card(id).dominions);
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF8FE3FF).withValues(alpha: 0.13)
              : Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF8FE3FF) : AppTheme.panelBorder,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.dashboard_customize,
              color: selected ? const Color(0xFF8FE3FF) : AppTheme.textMuted,
              size: 19,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${option.cardIds.length} cards · ${dominions.map((d) => d.name).join(' · ')}',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF8FE3FF),
                size: 19,
              ),
          ],
        ),
      ),
    );
  }

  /// Signing in is its own step. Folding it into "find opponent" meant the
  /// Google account picker appeared out of nowhere when the player thought
  /// they were starting a match.
  Widget _joinButton(_PvpDeckOption? selected) {
    if (!widget.auth.isSignedIn) {
      return SizedBox(
        height: 48,
        child: FilledButton.icon(
          onPressed: _signIn,
          icon: const Icon(Icons.login),
          label: const Text('SIGN IN WITH GOOGLE'),
        ),
      );
    }
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        onPressed: selected == null ? null : _join,
        icon: const Icon(Icons.radar),
        label: const Text('FIND OPPONENT'),
      ),
    );
  }

  Widget _queueCard(PvpController controller) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF8FE3FF).withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0x778FE3FF)),
    ),
    child: Row(
      children: [
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Searching for a closed-test opponent...',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          ),
        ),
        TextButton(onPressed: controller.leave, child: const Text('CANCEL')),
      ],
    ),
  );

  Widget _connectingCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF8FE3FF).withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0x778FE3FF)),
    ),
    child: const Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Opponent found. Setting up the match...',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          ),
        ),
      ],
    ),
  );

  /// A live match survives leaving the battle screen, so the lobby offers a
  /// way back in instead of pretending the queue is the only option.
  Widget _rejoinButton(PvpController controller) => SizedBox(
    height: 48,
    child: FilledButton.icon(
      onPressed: () => unawaited(_openMatch(controller)),
      icon: const Icon(Icons.play_arrow),
      label: const Text('REJOIN MATCH'),
    ),
  );

  Widget _errorCard(String message) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.danger.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.danger.withValues(alpha: 0.5)),
    ),
    child: Text(
      message,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
    ),
  );
}

class _PvpDeckOption {
  final String name;
  final List<String> cardIds;

  const _PvpDeckOption({required this.name, required this.cardIds});
}
