import '../story_data.dart';

import '../vow_encounters.dart';

// Act 1: The Work of Asking. Actual chapter-five continuity governs.

final vow01 = StoryChapter(
  id: "vow01",
  title: "The Spare Lamp",
  subtitle: "The Five Vows · Act 1 · The Work of Asking",
  playerDominion: "GLOOM",
  stages: [
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow01-01",
        title: "The Spare Lamp",
        dialogue: [
          DialogueLine.narrate(
            "The stair ends in morning. For the first time, nobody below it is alone. Above it, five cities are preparing five different accounts of what happened.",
          ),
          DialogueLine(
            "The Sister",
            "I thought the sky would have changed more.",
          ),
          DialogueLine("You", "It has only had eleven years."),
          DialogueLine(
            "The Sister",
            "Then it has had time to learn something.",
          ),
        ],
      ),
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-177",
        title: "The Queen's Errand",
        dialogue: [
          DialogueLine.narrate(
            "At the gate the watch asks for Ravenna's seal. Her sister sets an oil flask on the captain's desk instead.",
          ),
          DialogueLine(
            "The Sister",
            "She is alive. She is staying. Those are different statements. Write both.",
          ),
          DialogueLine("You", "They will ask who rules now."),
          DialogueLine(
            "The Sister",
            "They may begin by asking who needs breakfast.",
          ),
        ],
      ),
    ),
    vowBattle(
      chapter: 1,
      encounter: 1,
      player: "GLOOM",
      enemy: "GLOOM",
      name: "The Unrelieved Watch",
      objective:
          "Clear the gate by defeating the watch captain; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "You",
          "We are taking people out, not bringing an army in.",
        ),
        DialogueLine(
          "The Sister",
          "Then let them see us put the weapons down afterward.",
        ),
      ],
      victory: [
        DialogueLine.narrate(
          "The watch lowers its spears one at a time. Nobody has taught them an order for this.",
        ),
        DialogueLine(
          "The Sister",
          "Keep the stair open. A duty without an exit becomes something else.",
        ),
        DialogueLine("You", "I will put that in the first letter."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-136",
        title: "A Letter without a Crown",
        dialogue: [
          DialogueLine.narrate(
            "Aurelian riders arrive before the ink dries. Their warrant calls the stair a strategic asset. The flask has left a ring over the word asset.",
          ),
          DialogueLine("Seraphel", "I did not sign that."),
          DialogueLine("You", "Your seal did."),
          DialogueLine(
            "Seraphel",
            "Then my seal has acquired ambitions. Help me disappoint it.",
          ),
        ],
      ),
    ),
    vowBattle(
      chapter: 1,
      encounter: 2,
      player: "GLOOM",
      enemy: "DAWN",
      name: "The Borrowed Warrant",
      objective:
          "Defeat the delegation enforcing the false warrant; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "Seraphel",
          "A command can be legal and still require a refusal.",
        ),
        DialogueLine(
          "You",
          "Let this be the first refusal they record accurately.",
        ),
      ],
      victory: [
        DialogueLine.narrate(
          "The warrant is folded rather than burned. Numen will need evidence; the riders will need a way to admit they were wrong.",
        ),
        DialogueLine(
          "Seraphel",
          "There must be a table where none of us owns the chairs.",
        ),
        DialogueLine("You", "I know four cities that will object."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow01-01",
        title: "The Second Lamp",
        dialogue: [
          DialogueLine.narrate(
            "Before leaving, you place a spare lamp at the stairhead. Below, Thornmaw calls up to ask whether the roof is still there.",
          ),
          DialogueLine("You", "Most of it."),
          DialogueLine(
            "Thornmaw",
            "Good. We shall need somewhere to meet when she can come upstairs.",
          ),
          DialogueLine.narrate(
            "You send five invitations. The fifth goes down the stair, with enough oil for a week.",
          ),
        ],
      ),
    ),
  ],
);

final vow02 = StoryChapter(
  id: "vow02",
  title: "The Table with Five Edges",
  subtitle: "The Five Vows · Act 1 · The Work of Asking",
  playerDominion: "DAWN",
  stages: [
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow02-01",
        title: "The Table with Five Edges",
        dialogue: [
          DialogueLine.narrate(
            "The roofless Hall of Measures has not hosted a council since the roof fell. This recommends it to everyone for different reasons.",
          ),
          DialogueLine(
            "Numen",
            "No acoustics for a grand speech. No gallery for applause. Excellent.",
          ),
          DialogueLine("Kaelis", "No roof for rain."),
          DialogueLine(
            "Seraphel",
            "We can repair something while we argue. It may be a useful precedent.",
          ),
        ],
      ),
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-134",
        title: "Who Owns the Threshold",
        dialogue: [
          DialogueLine.narrate(
            "The Concord has posted guards at the public entrance. At the servants' entrance its own masons wait in the rain.",
          ),
          DialogueLine("Seraphel", "The hall belongs to the city."),
          DialogueLine("Inquisitor", "And the city belongs to the light."),
          DialogueLine("Seraphel", "Then the light can queue with the masons."),
        ],
      ),
    ),
    vowBattle(
      chapter: 2,
      encounter: 1,
      player: "DAWN",
      enemy: "DAWN",
      name: "The Proprietors of Dawn",
      objective:
          "Open the public hall by defeating its occupying guard; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine("Seraphel", "Keep the door behind us open."),
        DialogueLine("You", "So they can leave."),
      ],
      victory: [
        DialogueLine.narrate(
          "The captain withdraws. The masons enter, and the first common work of the five cities is an argument about drainage.",
        ),
        DialogueLine("Numen", "I shall preserve that in full."),
        DialogueLine("Kaelis", "You would."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-056",
        title: "A Seat for the Absent",
        dialogue: [
          DialogueLine.narrate(
            "A Pyre escort brings a chair of black iron and demands the place nearest the exit. Kaelis moves it beside the empty fifth chair.",
          ),
          DialogueLine(
            "Kaelis",
            "Ravenna is not a vacancy. Her sister carries her words until she can carry them herself.",
          ),
          DialogueLine("You", "And Thornmaw?"),
          DialogueLine(
            "The Sister",
            "He asked us to leave room for antlers. I have done what I can.",
          ),
        ],
      ),
    ),
    vowBattle(
      chapter: 2,
      encounter: 2,
      player: "DAWN",
      enemy: "PYRE",
      name: "The Iron Precedence",
      objective:
          "Defeat the escort disputing the council's equal seats; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "Kaelis",
          "We did not cool the forge to warm a different throne.",
        ),
        DialogueLine("You", "Then give them a place where they can hear that."),
      ],
      victory: [
        DialogueLine.narrate(
          "The iron chair stays. The escort takes ordinary stools. Nobody loses a seat to make room.",
        ),
        DialogueLine("Seraphel", "Five voices. No deciding voice."),
        DialogueLine(
          "Numen",
          "A difficult system. I am beginning to trust it.",
        ),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow02-01",
        title: "The First Condition",
        dialogue: [
          DialogueLine.narrate(
            "They agree to build a seal renewed by living people. Nothing may be hidden in its wording. Anyone may withdraw.",
          ),
          DialogueLine(
            "Kaelis",
            "And if someone withdraws at the wrong moment?",
          ),
          DialogueLine(
            "You",
            "Then we make something strong enough to survive an honest answer.",
          ),
          DialogueLine.narrate(
            "Numen writes the condition above the signatures, where nobody can mistake it for a footnote.",
          ),
        ],
      ),
    ),
  ],
);

final vow03 = StoryChapter(
  id: "vow03",
  title: "The Orchard of Borrowed Years",
  subtitle: "The Five Vows · Act 1 · The Work of Asking",
  playerDominion: "VERDANCE",
  stages: [
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow03-01",
        title: "The Orchard of Borrowed Years",
        dialogue: [
          DialogueLine.narrate(
            "The treaty is read to an orchard that has spent three seasons feeding soldiers. There is little left to promise it.",
          ),
          DialogueLine("You", "Thornmaw sent instructions."),
          DialogueLine(
            "Sproutling",
            "He always sends instructions. Did he send himself?",
          ),
          DialogueLine("You", "He is keeping a different promise today."),
        ],
      ),
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-005",
        title: "The Keeper's Exception",
        dialogue: [
          DialogueLine.narrate(
            "The rootkeepers will lend strength only if the orchard receives the first water forever. Beside the channel a village sets out empty jars.",
          ),
          DialogueLine(
            "You",
            "Forever is a large word to write beside a thirsty child.",
          ),
          DialogueLine(
            "Sproutling",
            "The roots do not know where the boundary is.",
          ),
          DialogueLine("You", "Then we must not teach them the wrong one."),
        ],
      ),
    ),
    vowBattle(
      chapter: 3,
      encounter: 1,
      player: "VERDANCE",
      enemy: "VERDANCE",
      name: "The Orchard Claim",
      objective:
          "Defeat the rootkeepers blocking the shared channel; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine("Sproutling", "Do we have to break the trees?"),
        DialogueLine(
          "You",
          "No. We have to stop the people speaking for them.",
        ),
      ],
      victory: [
        DialogueLine.narrate(
          "The gate lifts. Water reaches the orchard and the jars. The roots drink last and, to the keepers' embarrassment, survive.",
        ),
        DialogueLine("Sproutling", "Perhaps we asked them the wrong question."),
        DialogueLine("You", "Ask again tomorrow."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-183",
        title: "What the Roots Carried",
        dialogue: [
          DialogueLine.narrate(
            "Under the oldest tree the old calling has hardened into a knot. It repeats Thornmaw's silence in the voices of everyone he tried to protect.",
          ),
          DialogueLine(
            "Thornmaw",
            "I cannot be there. I can tell you where to cut.",
          ),
          DialogueLine("You", "You are speaking through a root."),
          DialogueLine("Thornmaw", "I am learning to delegate."),
        ],
      ),
    ),
    vowBattle(
      chapter: 3,
      encounter: 2,
      player: "VERDANCE",
      enemy: "GLOOM",
      name: "The Knotted Silence",
      objective:
          "Break the remnant haunting the orchard; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "Thornmaw",
          "Do not cut the living root beside it. They have grown together.",
        ),
        DialogueLine("You", "I can see the difference."),
      ],
      victory: [
        DialogueLine.narrate(
          "The knot opens around a green shoot. The old tree has been growing toward water, not toward the Shard.",
        ),
        DialogueLine("Thornmaw", "My vow is to tend what can grow without me."),
        DialogueLine(
          "Sproutling",
          "Then you will have to let us make mistakes.",
        ),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow03-01",
        title: "The Vow of Growth",
        dialogue: [
          DialogueLine.narrate(
            "The orchard sends no royal seal. It sends a basket of seeds, with instructions for giving half away.",
          ),
          DialogueLine("You", "No penalty if the seedlings die?"),
          DialogueLine(
            "Thornmaw",
            "Try again. That is the penalty. It is also the work.",
          ),
          DialogueLine.narrate(
            "The first vow travels to the roofless hall wrapped in damp cloth. It needs checking every morning.",
          ),
        ],
      ),
    ),
  ],
);

final vow04 = StoryChapter(
  id: "vow04",
  title: "The Cold Kiln",
  subtitle: "The Five Vows · Act 1 · The Work of Asking",
  playerDominion: "PYRE",
  stages: [
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow04-01",
        title: "The Cold Kiln",
        dialogue: [
          DialogueLine.narrate(
            "Ashmar's great forge is dark. Inside its firebox the smiths have built a smaller kiln, and are ashamed of how little it lights.",
          ),
          DialogueLine("Kaelis", "It cooked three hundred dinners yesterday."),
          DialogueLine("Forgewright", "It used to make sunspears."),
          DialogueLine(
            "Kaelis",
            "Three hundred people noticed the difference.",
          ),
        ],
      ),
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-048",
        title: "The Last Ember Tax",
        dialogue: [
          DialogueLine.narrate(
            "Draxus has closed the charcoal road. He calls the fuel a military reserve. The hospital calls it a winter.",
          ),
          DialogueLine("Draxus", "You cannot hold a city with soup."),
          DialogueLine(
            "Kaelis",
            "No. You can feed one. I have spent too long confusing the tasks.",
          ),
          DialogueLine("You", "We need the road, not his surrender oath."),
        ],
      ),
    ),
    vowBattle(
      chapter: 4,
      encounter: 1,
      player: "PYRE",
      enemy: "PYRE",
      name: "The Charcoal Road",
      objective:
          "Defeat the force withholding the city's fuel; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "Kaelis",
          "Leave a way back to the city. These are our smiths.",
        ),
        DialogueLine("Draxus", "Then give them something worth returning to."),
      ],
      victory: [
        DialogueLine.narrate(
          "The first carts go to the hospital. The second go to the kitchens. The army receives the third and discovers it can wait.",
        ),
        DialogueLine(
          "Kaelis",
          "Write every delivery down. No heroic exceptions.",
        ),
        DialogueLine("Forgewright", "That will be a remarkably dull ledger."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-170",
        title: "An Offer of Clean Fire",
        dialogue: [
          DialogueLine.narrate(
            "Aurelian engineers offer a radiant furnace. Its contract binds Ashmar's gates to the Concord for a hundred years.",
          ),
          DialogueLine("Seraphel", "I sent engineers. I did not send owners."),
          DialogueLine("Kaelis", "They brought both qualifications."),
          DialogueLine("You", "We can keep the design and refuse the terms."),
        ],
      ),
    ),
    vowBattle(
      chapter: 4,
      encounter: 2,
      player: "PYRE",
      enemy: "DAWN",
      name: "The Furnace Contract",
      objective:
          "Defeat the contract guard impounding the kiln; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "Seraphel",
          "Your knowledge will be credited. Your claim will not.",
        ),
        DialogueLine(
          "Kaelis",
          "That is a distinction Ashmar should have learned sooner.",
        ),
      ],
      victory: [
        DialogueLine.narrate(
          "The engineers leave a drawing on the workbench. One stays to learn how a charcoal fire is banked for the night.",
        ),
        DialogueLine(
          "Kaelis",
          "My vow is to spend strength where it warms someone other than me.",
        ),
        DialogueLine("You", "Tomorrow, too."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow04-01",
        title: "The Vow of the Hearth",
        dialogue: [
          DialogueLine.narrate(
            "At midnight Kaelis returns to the dead forge alone. A pale warmth rests inside her gauntlet. She closes it before anyone arrives.",
          ),
          DialogueLine(
            "The Voice",
            "We remember what your city sounded like when it was warm.",
          ),
          DialogueLine("Kaelis", "So do I."),
          DialogueLine.narrate(
            "She signs the second vow with a hand that is no longer cold. The ink dries faster there than anywhere else.",
          ),
        ],
      ),
    ),
  ],
);

final vow05 = StoryChapter(
  id: "vow05",
  title: "The Page That Refused the Tide",
  subtitle: "The Five Vows · Act 1 · The Work of Asking",
  playerDominion: "TIDE",
  stages: [
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow05-01",
        title: "The Page That Refused the Tide",
        dialogue: [
          DialogueLine.narrate(
            "Meridine receives the vows at low water. Numen weighs each page down with a different stone, as though identical weights might imply identical words.",
          ),
          DialogueLine("Numen", "I am publishing what I erased."),
          DialogueLine("You", "All of it?"),
          DialogueLine("Numen", "That is the portion causing difficulty."),
        ],
      ),
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-099",
        title: "The Archive's Immune Response",
        dialogue: [
          DialogueLine.narrate(
            "The custodians have orders to preserve public calm. They have interpreted public with unusual precision and calm with none at all.",
          ),
          DialogueLine(
            "Numen",
            "I wrote the order. It has outlived its excuse.",
          ),
          DialogueLine("You", "Can you rescind it?"),
          DialogueLine(
            "Numen",
            "It requires a truthful record. We are currently fighting over the paper.",
          ),
        ],
      ),
    ),
    vowBattle(
      chapter: 5,
      encounter: 1,
      player: "TIDE",
      enemy: "TIDE",
      name: "The Custodians of Calm",
      objective:
          "Defeat the custodians barring the public archive; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "Numen",
          "Do not destroy their tablets. Those contain the names of the people I omitted.",
        ),
        DialogueLine("You", "Then we bring the tablets out with them."),
      ],
      victory: [
        DialogueLine.narrate(
          "The doors open onto a queue. Most people have come to find a relative, not an explanation of the world.",
        ),
        DialogueLine("Numen", "I prepared a speech."),
        DialogueLine("You", "Start with the index."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-185",
        title: "The Page in His Hand",
        dialogue: [
          DialogueLine.narrate(
            "One undated record describes Kaelis carrying a warmth she did not kindle. Numen recognizes his handwriting and cannot tell whether it is memory or warning.",
          ),
          DialogueLine(
            "Numen",
            "The archive has never reliably distinguished those things.",
          ),
          DialogueLine("You", "Will you tell her?"),
          DialogueLine(
            "Numen",
            "After I have stopped wanting the answer to be convenient.",
          ),
        ],
      ),
    ),
    vowBattle(
      chapter: 5,
      encounter: 2,
      player: "TIDE",
      enemy: "GLOOM",
      name: "The Convenient Erasure",
      objective:
          "Defeat the remnant trying to consume the restored record; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine("Numen", "It knows which page I am tempted to lose."),
        DialogueLine("You", "Hold that page where everyone can see it."),
      ],
      victory: [
        DialogueLine.narrate(
          "The remnant burns around the blank margin. The difficult sentence remains. Numen makes five copies before reading it again.",
        ),
        DialogueLine(
          "Numen",
          "My vow is to keep the whole record, including the hand that altered it.",
        ),
        DialogueLine("You", "Put your name first."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow05-01",
        title: "Five Copies",
        dialogue: [
          DialogueLine.narrate(
            "The third vow returns with the published confession. Beneath each erased name is a space for corrections from the living.",
          ),
          DialogueLine(
            "Numen",
            "Truth is not a thing I can finish on their behalf.",
          ),
          DialogueLine("You", "Will the seal accept an unfinished record?"),
          DialogueLine("Numen", "If it cannot, we are building another lie."),
        ],
      ),
    ),
  ],
);
