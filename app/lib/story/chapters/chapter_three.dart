import '../story_data.dart';

/// Chapter III — twenty scenes in the drowned Archive of Meridine.
///
/// The arc: records are disappearing, and the culprit is not an enemy in the
/// stacks. Meridine has been erasing its own history for a thousand years, on
/// purpose, as a defence — because the thing beneath the five cities learns
/// through what is written, and a fact nobody has recorded is a fact it cannot
/// read. Archivist Numen keeps that order. What the erasures were hiding is the
/// pact: five capitals, five doors, and an agreement to feed what lies under
/// them and then forget having agreed.
const chapterThree = StoryChapter(
  id: 'ch3',
  title: 'Chapter III — The Erased Archive',
  subtitle: 'A Tide story',
  playerDominion: 'TIDE',
  stages: [
    // ══ 1 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch3-01',
      title: 'The City That Remembers',
      dialogue: [
        DialogueLine.narrate(
            'Meridine floats above its own library. Beneath the hulls, shelves '
            'go down further than light does, and every tablet on them glows '
            'faintly, because a thing written in Meridine is a thing kept.'),
        DialogueLine('Numen',
            'Nine hundred thousand records, Caller. I could tell you the count '
            'to the last one.'),
        DialogueLine('You', 'Could you yesterday?'),
        DialogueLine('Numen', 'That is precisely the problem.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'Ink-Eaters',
      objective: 'Something is grazing in the shallow stacks.',
      specialRules: [
        'Two of the Archive already stand with you.',
        'The foe has 15 Health to your 25.',
      ],
      enemyHealth: 15,
      playerBoardIds: ['SF001-041', 'SF001-043'],
    )),

    // ══ 2 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch3-02',
      title: 'The First Missing Page',
      dialogue: [
        DialogueLine.narrate(
            'A tablet in the third vault has gone half blank. Not smashed, not '
            'stolen — the ink is simply thinning, letter by letter, while you '
            'watch it.'),
        DialogueLine('You', 'What did it say?'),
        DialogueLine('Numen',
            'I read it four days ago and I cannot tell you. That is not '
            'forgetting, Caller. I know exactly what forgetting feels like.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Thinning',
      objective: 'Reach the tablet before the last line goes.',
      specialRules: [
        'One of the Archive stands with you.',
        'The foe has 16 Health to your 25.',
      ],
      enemyHealth: 16,
      playerBoardIds: ['SF001-041'],
    )),

    // ══ 3 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch3-03',
      title: 'A Nyxhollow Infiltrator',
      dialogue: [
        DialogueLine.narrate(
            'You catch her in the ninth vault with no bag, no cart, and '
            'nothing in her hands.'),
        DialogueLine('Infiltrator',
            'I am not here to take anything. Lady Duskveil sent me to check '
            'whether one particular page still exists.'),
        DialogueLine('You', 'Which page?'),
        DialogueLine('Infiltrator',
            'If I say it aloud in this room it will be gone by morning. That '
            'is how it works here. Surely you know how it works here.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'A Nyxhollow Infiltrator',
      objective: 'Take her alive, if the vault allows it.',
      specialRules: [
        'One of the Archive stands with you.',
        'The foe has 18 Health to your 25.',
      ],
      enemyHealth: 18,
      playerBoardIds: ['SF001-041'],
    )),

    // ══ 4 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch3-04',
      title: 'The Reading Room',
      dialogue: [
        DialogueLine.narrate(
            'You sit in the reading room with a single tablet and watch it for '
            'an hour. Nothing happens. Then you read it aloud, and the line '
            'you read fades while your mouth is still shaping it.'),
        DialogueLine('Numen', 'Now you have seen it.'),
        DialogueLine('You', 'It goes when it is read.'),
        DialogueLine('Numen',
            'It goes when it is *known*. Something is reading through us, '
            'Caller, and it does not leave what it has taken.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'What Reads Beside You',
      objective: 'You are not alone at the table.',
      specialRules: [
        'The foe has 20 Health to your 25.',
      ],
      enemyHealth: 20,
    )),

    // ══ 5 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch3-05',
      title: 'The Order Numen Never Read Aloud',
      dialogue: [
        DialogueLine.narrate(
            'She takes the Ashmar flood order out of her sleeve, still sealed, '
            'and drops it into the black water of the vault.'),
        DialogueLine('Numen',
            'Sixty thousand. I told you I would burn it in front of you. There '
            'is no fire left in Ashmar, so this will have to do.'),
        DialogueLine('You', 'Your order will ask.'),
        DialogueLine('Numen', 'My order will not remember asking.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'TIDE',
      enemyName: 'The Compliance Wardens',
      objective: 'Meridine notices a missing order.',
      specialRules: [
        'The foe has 22 Health to your 25.',
      ],
      enemyHealth: 22,
    )),

    // ══ 6 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch3-06',
      title: 'Gold on the Water',
      dialogue: [
        DialogueLine.narrate(
            'Aurelian sail comes over the horizon in a line, and it does not '
            'slow at the harbour boom. It goes through it.'),
        DialogueLine('Inquisitor',
            'Meridine has been keeping records it had no right to keep. '
            'Aurelia will take the Archive into safekeeping.'),
        DialogueLine('You', 'That word again.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'DAWN',
      enemyName: 'The Aurelian Inquisition',
      objective: 'Hold the upper stacks.',
      specialRules: [
        'The foe has 23 Health to your 25.',
      ],
      enemyHealth: 23,
    )),

    // ══ 7 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch3-07',
      title: 'What Aurelia Came For',
      dialogue: [
        DialogueLine.narrate(
            'The Inquisition does not loot. It goes straight down, past nine '
            'centuries of trade ledgers, to a vault it should not know '
            'about.'),
        DialogueLine('You', 'They have a shelf number.'),
        DialogueLine('Numen',
            'They have *our* shelf number. Someone in this Archive gave it to '
            'them.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'DAWN',
      enemyName: 'Seraphel\'s Vanguard',
      objective: 'Beat them to the deep vault.',
      specialRules: [
        'The foe has 24 Health to your 25.',
      ],
      enemyHealth: 24,
    )),

    // ══ 8 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch3-08',
      title: 'The Ledger of Five',
      dialogue: [
        DialogueLine.narrate(
            'The vault holds one tablet on an empty shelf built for six '
            'hundred. It is a contract. It has five marks on it.'),
        DialogueLine('You',
            'Sylvaris. Ashmar. Meridine. Aurelia. Nyxhollow. All five.'),
        DialogueLine('Numen',
            'Signed nine hundred and eleven years ago, and every copy of it '
            'has been erased since — by us.'),
        DialogueLine('You', 'What did the five of us agree to?'),
        DialogueLine('Numen', 'The clause is blank. We erased that too.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Drowned Memories',
      objective: 'The vault does not like being opened.',
      specialRules: [
        'The foe has 25 Health to your 25.',
      ],
      enemyHealth: 25,
    )),

    // ══ 9 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch3-09',
      title: 'The Keeper of the Erasure',
      dialogue: [
        DialogueLine('Numen',
            'You should hear it from me. The erasures are not an attack. They '
            'are my office. I am the ninth Keeper of the Erasure and I have '
            'unmade eleven thousand records with my own hand.'),
        DialogueLine('You', 'You have been destroying your own history.'),
        DialogueLine('Numen',
            'I have been starving something that eats it. A fact nobody has '
            'written down is a fact it cannot read.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'TIDE',
      enemyName: 'The Keepers Before Her',
      objective: 'The office defends itself.',
      specialRules: [
        'The foe has 25 Health to your 25.',
      ],
      enemyHealth: 25,
    )),

    // ══ 10 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch3-10',
      title: 'It Has Been Reading Anyway',
      dialogue: [
        DialogueLine.narrate(
            'In the deepest vault the shelves are not empty. They are full — '
            'of tablets Meridine never wrote, in Meridine\'s own hand, '
            'recording things nobody alive has done yet.'),
        DialogueLine('You', 'It has been keeping its own copy.'),
        DialogueLine('Numen',
            'Nine hundred years of erasure. And it simply wrote them out again '
            'behind us, one shelf lower, every single time.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Second Archive',
      objective: 'Burn a library that is not yours.',
      specialRules: [
        'The foe has 26 Health to your 25.',
      ],
      enemyHealth: 26,
    )),

    // ══ 11 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch3-11',
      title: 'Hoofprints on the Seabed',
      dialogue: [
        DialogueLine.narrate(
            'Below the last shelf the floor is silt, and across the silt, '
            'unhurried, go the prints of something enormous with hooves. They '
            'do not disturb the water.'),
        DialogueLine('You', 'He was in Ashmar eleven days ago.'),
        DialogueLine('Numen',
            'He was in Sylvaris a month ago. Caller — it is one room down '
            'here, and your warden is walking it faster than we can sail.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Silt Wardens',
      objective: 'Follow the tracks alone.',
      specialRules: ['No help on either side.', 'They have 26 Health.'],
      enemyHealth: 26,
    )),

    // ══ 12 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch3-12',
      title: 'Five Cities, Five Doors',
      dialogue: [
        DialogueLine.narrate(
            'The second archive has a map, and the map is the only thing on it '
            'that has never been erased, because the thing that drew it wanted '
            'it kept.'),
        DialogueLine('You',
            'Every capital is on a door. All five. We did not settle where the '
            'Shards fell. We settled where the doors were.'),
        DialogueLine('Numen', 'We were placed, Caller. Like weights.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Cartographer',
      objective: 'Whatever drew the map is still drawing.',
      specialRules: ['No help on either side.', 'It has 27 Health.'],
      enemyHealth: 27,
    )),

    // ══ 13 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch3-13',
      title: 'The Blank Clause',
      dialogue: [
        DialogueLine.narrate(
            'In the second archive, the Ledger of Five is not blank. The '
            'clause is there, written out fully, in nine hundred year old '
            'ink.'),
        DialogueLine('Numen', 'Do not read it aloud.'),
        DialogueLine('You', 'It is already read. It has always been read. That '
            'is the whole point of this shelf.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Clause Made Flesh',
      objective: 'It objects to being quoted.',
      specialRules: [
        'The enemy opens with a creature in play.',
        'It has 27 Health.',
      ],
      enemyHealth: 27,
      enemyBoardIds: ['SF001-081'],
    )),

    // ══ 14 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch3-14',
      title: 'What the Five Agreed',
      dialogue: [
        DialogueLine.narrate(
            'The clause is short. Nine hundred years of erasure to hide four '
            'lines.'),
        DialogueLine('Numen',
            '"Each city shall sit upon its door. Each city shall give what is '
            'asked. Each city shall forget the asking. The fifth shall keep '
            'the count."'),
        DialogueLine('You', 'The fifth. Nyxhollow.'),
        DialogueLine('Numen',
            'Ravenna Duskveil\'s house has kept the count for nine hundred '
            'years while the other four called them the villains of the '
            'story.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Count Keeper\'s Shadow',
      objective: 'Something has been keeping a rival tally.',
      specialRules: [
        'The enemy opens with a creature in play.',
        'It has 28 Health.',
      ],
      enemyHealth: 28,
      enemyBoardIds: ['SF001-084'],
    )),

    // ══ 15 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch3-15',
      title: 'The Inquisition Takes the Vault',
      dialogue: [
        DialogueLine.narrate(
            'Aurelia reaches the second archive an hour behind you and does '
            'not pause at the shelves. They begin loading them.'),
        DialogueLine('Inquisitor',
            'Every word of this returns to Aurelia. A truth this size cannot '
            'be left with a city that erases things.'),
        DialogueLine('Numen',
            'You are about to carry nine hundred years of its own writing into '
            'the one capital that has never once erased anything.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'DAWN',
      enemyName: 'The Loading Detail',
      objective: 'Do not let the shelves leave.',
      specialRules: [
        'The enemy opens with a creature in play.',
        'They have 28 Health.',
      ],
      enemyHealth: 28,
      enemyBoardIds: ['SF001-065'],
    )),

    // ══ 16 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch3-16',
      title: 'The Name Under the Oak',
      dialogue: [
        DialogueLine.narrate(
            'One line in the second archive has been struck through by a '
            'different hand — an old hand, a frightened one.'),
        DialogueLine('Numen',
            'The name of the first Caller. The one buried under Sylvaris. '
            'Someone tried to take it out of even *this* record.'),
        DialogueLine('You', 'Who strikes out a name in a library nobody knows '
            'exists?'),
        DialogueLine('Numen', 'Someone who has been down here a very long '
            'time.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Struck-Through',
      objective: 'What the old hand was hiding.',
      specialRules: [
        'The enemy opens with two creatures in play.',
        'It has 29 Health.',
      ],
      enemyHealth: 29,
      enemyBoardIds: ['SF001-082', 'SF001-084'],
    )),

    // ══ 17 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch3-17',
      title: 'The Erasure Comes Up',
      dialogue: [
        DialogueLine.narrate(
            'Every tablet in the Archive goes blank at once, from the deepest '
            'shelf upward, and the blankness keeps rising.'),
        DialogueLine('Numen',
            'It has finished reading. It does not need the copies any more.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Drowned Memories',
      objective: 'Nine centuries of archivists, unmade and rising.',
      specialRules: [
        'The enemy opens with two creatures in play.',
        'They have 30 Health.',
      ],
      enemyHealth: 30,
      enemyBoardIds: ['SF001-085', 'SF001-083'],
    )),

    // ══ 18 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch3-18',
      title: 'Numen Keeps Her Office',
      dialogue: [
        DialogueLine('Numen',
            'It reads what is known. It cannot read what no longer exists to '
            'be known. There is one record left that it has not taken.'),
        DialogueLine('You', 'The name.'),
        DialogueLine('Numen',
            'In my head, Caller. Only there. And I am the ninth Keeper of the '
            'Erasure, and I do know how to unmake a record.'),
        DialogueLine('You', 'Numen —'),
        DialogueLine('Numen',
            'Tell Duskveil the count was kept honestly. Tell her Meridine is '
            'sorry it took nine hundred years to say so.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'What Comes for the Name',
      objective: 'Buy her the time.',
      specialRules: [
        'The enemy opens with two creatures in play.',
        'It has 31 Health.',
      ],
      enemyHealth: 31,
      enemyBoardIds: ['SF001-086', 'SF001-084'],
    )),

    // ══ 19 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch3-19',
      title: 'The Shape It Chooses',
      dialogue: [
        DialogueLine.narrate(
            'Where Numen was standing there is an absence, and the absence is '
            'wearing her robes.'),
        DialogueLine('The Erasure',
            'She unmade herself to keep four syllables from me. Do you know '
            'how nearly that worked?'),
        DialogueLine('You', 'It worked.'),
        DialogueLine('The Erasure',
            'It cost her everything and bought you a season. Yes. Call that '
            'working, if the word helps.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Unwritten Guard',
      objective: 'It wears nine hundred years of erased things.',
      specialRules: [
        'They fight with real cunning.',
        'They have 32 Health and open with two creatures.',
      ],
      enemyHealth: 32,
      enemyBoardIds: ['SF001-086', 'SF001-085'],
      hardAi: true,
    )),

    // ══ 20 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch3-20',
      title: 'The Erasure',
      dialogue: [
        DialogueLine('The Erasure',
            'Four cities fed me and forgot. The fifth counted. And one warden '
            'sat on a lid for a thousand years and talked to me every night of '
            'it, which was kinder than any of you managed.'),
        DialogueLine('You', 'Thornmaw.'),
        DialogueLine('The Erasure',
            'He is ahead of you. He has been ahead of you since the Grove. Ask '
            'yourself, Caller — ahead of you, or leading you?'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Erasure',
      objective: 'Take back what it read.',
      specialRules: [
        'It fights with everything it has taken.',
        'It has 38 Health and opens with two creatures.',
      ],
      enemyHealth: 38,
      enemyBoardIds: ['SF001-086', 'SF001-085'],
      hardAi: true,
      preBattle: [
        DialogueLine('The Erasure',
            'Her name is already gone, you know. You will not get that one '
            'back.'),
      ],
      victory: [
        DialogueLine.narrate(
            'The blankness stops rising. Ink returns to eleven shelves and no '
            'further, and one of the restored tablets is a duty roster with a '
            'name on it that nobody in the room can read.'),
        DialogueLine.narrate(
            'Meridine will rebuild the Archive. It will take four hundred '
            'years and they will start tomorrow.'),
        DialogueLine.narrate(
            'The Archive endures, thinner. The tale turns to the light.'),
      ],
    )),
  ],
);
