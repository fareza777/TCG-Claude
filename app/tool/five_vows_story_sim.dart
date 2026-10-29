// Headless evidence for the actual SF002 loan decks, boards, health and AI.
// From app/: dart tool/five_vows_story_sim.dart --games=4 --seed=41000
import 'dart:io';
import 'package:shardfall/story/story_data.dart';
import 'package:shardfall_engine/shardfall_engine.dart';
import 'story_runner.dart';

void main(List<String> args) {
  int flag(String key,int fallback) => int.parse(args.firstWhere(
      (a)=>a.startsWith('--$key='),orElse:()=>'--$key=$fallback').split('=').last);
  final games=flag('games',4),seed=flag('seed',41000);
  final library=CardLibrary.fromJsonStrings([
    File.fromUri(Platform.script.resolve('../assets/data/set01.json')).readAsStringSync(),
    File.fromUri(Platform.script.resolve('../assets/data/set02.json')).readAsStringSync(),
  ]);
  stdout.writeln('chapter,battle,player,enemy,wins,games,stalls');
  for(final chapter in storyChapters.skip(5)) {
    var number=0;
    for(final battle in chapter.stages.map((s)=>s.battle).whereType<StoryBattle>()) {
      number++;var wins=0,stalls=0;
      for(var i=0;i<games;i++) {
        final result=playBattle(library:library,chapter:chapter,battle:battle,
          setup:Setup.of(battle),playerSkill:AiTier.tactician,seed:seed+i);
        if(result==true)wins++;
        if(result==null)stalls++;
      }
      stdout.writeln('${chapter.id},$number,${chapter.playerDominion},${battle.enemyDominion},$wins,$games,$stalls');
    }
  }
}
