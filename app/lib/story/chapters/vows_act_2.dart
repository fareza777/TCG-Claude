import '../story_data.dart';

import '../vow_encounters.dart';

// Act 2: Terms of Mercy. Actual chapter-five continuity governs.

final vow06 = StoryChapter(
  id: "vow06",
  title: "The Bridge of Returning Feet",
  subtitle: "The Five Vows · Act 2 · Terms of Mercy",
  playerDominion: "VERDANCE",
  stages: [
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow06-01",
        title: "The Bridge of Returning Feet",
        dialogue: [
          DialogueLine.narrate(
            "The root bridge has a gap at its center. Verdance says it marks the frontier. The people stranded above the ravine call it the missing part.",
          ),
          DialogueLine("Sproutling", "If we close it, soldiers can cross."),
          DialogueLine("You", "So can the people waiting behind them."),
          DialogueLine("Sproutling", "I was hoping for an easier answer."),
        ],
      ),
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-005",
        title: "The Right to Return",
        dialogue: [
          DialogueLine.narrate(
            "The keepers permit departures but forbid returns. They say a vow to shelter strangers must end somewhere.",
          ),
          DialogueLine(
            "You",
            "These people were strangers yesterday. Today they have houses here.",
          ),
          DialogueLine(
            "Sproutling",
            "And seedlings. Some of them planted seedlings.",
          ),
          DialogueLine("You", "Then perhaps the roots already know them."),
        ],
      ),
    ),
    vowBattle(
      chapter: 6,
      encounter: 1,
      player: "VERDANCE",
      enemy: "VERDANCE",
      name: "The Border of Roots",
      objective:
          "Defeat the keepers preventing the refugees' return; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine("Sproutling", "Leave the bridge standing."),
        DialogueLine("You", "It is the reason we are here."),
      ],
      victory: [
        DialogueLine.narrate(
          "The bridge grows a narrow crossing. Its handrails remain separate, with a rope between them for people who need help.",
        ),
        DialogueLine("Sproutling", "It did not heal shut."),
        DialogueLine("You", "A gap can be a choice instead of a wound."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-050",
        title: "The Price at the Far End",
        dialogue: [
          DialogueLine.narrate(
            "Pyre deserters have built a toll furnace on the opposite bank. They burn the refugees' belongings and call it an entry fee.",
          ),
          DialogueLine(
            "Kaelis",
            "I taught them that nothing should cross a border without paying.",
          ),
          DialogueLine("You", "Then tell them what you have learned since."),
          DialogueLine(
            "Kaelis",
            "They are holding the road. They may require a demonstration.",
          ),
        ],
      ),
    ),
    vowBattle(
      chapter: 6,
      encounter: 2,
      player: "VERDANCE",
      enemy: "PYRE",
      name: "The Toll of Ash",
      objective:
          "Defeat the toll company holding the far bridgehead; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "Kaelis",
          "Your pay is late. Their lives are not compensation.",
        ),
        DialogueLine("You", "We can settle the first problem after this."),
      ],
      victory: [
        DialogueLine.narrate(
          "The furnace is dismantled into cooking stoves. The soldiers' names go into the same relief ledger as everyone else's.",
        ),
        DialogueLine(
          "Kaelis",
          "No oath of gratitude. Just sign that you received your share.",
        ),
        DialogueLine("Sproutling", "That is a much smaller piece of paper."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow06-01",
        title: "The First Renewal",
        dialogue: [
          DialogueLine.narrate(
            "A message from Thornmaw asks whether the orchard still agrees. The keepers are offended. The refugees are relieved.",
          ),
          DialogueLine("You", "He said to ask each morning."),
          DialogueLine("Sproutling", "Even after we said yes?"),
          DialogueLine("You", "Especially then."),
        ],
      ),
    ),
  ],
);

final vow07 = StoryChapter(
  id: "vow07",
  title: "The House of Unspent Heat",
  subtitle: "The Five Vows · Act 2 · Terms of Mercy",
  playerDominion: "PYRE",
  stages: [
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow07-01",
        title: "The House of Unspent Heat",
        dialogue: [
          DialogueLine.narrate(
            "The visitor comes to the kitchen after the last bowl is washed. There is no escort, no banner, and no request to see the queen.",
          ),
          DialogueLine(
            "The Cantor",
            "A city that cooks together has understood more than its generals.",
          ),
          DialogueLine(
            "Kaelis",
            "And a stranger who arrives after supper has understood less than its children.",
          ),
          DialogueLine("The Cantor", "We can wait."),
        ],
      ),
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-213",
        title: "Rest Offered Freely",
        dialogue: [
          DialogueLine.narrate(
            "The visitor leaves a coal that burns without fuel. Beside it is a note asking nothing in return. The hospital sends for it before the council can meet.",
          ),
          DialogueLine("You", "Does it open the seal?"),
          DialogueLine(
            "The Cantor",
            "It opens a hand. You may close it again.",
          ),
          DialogueLine(
            "Kaelis",
            "Let us test the second part before we accept the first.",
          ),
        ],
      ),
    ),
    vowBattle(
      chapter: 7,
      encounter: 1,
      player: "PYRE",
      enemy: "GLOOM",
      name: "The Coal's Echo",
      objective:
          "Defeat the echo released when the gift is refused; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine("The Cantor", "We did not ask it to cling."),
        DialogueLine("Kaelis", "Then help us make it let go."),
      ],
      victory: [
        DialogueLine.narrate(
          "The coal cools. The visitor kneels beside the injured stoker and waits while a mortal doctor works.",
        ),
        DialogueLine(
          "The Cantor",
          "We are sorry. Kindness without a way to refuse is another appetite.",
        ),
        DialogueLine(
          "You",
          "You sound as though you have practiced saying that.",
        ),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-048",
        title: "The Captains' Cure",
        dialogue: [
          DialogueLine.narrate(
            "Draxus orders every recipient detained. The hospital wards fill with guards, and nobody can reach the water pump.",
          ),
          DialogueLine(
            "Kaelis",
            "The gift was dangerous. That does not make the sick criminals.",
          ),
          DialogueLine("Draxus", "It makes them a breach."),
          DialogueLine("You", "They have names. Start there."),
        ],
      ),
    ),
    vowBattle(
      chapter: 7,
      encounter: 2,
      player: "PYRE",
      enemy: "PYRE",
      name: "The Quarantine Spears",
      objective:
          "Defeat the captains occupying the hospital courtyard; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "Kaelis",
          "We are removing spears from a hospital. Remember how that should sound.",
        ),
        DialogueLine("You", "The patients stay where they can be treated."),
      ],
      victory: [
        DialogueLine.narrate(
          "The guards return to the gates. The patients keep their blankets. The Cantor departs without demanding a hearing.",
        ),
        DialogueLine(
          "The Cantor",
          "A refusal is an answer. We will remember yours.",
        ),
        DialogueLine(
          "Kaelis",
          "And I will remember that you waited for the doctor.",
        ),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow07-01",
        title: "The Coal She Kept",
        dialogue: [
          DialogueLine.narrate(
            "Kaelis opens her other hand. A second pale warmth moves beneath the iron. She has carried it since the cold kiln.",
          ),
          DialogueLine("You", "You should have told the council."),
          DialogueLine(
            "Kaelis",
            "I wanted to know whether it was hope before you named it treason.",
          ),
          DialogueLine.narrate(
            "She does not surrender it. You do not pretend you failed to notice.",
          ),
        ],
      ),
    ),
  ],
);

final vow08 = StoryChapter(
  id: "vow08",
  title: "The Hall of Unfinished Names",
  subtitle: "The Five Vows · Act 2 · Terms of Mercy",
  playerDominion: "TIDE",
  stages: [
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow08-01",
        title: "The Hall of Unfinished Names",
        dialogue: [
          DialogueLine.narrate(
            "The restored names do not fit on the memorial wall. Numen asks the masons for more stone. They ask which names may be written smaller.",
          ),
          DialogueLine("Numen", "None."),
          DialogueLine("You", "We will need another wall."),
          DialogueLine(
            "Numen",
            "Yes. I am learning to give expensive answers.",
          ),
        ],
      ),
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-095",
        title: "The Living Correction",
        dialogue: [
          DialogueLine.narrate(
            "A woman has crossed two seas to remove her husband's name. He is alive in the southern islands. The archive demands proof that she is herself.",
          ),
          DialogueLine(
            "Numen",
            "I once made certainty into an entrance requirement.",
          ),
          DialogueLine("You", "She has brought letters."),
          DialogueLine(
            "Numen",
            "I will read them as though someone other than me can know a thing.",
          ),
        ],
      ),
    ),
    vowBattle(
      chapter: 8,
      encounter: 1,
      player: "TIDE",
      enemy: "TIDE",
      name: "The Proof Wardens",
      objective:
          "Defeat the wardens preventing the memorial correction; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine("Numen", "Protect the letters from the water."),
        DialogueLine("You", "And their owner from the archive."),
      ],
      victory: [
        DialogueLine.narrate(
          "The name is removed without erasing the place it occupied. Under it the mason writes that the record was corrected by someone who came back.",
        ),
        DialogueLine("Numen", "A memorial should be pleased to lose a name."),
        DialogueLine("You", "Put that above the door."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-138",
        title: "The Kindly Abridgment",
        dialogue: [
          DialogueLine.narrate(
            "The Concord offers a shortened confession. It retains Numen's remorse and removes the people who benefited from his silence.",
          ),
          DialogueLine("Seraphel", "It is written beautifully."),
          DialogueLine(
            "Numen",
            "That has been a persistent problem with our lies.",
          ),
          DialogueLine("You", "Will they publish the whole thing?"),
        ],
      ),
    ),
    vowBattle(
      chapter: 8,
      encounter: 2,
      player: "TIDE",
      enemy: "DAWN",
      name: "The Golden Abridgment",
      objective:
          "Defeat the censors impounding the complete confession; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "Seraphel",
          "There is room in the light for an unflattering page.",
        ),
        DialogueLine("Numen", "Several, in this instance."),
      ],
      victory: [
        DialogueLine.narrate(
          "The unabridged record travels on public boats. The first correction arrives before the last copy has left the quay.",
        ),
        DialogueLine("Numen", "My vow has survived being contradicted."),
        DialogueLine(
          "You",
          "It may be the first thing you have written that wanted to.",
        ),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow08-01",
        title: "A Marginal Note",
        dialogue: [
          DialogueLine.narrate(
            "In the oldest binding Numen finds five marks around an empty place. Someone wrote: leave room for the one who says no.",
          ),
          DialogueLine("You", "Who wrote it?"),
          DialogueLine(
            "Numen",
            "The First Caller. Before she learned to call a lie protection.",
          ),
          DialogueLine.narrate(
            "He sends the page down the well-kept stair. This time he keeps no private copy from the others.",
          ),
        ],
      ),
    ),
  ],
);

final vow09 = StoryChapter(
  id: "vow09",
  title: "The Mercy Gate",
  subtitle: "The Five Vows · Act 2 · Terms of Mercy",
  playerDominion: "DAWN",
  stages: [
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow09-01",
        title: "The Mercy Gate",
        dialogue: [
          DialogueLine.narrate(
            "Seraphel opens the Mercy Gate. Petitioners arrive carrying the chains once used to turn them away. They want to know where to put them.",
          ),
          DialogueLine(
            "Seraphel",
            "Here, where we will have to step around them.",
          ),
          DialogueLine("You", "Some will say that obstructs the entrance."),
          DialogueLine(
            "Seraphel",
            "They obstructed it more effectively before.",
          ),
        ],
      ),
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-134",
        title: "A Halo Is Not a Signature",
        dialogue: [
          DialogueLine.narrate(
            "The Inquisitor brings an oath binding every citizen to Seraphel's mercy. It has no provision for anyone who does not want it.",
          ),
          DialogueLine("Inquisitor", "You are mercy."),
          DialogueLine(
            "Seraphel",
            "Then listen when I tell you it cannot be compulsory.",
          ),
          DialogueLine("You", "Who is permitted to cross?"),
        ],
      ),
    ),
    vowBattle(
      chapter: 9,
      encounter: 1,
      player: "DAWN",
      enemy: "DAWN",
      name: "The Gate of Consent",
      objective:
          "Defeat the wardens enforcing the compulsory oath; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "Seraphel",
          "They may keep their faith. They may not use it as a lock.",
        ),
        DialogueLine("You", "The gate remains open after we win."),
      ],
      victory: [
        DialogueLine.narrate(
          "The oath is taken down. Several petitioners leave. Seraphel watches until they are safely beyond the walls.",
        ),
        DialogueLine("Seraphel", "That was harder than opening the gate."),
        DialogueLine(
          "You",
          "It was the part that made opening it mean something.",
        ),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-178",
        title: "What the Halo Remembers",
        dialogue: [
          DialogueLine.narrate(
            "Under the arch Seraphel's halo casts a second shadow. It knows a voice from before there were separate voices.",
          ),
          DialogueLine("The Voice", "We never meant to make mercy lonely."),
          DialogueLine(
            "Seraphel",
            "You made me able to leave. Do not call that a mistake.",
          ),
          DialogueLine("You", "Can you hold the gate while we clear the echo?"),
        ],
      ),
    ),
    vowBattle(
      chapter: 9,
      encounter: 2,
      player: "DAWN",
      enemy: "GLOOM",
      name: "The Mercy That Clings",
      objective:
          "Defeat the echo gathering under the open arch; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine("The Voice", "We could make their pain quiet."),
        DialogueLine("Seraphel", "First ask whether they want your quiet."),
      ],
      victory: [
        DialogueLine.narrate(
          "The second shadow withdraws. Outside the gate a petitioner curses Seraphel's name and continues home unharmed.",
        ),
        DialogueLine(
          "Seraphel",
          "My vow is to protect the right to refuse me.",
        ),
        DialogueLine("You", "Including when you are right."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow09-01",
        title: "The Fourth Vow",
        dialogue: [
          DialogueLine.narrate(
            "Seraphel signs without her halo's seal. The signature is awkward. She has always allowed the light to do that part for her.",
          ),
          DialogueLine("Seraphel", "Does it look like a person's name?"),
          DialogueLine("Numen", "It looks like someone wrote it herself."),
          DialogueLine.narrate(
            "She asks for another page to practice on. The first is kept, with the uneven letters plainly visible.",
          ),
        ],
      ),
    ),
  ],
);

final vow10 = StoryChapter(
  id: "vow10",
  title: "The Open Door Below",
  subtitle: "The Five Vows · Act 2 · Terms of Mercy",
  playerDominion: "GLOOM",
  stages: [
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow10-01",
        title: "The Open Door Below",
        dialogue: [
          DialogueLine.narrate(
            "Ravenna sits where her sister sat. Thornmaw has brought a cushion and been instructed to stop hovering. He has obeyed one instruction.",
          ),
          DialogueLine(
            "Ravenna",
            "You have brought a committee into my cellar.",
          ),
          DialogueLine("The Sister", "You asked for reports."),
          DialogueLine(
            "Ravenna",
            "I hoped they would learn brevity on the stairs.",
          ),
        ],
      ),
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-214",
        title: "A Duty with an Exit",
        dialogue: [
          DialogueLine.narrate(
            "The stone tightens when the fifth vow is read. It has become accustomed to a single name that never changes its mind.",
          ),
          DialogueLine(
            "The First Caller",
            "A lock remembers what worked, even when what worked was cruelty.",
          ),
          DialogueLine(
            "Ravenna",
            "Then we shall be patient while it learns manners.",
          ),
          DialogueLine(
            "You",
            "The stair stays open. That was the first condition.",
          ),
        ],
      ),
    ),
    vowBattle(
      chapter: 10,
      encounter: 1,
      player: "GLOOM",
      enemy: "GLOOM",
      name: "The Inherited Lock",
      objective:
          "Defeat the binding's remnant resisting a freely chosen relief; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "Ravenna",
          "Do not promise to take my place. Promise to ask whether I still choose it.",
        ),
        DialogueLine("You", "I will ask while the answer can still be no."),
      ],
      victory: [
        DialogueLine.narrate(
          "The pressure eases. Ravenna lifts one hand from her knee and reaches for the tea her sister has carried down.",
        ),
        DialogueLine("Ravenna", "Still dreadful."),
        DialogueLine("The Sister", "You are welcome."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-127",
        title: "The Account of Eleven Years",
        dialogue: [
          DialogueLine.narrate(
            "Numen's measurement would divide the burden into equal turns. It has no space for age, exhaustion, or someone who simply cannot continue.",
          ),
          DialogueLine("Numen", "It is an elegant schedule."),
          DialogueLine("Ravenna", "Then I advise you to mistrust it."),
          DialogueLine(
            "The Sister",
            "I will not be made the unit in which you measure endurance.",
          ),
        ],
      ),
    ),
    vowBattle(
      chapter: 10,
      encounter: 2,
      player: "GLOOM",
      enemy: "TIDE",
      name: "The Equal Burden",
      objective:
          "Defeat the archive constructs enforcing the flawed schedule; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "Numen",
          "I forgot that an equal number can conceal an unequal cost.",
        ),
        DialogueLine("You", "Help us dismantle your conclusion."),
      ],
      victory: [
        DialogueLine.narrate(
          "Numen crosses out the schedule in front of everyone. He leaves the calculation readable beneath the correction.",
        ),
        DialogueLine(
          "Ravenna",
          "My vow is to name the cost before asking anyone to carry it.",
        ),
        DialogueLine("The Sister", "Include the one who asks."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow10-01",
        title: "A Fifth Answer",
        dialogue: [
          DialogueLine.narrate(
            "Ravenna signs. The First Caller asks whether her own name is required. Nobody answers for her.",
          ),
          DialogueLine("The First Caller", "I shall need time."),
          DialogueLine(
            "Ravenna",
            "We have spent a thousand years pretending we did not.",
          ),
          DialogueLine.narrate(
            "Above them five separate lights appear on the roofless table. For one evening nothing asks to be worshipped.",
          ),
        ],
      ),
    ),
  ],
);
