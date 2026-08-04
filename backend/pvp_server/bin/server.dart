import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:shardfall_pvp_server/src/http_server.dart';
import 'package:shardfall_pvp_server/src/in_memory_pvp_repository.dart';
import 'package:shardfall_pvp_server/src/match_service.dart';

Future<void> main() async {
  final secret = Platform.environment['PVP_INTERNAL_AUTH_SECRET'];
  if (secret == null || secret.isEmpty) {
    stderr.writeln('PVP_INTERNAL_AUTH_SECRET is required');
    exitCode = 64;
    return;
  }

  // The durable Supabase repository is wired by the deployment build. Keeping
  // the local entrypoint in-memory makes the container health endpoint and
  // protocol smoke tests runnable without a production credential.
  final service = MatchService(repository: InMemoryPvpRepository());
  final server = PvpHttpServer(service: service, internalSecret: secret);
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(server.handler);
  final httpServer =
      await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  httpServer.autoCompress = true;
  stdout.writeln('SHARDFALL PvP listening on ${httpServer.port}');
}
