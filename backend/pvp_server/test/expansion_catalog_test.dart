import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import '../bin/server.dart' show loadCardLibrary;

void main() {
  late Directory directory;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('shardfall-catalog-');
    for (var set = 1; set <= 2; set++) {
      File('${directory.path}/set0$set.json').writeAsStringSync(jsonEncode({
        'cards': [
          {
            'id': 'SF00$set-001',
            'name': 'Set $set',
            'dominion': ['VERDANCE'],
            'type': 'UNIT',
            'might': 1,
            'guard': 1
          }
        ],
      }));
    }
  });
  tearDown(() => directory.deleteSync(recursive: true));

  test('existing original path loads the sibling expansion too', () {
    final library = loadCardLibrary(
        {'SHARDFALL_CARD_DATA': '${directory.path}/set01.json'});
    expect(library.byId.keys, containsAll(['SF001-001', 'SF002-001']));
  });

  test(
      'missing expansion fails startup rather than silently rejecting expansion decks',
      () {
    File('${directory.path}/set02.json').deleteSync();
    expect(
        () => loadCardLibrary(
            {'SHARDFALL_CARD_DATA': '${directory.path}/set01.json'}),
        throwsA(isA<FileSystemException>()));
  });

  test('expansion path can be configured independently', () {
    final moved = File('${directory.path}/set02.json')
        .renameSync('${directory.path}/expansion.json');
    final library = loadCardLibrary({
      'SHARDFALL_CARD_DATA': '${directory.path}/set01.json',
      'SHARDFALL_EXPANSION_CARD_DATA': moved.path
    });
    expect(library.byId.length, 2);
  });
}
