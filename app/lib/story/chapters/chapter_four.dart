import '../story_data.dart';

/// Chapter IV — twenty scenes in Aurelia, the city that never erased anything.
///
/// The arc: the Inquisition carries the second archive home in triumph, and in
/// doing so hands the thing beneath the world nine hundred years of reading in
/// a single afternoon. Aurelia's creed is total truth, total record — which
/// makes it the perfect meal. The golden Halo everyone calls a blessing turns
/// out to be a lock, the founding miracle turns out to have been borrowed, and
/// Seraphel the Lightkeeper has been quietly breaking her own city's first
/// commandment for four hundred years to keep it shut.
const chapterFour = StoryChapter(
  id: 'ch4',
  title: 'Chapter IV — The Hollow Halo',
  subtitle: 'A Dawn story',
  playerDominion: 'DAWN',
  stages: [
    // ══ 1 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch4-01',
      title: 'The City That Never Sleeps',
      dialogue: [
        DialogueLine.narrate(
            'Aurelia has not known darkness in nine hundred years. The Halo '
            'hangs above the high spire and the light it throws does not cast '
            'shadows, which visitors find beautiful for about two days.'),
        DialogueLine('Seraphel',
            'You come from Meridine carrying bad news, and the Inquisition '
            'came back yesterday carrying eleven barges of shelves. Tell me '
            'which of you I should be more afraid of.'),
        DialogueLine('You', 'The barges.'),
        DialogueLine('Seraphel', 'Yes. I was hoping to be wrong.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'Shadowless Things',
      objective: 'Something walks in a city with no shadows.',
      specialRules: [
        'Two of the Chosen already stand with you.',
        'The foe has 15 Health to your 25.',
      ],
      enemyHealth: 15,
      playerBoardIds: ['SF001-061', 'SF001-063'],
    )),

    // ══ 2 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch4-02',
      title: 'The Wall of Edicts',
      dialogue: [
        DialogueLine.narrate(
            'Aurelia writes everything down and destroys nothing. The Wall of '
            'Edicts runs the length of the sanctum and it is nine hundred '
            'years deep in gold leaf.'),
        DialogueLine('You', 'Every law you have ever passed.'),
        DialogueLine('Seraphel',
            'Every law, every census, every confession. The first commandment '
            'of Aurelia is that a thing recorded cannot be taken from you.'),
        DialogueLine('You', 'In Meridine they proved the opposite.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Readers in the Stacks',
      objective: 'The barges are being unloaded tonight.',
      specialRules: [
        'One of the Chosen stands with you.',
        'The foe has 16 Health to your 25.',
      ],
      enemyHealth: 16,
      playerBoardIds: ['SF001-061'],
    )),

    // ══ 3 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch4-03',
      title: 'The Halo Flickers',
      dialogue: [
        DialogueLine.narrate(
            'At the fourth hour the Halo stutters. For the length of one '
            'breath, Aurelia has shadows. Nine hundred years, and nobody alive '
            'has seen their own.'),
        DialogueLine('Seraphel', 'Note the hour.'),
        DialogueLine('You', 'Why the hour?'),
        DialogueLine('Seraphel',
            'Because it is the eleventh time this season and I have all ten '
            'others written down, and they are getting closer together.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The First Shadows',
      objective: 'Things arrive in the flicker.',
      specialRules: [
        'One of the Chosen stands with you.',
        'The foe has 18 Health to your 25.',
      ],
      enemyHealth: 18,
      playerBoardIds: ['SF001-061'],
    )),

    // ══ 4 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch4-04',
      title: 'The Inquisitor\'s Triumph',
      dialogue: [
        DialogueLine.narrate(
            'The Inquisition parades the Meridine shelves through the Ivory '
            'Gate. Scribes have been copying them onto the Wall since dawn.'),
        DialogueLine('Inquisitor',
            'Nine hundred years of a drowned city\'s cowardice, brought into '
            'the light. Every erased word restored.'),
        DialogueLine('You', 'You are feeding it.'),
        DialogueLine('Inquisitor',
            'I am recording the truth. If your enemy is harmed by truth, '
            'Caller, examine which side you are on.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'What the Scribes Wrote',
      objective: 'The copied pages are not staying on the wall.',
      specialRules: [
        'The foe has 20 Health to your 25.',
      ],
      enemyHealth: 20,
    )),

    // ══ 5 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch4-05',
      title: 'The Lightkeeper\'s Confession',
      dialogue: [
        DialogueLine('Seraphel',
            'I am going to tell you something that would end me if the '
            'Inquisition heard it. I have been destroying records for four '
            'hundred years.'),
        DialogueLine('You', 'Aurelia\'s first commandment.'),
        DialogueLine('Seraphel',
            'I know what it is. I wrote the modern wording of it. And every '
            'decade I take eleven or twelve pages off that Wall and I burn '
            'them, and I have never once been caught, and I would do it '
            'again tonight.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'DAWN',
      enemyName: 'The Sanctum Watch',
      objective: 'Someone saw her leave the Wall.',
      specialRules: [
        'The foe has 22 Health to your 25.',
      ],
      enemyHealth: 22,
    )),

    // ══ 6 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch4-06',
      title: 'What the Halo Is',
      dialogue: [
        DialogueLine.narrate(
            'She takes you up the spire to the Halo, and this close it is not '
            'a ring of light. It is a mechanism, and it is under strain.'),
        DialogueLine('Seraphel', 'It is not a blessing. It is a lock.'),
        DialogueLine('You', 'On what?'),
        DialogueLine('Seraphel',
            'On the fourth door. Aurelia was built directly on top of it, and '
            'the light has been holding it shut since the founding.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Strain',
      objective: 'Something is testing the lock from below.',
      specialRules: [
        'The foe has 23 Health to your 25.',
      ],
      enemyHealth: 23,
    )),

    // ══ 7 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch4-07',
      title: 'The Borrowed Miracle',
      dialogue: [
        DialogueLine('Seraphel',
            'The founding miracle. Aurelia teaches that the light was given to '
            'us for our virtue. It was not given. It was lent.'),
        DialogueLine('You', 'Lent by whom?'),
        DialogueLine('Seraphel',
            'By the woman buried under Sylvaris. Every ray over this city for '
            'nine hundred years has been hers, and we have spent it, and we '
            'have never once said her name at a service.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'DAWN',
      enemyName: 'The Devout',
      objective: 'The truth reaches the congregation.',
      specialRules: [
        'The foe has 24 Health to your 25.',
      ],
      enemyHealth: 24,
    )),

    // ══ 8 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch4-08',
      title: 'The Inquisition Turns',
      dialogue: [
        DialogueLine.narrate(
            'They come for Seraphel at the sixth hour with a charge sheet four '
            'hundred years long and every entry on it true.'),
        DialogueLine('Inquisitor',
            'The Lightkeeper has been burning Aurelia\'s memory. She will '
            'answer for eleven thousand pages.'),
        DialogueLine('Seraphel',
            'Twelve thousand, four hundred and six. If you are going to hang '
            'me for it, hang me for the correct number.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'DAWN',
      enemyName: 'The Arrest Detail',
      objective: 'She is the only one holding the lock.',
      specialRules: [
        'The foe has 25 Health to your 25.',
      ],
      enemyHealth: 25,
    )),

    // ══ 9 ════════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch4-09',
      title: 'Hollow at the Gates',
      dialogue: [
        DialogueLine.narrate(
            'While Aurelia argues about a charge sheet, the thing under it '
            'walks up to the Ivory Gate in daylight and knocks.'),
        DialogueLine('Inquisitor', 'The gate has never been closed.'),
        DialogueLine('Seraphel', 'I am aware. Close it.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'Hollow at the Gates',
      objective: 'Nine hundred years, and the gate finally shuts.',
      specialRules: [
        'The foe has 25 Health to your 25.',
      ],
      enemyHealth: 25,
    )),

    // ══ 10 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch4-10',
      title: 'The Wall Reads Itself',
      dialogue: [
        DialogueLine.narrate(
            'The gold leaf on the Wall of Edicts begins to lift, letter by '
            'letter, and hangs in the air of the sanctum like a swarm.'),
        DialogueLine('Seraphel',
            'It is not stealing them. It is *finishing* them. Nine hundred '
            'years of Aurelian record, read in one night.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Golden Swarm',
      objective: 'Save what the Wall still holds.',
      specialRules: [
        'The foe has 26 Health to your 25.',
      ],
      enemyHealth: 26,
    )),

    // ══ 11 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch4-11',
      title: 'Alone on the Spire',
      dialogue: [
        DialogueLine.narrate(
            'The Chosen are holding the lower city. From here up, the spire is '
            'yours alone.'),
        DialogueLine('Seraphel',
            'Whatever you meet on these stairs, it will be wearing something '
            'you trust. That is what it does with a city that writes '
            'everything down — it knows exactly who you would open a door '
            'for.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'Something Wearing a Friend',
      objective: 'Climb the spire.',
      specialRules: ['No help on either side.', 'It has 26 Health.'],
      enemyHealth: 26,
    )),

    // ══ 12 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch4-12',
      title: 'The Aurelian Inquisition',
      dialogue: [
        DialogueLine.narrate(
            'The Inquisitor holds the middle landing with forty knights and '
            'the Halo flickering above all of them.'),
        DialogueLine('Inquisitor',
            'I have read the Meridine shelves. All of them. I know what the '
            'light is and I know what we owe.'),
        DialogueLine('You', 'Then stand aside.'),
        DialogueLine('Inquisitor',
            'And tell six hundred thousand faithful that their salvation was '
            'a loan from a corpse? No, Caller. Some truths are load-bearing '
            'and this one is not mine to pull out.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'DAWN',
      enemyName: 'The Aurelian Inquisition',
      objective: 'Take the landing.',
      specialRules: ['No help on either side.', 'They have 27 Health.'],
      enemyHealth: 27,
    )),

    // ══ 13 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch4-13',
      title: 'What He Read on the Barges',
      dialogue: [
        DialogueLine.narrate(
            'The Inquisitor is dying on the landing and he is still arguing, '
            'because he is Aurelian and that is what they do.'),
        DialogueLine('Inquisitor',
            'The clause. The fifth shall keep the count. Do you know what the '
            'count *is*, Caller? It is not a tally of tribute.'),
        DialogueLine('You', 'Then what?'),
        DialogueLine('Inquisitor', 'Years. Duskveil has been counting down.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Countdown',
      objective: 'Something has been waiting for a specific year.',
      specialRules: [
        'The enemy opens with a creature in play.',
        'It has 27 Health.',
      ],
      enemyHealth: 27,
      enemyBoardIds: ['SF001-081'],
    )),

    // ══ 14 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch4-14',
      title: 'The Ninth Hundredth Year',
      dialogue: [
        DialogueLine('Seraphel',
            'The pact was signed nine hundred and eleven years ago. The lock '
            'was cut for nine hundred.'),
        DialogueLine('You', 'It expired eleven years ago.'),
        DialogueLine('Seraphel',
            'Eleven years ago the Grove\'s moss stopped growing back in one '
            'clearing and nobody thought it was worth a letter.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'Eleven Years of Patience',
      objective: 'It has been polite for over a decade.',
      specialRules: [
        'The enemy opens with a creature in play.',
        'It has 28 Health.',
      ],
      enemyHealth: 28,
      enemyBoardIds: ['SF001-084'],
    )),

    // ══ 15 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch4-15',
      title: 'The Stag on the Stair',
      dialogue: [
        DialogueLine.narrate(
            'Thornmaw is standing on the upper stair with his flanks steaming '
            'in the cold, and he does not look surprised to see you.'),
        DialogueLine('Thornmaw', 'You are four days later than I hoped.'),
        DialogueLine('You', 'You have been ahead of me since Sylvaris.'),
        DialogueLine('Thornmaw',
            'I have been *opening* doors ahead of you since Sylvaris. Do not '
            'thank me yet. Ask me why.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'What Follows the Warden',
      objective: 'He does not travel alone any more.',
      specialRules: [
        'The enemy opens with a creature in play.',
        'It has 28 Health.',
      ],
      enemyHealth: 28,
      enemyBoardIds: ['SF001-085'],
    )),

    // ══ 16 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch4-16',
      title: 'Why the Warden Walks',
      dialogue: [
        DialogueLine('Thornmaw',
            'A thousand years I stood on her grave and listened to her. She is '
            'not a monster, Caller. She is a woman who was buried alive to '
            'hold something down, and five cities agreed to keep her fed and '
            'forget her name.'),
        DialogueLine('You', 'She has been erasing archives and hollowing '
            'people.'),
        DialogueLine('Thornmaw',
            'She has been *calling*. For nine hundred years. In every language '
            'any of us could hear. What would you have sounded like, by the '
            'end?'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Long Calling',
      objective: 'Nine centuries of unanswered voice.',
      specialRules: [
        'One of the Chosen stands with you.',
        'The enemy opens with two creatures in play.',
        'It has 29 Health.',
      ],
      enemyHealth: 29,
      enemyBoardIds: ['SF001-082', 'SF001-084'],
      playerBoardIds: ['SF001-063'],
    )),

    // ══ 17 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch4-17',
      title: 'What She Is Holding Down',
      dialogue: [
        DialogueLine('Seraphel', 'Warden. Finish it. What is under her?'),
        DialogueLine('Thornmaw',
            'I do not know. She would never say. In a thousand years of '
            'nights, that is the only question she refused.'),
        DialogueLine('Thornmaw',
            'But she said this: if she is ever freed, someone must be in the '
            'ground before she leaves it. Someone willing.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Thing Beneath the Thing',
      objective: 'A shape at the very bottom of the light.',
      specialRules: [
        'One of the Chosen stands with you.',
        'The enemy opens with two creatures in play.',
        'It has 30 Health.',
      ],
      enemyHealth: 30,
      enemyBoardIds: ['SF001-086', 'SF001-083'],
      playerBoardIds: ['SF001-063'],
    )),

    // ══ 18 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch4-18',
      title: 'The Lock Gives',
      dialogue: [
        DialogueLine.narrate(
            'The Halo tears. Aurelia has shadows for the first time in nine '
            'hundred years and they are all pointing the same way — down.'),
        DialogueLine('Seraphel',
            'Four hundred years I burned pages to buy this city time, and it '
            'bought eleven. Take the spire, Caller. I will hold what is left '
            'of the light.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Fourth Door',
      objective: 'It opens under the sanctum floor.',
      specialRules: [
        'One of the Chosen stands with you.',
        'The enemy opens with two creatures in play.',
        'It has 31 Health.',
      ],
      enemyHealth: 31,
      enemyBoardIds: ['SF001-086', 'SF001-084'],
      playerBoardIds: ['SF001-063'],
    )),

    // ══ 19 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch4-19',
      title: 'Seraphel Holds the Light',
      dialogue: [
        DialogueLine.narrate(
            'She walks into the broken Halo and the mechanism takes her the '
            'way a lock takes a key — completely, and without ceremony.'),
        DialogueLine('Seraphel',
            'Tell Aurelia the truth. All of it. We were never owed the light. '
            'Tell them, and then let them decide what kind of city they want '
            'to be in the dark.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'DAWN',
      enemyName: 'The Chosen, Hollowed',
      objective: 'The order she built comes up the stair.',
      specialRules: [
        'One of the Chosen stands with you.',
        'They fight with real cunning.',
        'They have 32 Health and open with two creatures.',
      ],
      enemyHealth: 32,
      enemyBoardIds: ['SF001-067', 'SF001-066'],
      playerBoardIds: ['SF001-063'],
      hardAi: true,
    )),

    // ══ 20 ═══════════════════════════════════════════════════════════════
    StoryStage.read(StoryBeat(
      artAsset: 'STORY-ch4-20',
      title: 'The Voice in the Halo',
      dialogue: [
        DialogueLine.narrate(
            'What is left of the Halo speaks, and it uses Seraphel\'s voice '
            'because it has just finished reading her.'),
        DialogueLine('The Voice',
            'Four cities. Four doors. Your warden opened three of them for '
            'you and you called it help.'),
        DialogueLine('You', 'He opened them so I could close them.'),
        DialogueLine('The Voice',
            'He opened them so you would be standing at the fifth when the '
            'count runs out. Go to Nyxhollow, Caller. Everyone else already '
            'has.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Voice in the Halo',
      objective: 'Take back the light Aurelia never owned.',
      specialRules: [
        'One of the Chosen stands with you.',
        'It fights with a stolen city behind it.',
        'It has 40 Health and opens with two creatures.',
      ],
      enemyHealth: 40,
      enemyBoardIds: ['SF001-086', 'SF001-085'],
      playerBoardIds: ['SF001-063'],
      hardAi: true,
      preBattle: [
        DialogueLine('The Voice',
            'She gave you an instruction with her last breath. Ask yourself '
            'who was listening when she said it.'),
      ],
      victory: [
        DialogueLine.narrate(
            'The Halo goes out. Aurelia stands in its first darkness in nine '
            'hundred years, and the shadows are ordinary, and long, and '
            'harmless.'),
        DialogueLine('Thornmaw',
            'Three doors shut. One left, and it is the one that has been '
            'counted down to.'),
        DialogueLine('You', 'You are going to tell me why you opened them.'),
        DialogueLine('Thornmaw',
            'In Nyxhollow. In front of Duskveil, so that there is a witness '
            'who can stop me if the answer is bad enough.'),
        DialogueLine.narrate(
            'Aurelia endures, in the dark. The tale turns at last to the '
            'thankless city.'),
      ],
    )),
  ],
);
