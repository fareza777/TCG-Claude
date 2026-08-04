import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shardfall_engine/shardfall_engine.dart';

import 'match_service.dart';

class PvpHttpServer {
  final MatchService service;
  final String internalSecret;
  final String serviceName;
  late final Router _router = _buildRouter();

  PvpHttpServer({
    required this.service,
    required this.internalSecret,
    this.serviceName = 'shardfall-pvp',
  });

  Handler get handler => _router.call;

  Router _buildRouter() => Router()
    ..get('/health', _health)
    ..post(
      '/internal/v1/matches/<matchId>/commands',
      (Request request, String matchId) => _command(request, matchId),
    )
    ..get(
      '/internal/v1/matches/<matchId>/projection',
      (Request request, String matchId) => _reconnect(request, matchId),
    );

  Response _health(Request request) => _json({
        'service': serviceName,
        'ok': true,
        'engineVersion': service.engineVersion,
        'rulesetVersion': service.rulesetVersion,
      });

  Future<Response> _command(Request request, String matchId) async {
    if (!_authorized(request)) return _json({'errorCode': 'unauthorized'}, 401);
    try {
      final body = await _jsonBody(request);
      final actorUserId = body['actorUserId'];
      final commandJson = body['command'];
      if (actorUserId is! String || commandJson is! Map) {
        throw const FormatException('actorUserId and command are required');
      }
      final response = await service.command(
        matchId: matchId,
        actorUserId: actorUserId,
        command: PvpCommand.fromJson(Map<String, dynamic>.from(commandJson)),
      );
      return _json(response.toJson(), _statusFor(response.errorCode));
    } on FormatException catch (error) {
      return _json({
        'errorCode': 'invalid_payload',
        'message': error.message,
      }, 400);
    } on ArgumentError catch (error) {
      return _json({
        'errorCode': 'invalid_payload',
        'message': error.message.toString(),
      }, 400);
    }
  }

  Future<Response> _reconnect(Request request, String matchId) async {
    if (!_authorized(request)) return _json({'errorCode': 'unauthorized'}, 401);
    final userId = request.url.queryParameters['userId'];
    if (userId == null || userId.isEmpty) {
      return _json({
        'errorCode': 'invalid_payload',
        'message': 'userId is required',
      }, 400);
    }
    final response = await service.reconnect(
      matchId: matchId,
      actorUserId: userId,
    );
    return _json(response.toJson(), _statusFor(response.errorCode));
  }

  bool _authorized(Request request) => _constantTimeEquals(
      request.headers['x-pvp-internal-secret'], internalSecret);

  static Future<Map<String, dynamic>> _jsonBody(Request request) async {
    final length = int.tryParse(request.headers['content-length'] ?? '');
    if (length != null && length > 64 * 1024) {
      throw const FormatException('Request body is too large');
    }
    final text = await request.readAsString();
    if (text.length > 64 * 1024) {
      throw const FormatException('Request body is too large');
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map)
      throw const FormatException('JSON body must be an object');
    return Map<String, dynamic>.from(decoded);
  }

  static Response _json(Map<String, dynamic> body, [int status = 200]) =>
      Response(
        status,
        body: jsonEncode(body),
        headers: const {'content-type': 'application/json'},
      );

  static int _statusFor(String? code) => switch (code) {
        null => 200,
        'unauthorized' => 401,
        'not_a_player' => 403,
        'match_not_found' => 404,
        'stale_revision' => 409,
        'invalid_payload' => 400,
        _ => 422,
      };

  static bool _constantTimeEquals(String? actual, String expected) {
    final left = Uint8List.fromList(utf8.encode(actual ?? ''));
    final right = Uint8List.fromList(utf8.encode(expected));
    var difference = left.length ^ right.length;
    for (var i = 0; i < math.max(left.length, right.length); i++) {
      final a = i < left.length ? left[i] : 0;
      final b = i < right.length ? right[i] : 0;
      difference |= a ^ b;
    }
    return difference == 0;
  }
}
