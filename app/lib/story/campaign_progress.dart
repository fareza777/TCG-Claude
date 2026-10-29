import '../services/save_service.dart';
import 'story_data.dart';

enum StoryCampaign {
  sundering('SET 1', 'The Sundering'),
  fiveVows('SET 2', 'The Five Vows');

  final String label;
  final String title;
  const StoryCampaign(this.label, this.title);
  bool contains(StoryChapter chapter) =>
      chapter.id.startsWith('vow') == (this == fiveVows);
  List<int> get chapterIndices => [
    for (var i = 0; i < storyChapters.length; i++)
      if (contains(storyChapters[i])) i,
  ];
}

/// Shared by the campaign map and progression checks. The first expansion
/// chapter follows ch5; no special-case unlock can bypass that boundary.
bool storyChapterUnlocked(int index, SaveService save) =>
    index == 0 ||
    (index > 0 &&
        index < storyChapters.length &&
        save.chapterDone(storyChapters[index - 1].id));

StoryChapter? nextStoryChapter(SaveService save) {
  for (final chapter in storyChapters) {
    if (!save.chapterDone(chapter.id)) return chapter;
  }
  return null;
}

/// Expansion replays revisit scenes without farming gold or quest progress.
/// Original-set replay rewards retain their existing economy.
Future<int> rewardCampaignBattle(
  SaveService save,
  String chapter,
  int stage, {
  required bool freePlay,
}) async {
  if (freePlay && chapter.startsWith('vow')) return 0;
  final reward = await save.rewardStoryBattle('$chapter:$stage');
  await save.trackQuest('story_win');
  return reward;
}
