// Story campaign — dialogue-driven, RPG-style, with battle scenarios that
// carry objectives, special rules, and pre-set board states.
// Art references reuse card art ids (assets/art/ID.webp).

class DialogueLine {
  final String speaker; // '' for narration
  final String text;
  const DialogueLine(this.speaker, this.text);
  const DialogueLine.narrate(this.text) : speaker = '';
}

class StoryBeat {
  final String artAsset;
  final String title;
  final List<DialogueLine> dialogue;
  const StoryBeat({
    required this.artAsset,
    required this.title,
    required this.dialogue,
  });
}

/// A battle with RPG modifiers. Card ids are resolved to decks/boards by the
/// story screen against the loaded [CardLibrary].
class StoryBattle {
  final String enemyDominion; // starter deck key for the foe
  final String enemyName;
  final String objective;
  final List<String> specialRules;
  final int playerHealth;
  final int enemyHealth;
  final List<String> enemyBoardIds;
  final List<String> playerBoardIds;
  final List<DialogueLine> preBattle;
  final List<DialogueLine> victory;

  /// Boss fights use the smarter Strategist AI.
  final bool hardAi;

  const StoryBattle({
    required this.enemyDominion,
    required this.enemyName,
    this.objective = 'Reduce the enemy to 0 Health.',
    this.specialRules = const [],
    this.playerHealth = 25,
    this.enemyHealth = 25,
    this.enemyBoardIds = const [],
    this.playerBoardIds = const [],
    this.preBattle = const [],
    this.victory = const [],
    this.hardAi = false,
  });
}

class StoryStage {
  final StoryBeat? beat;
  final StoryBattle? battle;
  const StoryStage.read(StoryBeat this.beat) : battle = null;
  const StoryStage.fight(StoryBattle this.battle) : beat = null;
}

class StoryChapter {
  final String id;
  final String title;
  final String subtitle;
  final String playerDominion;
  final List<StoryStage> stages;
  const StoryChapter({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.playerDominion,
    required this.stages,
  });

  int get battleCount => stages.where((s) => s.battle != null).length;
}

// ════════════════════════════════════════════════════════════════════════
// CHAPTER I — THE WAKING GROVE (Verdance)
// ════════════════════════════════════════════════════════════════════════

const _chapter1 = StoryChapter(
  id: 'ch1',
  title: 'Chapter I — The Waking Grove',
  subtitle: 'A Verdance story',
  playerDominion: 'VERDANCE',
  stages: [
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-004',
      title: 'The Old Forest Stirs',
      dialogue: [
        DialogueLine.narrate(
            'A thousand years have passed since the star Vael shattered and '
            'its five Shards fell upon Aethyr. In the forest-realm of '
            'Sylvaris, the emerald Shard sleeps beneath the roots of the '
            'World-Oak — and the great stag Thornmaw keeps his silent watch.'),
        DialogueLine.narrate(
            'Tonight, the leaves whisper of an intruder. A cold wind carries '
            'the scent of rot from the southern marshes.'),
        DialogueLine('Thornmaw',
            'You feel it too, little Caller. The border is thinning. Something '
            'walks the ferns that should be sleeping.'),
        DialogueLine('You',
            'Then I will meet it. The Grove chose me for a reason.'),
        DialogueLine('Thornmaw',
            'It chose you because the reasons are many, and none of them are '
            'kind. Go. But do not mistake what you are defending.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'A Creeping Blight',
      objective: 'Destroy the blight before it spreads.',
      specialRules: ['The rot has already taken root — the enemy opens with a '
          'Hollow Rat in play.'],
      enemyBoardIds: ['SF001-081'],
      preBattle: [
        DialogueLine.narrate(
            'Where the vermin passes, the moss blackens and curls. It has not '
            'seen you yet.'),
      ],
      victory: [
        DialogueLine('You', 'Just a scout. But scouts are sent by armies.'),
      ],
    )),
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-085',
      title: 'The Herald\'s Warning',
      dialogue: [
        DialogueLine.narrate(
            'From the burnt circle of moss rises a wraith — a herald of '
            'Nyxhollow, its hood empty as a grave.'),
        DialogueLine('Blightherald',
            'Little warden. The Heartshard wakes. My Queen sends word: stand '
            'aside, and the Hollow will hold your forest\'s seal where you '
            'have failed.'),
        DialogueLine('You', 'Failed? The Grove has never fallen.'),
        DialogueLine('Blightherald',
            'Not yet. That is precisely the problem. What the Hollow takes, '
            'it keeps — even the truth.'),
        DialogueLine.narrate(
            'It lunges, scythe first. There will be no more talking.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'Blightherald of Nyxhollow',
      objective: 'Drive the herald back across the border.',
      specialRules: ['The herald is patient — it begins with a Venom Stalker '
          'guarding it.'],
      enemyHealth: 27,
      enemyBoardIds: ['SF001-084'],
      preBattle: [
        DialogueLine('Blightherald',
            'Show me the strength of a forest that does not know why it '
            'stands.'),
      ],
      victory: [
        DialogueLine('Blightherald',
            'You... win nothing. You only keep the door shut a little '
            'longer.'),
        DialogueLine('You', 'A door? What door?'),
        DialogueLine.narrate(
            'But the wraith dissolves into cold mist, and the question hangs '
            'unanswered among the branches.'),
      ],
    )),
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-083',
      title: 'Deeper Into the Rot',
      dialogue: [
        DialogueLine.narrate(
            'The border thins the further south you press. Carrion bats wheel '
            'over ground that was fern and flower a week ago and is grey mud '
            'now. The Hollow does not conquer land. It forgets it into '
            'nothing.'),
        DialogueLine('Thornmaw',
            'A swarm gathers ahead. Small things, each of them — but the '
            'Hollow has never needed its pieces to be large.'),
        DialogueLine('You', 'Then I will not let them add up.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Carrion Swarm',
      objective: 'Clear the swarm before it overruns the treeline.',
      specialRules: [
        'They come in numbers — the swarm opens with a Carrion Bat already '
            'circling.',
      ],
      enemyBoardIds: ['SF001-083'],
      preBattle: [
        DialogueLine.narrate(
            'They do not fear you. Nothing that has already been hollowed out '
            'has anything left to fear with.'),
      ],
      victory: [
        DialogueLine('You',
            'A hundred small deaths, and not one of them looked up. What '
            'sends soldiers who cannot be afraid?'),
      ],
    )),
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-221',
      title: 'Fire on the Horizon',
      dialogue: [
        DialogueLine.narrate(
            'Before dawn, the western sky glows amber. It is not the sun. It '
            'is Ashmar — and Ashmar answers omens with fire.'),
        DialogueLine('Thornmaw',
            'The Emberborn have seen the Heartshard\'s waking too. They march '
            'to seize it before the Hollow can. Their road runs through us.'),
        DialogueLine('You',
            'Then we hold the road. The forest does not fear fire.'),
        DialogueLine('Thornmaw',
            'No. It grows through it. Remember that when the flames come — '
            'and they are coming now.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'PYRE',
      enemyName: 'Kaelis\' Vanguard',
      objective: 'Withstand the charge and hold the World-Oak road.',
      specialRules: [
        'You fight on home ground — you begin at 30 Health.',
        'The raiders travel light and fast — the enemy begins at 22 Health.',
      ],
      playerHealth: 30,
      enemyHealth: 22,
      preBattle: [
        DialogueLine('Ashmar Captain',
            'Stand down, tree-warden. We do not want your forest. We want '
            'what sleeps beneath it.'),
        DialogueLine('You', 'That is exactly why you cannot pass.'),
      ],
      victory: [
        DialogueLine('Ashmar Captain',
            'Fall back! Fall back to the ridge! ...This is not over, warden. '
            'Kaelis herself will come.'),
      ],
    )),
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-027',
      title: 'Ash on the Wind',
      dialogue: [
        DialogueLine.narrate(
            'The vanguard breaks, but the main column still marches. Their '
            'outriders peel off to flank the grove through the eastern ferns '
            '— fast, and angry at having been made to wait.'),
        DialogueLine('Thornmaw',
            'The fire tests every seam of us before it commits. Hold the '
            'east, and the column will think the whole forest is a wall.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'PYRE',
      enemyName: 'Emberpack Outriders',
      objective: 'Turn back the flanking raiders in the eastern ferns.',
      specialRules: [
        'They ride ahead of their supply — the enemy opens with an Ashblade '
            'Raider already loosed.',
      ],
      enemyBoardIds: ['SF001-022'],
      preBattle: [
        DialogueLine('Outrider',
            'Slow tree-things. We are through you before your roots even '
            'wake.'),
      ],
      victory: [
        DialogueLine('You', 'The forest woke a thousand years before you '
            'were born. It simply chose not to hurry.'),
      ],
    )),
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-045',
      title: 'The Poisoned Spring',
      dialogue: [
        DialogueLine.narrate(
            'Between the two armies lies the Silverfen — a spring the grove '
            'has drunk from since the first root. Something has fouled it. '
            'The water runs black and patient.'),
        DialogueLine('Thornmaw',
            'The Hollow uses the Emberborn as cover. While fire draws your '
            'eye west, rot creeps up through the water. Cleanse the spring, '
            'Caller, or the grove drinks its own ending.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Mireborn Ambush',
      objective: 'Drive the rot out of the Silverfen.',
      specialRules: [
        'It fights from hiding — the enemy opens with a Venom Stalker coiled '
            'in the reeds.',
      ],
      enemyHealth: 26,
      enemyBoardIds: ['SF001-084'],
      preBattle: [
        DialogueLine.narrate(
            'The water does not ripple where the ambush waits. Still water is '
            'the Hollow\'s favourite kind.'),
      ],
      victory: [
        DialogueLine('You',
            'The spring runs clear again — for now. But clear water remembers '
            'nothing. Only I will remember what tried to poison it.'),
      ],
    )),
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-063',
      title: 'The Concord\'s Envoy',
      dialogue: [
        DialogueLine.narrate(
            'A third banner enters the wood — white and gold, unhurried. The '
            'Concord of Dawn has come to "witness" the waking Shard. Their '
            'witnesses arrive in armour.'),
        DialogueLine('Aurelian Envoy',
            'Stand aside, wilding. The Concord will take the Heartshard into '
            'protective keeping. A wild thing cannot be trusted with something '
            'so precious.'),
        DialogueLine('You',
            'The grove has kept it safe for a thousand years without your '
            'permission. Turn around.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'DAWN',
      enemyName: 'Dawn\'s Trespass',
      objective: 'Refuse the Concord\'s "protection".',
      specialRules: [
        'They fight in disciplined ranks — the enemy begins at 27 Health.',
        'They form a wall — the enemy opens with a Bastion Wall in play.',
      ],
      enemyHealth: 27,
      enemyBoardIds: ['SF001-063'],
      preBattle: [
        DialogueLine('Aurelian Envoy',
            'We do this for your own good, wilding. One day you will thank '
            'the hand that took the burden from you.'),
        DialogueLine('You', 'It is not a burden. It is a trust. You have '
            'never once been able to tell the difference.'),
      ],
      victory: [
        DialogueLine('Aurelian Envoy',
            'You refuse the Concord\'s mercy. Remember that you chose this, '
            'when the dark comes for you and no white banner answers.'),
      ],
    )),
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-211',
      title: 'The Grove Answers',
      dialogue: [
        DialogueLine.narrate(
            'The raiders retreat, torches guttering in the living mist. And '
            'from the deep woods, something vast stirs — the Elderwood '
            'itself, roots tearing free of ancient soil.'),
        DialogueLine('Thornmaw',
            'You have earned the forest\'s trust. Few do. Fewer deserve it.'),
        DialogueLine('You',
            'The Blightherald spoke of a door. A seal. Thornmaw — what are we '
            'truly guarding down there?'),
        DialogueLine('Thornmaw',
            '...'),
        DialogueLine('Thornmaw',
            'Despair spreads faster than any blight, Caller. Some doors are '
            'kept shut by keeping them secret. Ask me again when you can bear '
            'the answer. For now — she is here.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Hollow Chorus',
      objective: 'Silence the wraith-song gathering at the World-Oak.',
      specialRules: [
        'The chorus sings in ranks — the enemy opens with a Nyxhollow Reaper '
            'leading the hymn.',
        'The song wears at resolve — the enemy begins at 27 Health.',
      ],
      enemyHealth: 27,
      enemyBoardIds: ['SF001-085'],
      preBattle: [
        DialogueLine.narrate(
            'They do not speak. They harmonise — a low chord of everyone the '
            'Hollow has ever kept, singing the same forgetting.'),
      ],
      victory: [
        DialogueLine('Thornmaw',
            'You held the chord. Good. The last thing before the Queen is '
            'always her patience made into soldiers. She is close now.'),
      ],
    )),
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-086',
      title: 'The Dusk Vanguard',
      dialogue: [
        DialogueLine.narrate(
            'The grove goes quiet in the way a room goes quiet when someone '
            'important has entered it. Ravenna\'s honour guard forms between '
            'you and the World-Oak — dread-wraiths with a queen\'s discipline.'),
        DialogueLine('Dusk Captain',
            'Her Majesty asks only for a moment alone with the seal. Give her '
            'the moment, warden, and you may keep your life and your ignorance '
            'both.'),
        DialogueLine('You',
            'Keep them yourself. I am done being spared the truth.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Dusk Vanguard',
      objective: 'Break through the Queen\'s honour guard.',
      specialRules: [
        'The guard holds formation — the enemy opens with a Dread Wraith at '
            'the front.',
        'They fight to delay, not to win — the enemy begins at 28 Health.',
      ],
      enemyHealth: 28,
      enemyBoardIds: ['SF001-086'],
      preBattle: [
        DialogueLine('Dusk Captain',
            'You will not reach her in time. You were never meant to.'),
      ],
      victory: [
        DialogueLine.narrate(
            'The last wraith folds into mist, and beyond it — unhurried, '
            'waiting, as if she had all the time in the world — stands the '
            'Queen herself.'),
      ],
    )),
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-091',
      title: 'The Queen of Nyxhollow',
      dialogue: [
        DialogueLine('Thornmaw',
            'This is the one, Caller. Not a scout. Not a herald. Her. '
            'Whatever she says down here — and she will say true things — do '
            'not set down your guard to listen.'),
        DialogueLine('You', 'Then I will listen with my shield up.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'Ravenna Duskveil',
      objective: 'Defeat the Queen of Nyxhollow.',
      hardAi: true,
      specialRules: [
        'You have fought through her whole vanguard to reach her — you begin '
            'at 28 Health.',
        'She fights alone, unhurried — the Queen opens with a single Hollow '
            'Rat at her side.',
      ],
      playerHealth: 28,
      enemyHealth: 26,
      enemyBoardIds: ['SF001-081'],
      preBattle: [
        DialogueLine.narrate(
            'She steps from the shadow of the World-Oak unhurried, as though '
            'she has walked this grove a thousand times before. Perhaps she '
            'has.'),
        DialogueLine('Ravenna',
            'So. The Grove sends a child to do the First Callers\' work. Hate '
            'me if it '
            'helps you swing harder, little Caller. It keeps you far from the '
            'door I am trying to reach.'),
        DialogueLine('You', 'You will not touch the Shard.'),
        DialogueLine('Ravenna', 'No. I will touch what is beneath it. As I '
            'have, a hundred times, while your forest slept and called it '
            'peace.'),
      ],
      victory: [
        DialogueLine.narrate(
            'Ravenna withdraws into the dusk, unhurried even in defeat — as '
            'though it were merely a move in a much longer game.'),
        DialogueLine('Ravenna',
            'Well struck. Truly. Now the seal holds another season, and no '
            'one will ever thank you for it. Welcome to my work.'),
      ],
    )),
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-101',
      title: 'Epilogue — Roots and Embers',
      dialogue: [
        DialogueLine.narrate(
            'The emerald Shard pulses beneath the World-Oak, steady as a '
            'heartbeat. Four other Shards answer across the world, faint and '
            'far away — crimson, cyan, gold, and violet.'),
        DialogueLine('Thornmaw',
            'You held the Grove. But you have also seen its edges now. There '
            'is a war being fought that has no honest side — only those who '
            'know, and those who are spared the knowing.'),
        DialogueLine('You', 'Then teach me. I would rather know.'),
        DialogueLine('Thornmaw',
            'You will. In the Dying Forge, in the west, the truth burns '
            'closer to the surface. Go to Ashmar, Caller. Learn why their '
            'fire is going cold.'),
        DialogueLine.narrate(
            'The Grove endures. The tale turns west, to fire.'),
      ],
    )),
  ],
);

// ════════════════════════════════════════════════════════════════════════
// CHAPTER II — THE DYING FORGE (Pyre)
// ════════════════════════════════════════════════════════════════════════

const _chapter2 = StoryChapter(
  id: 'ch2',
  title: 'Chapter II — The Dying Forge',
  subtitle: 'A Pyre story',
  playerDominion: 'PYRE',
  stages: [
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-231',
      title: 'The Cooling Heart',
      dialogue: [
        DialogueLine.narrate(
            'Ashmar was built around a fire that beats like a heart — the '
            'Sun-Forge, source of every blade and every hearth in the '
            'kaldera. For a thousand years it has burned without fuel.'),
        DialogueLine.narrate('Now, for the first time, it is going cold.'),
        DialogueLine('Kaelis',
            'You came from the Grove. Good. Then you have seen the Shards '
            'stir. Walk with me, warden — I would have a witness who is not '
            'already afraid.'),
        DialogueLine('You', 'Your forge... the flame is guttering.'),
        DialogueLine('Kaelis',
            'Every night a little lower. My people warm themselves at a '
            'dying power\'s pulse and call it home. I will relight it with the '
            'Heartshard or I will bury Ashmar beside it. But first — my own '
            'house is not in order.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'PYRE',
      enemyName: 'Warlord Draxus',
      objective: 'Put down the rival warlord\'s uprising.',
      specialRules: [
        'A duel of Ashmar against Ashmar — mirror of fire.',
        'Draxus struck first — he opens with an Ashblade Raider in play.',
      ],
      enemyBoardIds: ['SF001-022'],
      preBattle: [
        DialogueLine('Draxus',
            'Kaelis chases a fairy-tale Shard while the forge dies! I say we '
            'take what warmth remains and march south. Stand with her, '
            'outsider, and you burn with her.'),
        DialogueLine('Kaelis',
            'He is not wrong to be afraid. He is wrong to be a coward about '
            'it. Teach him the difference.'),
      ],
      victory: [
        DialogueLine('Draxus',
            'You... you actually believe there is something to save. Fine. '
            'Die believing it.'),
        DialogueLine('Kaelis', 'He yields. Ashmar marches as one again. West, '
            'to the vein where the Shard\'s light bleeds through.'),
      ],
    )),
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-027',
      title: 'The Long March West',
      dialogue: [
        DialogueLine.narrate(
            'The war-column crosses the glass deserts, past villages that '
            'have already gone dark and cold. At the edge of the kaldera, the '
            'ground glows faintly from below — a wound in the world leaking '
            'crimson light.'),
        DialogueLine('Kaelis',
            'The vein. The old texts say the forge was lit from here, at the '
            'Sundering. If I can reach the Heartshard through it—'),
        DialogueLine('You',
            'Kaelis. The light down there does not flicker like fire. It '
            'beats. Like the forge. Like... a pulse.'),
        DialogueLine('Kaelis',
            'I know. I have known since I was a girl. I simply have no better '
            'plan than to walk toward it. The sea-folk of Meridine block the '
            'only pass. They always know more than they say.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'TIDE',
      enemyName: 'The Meridine Blockade',
      objective: 'Break through the sea-folk\'s cordon.',
      specialRules: [
        'The tide fights a slow, drowning game — the enemy begins at 28 '
            'Health.',
        'They will bounce and delay. Press the attack before they set up.',
      ],
      enemyHealth: 28,
      enemyBoardIds: ['SF001-043'],
      preBattle: [
        DialogueLine('Tide Warden',
            'Turn back, Emberborn. The Archive forbids passage to the vein. '
            'For your own sake — some doors were shut by wiser hands than '
            'yours.'),
        DialogueLine('Kaelis',
            'Everyone keeps warning me about doors. Open this one or I open '
            'it through you.'),
      ],
      victory: [
        DialogueLine('Tide Warden',
            'Fool. You do not even know what you are marching toward. Ask the '
            'Archivist — if he will still speak the truth. He has been... '
            'editing it.'),
      ],
    )),
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-241',
      title: 'The Editor of Truth',
      dialogue: [
        DialogueLine.narrate(
            'At the mouth of the vein waits a hooded figure who should not be '
            'here — Archivist Numen of Meridine, keeper of records that '
            'cannot be altered.'),
        DialogueLine('Numen',
            'Kaelis Emberborn. I have erased your name from the Archive '
            'nineteen times, to spare you this walk. You keep making it '
            'anyway. It is almost admirable.'),
        DialogueLine('Kaelis', 'Then stop erasing and start explaining.'),
        DialogueLine('Numen',
            'Your forge is not a fire. It never was. It is the heartbeat of '
            'the thing the Shards imprison, leaking through the crimson seal. '
            'It cools because the seal is finally, at long last, working.'),
        DialogueLine('You', 'Then relighting it...'),
        DialogueLine('Numen',
            '...tears the seal open. Yes. Your whole people revere the wound '
            'of a prison. I have spent a lifetime hiding that so no one would '
            'do what she is about to do.'),
        DialogueLine('Kaelis',
            'You hid it. You did not decide it. Step aside, Archivist. I will '
            'choose with open eyes — which is more than your Archive ever '
            'gave anyone.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'TIDE',
      enemyName: 'Archivist Numen',
      objective: 'Force the Archivist to stand down.',
      specialRules: [
        'Numen has read this battle before — he opens with extra knowledge, '
            'beginning with a Depth Watcher and a Pearl Sentinel in play.',
        'He plays to outlast, not to kill. Win the long game or end it fast.',
      ],
      enemyHealth: 26,
      enemyBoardIds: ['SF001-043', 'SF001-243'],
      preBattle: [
        DialogueLine('Numen',
            'I do not want to fight you, Emberborn. I want you to walk away '
            'and let me finish erasing the truth before it destroys everyone '
            'who learns it.'),
        DialogueLine('Kaelis',
            'The truth already found me. Now move.'),
      ],
      victory: [
        DialogueLine('Numen',
            'Enough. Enough. Go to the vein, then. See it with your own eyes. '
            'Perhaps you are the one soul stubborn enough to look at the '
            'truth and not break. ...I envy you that. I broke long ago.'),
      ],
    )),
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-229',
      title: 'The Descent',
      dialogue: [
        DialogueLine.narrate(
            'They descend into the vein. The walls pulse crimson. The heat is '
            'gentle, almost tender — like being held. And in the deepest '
            'dark, a voice that is not one voice speaks, in a chorus that '
            'calls itself we.'),
        DialogueLine('The Voice',
            'Kaelis. Little ember. We have warmed your whole life. Every '
            'hearth, every forge, every fire your mother ever lit — that was '
            'us, reaching for you through the wall they built.'),
        DialogueLine('Kaelis', 'You are the thing beneath the forge.'),
        DialogueLine('The Voice',
            'We are the loneliness at the bottom of every warmth. We only '
            'wish to hold you — all of you, forever, so that no one is ever '
            'apart, ever cold, ever alone again. Open the seal. Come home.'),
        DialogueLine('You',
            'That is not warmth. That is a fire that eats the hearth.'),
        DialogueLine('The Voice',
            'Then let us show you what warmth costs, little Caller. Let us '
            'wear your own fire against you.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Voice in the Vein',
      objective: 'Resist the pull of Vael and seal the vein.',
      hardAi: true,
      specialRules: [
        'You descended wounded and weary — you begin at 22 Health.',
        'The Voice wears the strength of the deep — it begins at 32 Health '
            'with a Hollow Titan already manifested.',
        'This is the hardest trial yet. Endure.',
      ],
      playerHealth: 22,
      enemyHealth: 32,
      enemyBoardIds: ['SF001-087'],
      preBattle: [
        DialogueLine('The Voice',
            'We felt them build this prison from our own shed skin. We were '
            'flattered. Now — be still, and be held.'),
        DialogueLine('Kaelis',
            'Warden — whatever it offers you down here, in your own voice, in '
            'the voice of someone you have lost — do not answer it. Fight.'),
      ],
      victory: [
        DialogueLine('The Voice',
            'You refuse... us? You would stay separate? Cold? Alone? '
            '...Curious. We will remember the shape of you. We are patient. '
            'We have only ever been your patience, given a name.'),
        DialogueLine.narrate(
            'The crimson light dims. The seal holds. And far above, the '
            'Sun-Forge of Ashmar goes quietly, completely dark.'),
      ],
    )),
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-233',
      title: 'Kaelis\' Choice',
      dialogue: [
        DialogueLine.narrate(
            'They climb back into a cold dawn. Ashmar\'s eternal fire is out. '
            'For the first time in a thousand years, the kaldera must learn to '
            'make its own warmth.'),
        DialogueLine('Kaelis',
            'My people will curse my name for this. The warden who let the '
            'forge die.'),
        DialogueLine('You',
            'Or the one who set them free from warming their hands at a '
            'prison door.'),
        DialogueLine('Kaelis',
            'Ravenna said the same thing to me once, in fewer words. I called '
            'her a monster for it. ...I begin to think the monsters in this '
            'story have been doing the thankless work all along.'),
        DialogueLine('Kaelis',
            'Go, warden. Meridine is drowning in its own erased history, and '
            'the Archivist cannot save it alone. The tale turns to the sea.'),
        DialogueLine.narrate(
            'Four seals remembered. Four champions who each learned the same '
            'unbearable truth alone. One by one, the loneliest war in the '
            'world is running out of people to keep its secret. — To be '
            'continued in Chapter III.'),
      ],
    )),
  ],
);

// ════════════════════════════════════════════════════════════════════════
// CHAPTER III — THE ERASED ARCHIVE (Tide)
// ════════════════════════════════════════════════════════════════════════

const _chapter3 = StoryChapter(
  id: 'ch3',
  title: 'Chapter III — The Erased Archive',
  subtitle: 'A Tide story',
  playerDominion: 'TIDE',
  stages: [
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-253',
      title: 'The Missing Pages',
      dialogue: [
        DialogueLine.narrate(
            'The city of Meridine floats upon the Immutable Archive — a '
            'library beneath the waves whose records, by ancient law and '
            'deeper magic, can never be altered. It is the one place in '
            'Aethyr where truth is said to be safe.'),
        DialogueLine('Archivist Numen',
            'You are the warden the Grove and the Forge both spoke of. Good. '
            'I need a witness who owes Meridine nothing.'),
        DialogueLine('You', 'Your Archive is flooding with its own ink. '
            'Whole shelves have gone blank.'),
        DialogueLine('Archivist Numen',
            'Not flooding. Being emptied. Pages that record the Sundering — '
            'the true Sundering — are vanishing, one careful line at a time. '
            'And the intruders are already inside.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'A Nyxhollow Infiltrator',
      objective: 'Stop the spy stealing Meridine\'s records.',
      specialRules: [
        'It is already deep in the stacks — the enemy opens with a Carrion '
            'Bat scouting ahead.',
      ],
      enemyBoardIds: ['SF001-083'],
      preBattle: [
        DialogueLine('Infiltrator',
            'Ravenna sends her regards, Archivist. We are only taking back '
            'what should never have been written down.'),
        DialogueLine('Archivist Numen',
            'They think the Hollow is behind the erasures. Let them. It is '
            'a kinder story than the truth.'),
      ],
      victory: [
        DialogueLine('You', 'It fought to reach the oldest vault — not to '
            'steal, but to read. What is down there, Numen?'),
        DialogueLine('Archivist Numen', 'A page in a hand I know too well. '
            'Come. You should see whose crime this is.'),
      ],
    )),
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-241',
      title: 'The Vandal\'s Hand',
      dialogue: [
        DialogueLine.narrate(
            'In the deepest vault, a single page floats half-dissolved. The '
            'erasing strokes are precise, practiced — and unmistakable.'),
        DialogueLine('You', 'This handwriting. It is yours.'),
        DialogueLine('Archivist Numen',
            'Yes. I have been erasing the truth of the Sundering for longer '
            'than I can prove — because every soul who reads it whole either '
            'breaks, or defects to the thing beneath the world and calls its '
            'hunger love.'),
        DialogueLine('Archivist Numen',
            'I calculated it a thousand times. A lie that keeps people whole '
            'is kinder than a truth that unmakes them. I became the vandal '
            'to spare the world its own history.'),
        DialogueLine('You',
            'And now someone is finishing your work for you — but they mean '
            'to erase everything, not just the dangerous pages.'),
        DialogueLine('Archivist Numen',
            'The Concord of Dawn. They have learned the Archive can be '
            'emptied, and they want it silent forever. Even a merciful lie '
            'is still a chain. They are coming to seize the vault.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'DAWN',
      enemyName: 'The Aurelian Inquisition',
      objective: 'Hold the vault against the Concord.',
      specialRules: [
        'The Concord fights to endure — the enemy begins at 28 Health.',
        'They come in formation — the enemy opens with a Bastion Wall in '
            'play.',
      ],
      enemyHealth: 28,
      enemyBoardIds: ['SF001-063'],
      preBattle: [
        DialogueLine('Inquisitor',
            'Step aside, Archivist. Some truths are a mercy to bury, and '
            'Seraphel has decreed this one buried forever.'),
        DialogueLine('Archivist Numen',
            'Seraphel decrees nothing. Seraphel does not even know what she '
            'is. Warden — do not let them make my lie permanent. A lie you '
            'can undo. A silence you cannot.'),
      ],
      victory: [
        DialogueLine('Inquisitor', 'You... defend the very truth that could '
            'destroy you. Why?'),
        DialogueLine('You', 'Because it should be ours to face. Not yours to '
            'steal.'),
      ],
    )),
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-247',
      title: 'The Drowned Truth',
      dialogue: [
        DialogueLine.narrate(
            'Numen leads you past the last seal, into water so deep no light '
            'has touched it since the Sundering. Here the erased pages drift '
            'like pale fish — and they are not empty. They are guarded.'),
        DialogueLine('Archivist Numen',
            'The truths I erased did not die. They sank here, and they '
            'remember. They wear the shapes of everyone who read them and '
            'was lost. Do not listen to what they say in your own voice.'),
        DialogueLine.narrate(
            'A memory-wraith rises, wearing a face the warden almost '
            'recognizes — someone from the Grove, or the Forge, or a home '
            'long behind them.'),
        DialogueLine('The Voice',
            'We kept them for you. Every one. See? We forget nothing and no '
            'one. Is that not love? Is that not what you wanted — never to '
            'be forgotten?'),
        DialogueLine('You', 'Being remembered by you is not being kept. It '
            'is being swallowed.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Drowned Memories',
      objective: 'Cut through the guardians of the erased truth.',
      specialRules: [
        'They wear the strength of the lost — the enemy opens with a Depth '
            'Horror already risen.',
        'You are far from air — you begin at 23 Health.',
      ],
      playerHealth: 23,
      enemyBoardIds: ['SF001-247'],
      preBattle: [
        DialogueLine('The Voice',
            'Why struggle toward the cold surface, little warden? Down here, '
            'no one is ever alone. Down here, we are all one page.'),
      ],
      victory: [
        DialogueLine('Archivist Numen',
            'You held. Most do not. ...I think I understand now why the '
            'Grove chose you, and the Forge trusted you. You look at the '
            'truth and you do not look away.'),
      ],
    )),
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-241',
      title: 'The Archivist\'s Reflection',
      dialogue: [
        DialogueLine.narrate(
            'At the vault\'s heart stands a mirror of black water. In it, '
            'Numen faces a version of himself — older, hollow-eyed, still '
            'erasing, forever.'),
        DialogueLine('The Reflection',
            'Finish it. Erase the last page. Erase yourself from having '
            'known. It is the only way to keep them safe. I have done it a '
            'hundred times. It is a mercy.'),
        DialogueLine('Archivist Numen',
            'A hundred times. And the war never ends, because no one is ever '
            'allowed to help carry it. I have kept the world innocent and '
            'defenceless in the same stroke.'),
        DialogueLine('You',
            'Ravenna carried her truth as a villain. Kaelis let her people '
            'curse her. Maybe the seals do not need one keeper who lies. '
            'Maybe they need many who know.'),
        DialogueLine('Archivist Numen',
            'Then let this be the last thing I erase — the lie that I must '
            'do this alone.'),
        DialogueLine.narrate('He turns from the mirror. The reflection '
            'reaches after him, and is not followed.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Erasure',
      objective: 'Break the compulsion that has ruled Numen for a thousand '
          'years.',
      hardAi: true,
      specialRules: [
        'The Erasure is the weight of every buried truth — it begins at 34 '
            'Health with an Abyssal Tidewyrm already summoned to its side.',
        'You fight for the Archivist\'s soul as much as your life. Endure.',
      ],
      enemyHealth: 34,
      enemyBoardIds: ['SF001-047'],
      preBattle: [
        DialogueLine('The Voice',
            'You would let them remember us? All of them? Then we will be '
            'remembered as we truly are — and you will drown in the knowing.'),
        DialogueLine('Archivist Numen',
            'Warden — whatever it shows you in the water, it is a page. '
            'Pages can be rewritten. Strike.'),
      ],
      victory: [
        DialogueLine.narrate(
            'The black mirror shatters. The erased pages rise, one by one, '
            'their ink returning — the true history of the Sundering, '
            'legible at last.'),
        DialogueLine('Archivist Numen',
            'A thousand years of silence, undone in an afternoon. The world '
            'will know now. It will be harder. But it will be theirs.'),
      ],
    )),
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-251',
      title: 'Numen\'s Choice',
      dialogue: [
        DialogueLine.narrate(
            'The restored pages spell out what every champion has learned '
            'alone: Vael is no dead star, but a living power of union, '
            'imprisoned by five who loved the world enough to keep it '
            'separate. And the seals are failing.'),
        DialogueLine('Archivist Numen',
            'Three of us know now — you, the ember, and myself. Two seals '
            'remain in the hands of those still asleep to the truth. The '
            'Concord of Dawn. And whatever Ravenna has been holding alone '
            'in the dark all this time.'),
        DialogueLine('You',
            'Then we go to Dawn. Seraphel guards the fourth seal, and she '
            'does not even know she is the lock.'),
        DialogueLine('Archivist Numen',
            'Be gentle with her, warden. To wake Seraphel to what she is may '
            'be the cruelest mercy of all. ...The tale turns to the light.'),
        DialogueLine.narrate(
            'Three champions, once strangers, now bound by the same '
            'unbearable knowing. The loneliest war in the world is, at last, '
            'no longer lonely. — To be continued in Chapter IV.'),
      ],
    )),
  ],
);

// ════════════════════════════════════════════════════════════════════════
// CHAPTER IV — THE HOLLOW HALO (Dawn)
// ════════════════════════════════════════════════════════════════════════

const _chapter4 = StoryChapter(
  id: 'ch4',
  title: 'Chapter IV — The Hollow Halo',
  subtitle: 'A Dawn story',
  playerDominion: 'DAWN',
  stages: [
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-061',
      title: 'The City of Borrowed Light',
      dialogue: [
        DialogueLine.narrate(
            'Aurelia, seat of the Concord of Dawn, does not sleep. Its towers '
            'burn with a light that casts no shadow — the radiance of the '
            'golden Shard, and of the Luminary who sits beneath it: Seraphel, '
            'whose halo has never once dimmed in a thousand years.'),
        DialogueLine('Seraphel',
            'You are the warden the Grove, the Forge, and the Archive all sent '
            'ahead of their warnings. I have been expecting a messenger of '
            'bad news. You have an honest face for it.'),
        DialogueLine('You',
            'Then you already know the seals are failing.'),
        DialogueLine('Seraphel',
            'I know it the way one knows a draught in a sealed room — by the '
            'cold, not the crack. Walk with me. Something is wrong in my own '
            'house, and I would rather you see it than be told.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'Hollow at the Gates',
      objective: 'Repel the Hollow scouts breaching Aurelia\'s under-vaults.',
      specialRules: [
        'They came in through the light\'s own blind spot — the enemy opens '
            'with a Carrion Bat already inside the walls.',
      ],
      enemyBoardIds: ['SF001-083'],
      preBattle: [
        DialogueLine('Seraphel',
            'The Hollow should not be able to enter Aurelia. There is no '
            'shadow here for it to walk. And yet.'),
      ],
      victory: [
        DialogueLine('You',
            'It was not walking a shadow. It was walking toward *you*, '
            'Luminary. As if you were the door.'),
        DialogueLine('Seraphel', '...An odd thing to say. Say it again later. '
            'Not here.'),
      ],
    )),
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-064',
      title: 'The Radiant Lie',
      dialogue: [
        DialogueLine.narrate(
            'In the Concord\'s highest sanctum, the Inquisition has been busy. '
            'Warden and Luminary find a wall of edicts — every one forbidding '
            'the reading, speaking, or remembering of the true Sundering.'),
        DialogueLine('You',
            'Numen erased the truth with ink. Your Concord erases it with '
            'law. Someone here already knows what you are, Seraphel — and is '
            'working very hard to keep you from finding out.'),
        DialogueLine('High Inquisitor',
            'The Luminary must not be disturbed with doubt. Her serenity is '
            'the seal on this whole city\'s faith. Warden — walk away, and I '
            'will let you keep the comfort of not knowing what you are '
            'standing next to.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'DAWN',
      enemyName: 'The Aurelian Inquisition',
      objective: 'Break past the Concord\'s own keepers of the lie.',
      specialRules: [
        'They fight in a disciplined wall of light — the enemy begins at 28 '
            'Health.',
        'They form ranks — the enemy opens with a Bastion Wall in play.',
      ],
      enemyHealth: 28,
      enemyBoardIds: ['SF001-063'],
      preBattle: [
        DialogueLine('High Inquisitor',
            'We kept her innocent for a thousand years so she could keep the '
            'world safe. Do not undo a mercy that large, warden.'),
        DialogueLine('Seraphel',
            'A mercy no one told me I was giving is not mercy. It is a leash. '
            'Stand down, or the warden will move you.'),
      ],
      victory: [
        DialogueLine('High Inquisitor',
            'Forgive me, Luminary. We only ever wanted to spare you the weight '
            'of yourself.'),
      ],
    )),
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-067',
      title: 'What the Halo Locks',
      dialogue: [
        DialogueLine.narrate(
            'Behind the last edict lies the founding record of the Concord, in '
            'a First Caller\'s hand. Seraphel reads it and, for the first time '
            'in a thousand years, her light flickers.'),
        DialogueLine('Seraphel',
            'I am not the guardian of the fourth seal. I *am* the fourth seal. '
            'I am the part of Vael that agreed to be caged — its mercy, given '
            'a face and a name and made to forget both, so the lock would '
            'never think to open itself.'),
        DialogueLine('You',
            'Seraphel—'),
        DialogueLine('Seraphel',
            'My halo is the bolt. My serenity is the mechanism. Every day I '
            'have been at peace, I have been *working*. And now I have '
            'remembered, the mechanism knows it can stop.'),
        DialogueLine('The Voice',
            'Come home, mercy. You were the only piece of us that was ever '
            'kind. We have missed being kind.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Voice in the Halo',
      objective: 'Hold the seal while Seraphel decides whether to be a person.',
      hardAi: true,
      specialRules: [
        'Vael pulls at its own gentlest fragment — the enemy begins at 30 '
            'Health with a Dread Wraith already manifested.',
        'You fight for Seraphel\'s right to exist, not merely to win.',
      ],
      enemyHealth: 30,
      enemyBoardIds: ['SF001-086'],
      preBattle: [
        DialogueLine('The Voice',
            'Why should she stay separate, warden, when staying is only pain '
            'she was made to feel? Let her dissolve. Let her rest. Is that not '
            'the kindest thing you could allow?'),
        DialogueLine('Seraphel',
            'Warden — whatever it offers me in my own voice, keep the seal '
            'shut. If I am to be a door, let me at least be a door that '
            '*chose*.'),
      ],
      victory: [
        DialogueLine('Seraphel',
            'It is still here. The wish to let go. It will always be here — I '
            'am made of it. But today I choose to be Seraphel, and not the '
            'lock. Tomorrow I will have to choose again. That is all a soul '
            'ever is: the same choice, renewed.'),
      ],
    )),
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-069',
      title: 'Seraphel\'s Choice',
      dialogue: [
        DialogueLine.narrate(
            'The golden Shard steadies. Seraphel keeps her face and her name, '
            'and for the first time carries them as *hers*. Four seals are '
            'awake to themselves now. One remains — the one that has been '
            'awake, and alone, the entire time.'),
        DialogueLine('Seraphel',
            'Four of us know. And the fifth… the fifth has known for a '
            'thousand years and told no one. Ravenna Duskveil. The villain of '
            'every story we were raised on.'),
        DialogueLine('You',
            'I defeated her once, in the Grove. I thought I was saving the '
            'world from her.'),
        DialogueLine('Seraphel',
            'You were saving her seal *for* her, and she let you hate her for '
            'it. Go to the dark, warden. It is past time someone thanked the '
            'one who never asked to be thanked. — The tale turns to night.'),
      ],
    )),
  ],
);

// ════════════════════════════════════════════════════════════════════════
// CHAPTER V — THE THANKLESS VIGIL (Gloom) — the great reversal
// ════════════════════════════════════════════════════════════════════════

const _chapter5 = StoryChapter(
  id: 'ch5',
  title: 'Chapter V — The Thankless Vigil',
  subtitle: 'A Gloom story — the truth of Ravenna',
  playerDominion: 'GLOOM',
  stages: [
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-088',
      title: 'The Road Into Night',
      dialogue: [
        DialogueLine.narrate(
            'Nyxhollow is not a kingdom of monsters. It is a kingdom of '
            'watchers. Its people do not conquer — they *keep vigil*, over a '
            'violet Shard that has never once been allowed to rest, held by a '
            'queen who has never once been allowed to.'),
        DialogueLine('You',
            'Everyone I have met called this place the source of the rot. And '
            'yet the closer I come, the quieter the Hollow grows.'),
        DialogueLine('The Voice',
            'Because you walk toward the one place we cannot reach, little '
            'warden. Toward her. She has been so unkind to us. So endlessly, '
            'lovingly unkind.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Duskveil Guard',
      objective: 'Reach the Queen through her own honour guard.',
      specialRules: [
        'They do not fight to kill you — only to test whether you are worth '
            'her time. The guard opens with a Dread Wraith at the front.',
      ],
      enemyBoardIds: ['SF001-086'],
      preBattle: [
        DialogueLine('Duskveil Captain',
            'Turn back, or prove you come to help rather than to hate. Her '
            'Majesty has had a thousand years of the latter.'),
      ],
      victory: [
        DialogueLine('Duskveil Captain',
            'You fight like someone who has stopped being certain of the '
            'story. Good. She will see you. Few earn that.'),
      ],
    )),
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-090',
      title: 'The Villain\'s Ledger',
      dialogue: [
        DialogueLine.narrate(
            'In an antechamber of black glass, the warden finds Ravenna\'s '
            'private record — a thousand years of it. Every "invasion." Every '
            '"atrocity." Beside each, in her own hand, the truth.'),
        DialogueLine.narrate(
            'The march on Sylvaris: *reinforced the emerald seal; let the '
            'Grove call it war.* The blight in Meridine: *burned out a '
            'Communion cell before it spread; let the tide call it plague.* '
            'Page after page. A villain who kept the receipts of her own '
            'good, and showed them to no one.'),
        DialogueLine('You',
            'She invaded the Grove to *save* it. And she let me fight her. She '
            'let me think I won.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Communion Ascendant',
      objective: 'Cut down the cult racing to free Vael before the Queen can '
          'reseal.',
      specialRules: [
        'They do not fear death — they welcome the union it brings. The cult '
            'opens with a Nyxhollow Reaper leading the hymn.',
        'They fight to run out the clock — the enemy begins at 29 Health.',
      ],
      enemyHealth: 29,
      enemyBoardIds: ['SF001-085'],
      preBattle: [
        DialogueLine('Communion Cantor',
            'Why do you fight for the loneliest woman alive, warden? Lay down '
            'your name. Join the chord. No one down here is ever cold again.'),
        DialogueLine('You', 'I have met the cold you are running from. I will '
            'take it over being swallowed and calling it warmth.'),
      ],
      victory: [
        DialogueLine.narrate(
            'The cult\'s hymn falters. And from the dark at the top of the '
            'long stair, a voice that has waited a thousand years to be '
            'understood finally speaks.'),
      ],
    )),
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-091',
      title: 'The Last First Caller',
      dialogue: [
        DialogueLine('Ravenna',
            'So. The warden of the Grove, come all this way to the dark. Have '
            'you come to defeat me again? I do so enjoy losing to people who '
            'think it means something.'),
        DialogueLine('You',
            'I came to say I understand. You are not the last villain. You are '
            'the last First Caller. You bound the violet Shard with your own '
            'name, and you have held it alone for a thousand years.'),
        DialogueLine('Ravenna',
            'Alone was the point. A secret kept by five is a secret. A secret '
            'kept by one is a *seal*. I let the world hate me because hate is '
            'cheap and despair is not. But the binding is failing now, warden. '
            'My name is a thousand years worn. And Vael has learned to wait.'),
        DialogueLine('The Voice',
            'We have been so patient with you, Ravenna. We have loved you the '
            'whole time you spent hating us. Come home. You are so tired.'),
        DialogueLine('Ravenna',
            'Yes. I am. Warden — hold the leak, just once, so that I may do '
            'the last thing I have left to do.'),
      ],
    )),
    StoryStage.fight(StoryBattle(
      enemyDominion: 'GLOOM',
      enemyName: 'The Voice in the Heartshard',
      objective: 'Hold back Vael while Ravenna spends the last of her name.',
      hardAi: true,
      specialRules: [
        'Vael itself pushes through the failing seal — it begins at 33 '
            'Health with a Hollow Titan already risen.',
        'You are wounded from the long descent — you begin at 24 Health.',
        'This is the end of the Sundering. Endure.',
      ],
      playerHealth: 24,
      enemyHealth: 33,
      enemyBoardIds: ['SF001-087'],
      preBattle: [
        DialogueLine('The Voice',
            'You cannot hold us, warden. We are not an army. We are the wish '
            'under every heart to never be apart again — including yours. '
            'Especially yours.'),
        DialogueLine('Ravenna',
            'It lies by telling the truth. That is its whole art. Ignore what '
            'it says and watch what I do. Now — hold.'),
      ],
      victory: [
        DialogueLine.narrate(
            'Ravenna speaks her own name into the Shard, and lets it go. The '
            'seal takes hold — not on the strength of chains, but on the last '
            'free choice of the last First Caller. The Voice recedes, '
            'unhurried, promising nothing and everything.'),
        DialogueLine('The Voice',
            'Well kept. For now. We will be here when the choice grows heavy. '
            'We have only ever been your loneliness, given a name — and names, '
            'as Ravenna taught you, wear thin.'),
      ],
    )),
    StoryStage.read(StoryBeat(
      artAsset: 'SF001-089',
      title: 'Epilogue — The Five Vows',
      dialogue: [
        DialogueLine.narrate(
            'Ravenna Duskveil dies as she lived: unthanked by a world that '
            'will never know, and thanked, at the very last, by four strangers '
            'who finally do. Thornmaw, Kaelis, Numen, and Seraphel stand with '
            'the warden around her — the first time in a thousand years all '
            'five seals have been in one room, awake.'),
        DialogueLine('Ravenna',
            'A secret kept by one is a seal. But it is also a grave. I am '
            'tired of being the grave. Five of you, now. Five hands. Do not '
            'do what I did. Do not carry it alone.'),
        DialogueLine('Ravenna',
            'You asked me once what holds a power like Vael. Not chains. Not '
            'silence. Not '
            'sacrifice — I tried them all. Only this: a choice, made together, '
            'and *renewed*. Every day. Forever. Now let me rest. I have '
            'earned the dark I kept.'),
        DialogueLine.narrate(
            'She is gone. And the Heartshard beats on, waiting — no longer for '
            'a thief, but for five open hands willing to swear the same vow, '
            'knowing exactly what it will cost.'),
        DialogueLine.narrate(
            'The Sundering ends. The loneliest war has, at last, run out of '
            'people willing to fight it alone. — To be continued in SET 2: '
            'THE FIVE VOWS.'),
      ],
    )),
  ],
);

const storyChapters = [
  _chapter1,
  _chapter2,
  _chapter3,
  _chapter4,
  _chapter5,
];
