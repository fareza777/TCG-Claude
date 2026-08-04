import 'package:flutter/material.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import '../card_render/card_widget.dart';
import '../services/auth_service.dart';
import '../services/backend_config.dart';
import '../services/save_service.dart';
import '../theme.dart';
import 'pvp_controller.dart';
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
    await _openMatch(controller);
  }

  Future<void> _openMatch(PvpController controller) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            PvpMatchScreen(library: widget.library, controller: controller),
      ),
    );
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
    if (signedIn) await _resumeIfInMatch();
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
    if (!mounted || controller.matchId == null) return;
    if (controller.state == PvpConnectionState.active ||
        controller.state == PvpConnectionState.finished) {
      await _openMatch(controller);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
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

class PvpMatchScreen extends StatefulWidget {
  final CardLibrary library;
  final PvpController controller;

  const PvpMatchScreen({
    super.key,
    required this.library,
    required this.controller,
  });

  @override
  State<PvpMatchScreen> createState() => _PvpMatchScreenState();
}

class _PvpMatchScreenState extends State<PvpMatchScreen> {
  PvpCardView? _selectedHand;
  final _selectedAttackers = <int>{};
  bool _readySent = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  CardDef _definition(PvpCardView card) => widget.library.card(card.cardId);

  /// Sends a command that latches its button while it is in flight.
  ///
  /// [PvpController.send] reports failure through `lastError` instead of
  /// throwing, so a latch that is never released leaves the player staring at
  /// a dead button with no way to retry and no visible reason. Releasing it on
  /// failure is what keeps the match recoverable.
  Future<void> _sendLatched(Future<void> Function() action) async {
    if (_readySent) return;
    setState(() => _readySent = true);

    widget.controller.clearError();
    await action();
    if (!mounted) return;

    final failure = widget.controller.lastError;
    if (failure != null) {
      setState(() => _readySent = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure)));
      return;
    }
    setState(() {});
  }

  Future<void> _ready() => _sendLatched(widget.controller.ready);

  Future<void> _redraw() => _sendLatched(widget.controller.redraw);

  Future<void> _playSelected() async {
    final card = _selectedHand;
    if (card == null) return;
    setState(() => _selectedHand = null);
    switch (card.type) {
      case CardType.wellspring:
        await widget.controller.playWellspring(card.instanceId);
      case CardType.unit:
        await widget.controller.playUnit(card.instanceId);
      case CardType.rite:
      case CardType.ritual:
      case CardType.sigil:
      case CardType.relic:
        await widget.controller.cast(card.instanceId);
      case null:
        break;
    }
  }

  Future<void> _declareBlocks() async {
    final attackers =
        widget.controller.projection?.pendingAttackers ?? const [];
    await widget.controller.declareBlocks([
      for (final attackerId in attackers)
        {'attackerId': attackerId, 'blockerIds': const <int>[]},
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final projection = widget.controller.projection;
    if (projection == null) {
      return const Scaffold(
        backgroundColor: AppTheme.bgBottom,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bgBottom,
      appBar: AppBar(
        title: const Text('SHARDFALL · PVP'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          IconButton(
            tooltip: 'Reconnect',
            onPressed: widget.controller.reconnect,
            icon: const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: 'Concede',
            onPressed: projection.isFinished
                ? null
                : () => _confirmConcede(context),
            icon: const Icon(Icons.flag_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _statusBar(projection),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
                child: Column(
                  children: [
                    _playerBar(projection.opponent, isOpponent: true),
                    _arenaRow(projection.opponent.arena, isOpponent: true),
                    const SizedBox(height: 8),
                    _chainNotice(projection),
                    const Divider(color: AppTheme.panelBorder, height: 22),
                    _playerBar(projection.self, isOpponent: false),
                    _arenaRow(projection.self.arena, isOpponent: false),
                    const SizedBox(height: 8),
                    _handRow(projection.self.hand),
                    const SizedBox(height: 10),
                    _actionPanel(projection),
                    if (widget.controller.lastError != null) ...[
                      const SizedBox(height: 10),
                      _errorBanner(widget.controller.lastError!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBar(PvpProjection projection) {
    final turnText = projection.isFinished
        ? (projection.winner == projection.viewer ? 'VICTORY' : 'DEFEAT')
        : projection.isMyTurn
        ? 'YOUR TURN'
        : 'OPPONENT TURN';
    final color = projection.isFinished
        ? (projection.winner == projection.viewer
              ? const Color(0xFF8FE3FF)
              : AppTheme.danger)
        : const Color(0xFFE3B341);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 9),
          const SizedBox(width: 8),
          Text(
            turnText,
            style: TextStyle(
              color: color,
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Text(
            'Turn ${projection.turnNumber} · ${projection.stage.name}',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _playerBar(PvpPlayerView player, {required bool isOpponent}) => Row(
    children: [
      Icon(
        isOpponent ? Icons.person_outline : Icons.person,
        color: isOpponent ? AppTheme.textMuted : const Color(0xFF8FE3FF),
        size: 17,
      ),
      const SizedBox(width: 6),
      Text(
        isOpponent ? 'OPPONENT' : 'YOU',
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 11,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(width: 10),
      Icon(
        Icons.favorite,
        color: AppTheme.danger.withValues(alpha: 0.9),
        size: 14,
      ),
      const SizedBox(width: 3),
      Text(
        '${player.health}',
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
      const Spacer(),
      Icon(Icons.style, color: AppTheme.textMuted, size: 14),
      const SizedBox(width: 3),
      Text(
        '${player.handCount} hand · ${player.deckCount} deck',
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
      ),
    ],
  );

  Widget _arenaRow(List<PvpCardView> cards, {required bool isOpponent}) {
    if (cards.isEmpty) {
      return Container(
        height: 84,
        margin: const EdgeInsets.only(top: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppTheme.panelBorder),
        ),
        child: Center(
          child: Text(
            isOpponent ? 'Opponent arena is empty' : 'Your arena is empty',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
        ),
      );
    }
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (_, index) {
          final card = cards[index];
          final selected = _selectedAttackers.contains(card.instanceId);
          return GestureDetector(
            onTap:
                !isOpponent &&
                    widget.controller.projection?.stage ==
                        PvpStage.attackDeclaration
                ? () => setState(() {
                    if (!selected) {
                      _selectedAttackers.add(card.instanceId);
                    } else {
                      _selectedAttackers.remove(card.instanceId);
                    }
                  })
                : null,
            child: Container(
              padding: selected ? const EdgeInsets.all(2) : EdgeInsets.zero,
              decoration: selected
                  ? BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFE3B341),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
              child: CardWidget(
                def: _definition(card),
                width: 76,
                exerted: card.exerted,
                plusCounters: card.plusCounters,
                damage: card.damage,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _handRow(List<PvpCardView> cards) {
    if (cards.isEmpty) {
      return const Text(
        'No cards in hand',
        style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
      );
    }
    return SizedBox(
      height: 151,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, index) {
          final card = cards[index];
          final selected = _selectedHand?.instanceId == card.instanceId;
          return GestureDetector(
            onTap: () => setState(() => _selectedHand = selected ? null : card),
            child: Container(
              padding: selected ? const EdgeInsets.all(2) : EdgeInsets.zero,
              decoration: selected
                  ? BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF8FE3FF),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
              child: CardWidget(def: _definition(card), width: 92),
            ),
          );
        },
      ),
    );
  }

  Widget _chainNotice(PvpProjection projection) {
    if (projection.stage != PvpStage.chainPriority) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFC77DFF).withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x66C77DFF)),
      ),
      child: Text(
        projection.hasPriority
            ? 'Your priority — cast a response or pass.'
            : 'Opponent has priority — waiting for response.',
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
      ),
    );
  }

  Widget _actionPanel(PvpProjection projection) {
    final selected = _selectedHand;
    final buttons = <Widget>[];
    if (projection.stage == PvpStage.waitingForReady) {
      buttons.add(
        _actionButton(
          label: _readySent ? 'READY SENT' : 'READY',
          icon: Icons.check,
          onPressed: _readySent ? null : _ready,
        ),
      );
    } else if (projection.stage == PvpStage.mulligan) {
      buttons.add(
        _actionButton(
          label: 'KEEP HAND',
          icon: Icons.pan_tool_outlined,
          onPressed: _readySent ? null : _ready,
        ),
      );
      buttons.add(
        _actionButton(
          label: 'REDRAW',
          icon: Icons.refresh,
          onPressed: _readySent ? null : _redraw,
        ),
      );
    } else if (projection.stage == PvpStage.attackDeclaration) {
      buttons.add(
        _actionButton(
          label: 'ATTACK (${_selectedAttackers.length})',
          icon: Icons.flash_on,
          onPressed: projection.isMyTurn
              ? () => widget.controller.declareAttackers(
                  _selectedAttackers.toList(),
                )
              : null,
        ),
      );
    } else if (projection.stage == PvpStage.blockDeclaration) {
      buttons.add(
        _actionButton(
          label: 'DECLARE BLOCKS',
          icon: Icons.shield,
          onPressed: _declareBlocks,
        ),
      );
    } else if (projection.stage == PvpStage.chainPriority) {
      if (projection.hasPriority) {
        buttons.add(
          _actionButton(
            label: selected == null ? 'PASS PRIORITY' : 'CAST SELECTED',
            icon: selected == null ? Icons.skip_next : Icons.auto_awesome,
            onPressed: selected == null
                ? widget.controller.passPriority
                : _playSelected,
          ),
        );
      }
    } else if (projection.stage == PvpStage.main) {
      if (projection.isMyTurn) {
        buttons.add(
          _actionButton(
            label: selected == null ? 'SELECT A CARD' : 'PLAY SELECTED',
            icon: Icons.auto_awesome,
            onPressed: selected == null ? null : _playSelected,
          ),
        );
        buttons.add(
          _actionButton(
            label: 'NEXT PHASE',
            icon: Icons.skip_next,
            onPressed: widget.controller.nextPhase,
          ),
        );
      }
    }
    if (projection.isFinished) {
      buttons.add(
        Text(
          projection.winner == projection.viewer ? 'Match won' : 'Match lost',
          style: TextStyle(
            color: projection.winner == projection.viewer
                ? const Color(0xFF8FE3FF)
                : AppTheme.danger,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }
    if (buttons.isEmpty) {
      return const Text(
        'Waiting for the other player...',
        style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 16),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFFE6CE96),
      side: BorderSide(color: const Color(0xFFC9A86A).withValues(alpha: 0.65)),
      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );

  Widget _errorBanner(String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppTheme.danger.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.danger.withValues(alpha: 0.45)),
    ),
    child: Text(
      message,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
    ),
  );

  Future<void> _confirmConcede(BuildContext context) async {
    final concede = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: const Text(
          'Concede match?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'This will give the opponent the win.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CONCEDE'),
          ),
        ],
      ),
    );
    if (concede == true) {
      await widget.controller.concede();
    }
  }
}
