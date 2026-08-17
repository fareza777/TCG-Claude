import '../story_data.dart';

/// Chapter II — twenty scenes in Ashmar, where the eternal forge is going out.
///
/// The arc: a Warlord solves a heat shortage with arithmetic and atrocity, a
/// Tide fleet blockades the coast for reasons nobody will say out loud, and the
/// Heartforge turns out never to have been fed by the mountain at all. Ashmar
/// has spent a thousand years burning the same buried thing Sylvaris built a
/// lid over — and it has stopped giving, deliberately, to make them dig.
///
/// The ramp matches Chapter I: scene 1 is a tutorial with two creatures
/// already in play, scenes 2–3 drop to one, from scene 4 you stand alone,
/// boards appear against you at 13, and Draxus closes the chapter on 36
/// Health with the smarter AI.
const chapterTwo = StoryChapter(
  id: 'ch2',
  title: 'Chapter II — The Dying Forge',
  subtitle: 'A Pyre story',
  playerDominion: 'PYRE',
  stages: [
    // ══ 1 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch2-01',
      title: 'Ashmar, Cold',
      dialogue: [
        DialogueLine.narrate(
            'You smell Ashmar three days before you see it, and what you smell '
            'is wrong: not smoke, but wet ash. Rain has been falling on the '
            'city of fire and nothing has been drying it.'),
        DialogueLine.narrate(
            'The Heartforge still burns at the centre of the caldera. It is '
            'the size of a cathedral and it is the colour of a dying coal.'),
        DialogueLine('Forgewright',
            'A thousand years, Caller. A thousand years it never once needed '
            'stoking, and now we feed it all night and by dawn it has given '
            'the heat back.'),
        DialogueLine('You', 'Given it back to what?'),
        DialogueLine('Forgewright', 'That is the question nobody here likes.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'Ash-Crawlers',
      objective: 'Something is nesting in the cooling slag.',
      specialRules: [
        'Two of Ashmar already stand with you.',
        'The foe has 15 Health to your 25.',
      ],
      enemyHealth: 15,
      playerBoardIds: ['SF001-021', 'SF001-023'],
      preBattle: [
        DialogueLine('Forgewright',
            'They never came near heat before. Now they sleep in it.'),
      ],
    )),

    // ══ 2 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch2-02',
      title: 'The Ration Line',
      dialogue: [
        DialogueLine.narrate(
            'Ashmar has begun rationing heat. The line for a warming-stone '
            'runs four streets and does not move quickly.'),
        DialogueLine('Old Smelter',
            'Third day I have stood here. Yesterday they turned the line away '
            'at dusk. Two did not walk home.'),
        DialogueLine('You', 'Who decides who gets a stone?'),
        DialogueLine('Old Smelter', 'The Warlord decides. The Warlord decides '
            'everything now.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'PYRE',
      enemyName: 'Stone-Thieves',
      objective: 'The line turns on itself.',
      specialRules: [
        'One of Ashmar stands with you.',
        'The foe has 16 Health to your 25.',
      ],
      enemyHealth: 16,
      playerBoardIds: ['SF001-021'],
      victory: [
        DialogueLine.narrate(
            'They were not thieves this morning. Ashmar is four days of cold '
            'away from not being Ashmar.'),
      ],
    )),

    // ══ 3 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch2-03',
      title: 'The Warlord\'s Arithmetic',
      dialogue: [
        DialogueLine.narrate(
            'Warlord Draxus reads the decree himself, from the forge steps, in '
            'a voice built for exactly this.'),
        DialogueLine('Draxus',
            'The outer holds will be emptied and burned. Their fuel comes to '
            'the Heartforge. Ashmar survives as a smaller Ashmar or it does '
            'not survive.'),
        DialogueLine('You', 'You are burning your own villages.'),
        DialogueLine('Draxus',
            'I am burning six thousand to keep sixty thousand. Give me a '
            'better number, Caller, and I will read that one instead.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'PYRE',
      enemyName: 'Draxus\' Enforcers',
      objective: 'A hold that will not be emptied.',
      specialRules: [
        'One of Ashmar stands with you.',
        'The foe has 18 Health to your 25.',
      ],
      enemyHealth: 18,
      playerBoardIds: ['SF001-021'],
      preBattle: [
        DialogueLine('Enforcer',
            'Step aside. We take no pleasure in this and we will do it '
            'anyway.'),
      ],
    )),

    // ══ 4 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch2-04',
      title: 'The Ember Widow',
      dialogue: [
        DialogueLine.narrate(
            'A woman waits at the hold gate with her husband\'s tools on her '
            'back and no husband.'),
        DialogueLine('Ember Widow',
            'He went down the vein with the third survey. Twelve went. Twelve '
            'came back. He was not one of the twelve, and one of them was not '
            'anyone.'),
        DialogueLine('You', 'Say that again.'),
        DialogueLine('Ember Widow',
            'Twelve went down and twelve came up, and one of the twelve who '
            'came up had never gone down.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Thirteenth Surveyor',
      objective: 'Find the one who came up uninvited.',
      specialRules: [
        'The foe has 20 Health to your 25.',
      ],
      enemyHealth: 20,
      victory: [
        DialogueLine.narrate(
            'What is left on the stones does not match any of the twelve, and '
            'does not match anything else either.'),
      ],
    )),

    // ══ 5 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch2-05',
      title: 'The Mouth of the Vein',
      dialogue: [
        DialogueLine.narrate(
            'The vein opens in the caldera floor like a wound that has been '
            'kept open on purpose. Warm air comes out of it in slow, even '
            'pushes.'),
        DialogueLine('Forgewright', 'That is not a draught, Caller.'),
        DialogueLine('You', 'No. That is breathing.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Vein\'s Watchers',
      objective: 'Something guards the entrance from the inside.',
      specialRules: [
        'The foe has 22 Health to your 25.',
      ],
      enemyHealth: 22,
    )),

    // ══ 6 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch2-06',
      title: 'The Blockade',
      dialogue: [
        DialogueLine.narrate(
            'Word comes up from the coast: Meridine has closed the sea. Tide '
            'hulls sit in a ring around Ashmar\'s harbours, and they are not '
            'firing.'),
        DialogueLine('Draxus',
            'A siege without a shot. They mean to watch us go cold and then '
            'walk in.'),
        DialogueLine('Forgewright',
            'Or they mean nothing to leave. Warlord — they are facing '
            'outward.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'TIDE',
      enemyName: 'The Meridine Blockade',
      objective: 'Break the ring, or learn why it is there.',
      specialRules: [
        'The foe has 23 Health to your 25.',
      ],
      enemyHealth: 23,
    )),

    // ══ 7 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch2-07',
      title: 'Archivist Numen',
      dialogue: [
        DialogueLine.narrate(
            'The Tide envoy comes ashore alone, robed to the fingertips, '
            'carrying a coral staff and no weapon.'),
        DialogueLine('Numen',
            'We are not besieging you. We are containing you. There is a '
            'difference, and you will like it less.'),
        DialogueLine('You', 'Containing what?'),
        DialogueLine('Numen',
            'Whatever comes up that vein when your fire finally fails. The '
            'Archive has a word for it. I am forbidden to say the word.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'TIDE',
      enemyName: 'Numen\'s Wardens',
      objective: 'Her escort does not share her patience.',
      specialRules: [
        'The foe has 24 Health to your 25.',
      ],
      enemyHealth: 24,
    )),

    // ══ 8 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch2-08',
      title: 'What the Archive Read',
      dialogue: [
        DialogueLine('Numen',
            'Your Heartforge has no fuel source. It never had. Meridine '
            'measured the mountain nine hundred years ago and the mountain '
            'does not produce a tenth of what you burn.'),
        DialogueLine('You', 'Then where has the heat come from?'),
        DialogueLine('Numen',
            'Up. From something that has been giving it to you, without '
            'complaint, for a thousand years.'),
        DialogueLine('You', 'Giving?'),
        DialogueLine('Numen', 'I chose that word carefully, Caller.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Cinder Chorus',
      objective: 'The slag heaps stand up.',
      specialRules: [
        'The foe has 25 Health to your 25.',
      ],
      enemyHealth: 25,
    )),

    // ══ 9 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch2-09',
      title: 'Emberhold Burns',
      dialogue: [
        DialogueLine.narrate(
            'Draxus does not wait for the argument to finish. Emberhold goes '
            'up at dusk, and the column of smoke is the brightest thing in '
            'Ashmar for the first time in a season.'),
        DialogueLine('Draxus',
            'Four hundred souls, and the Heartforge came up two shades. Say it '
            'was not worth it. Say it to the sixty thousand.'),
        DialogueLine('You', 'It came up two shades for one night.'),
        DialogueLine('Draxus', 'Then we will need more holds.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'PYRE',
      enemyName: 'The Emberhold Survivors',
      objective: 'They blame the wrong person, and they are armed.',
      specialRules: [
        'The foe has 25 Health to your 25.',
      ],
      enemyHealth: 25,
    )),

    // ══ 10 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch2-10',
      title: 'Ashmar Splits',
      dialogue: [
        DialogueLine.narrate(
            'By morning the city wears two colours. Draxus holds the forge and '
            'the granaries. The holds hold the roads.'),
        DialogueLine('Forgewright',
            'A civil war over a fire that is going out either way. There is a '
            'joke in that and I cannot find it.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'PYRE',
      enemyName: 'The Forge Loyalists',
      objective: 'Cut a road to the vein.',
      specialRules: [
        'The foe has 26 Health to your 25.',
      ],
      enemyHealth: 26,
    )),

    // ══ 11 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch2-11',
      title: 'Down the Vein',
      dialogue: [
        DialogueLine.narrate(
            'The descent takes a day. The walls are warm, then hot, then warm '
            'again — and the warmth arrives in slow, even pushes, the same '
            'rhythm as the mouth above.'),
        DialogueLine('Numen',
            'From here you go alone. My order permits me to observe. It does '
            'not permit me to help, and I am sorry for the distinction.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Deep Wardens',
      objective: 'The vein has an immune system.',
      specialRules: ['No help on either side.', 'They have 26 Health.'],
      enemyHealth: 26,
    )),

    // ══ 12 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch2-12',
      title: 'The Thing That Feeds',
      dialogue: [
        DialogueLine.narrate(
            'The vein opens into a chamber that is not a chamber. The walls '
            'move. They have been moving for a thousand years, slowly, in the '
            'rhythm of the heat.'),
        DialogueLine('You', 'Ashmar has not been mining.'),
        DialogueLine('Numen',
            'No. Ashmar has been drawing. And it has been letting you.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Vein\'s Antibodies',
      objective: 'It has finally noticed the wound.',
      specialRules: ['No help on either side.', 'They have 27 Health.'],
      enemyHealth: 27,
    )),

    // ══ 13 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch2-13',
      title: 'It Is Not Dying',
      dialogue: [
        DialogueLine('Numen',
            'Understand what you are looking at. The fire is not failing. It '
            'is being withheld.'),
        DialogueLine('You', 'Why would it stop now?'),
        DialogueLine('Numen',
            'Because a cold city digs. Because a starving Warlord burns his '
            'own holds and calls it arithmetic. Everything Ashmar has done '
            'this season, it did because the heat stopped.'),
        DialogueLine('You', 'It wanted us to come down here.'),
        DialogueLine('Numen', 'It has wanted that for a thousand years. This '
            'season it simply asked.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Invitation',
      objective: 'Something holds the way open for you.',
      specialRules: [
        'The enemy opens with a creature in play.',
        'It has 27 Health.',
      ],
      enemyHealth: 27,
      enemyBoardIds: ['SF001-081'],
    )),

    // ══ 14 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch2-14',
      title: 'Kaelis, Who Went Down in Sylvaris',
      dialogue: [
        DialogueLine.narrate(
            'A man walks out of the deep dark of an Ashmaran vein, a month\'s '
            'travel from the shaft he descended, and he is not out of breath.'),
        DialogueLine('Kaelis', 'Caller.'),
        DialogueLine('You', 'You went down under the World-Oak.'),
        DialogueLine('Kaelis',
            'I did. I have not walked a single step since. It is one place '
            'down here. Sylvaris, Ashmar, Meridine — one room with a thousand '
            'doors, and we built our cities on the doors.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'What Walks With Kaelis',
      objective: 'He did not come up alone.',
      specialRules: [
        'The enemy opens with a creature in play.',
        'It has 28 Health.',
      ],
      enemyHealth: 28,
      enemyBoardIds: ['SF001-084'],
    )),

    // ══ 15 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch2-15',
      title: 'Tracks in the Ash',
      dialogue: [
        DialogueLine.narrate(
            'In the fine grey ash of the chamber floor there are hoofprints. '
            'Enormous ones. They come from the direction of Sylvaris and they '
            'go deeper.'),
        DialogueLine('You', 'Thornmaw.'),
        DialogueLine('Kaelis',
            'He passed through eleven days ago and he did not stop. He is the '
            'only one down here who knows where he is going.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Hollowed Twelve',
      objective: 'The survey crew, still working.',
      specialRules: [
        'The enemy opens with a creature in play.',
        'They have 28 Health.',
      ],
      enemyHealth: 28,
      enemyBoardIds: ['SF001-085'],
    )),

    // ══ 16 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch2-16',
      title: 'Numen\'s Instruction',
      dialogue: [
        DialogueLine('Numen',
            'Meridine\'s order is to flood the vein. Sea water, all of it, '
            'until Ashmar is a lake and the door is shut.'),
        DialogueLine('You', 'Sixty thousand people live on top of that door.'),
        DialogueLine('Numen',
            'Yes. I have been carrying that order in my sleeve for nine days '
            'and I have not read it aloud once.'),
        DialogueLine('You', 'Then don\'t.'),
        DialogueLine('Numen',
            'Give me the alternative and I will burn it in front of you.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'TIDE',
      enemyName: 'The Floodwrights',
      objective: 'Her own engineers came ahead of the order.',
      specialRules: [
        'The enemy opens with two creatures in play.',
        'They have 29 Health.',
      ],
      enemyHealth: 29,
      enemyBoardIds: ['SF001-043', 'SF001-042'],
    )),

    // ══ 17 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch2-17',
      title: 'The Alternative',
      dialogue: [
        DialogueLine('You', 'Let the Heartforge go out.'),
        DialogueLine('Numen', 'Ashmar freezes.'),
        DialogueLine('You',
            'Ashmar freezes for one winter. The draw stops, the wound closes, '
            'and it has nothing left to bargain with.'),
        DialogueLine('Kaelis',
            'It will not simply allow that, Caller. It has spent a thousand '
            'years making sure we could not survive without it.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Withdrawal',
      objective: 'It takes back everything at once.',
      specialRules: [
        'The enemy opens with two creatures in play.',
        'It has 30 Health.',
      ],
      enemyHealth: 30,
      enemyBoardIds: ['SF001-082', 'SF001-084'],
    )),

    // ══ 18 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch2-18',
      title: 'The Last Order',
      dialogue: [
        DialogueLine.narrate(
            'Draxus has the Heartforge stoked to a height it has not reached '
            'in living memory. Every hold in Ashmar is burning to feed it.'),
        DialogueLine('Draxus',
            'You want me to let it go dark. I will do the opposite. I will '
            'burn so hot the thing below gives back everything it has taken.'),
        DialogueLine('You', 'You will wake it.'),
        DialogueLine('Draxus',
            'Then it will be awake, and cold, and in my city — where I have '
            'sixty thousand and a mountain of fuel.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'PYRE',
      enemyName: 'The Forge Guard',
      objective: 'Reach the Heartforge before it is fed again.',
      specialRules: [
        'The enemy opens with two creatures in play.',
        'They have 31 Health.',
      ],
      enemyHealth: 31,
      enemyBoardIds: ['SF001-026', 'SF001-025'],
    )),

    // ══ 19 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch2-19',
      title: 'Kaelis Keeps a Promise',
      dialogue: [
        DialogueLine.narrate(
            'Kaelis steps between you and the forge stair, and the black in '
            'his veins has reached his throat.'),
        DialogueLine('Kaelis',
            'It is using me to hold this door. I can feel exactly how it '
            'intends to do it.'),
        DialogueLine('You', 'I promised you an ending.'),
        DialogueLine('Kaelis',
            'You did. But not yet — I have one thing left that it does not '
            'expect. Take the stair. I will hold the door shut from this '
            'side.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Vein\'s Grip',
      objective: 'Everything it has, to keep you off the stair.',
      specialRules: [
        'It fights with real cunning.',
        'It has 32 Health and opens with two creatures.',
      ],
      enemyHealth: 32,
      enemyBoardIds: ['SF001-086', 'SF001-084'],
      hardAi: true,
    )),

    // ══ 20 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch2-20',
      title: 'Warlord Draxus',
      dialogue: [
        DialogueLine.narrate(
            'Draxus waits at the top of the forge stair with the Heartforge '
            'roaring white behind him, and he looks, for the first time, like '
            'a man who has done the arithmetic twice.'),
        DialogueLine('Draxus',
            'I know what it is. I have known since the third survey. Do you '
            'imagine that changes what a Warlord is for?'),
        DialogueLine('You', 'Let it go out, Draxus.'),
        DialogueLine('Draxus',
            'And be the man who froze Ashmar. No, Caller. Take the forge from '
            'me if you want it dark.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'PYRE',
      enemyName: 'Warlord Draxus',
      objective: 'Take the Heartforge, and put it out.',
      specialRules: [
        'He fights with everything Ashmar has left.',
        'Draxus has 36 Health and opens with two creatures.',
      ],
      enemyHealth: 36,
      enemyBoardIds: ['SF001-027', 'SF001-026'],
      hardAi: true,
      preBattle: [
        DialogueLine('Draxus', 'Sixty thousand, Caller. Be sure.'),
      ],
      victory: [
        DialogueLine.narrate(
            'The Heartforge goes out at the ninth hour of the night. A '
            'thousand years of light, and the sound it makes going is almost '
            'nothing at all.'),
        DialogueLine('Draxus',
            'Cold. So this is what the rest of the world has been doing all '
            'along.'),
        DialogueLine.narrate(
            'Deep below, the drawing stops. The wound begins to close. And '
            'somewhere further down, something that has been patient for a '
            'thousand years turns its attention elsewhere.'),
        DialogueLine('Numen',
            'It will look for another door. There are three left, and mine is '
            'the one made of paper.'),
        DialogueLine.narrate(
            'Ashmar endures, and shivers. The tale turns to the deep water.'),
      ],
    )),
  ],
);
