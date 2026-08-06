/// The only intents accepted by the authoritative PvP reducer.
enum PvpCommandType {
  ready,
  redraw,
  nextPhase,
  playWellspring,
  exertForAether,
  playUnit,
  cast,
  declareAttackers,
  declareBlocks,
  passPriority,
  concede,
  heartbeat,

  /// "Pass until the turn changes hands" as a single command.
  ///
  /// The reducer never resolves this: the match service expands it into
  /// nextPhase / empty-attack sub-commands inside one lock, so ending a turn
  /// costs the player one network round trip instead of three or four.
  endTurn,
}

class PvpCommand {
  final PvpCommandType type;
  final String idempotencyKey;
  final int revision;
  final Map<String, dynamic> payload;

  const PvpCommand({
    required this.type,
    required this.idempotencyKey,
    required this.revision,
    this.payload = const {},
  });

  factory PvpCommand.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'];
    final idempotencyKey = json['idempotencyKey'];
    final revision = json['revision'];
    final payload = json['payload'];
    if (typeName is! String || idempotencyKey is! String || revision is! int) {
      throw const FormatException('Invalid PvP command envelope');
    }
    if (payload != null && payload is! Map) {
      throw const FormatException('PvP command payload must be an object');
    }
    return PvpCommand(
      type: PvpCommandType.values.byName(typeName),
      idempotencyKey: idempotencyKey,
      revision: revision,
      payload: Map<String, dynamic>.from((payload as Map?) ?? const {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'idempotencyKey': idempotencyKey,
        'revision': revision,
        'payload': payload,
      };
}
