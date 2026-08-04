import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shardfall_engine/shardfall_engine.dart';

import 'package:shardfall_pvp_server/src/http_server.dart';
import 'package:shardfall_pvp_server/src/in_memory_pvp_repository.dart';
import 'package:shardfall_pvp_server/src/match_service.dart';
import 'package:shardfall_pvp_server/src/pvp_repository.dart';
import 'package:shardfall_pvp_server/src/supabase_pvp_repository.dart';

Future<void> main() async {
  final secret = Platform.environment['PVP_INTERNAL_AUTH_SECRET'];
  if (secret == null || secret.isEmpty) {
    stderr.writeln('PVP_INTERNAL_AUTH_SECRET is required');
    exitCode = 64;
    return;
  }

  final cardPath = Platform.environment['SHARDFALL_CARD_DATA'] ??
      'app/assets/data/set01.json';
  final cardLibrary = CardLibrary.fromJsonString(
    File(cardPath).readAsStringSync(),
  );
  final supabaseUrl = Platform.environment['SUPABASE_URL'];
  final serviceKey = Platform.environment['SHARDFALL_SERVICE_ROLE_KEY'] ??
      Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];
  final PvpRepository repository;
  if (supabaseUrl != null && serviceKey != null && serviceKey.isNotEmpty) {
    repository = SupabasePvpRepository(
      baseUrl: supabaseUrl,
      serviceKey: serviceKey,
      cardLibrary: cardLibrary,
    );
  } else if (Platform.environment['PVP_USE_IN_MEMORY'] == 'true') {
    repository = InMemoryPvpRepository();
  } else {
    stderr.writeln(
      'SUPABASE_URL and SHARDFALL_SERVICE_ROLE_KEY are required '
      '(or set PVP_USE_IN_MEMORY=true for local smoke tests)',
    );
    exitCode = 64;
    return;
  }
  final configuredService = MatchService(
    repository: repository,
    cardLibrary: cardLibrary,
  );
  final server = PvpHttpServer(
    service: configuredService,
    cardLibrary: cardLibrary,
    internalSecret: secret,
  );
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(server.handler);
  final httpServer =
      await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  httpServer.autoCompress = true;
  stdout.writeln('SHARDFALL PvP listening on ${httpServer.port}');
}
