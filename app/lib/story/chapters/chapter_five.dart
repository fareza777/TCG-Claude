import '../story_data.dart';

/// Chapter V — twenty scenes in Nyxhollow, and the end of Set One.
///
/// The arc: the city four capitals have called the villain turns out to have
/// been the only one keeping its side of the pact. The count the fifth house
/// kept was not tribute — it was a countdown, and the tally marks are their own
/// dead. Every generation of Duskveils has sent someone into the ground,
/// because the first Caller's one condition was that somebody willing had to be
/// down there. The count ran out eleven years ago and nobody came.
///
/// The last answer is the smallest one: there is nothing buried beneath her.
/// There never was. She invented it so five cities would build over the door
/// and stop digging, and she has been alone with that lie for nine hundred
/// years. What has been hollowing the world is not an enemy. It is the sound
/// she makes.
const chapterFive = StoryChapter(
  id: 'ch5',
  title: 'Chapter V — The Thankless Vigil',
  subtitle: 'A Gloom story — the truth of Ravenna',
  playerDominion: 'GLOOM',
  stages: [
    // ══ 1 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch5-01',
      title: 'The Thankless City',
      dialogue: [
        DialogueLine.narrate(
            'You have been told about Nyxhollow your whole life. Black spires, '
            'a violet moon, a people who traffic in rot.'),
        DialogueLine.narrate(
            'What you find is a city with clean streets, full granaries, and a '
            'watch that changes on the hour, every hour, without fail. It is '
            'the most disciplined place you have ever stood in.'),
        DialogueLine('Thornmaw',
            'Four capitals spent nine hundred years describing this city to '
            'each other. None of them ever visited.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Duskveil Guard',
      objective: 'They do not take strangers on trust.',
      specialRules: [
        'Two of the watch already stand with you.',
        'The foe has 15 Health to your 25.',
      ],
      enemyHealth: 15,
      playerBoardIds: ['SF001-081', 'SF001-084'],
    )),

    // ══ 2 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch5-02',
      title: 'The Ledger Hall',
      dialogue: [
        DialogueLine.narrate(
            'The heart of Nyxhollow is not a palace. It is a hall of black '
            'glass ledgers, nine hundred years deep, and every page is a '
            'tally.'),
        DialogueLine('You', 'The count.'),
        DialogueLine('Ravenna',
            'The count. Meridine erased its history to starve her. Aurelia '
            'wrote everything and fed her. We simply counted, every year, '
            'without missing one.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Unrecorded',
      objective: 'Things that never made it onto a page.',
      specialRules: [
        'One of the watch stands with you.',
        'The foe has 16 Health to your 25.',
      ],
      enemyHealth: 16,
      playerBoardIds: ['SF001-081'],
    )),

    // ══ 3 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch5-03',
      title: 'What the Count Counts',
      dialogue: [
        DialogueLine('You', 'Nine hundred entries. What is the unit?'),
        DialogueLine('Ravenna', 'Years remaining.'),
        DialogueLine('You', 'Then it reached zero —'),
        DialogueLine('Ravenna',
            'Eleven years ago. And I have been writing negative numbers in '
            'this ledger ever since, alone, while four capitals argued about '
            'trade tariffs.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'Eleven Years Overdue',
      objective: 'What has been accumulating since zero.',
      specialRules: [
        'One of the watch stands with you.',
        'The foe has 18 Health to your 25.',
      ],
      enemyHealth: 18,
      playerBoardIds: ['SF001-081'],
    )),

    // ══ 4 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch5-04',
      title: 'The Warden Confesses',
      dialogue: [
        DialogueLine('Thornmaw',
            'I asked for a witness. Here is the confession. I opened the first '
            'three doors. Sylvaris, Ashmar, Meridine — I went ahead of the '
            'Caller and I unsealed each one.'),
        DialogueLine('Ravenna', 'I know. I have been watching you do it.'),
        DialogueLine('You', 'You *knew*?'),
        DialogueLine('Ravenna',
            'I have counted every door he opened. It is the only reason the '
            'fifth has not torn. They had to open in order, and slowly, or '
            'this one takes the whole coast with it.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Pressure Below',
      objective: 'Four doors opened, and it all comes here.',
      specialRules: [
        'The foe has 20 Health to your 25.',
      ],
      enemyHealth: 20,
    )),

    // ══ 5 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch5-05',
      title: 'The Price of the House',
      dialogue: [
        DialogueLine.narrate(
            'Ravenna takes you to a wall of names. It is not a memorial to '
            'war. Every name is a Duskveil, and there is one per generation, '
            'without a gap, for nine hundred years.'),
        DialogueLine('You', 'Your family has sent one down. Every generation.'),
        DialogueLine('Ravenna',
            'Her condition was that somebody willing had to be in the ground. '
            'Not a prisoner. Not a sacrifice. Willing. Four cities agreed to '
            'that clause in an afternoon and then went home.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Names on the Wall',
      objective: 'Nine hundred years of Duskveils, still on duty.',
      specialRules: [
        'The foe has 22 Health to your 25.',
      ],
      enemyHealth: 22,
    )),

    // ══ 6 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch5-06',
      title: 'The Last Name',
      dialogue: [
        DialogueLine.narrate(
            'The final name on the wall was carved eleven years ago and the '
            'stone dust has not been swept from under it.'),
        DialogueLine('You', 'Who was she?'),
        DialogueLine('Ravenna',
            'My sister. She was nineteen. She volunteered because the count '
            'had run out and I was needed up here, and because one of us had '
            'to and she got to the door first.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Vigil Keepers',
      objective: 'Her guard has never stood down.',
      specialRules: [
        'The foe has 23 Health to your 25.',
      ],
      enemyHealth: 23,
    )),

    // ══ 7 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch5-07',
      title: 'The Heartshard',
      dialogue: [
        DialogueLine.narrate(
            'The violet Shard hangs in a shaft of still air under the city, '
            'and it is not glowing steadily. It pulses, unevenly, like '
            'something breathing badly.'),
        DialogueLine('Ravenna',
            'Ten years it held that rhythm. This season it began to '
            'stutter.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Stutter',
      objective: 'Something is coming through the gaps.',
      specialRules: [
        'The foe has 24 Health to your 25.',
      ],
      enemyHealth: 24,
    )),

    // ══ 8 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch5-08',
      title: 'The Four Capitals Send Word',
      dialogue: [
        DialogueLine.narrate(
            'Riders arrive from Sylvaris, Ashmar, Meridine and Aurelia within '
            'the same day. Nine hundred years of silence, and now everyone has '
            'an opinion.'),
        DialogueLine('Ravenna',
            'They want to know what Nyxhollow intends to do about it. Read the '
            'first line of every letter. Go on.'),
        DialogueLine('You', 'They all begin by asking whose fault it is.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'DAWN',
      enemyName: 'The Aurelian Delegation',
      objective: 'Aurelia arrives with terms, in the dark, unashamed.',
      specialRules: [
        'The foe has 25 Health to your 25.',
      ],
      enemyHealth: 25,
    )),

    // ══ 9 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch5-09',
      title: 'The Fifth Door',
      dialogue: [
        DialogueLine.narrate(
            'Beneath the Heartshard the fifth door is not a shaft or a vein or '
            'a vault. It is a plain stone stair going down, well maintained, '
            'with a handrail worn smooth by nine hundred years of use.'),
        DialogueLine('Thornmaw', 'Somebody has swept these steps.'),
        DialogueLine('Ravenna', 'Somebody sweeps them every week.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Stairward',
      objective: 'The stair is not unguarded.',
      specialRules: [
        'The foe has 25 Health to your 25.',
      ],
      enemyHealth: 25,
    )),

    // ══ 10 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch5-10',
      title: 'Down the Well-Kept Stair',
      dialogue: [
        DialogueLine.narrate(
            'Every landing has a lamp. Every lamp has oil. Somebody has been '
            'coming down here, alone, every week, for eleven years, to keep '
            'the lamps lit for a sister who cannot see them.'),
        DialogueLine('You', 'Ravenna.'),
        DialogueLine('Ravenna', 'Do not.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'What Gathers at the Landings',
      objective: 'It has been following the lamplighter down.',
      specialRules: [
        'The foe has 26 Health to your 25.',
      ],
      enemyHealth: 26,
    )),

    // ══ 11 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch5-11',
      title: 'Alone Below the Lamps',
      dialogue: [
        DialogueLine.narrate(
            'Past the last lamp the stair keeps going, and the guard does '
            'not.'),
        DialogueLine('Ravenna',
            'From here it is one at a time. That is not a rule of mine. It is '
            'a rule of the place.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Dark Below the Lamps',
      objective: 'Go on alone.',
      specialRules: ['No help on either side.', 'It has 26 Health.'],
      enemyHealth: 26,
    )),

    // ══ 12 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch5-12',
      title: 'The Sister',
      dialogue: [
        DialogueLine.narrate(
            'She is nineteen. She has been nineteen for eleven years. She is '
            'sitting with her back against the stone with her hands open on '
            'her knees, and she is entirely, unbearably awake.'),
        DialogueLine('The Sister', 'Ravenna. You are late with the oil.'),
        DialogueLine('Ravenna', 'I am four days early.'),
        DialogueLine('The Sister', 'Oh. Then it is worse than I thought.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'What She Has Been Holding',
      objective: 'Eleven years of it, in one place.',
      specialRules: ['No help on either side.', 'It has 27 Health.'],
      enemyHealth: 27,
    )),

    // ══ 13 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch5-13',
      title: 'A Duskveil Can Hold Ten Years',
      dialogue: [
        DialogueLine('The Sister',
            'Ten. Grandmother did ten. Her father did ten. Nobody has ever '
            'done eleven, and there is a reason nobody has ever done eleven.'),
        DialogueLine('You', 'What happens at eleven?'),
        DialogueLine('The Sister',
            'You stop being able to tell which of the two of you is doing the '
            'calling.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Blurring',
      objective: 'Two voices using one throat.',
      specialRules: [
        'The enemy opens with a creature in play.',
        'It has 27 Health.',
      ],
      enemyHealth: 27,
      enemyBoardIds: ['SF001-081'],
    )),

    // ══ 14 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch5-14',
      title: 'The First Caller',
      dialogue: [
        DialogueLine.narrate(
            'Beyond the sister, in the deepest chamber, there is a woman in '
            'the stone. She has been there for a thousand years and she turns '
            'her head when you come in.'),
        DialogueLine('The First Caller',
            'You are the one who has been shutting my doors.'),
        DialogueLine('You', 'I am.'),
        DialogueLine('The First Caller',
            'Good. Now sit down, because you are about to be very angry with '
            'four cities and I would rather you were sitting.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Thousand-Year Echo',
      objective: 'Her voice arrives before she does.',
      specialRules: [
        'The enemy opens with a creature in play.',
        'It has 28 Health.',
      ],
      enemyHealth: 28,
      enemyBoardIds: ['SF001-084'],
    )),

    // ══ 15 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch5-15',
      title: 'What Is Buried Beneath Her',
      dialogue: [
        DialogueLine('You', 'Tell me what you are holding down.'),
        DialogueLine('The First Caller', 'Nothing.'),
        DialogueLine('You', 'Nothing.'),
        DialogueLine('The First Caller',
            'There is nothing under me. There never was. I told five kings '
            'there was a horror beneath this stone because it was the only '
            'thing that would make them build cities on top of the doors '
            'instead of digging them out.'),
        DialogueLine('Thornmaw', 'A thousand years. You never told me that.'),
        DialogueLine('The First Caller',
            'You would have stopped visiting.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Lie She Told',
      objective: 'Nine hundred years of a story, gone solid.',
      specialRules: [
        'The enemy opens with a creature in play.',
        'It has 28 Health.',
      ],
      enemyHealth: 28,
      enemyBoardIds: ['SF001-085'],
    )),

    // ══ 16 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch5-16',
      title: 'Then What Has Been Hollowing Us',
      dialogue: [
        DialogueLine('The First Caller',
            'Me. Not on purpose. I have been calling for nine hundred years '
            'and nobody came, and a voice that is never answered does not stay '
            'a voice. It becomes weather.'),
        DialogueLine('You',
            'The blight. The erasure. The forge going cold. All of it was —'),
        DialogueLine('The First Caller',
            'A woman in a hole, asking. Yes. I am so sorry about your '
            'friend.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'Nine Hundred Years of Asking',
      objective: 'The weather she became.',
      specialRules: [
        'One of the watch stands with you.',
        'The enemy opens with two creatures in play.',
        'It has 29 Health.',
      ],
      enemyHealth: 29,
      enemyBoardIds: ['SF001-086', 'SF001-082'],
      playerBoardIds: ['SF001-084'],
    )),

    // ══ 17 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch5-17',
      title: 'The Warden Offers',
      dialogue: [
        DialogueLine('Thornmaw',
            'Then let me take the stone. I have sat over you for a thousand '
            'years already. I am practised.'),
        DialogueLine('The First Caller',
            'You are not willing, old friend. You are loving. It is a warmer '
            'thing and it is the wrong shape for this lock.'),
        DialogueLine('Thornmaw', 'Explain the difference.'),
        DialogueLine('The First Caller',
            'Willing means you could leave and you choose the stone anyway. '
            'You have never once believed you could leave.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Refusal',
      objective: 'The chamber rejects a warden who cannot leave.',
      specialRules: [
        'One of the watch stands with you.',
        'The enemy opens with two creatures in play.',
        'It has 30 Health.',
      ],
      enemyHealth: 30,
      enemyBoardIds: ['SF001-086', 'SF001-084'],
      playerBoardIds: ['SF001-084'],
    )),

    // ══ 18 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch5-18',
      title: 'Ravenna Duskveil Takes the Stone',
      dialogue: [
        DialogueLine('Ravenna',
            'I have kept the count for nineteen years. I have carried oil down '
            'four hundred and twelve times. I could walk up that stair tonight '
            'and be Queen of Nyxhollow until I died old.'),
        DialogueLine('Ravenna', 'Get up, little sister. You are relieved.'),
        DialogueLine('The Sister', 'Ravenna —'),
        DialogueLine('Ravenna',
            'Eleven years. You did eleven. Nobody has ever done eleven. Go and '
            'be nineteen somewhere with weather in it.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Handover',
      objective: 'Everything the stone has gathered fights the relief.',
      specialRules: [
        'One of the watch stands with you.',
        'The enemy opens with two creatures in play.',
        'It has 31 Health.',
      ],
      enemyHealth: 31,
      enemyBoardIds: ['SF001-086', 'SF001-085'],
      playerBoardIds: ['SF001-084'],
    )),

    // ══ 19 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch5-19',
      title: 'The Weather Objects',
      dialogue: [
        DialogueLine.narrate(
            'Nine hundred years of unanswered calling does not simply disperse '
            'because somebody finally answered. It has been a thing in its own '
            'right for a long time now.'),
        DialogueLine('The First Caller',
            'It is not mine any more, Caller. I made it and it left home. You '
            'will have to put it down yourself.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Unanswered',
      objective: 'What her voice turned into.',
      specialRules: [
        'One of the watch stands with you.',
        'It fights with real cunning.',
        'It has 33 Health and opens with two creatures.',
      ],
      enemyHealth: 32,
      enemyBoardIds: ['SF001-086', 'SF001-085'],
      playerBoardIds: ['SF001-084'],
      hardAi: true,
    )),

    // ══ 20 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch5-20',
      title: 'The Voice in the Heartshard',
      dialogue: [
        DialogueLine.narrate(
            'It goes up into the Heartshard and wears it, and nine hundred '
            'years of Nyxhollow\'s patience turns its face toward you.'),
        DialogueLine('The Voice',
            'Five cities heard me and four of them looked away. I am what is '
            'left when you do that for long enough.'),
        DialogueLine('You', 'I know. Someone is holding the stone now.'),
        DialogueLine('The Voice',
            'Then you have fixed the cause and left the consequence standing '
            'in front of you. How very like all five of you.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Voice in the Heartshard',
      objective: 'End nine hundred years of being ignored.',
      specialRules: [
        'One of the watch stands with you.',
        'It fights with everything five cities refused to hear.',
        'It has 44 Health and opens with two creatures.',
      ],
      enemyHealth: 44,
      enemyBoardIds: ['SF001-086', 'SF001-085'],
      playerBoardIds: ['SF001-084'],
      hardAi: true,
      preBattle: [
        DialogueLine('The Voice', 'Answer me properly, then.'),
      ],
      victory: [
        DialogueLine.narrate(
            'The Heartshard steadies. Under Nyxhollow a woman who has been '
            'nineteen for eleven years stands up, and above her a queen sits '
            'down with her hands open on her knees.'),
        DialogueLine('The First Caller',
            'Sylvaris, Ashmar, Meridine, Aurelia, Nyxhollow. Five doors shut, '
            'and one of them shut honestly. Do not let them forget which.'),
        DialogueLine('Thornmaw',
            'I will stay. Not for the lock — she is right, I was never the '
            'right shape for it. I will stay because somebody should be down '
            'here who chose to be, and because I have four hundred and twelve '
            'lamps to keep lit.'),
        DialogueLine.narrate(
            'You climb the well-kept stair alone. Behind you, for the first '
            'time in a thousand years, there is conversation in the dark.'),
        DialogueLine.narrate(
            'The five endure. Set One is closed.'),
      ],
    )),
  ],
);
