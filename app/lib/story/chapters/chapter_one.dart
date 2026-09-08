import '../story_data.dart';

/// Chapter I — twenty scenes, each its own beat of story and its own fight.
///
/// The shape is the campaign's original one: a storyboard beat with its own art
/// sets a scene, then the battle that scene has been building toward.
///
/// The arc: the Grove's guardian has kept a thousand-year watch, a rival Caller
/// arrives already hollowed, three separate powers turn out to be digging for
/// the same thing, and what is buried under the World-Oak is not the Shard.
/// Ravenna Duskveil — the villain of the Grove's own stories — is the last one
/// standing between the Caller and it, and she is not the villain.
///
/// Difficulty climbs deliberately and never dips, and the help tapers instead
/// of sitting flat. Scene 1 is a pure tutorial — two creatures already in play
/// against a foe on 15 Health and the gentlest AI, so the rules land while you
/// are winning. Scenes 2 and 3 drop to one creature, and from scene 4 you are
/// on your own against a foe that is still under strength. The foe starts
/// fielding boards at scene 13, and Ravenna closes on 34 Health with the
/// smarter AI.
///
/// The rules shown on the briefing screen for the opening ten are generated
/// from the scenario's real numbers, so the text cannot drift away from the
/// fight it is describing.
const chapterOne = StoryChapter(
  id: 'ch1',
  title: 'Chapter I — The Waking Grove',
  subtitle: 'A Verdance story',
  playerDominion: 'VERDANCE',
  stages: [
    // ══ 1 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch1-01',
      title: 'The Waking Grove',
      dialogue: [
        DialogueLine.narrate(
            'A thousand years ago the star Vael shattered and its five Shards '
            'fell upon Aethyr. The emerald Shard came down in Sylvaris, and '
            'the forest grew over it the way skin grows over a splinter.'),
        DialogueLine.narrate(
            'Tonight the leaves are wrong. A wind out of the southern marshes '
            'carries rot, and the great stag Thornmaw has stopped grazing.'),
        DialogueLine('Thornmaw', 'You feel it. Say what you feel.'),
        DialogueLine(
            'You', 'Something crossed the border, and the border let it.'),
        DialogueLine('Thornmaw',
            'Yes. Come. I will not send you out blind, and I will not send you '
            'out alone.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'A Creeping Blight',
      objective: 'Learn the shape of a fight.',
      specialRules: [
        'Two of the Grove already stand with you.',
        'The foe has 15 Health to your 25.',
      ],
      enemyHealth: 15,
      playerBoardIds: ['SF001-001', 'SF001-003'],
      preBattle: [
        DialogueLine('Thornmaw',
            'Two of mine are already standing. Send them forward. That is the '
            'whole of attacking.'),
      ],
      victory: [
        DialogueLine('You', 'A scout.'),
        DialogueLine('Thornmaw', 'Scouts are sent. Remember that word.'),
      ],
    )),

    // ══ 2 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch1-02',
      title: 'Where Nothing Grows Back',
      dialogue: [
        DialogueLine.narrate(
            'By morning the clearing where the blight fell is bare. Not '
            'burned, not poisoned — simply refusing.'),
        DialogueLine('Thornmaw',
            'The Grove heals everything. It has healed worse than this in a '
            'single night.'),
        DialogueLine('You', 'Then why not this?'),
        DialogueLine('Thornmaw', 'Because this is not a wound. It is a mark.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'Marsh Vermin',
      objective: 'Drive the vermin off the mark.',
      specialRules: [
        'One of the Grove stands with you.',
        'The foe has 16 Health to your 25.',
      ],
      enemyHealth: 16,
      playerBoardIds: ['SF001-001'],
      preBattle: [
        DialogueLine('Thornmaw',
            'Lay a Wellspring every turn. Every turn, without exception. A '
            'Caller who forgets is a Caller who watches.'),
      ],
      victory: [
        DialogueLine.narrate(
            'They were not feeding. They stood on the bare ground facing '
            'outward, as if guarding it.'),
      ],
    )),

    // ══ 3 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch1-03',
      title: 'The Sproutling\'s Question',
      dialogue: [
        DialogueLine.narrate(
            'A sylvaris sproutling, barely a season old, follows you to the '
            'root-line and will not be shooed away.'),
        DialogueLine('Sproutling', 'Warden. What is under the Oak?'),
        DialogueLine('Thornmaw', 'The Shard is under the Oak.'),
        DialogueLine('Sproutling',
            'I know what the Shard smells like. That is not what is under the '
            'Oak.'),
        DialogueLine.narrate(
            'Thornmaw does not answer. He turns, and the conversation is '
            'over.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Skittering Pack',
      objective: 'Hold the root-line.',
      specialRules: [
        'One of the Grove stands with you.',
        'The foe has 18 Health to your 25.',
      ],
      enemyHealth: 18,
      playerBoardIds: ['SF001-001'],
      preBattle: [
        DialogueLine('Thornmaw',
            'Thick bark in front. A creature with high Guard survives what it '
            'blocks, and the Grove cannot spare what it does not have to.'),
      ],
    )),

    // ══ 4 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch1-04',
      title: 'Kaelis Comes North',
      dialogue: [
        DialogueLine.narrate(
            'A man staggers out of the southern treeline with a marsh still '
            'drying on him, and the ember-brand of Ashmar burnt into his '
            'pauldron. Kaelis Emberborn. Everyone knows that name.'),
        DialogueLine('Kaelis',
            'Nyxhollow is not raiding, Caller. They are surveying. There is a '
            'difference, and the difference should frighten you.'),
        DialogueLine('You', 'Ashmar is a month west. Why come here?'),
        DialogueLine('Kaelis',
            'Because they are surveying there too, and our fire is going out.'),
        DialogueLine('You', 'Surveying for what?'),
        DialogueLine('Kaelis', 'For depth.'),
        DialogueLine.narrate(
            'Thornmaw has not moved since Kaelis appeared. He is watching him '
            'the way you watch a fire indoors.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'Rotfeeder Swarm',
      objective: 'Clear the trail Kaelis dragged behind him.',
      specialRules: [
        'The foe has 20 Health to your 25.',
      ],
      enemyHealth: 20,
      preBattle: [
        DialogueLine('Kaelis',
            'They followed me. I am sorry. They always follow me now.'),
      ],
    )),

    // ══ 5 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch1-05',
      title: 'The First Blade',
      dialogue: [
        DialogueLine.narrate(
            'The next thing across the border does not skitter. It walks '
            'upright, it carries steel, and it stops when it sees you — which '
            'nothing mindless has ever done.'),
        DialogueLine('Kaelis', 'That is a surveyor\'s escort.'),
        DialogueLine('You', 'It is looking at the Oak.'),
        DialogueLine('Kaelis',
            'They are all looking at the Oak. That is the entire problem.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The First Cutthroat',
      objective: 'Stop it before it reports.',
      specialRules: [
        'The foe has 22 Health to your 25.',
      ],
      enemyHealth: 22,
      victory: [
        DialogueLine.narrate(
            'It carried no loot and no rations. Only a measuring cord, knotted '
            'at intervals, already half used.'),
      ],
    )),

    // ══ 6 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch1-06',
      title: 'The Blightherald\'s Terms',
      dialogue: [
        DialogueLine.narrate(
            'At dusk something walks openly up the deer-path with both hands '
            'empty, which is its own kind of threat.'),
        DialogueLine('Blightherald',
            'Lady Duskveil offers terms. Stand aside from the Oak and Sylvaris '
            'keeps every leaf it has. She does not want your forest.'),
        DialogueLine('You', 'And if we refuse?'),
        DialogueLine('Blightherald',
            'Then she comes anyway, and the forest is simply in the way.'),
        DialogueLine('Thornmaw', 'Kill it.'),
        DialogueLine.narrate(
            'It is the first order Thornmaw has ever given you. He does not '
            'give orders. He asks.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'Blightherald of Nyxhollow',
      objective: 'Refuse the terms in the only language it brought.',
      specialRules: [
        'The foe has 23 Health to your 25.',
      ],
      enemyHealth: 23,
      preBattle: [
        DialogueLine('Blightherald',
            'She said you would do this. She said to tell you she is sorry.'),
      ],
    )),

    // ══ 7 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch1-07',
      title: 'What the Warden Will Not Say',
      dialogue: [
        DialogueLine('You',
            'It offered terms and you had it killed before it finished. Why?'),
        DialogueLine('Thornmaw', 'Because I have heard those terms before.'),
        DialogueLine('You', 'When?'),
        DialogueLine.narrate('Thornmaw walks away.'),
        DialogueLine('Kaelis',
            'Watch him, Caller. That was not a warden protecting a secret. '
            'That was something frightened protecting itself.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Carrion Swarm',
      objective: 'The sky fills before the argument finishes.',
      specialRules: [
        'The foe has 24 Health to your 25.',
      ],
      enemyHealth: 24,
    )),

    // ══ 8 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch1-08',
      title: 'The Root Map',
      dialogue: [
        DialogueLine.narrate(
            'Among the swarm\'s nest you find oilcloth, and on the oilcloth a '
            'map. Not of the forest — of the roots beneath it. Every taproot, '
            'every hollow, drawn true.'),
        DialogueLine('Kaelis',
            'No outsider surveyed this. This was drawn from underneath.'),
        DialogueLine('You', 'Then someone here drew it.'),
        DialogueLine('Kaelis', 'Or something here did.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'Duskblade Scout',
      objective: 'It came back for the map.',
      specialRules: [
        'The foe has 25 Health to your 25.',
      ],
      enemyHealth: 25,
    )),

    // ══ 9 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch1-09',
      title: 'Kaelis\' Vanguard',
      dialogue: [
        DialogueLine.narrate(
            'Warriors come up the deer-path in formation, and you recognise '
            'their colours before you recognise that they are attacking.'),
        DialogueLine('You', 'Those are yours.'),
        DialogueLine('Kaelis',
            'Those were mine. I have not commanded anything for eleven days.'),
        DialogueLine('Kaelis',
            'I did not come north to warn you, Caller. I came north because '
            'something walked me here.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'Kaelis\' Vanguard',
      objective: 'Put down men who were allies this morning.',
      specialRules: [
        'The foe has 25 Health to your 25.',
      ],
      enemyHealth: 25,
      victory: [
        DialogueLine.narrate(
            'They do not rout. They stop, all at once, like a hand letting '
            'go.'),
      ],
    )),

    // ══ 10 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch1-10',
      title: 'The Black in His Veins',
      dialogue: [
        DialogueLine.narrate(
            'Kaelis rolls back his sleeve without being asked. The dark is '
            'past his elbow, and it is not spreading — it is arriving, in '
            'pulses, from somewhere else.'),
        DialogueLine('Kaelis',
            'Eleven days. Since I stood at the edge of their dig and looked '
            'down.'),
        DialogueLine('You', 'Then you are already theirs.'),
        DialogueLine('Kaelis',
            'I am already something\'s. Theirs would be simpler. When I stop '
            'being able to say so — end it. Say you will.'),
        DialogueLine('You', 'I will.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'PYRE',
      enemyName: 'Emberpack Outriders',
      objective: 'Ashmar sold them an escort.',
      specialRules: [
        'The foe has 26 Health to your 25.',
      ],
      enemyHealth: 26,
      preBattle: [
        DialogueLine('Kaelis',
            'Those are Ashmar riders. My riders. Duskveil is paying in coin '
            'now instead of fear, and my people are taking it, because a cold '
            'forge does not feed anyone.'),
      ],
    )),

    // ══ 11 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch1-11',
      title: 'The Marsh Comes Inland',
      dialogue: [
        DialogueLine.narrate(
            'The southern bog has moved four hundred paces in a night. Trees '
            'that stood a thousand years are standing in water now, drowning '
            'politely, without complaint.'),
        DialogueLine('Thornmaw',
            'From here you fight alone. Not as punishment — because they are '
            'counting my herd, and I would rather the count were wrong.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Mireborn Ambush',
      objective: 'The water fights back.',
      specialRules: ['No help on either side.', 'The mire has 26 Health.'],
      enemyHealth: 26,
    )),

    // ══ 12 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch1-12',
      title: 'Dawn\'s Trespass',
      dialogue: [
        DialogueLine.narrate(
            'Gold on the ridgeline. Aurelian knights, banners high, marching '
            'into a war nobody invited them to.'),
        DialogueLine('Inquisitor',
            'Sylvaris has proven it cannot hold its Shard. Aurelia will take '
            'it into safekeeping. Stand down and no leaf burns.'),
        DialogueLine('Kaelis',
            'Two armies, one hole. Ask yourself how both of them learned about '
            'it in the same season.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'DAWN',
      enemyName: 'Dawn\'s Trespass',
      objective: 'Refuse the safekeeping.',
      specialRules: ['No help on either side.', 'The knights have 27 Health.'],
      enemyHealth: 27,
    )),

    // ══ 13 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch1-13',
      title: 'Two Enemies, One Hole',
      dialogue: [
        DialogueLine.narrate(
            'From the ridge you can see both digs at once. Nyxhollow from the '
            'south, Aurelia from the east. Neither is aimed at the Shard.'),
        DialogueLine('You', 'They are converging on a point beside it.'),
        DialogueLine('Thornmaw', 'Yes.'),
        DialogueLine('You', 'You knew. You have known since the first night.'),
        DialogueLine('Thornmaw', 'I have known for a thousand years.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Hollow Chorus',
      objective: 'They sing to keep the diggers working.',
      specialRules: [
        'The enemy opens with a creature in play.',
        'The chorus has 27 Health.',
      ],
      enemyHealth: 27,
      enemyBoardIds: ['SF001-081'],
    )),

    // ══ 14 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch1-14',
      title: 'What the Oak Was Planted On',
      dialogue: [
        DialogueLine('Thornmaw',
            'The Shard did not make this forest. It fell on a battlefield that '
            'was already old, and the first Caller lies under it — and the '
            'first Caller was not of Verdance.'),
        DialogueLine('You', 'What was she?'),
        DialogueLine('Thornmaw',
            'Gloom. The Grove was not grown to protect the Shard, Caller. The '
            'Grove is a lid.'),
        DialogueLine.narrate(
            'A thousand years of stories, and every one of them was the same '
            'lie told gently.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'Gravebound Digger',
      objective: 'Stop it before it reaches the lid.',
      specialRules: [
        'The enemy opens with a creature in play.',
        'The digger has 28 Health.',
      ],
      enemyHealth: 28,
      enemyBoardIds: ['SF001-084'],
    )),

    // ══ 15 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch1-15',
      title: 'The Grove Turns',
      dialogue: [
        DialogueLine.narrate(
            'The wardens you grew up beside are walking south with black in '
            'their veins, in step, in silence.'),
        DialogueLine('Kaelis',
            'It is not converting them. It is calling them. The difference is '
            'that they want to go.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Hollowed Warden',
      objective: 'One of your own, and she knows your name.',
      specialRules: [
        'The enemy opens with a creature in play.',
        'The warden has 28 Health.',
      ],
      enemyHealth: 28,
      enemyBoardIds: ['SF001-085'],
    )),

    // ══ 16 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch1-16',
      title: 'Kaelis Walks Down',
      dialogue: [
        DialogueLine.narrate(
            'You find his sword planted at the lip of the shaft and Kaelis '
            'already ten paces below it, going down without a torch.'),
        DialogueLine('Kaelis',
            'It has been pulling me since the marsh. If it wants me down there '
            'so badly, let it have me while I still choose the timing.'),
        DialogueLine('You', 'Kaelis —'),
        DialogueLine('Kaelis',
            'You promised me an ending. This is me taking it first.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Rotting Choir',
      objective: 'They close the shaft behind him.',
      specialRules: [
        'One of the grove wardens stands with you.',
        'The enemy opens with two creatures in play.',
        'The choir has 29 Health.',
      ],
      enemyHealth: 29,
      enemyBoardIds: ['SF001-081', 'SF001-083'],
      playerBoardIds: ['SF001-003'],
    )),

    // ══ 17 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch1-17',
      title: 'It Answers in His Voice',
      dialogue: [
        DialogueLine.narrate(
            'Something comes back up the shaft. It has Kaelis\' voice and it '
            'is using it carefully, like a borrowed coat.'),
        DialogueLine('The Voice',
            'He asked you to end it. You said you would. You are very slow.'),
        DialogueLine('You', 'What are you?'),
        DialogueLine('The Voice',
            'The thing your warden has been standing on. Ask him how tired he '
            'is.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'Blightfather\'s Herald',
      objective: 'Silence the borrowed voice.',
      specialRules: [
        'One of the grove wardens stands with you.',
        'The enemy opens with two creatures in play.',
        'The herald has 30 Health.',
      ],
      enemyHealth: 30,
      enemyBoardIds: ['SF001-082', 'SF001-084'],
      playerBoardIds: ['SF001-003'],
    )),

    // ══ 18 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch1-18',
      title: 'Ravenna at the Roots',
      dialogue: [
        DialogueLine.narrate(
            'Ravenna Duskveil stands at the shaft with her own dead stacked '
            'around her like sandbags. She is not digging. She is filling it '
            'in.'),
        DialogueLine('Ravenna',
            'Nine hundred years my house has held this lid down from the other '
            'side while your forest took the credit. Do you know what your '
            'warden did the first night I sent word?'),
        DialogueLine('You', 'He had your herald killed.'),
        DialogueLine('Ravenna', 'He has had eleven of them killed.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Last Warden',
      objective: 'Thornmaw\'s own guard bars the shaft.',
      specialRules: [
        'One of the grove wardens stands with you.',
        'The enemy opens with two creatures in play.',
        'The warden has 31 Health.',
      ],
      enemyHealth: 31,
      enemyBoardIds: ['SF001-084', 'SF001-085'],
      playerBoardIds: ['SF001-003'],
    )),

    // ══ 19 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch1-19',
      title: 'A Thousand Years of Waiting',
      dialogue: [
        DialogueLine.narrate(
            'Thornmaw comes through the treeline at a run, and he does not go '
            'for the diggers. He goes for Ravenna.'),
        DialogueLine('Ravenna', 'There. Now you have seen it.'),
        DialogueLine('You', 'Warden. Stop.'),
        DialogueLine('Thornmaw',
            'A thousand years I stood over her grave, Caller, and every single '
            'one of them I stood there listening.'),
        DialogueLine('Thornmaw',
            'Do you understand? I was not guarding it. I was keeping it '
            'company.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Dusk Vanguard',
      objective: 'Ravenna\'s guard will not let you near her.',
      specialRules: [
        'One of the grove wardens stands with you.',
        'They fight with real cunning.',
        'The vanguard has 31 Health and opens with two creatures.',
      ],
      enemyHealth: 32,
      enemyBoardIds: ['SF001-085', 'SF001-083'],
      playerBoardIds: ['SF001-003'],
      hardAi: true,
    )),

    // ══ 20 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch1-20',
      title: 'Ravenna Duskveil',
      dialogue: [
        DialogueLine('Ravenna',
            'I will not hand nine hundred years to a Caller who has held the '
            'truth for one afternoon. Show me you can carry it.'),
        DialogueLine('You', 'You want to fight me while that thing is awake?'),
        DialogueLine('Ravenna',
            'I want to fight you because it is awake. If you cannot beat me '
            'you cannot hold the lid, and I will not die leaving it to you.'),
        DialogueLine.narrate('Behind her, the shaft exhales.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'Ravenna Duskveil',
      objective: 'Earn the truth she has carried alone.',
      specialRules: [
        'One of the grove wardens stands with you.',
        'She fights with everything she has.',
        'Ravenna has 34 Health and opens with two creatures.',
      ],
      enemyHealth: 34,
      enemyBoardIds: ['SF001-086', 'SF001-085'],
      playerBoardIds: ['SF001-003'],
      hardAi: true,
      preBattle: [
        DialogueLine('Ravenna', 'No terms this time, Caller. Come on.'),
      ],
      victory: [
        DialogueLine.narrate(
            'She goes down on one knee and stays there — breathing, alive, and '
            'for the first time in nine hundred years not alone in this.'),
        DialogueLine('Ravenna', 'Good. Now look behind you.'),
        DialogueLine.narrate(
            'The shaft is sealed. The lid is holding. And Thornmaw is gone — '
            'no body, no trail, only tracks going down.'),
        DialogueLine('Ravenna',
            'He has gone to keep it company. Ashmar next, Caller — their '
            'forges are going cold, and cold forges mean someone is digging '
            'there too.'),
        DialogueLine.narrate('The Grove endures. The tale turns west, to fire.'),
      ],
    )),
  ],
);
