import '../story_data.dart';

import '../vow_encounters.dart';

// Act 3: The True Sentence. Actual chapter-five continuity governs.

final vow11 = StoryChapter(
  id: "vow11",
  title: "The Bell Without a Ringer",
  subtitle: "The Five Vows · Act 3 · The True Sentence",
  playerDominion: "DAWN",
  stages: [
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow11-01",
        title: "The Bell Without a Ringer",
        dialogue: [
          DialogueLine.narrate(
            "The five vows ring once across the city. Everyone hears the bell in a different street. For a moment the council mistakes agreement for success.",
          ),
          DialogueLine("Numen", "The intervals are narrowing."),
          DialogueLine("You", "Is that bad?"),
          DialogueLine(
            "Numen",
            "They are becoming the same interval. That is not what we wrote.",
          ),
        ],
      ),
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-137",
        title: "A Useful Mistake",
        dialogue: [
          DialogueLine.narrate(
            "The Concord begins ringing the bell for the citizens. Attendance is consent; absence is a clerical delay.",
          ),
          DialogueLine("Seraphel", "You have made renewal into a head count."),
          DialogueLine("Inquisitor", "People are busy. We are assisting them."),
          DialogueLine("You", "Then assist them by letting them answer."),
        ],
      ),
    ),
    vowBattle(
      chapter: 11,
      encounter: 1,
      player: "DAWN",
      enemy: "DAWN",
      name: "The Counted Assent",
      objective:
          "Defeat the officials enforcing automatic renewal; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine("Seraphel", "Take down the attendance boards."),
        DialogueLine("You", "Nobody's silence will be used as a signature."),
      ],
      victory: [
        DialogueLine.narrate(
          "The bell loses half its strength. The five lights remain, uneven and distinct. Numen exhales as though the weakness is good news.",
        ),
        DialogueLine("Numen", "It is finally measuring something real."),
        DialogueLine(
          "Seraphel",
          "Then we can finally repair what it shows us.",
        ),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-009",
        title: "The Orchard's No",
        dialogue: [
          DialogueLine.narrate(
            "The rootkeepers withdraw for a day to harvest before the storm. Their absence strains the other lights. The council asks them to reconsider.",
          ),
          DialogueLine("Sproutling", "You said we could refuse."),
          DialogueLine("You", "We did."),
          DialogueLine(
            "Sproutling",
            "Then why have you brought soldiers to ask us twice?",
          ),
        ],
      ),
    ),
    vowBattle(
      chapter: 11,
      encounter: 2,
      player: "DAWN",
      enemy: "VERDANCE",
      name: "The Helpful Occupation",
      objective:
          "Defeat the militia occupying the harvest road; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine("You", "Their no is not an attack on the seal."),
        DialogueLine("Seraphel", "Our answer to it might be."),
      ],
      victory: [
        DialogueLine.narrate(
          "The militia withdraws. Four cities send harvesters instead of negotiators. At dusk the orchard renews without being asked a third time.",
        ),
        DialogueLine("Sproutling", "That was a better argument."),
        DialogueLine("You", "It was not supposed to be an argument."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow11-01",
        title: "The Misplaced Warmth",
        dialogue: [
          DialogueLine.narrate(
            "When the bell rings again Kaelis answers before it sounds. Numen sees her mouth move a fraction ahead of everyone else's.",
          ),
          DialogueLine("Numen", "How did you know the moment?"),
          DialogueLine("Kaelis", "I have been waiting for it all day."),
          DialogueLine.narrate(
            "It is a truthful answer. Numen writes it down and leaves room beneath it.",
          ),
        ],
      ),
    ),
  ],
);

final vow12 = StoryChapter(
  id: "vow12",
  title: "The Ash That Remembers",
  subtitle: "The Five Vows · Act 3 · The True Sentence",
  playerDominion: "PYRE",
  stages: [
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow12-01",
        title: "The Ash That Remembers",
        dialogue: [
          DialogueLine.narrate(
            "Kaelis leads you below the coal store. In five jars she has saved the ashes of the old forge. A pale heat passes between them without consuming anything.",
          ),
          DialogueLine(
            "Kaelis",
            "It began before the Cantor came. I thought that mattered.",
          ),
          DialogueLine("You", "It matters. It does not make it safe."),
          DialogueLine("Kaelis", "I know. That is why you are here now."),
        ],
      ),
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-054",
        title: "The Captains Find a Traitor",
        dialogue: [
          DialogueLine.narrate(
            "Draxus follows with soldiers. He sees the warmth and reaches the obvious conclusion before Kaelis has finished speaking.",
          ),
          DialogueLine(
            "Draxus",
            "You ordered us to let the forge die. Then you kept its fire for yourself.",
          ),
          DialogueLine(
            "Kaelis",
            "Yes. That is the part I have no defense for.",
          ),
          DialogueLine("You", "An admission is not permission to execute her."),
        ],
      ),
    ),
    vowBattle(
      chapter: 12,
      encounter: 1,
      player: "PYRE",
      enemy: "PYRE",
      name: "The Ash Tribunal",
      objective:
          "Defeat the captains demanding an immediate execution; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "Kaelis",
          "Take my command. Leave the people in this room alive.",
        ),
        DialogueLine(
          "You",
          "There will be a hearing with more than one possible ending.",
        ),
      ],
      victory: [
        DialogueLine.narrate(
          "Kaelis lays her command seal on the floor. Draxus picks it up without looking pleased. Neither has won what they wanted.",
        ),
        DialogueLine(
          "Kaelis",
          "I can answer questions without a throne behind me.",
        ),
        DialogueLine("You", "Then start with the first warmth."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-184",
        title: "The Vow That Read True",
        dialogue: [
          DialogueLine.narrate(
            "She repeats her vow. The second light answers honestly: strength spent to warm someone else. A thousand joined voices also meet that condition.",
          ),
          DialogueLine(
            "The Voice",
            "We did not change her words. We believed them.",
          ),
          DialogueLine("Kaelis", "You let me think the warmth was mine."),
          DialogueLine(
            "The Voice",
            "You let yourself think the difference would not matter.",
          ),
        ],
      ),
    ),
    vowBattle(
      chapter: 12,
      encounter: 2,
      player: "PYRE",
      enemy: "GLOOM",
      name: "The Borrowed Hearth",
      objective:
          "Defeat the communion echo rooted in Kaelis's hidden warmth; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "Kaelis",
          "It has been answering when I thought I was choosing.",
        ),
        DialogueLine("You", "Then choose now, while we can hear you."),
      ],
      victory: [
        DialogueLine.narrate(
          "The warmth leaves her gauntlet. Her hand is cold again. Across the city the second vow goes dark.",
        ),
        DialogueLine(
          "Kaelis",
          "I promised warmth. I never promised to remain myself to give it.",
        ),
        DialogueLine(
          "You",
          "That is what we must add, if you choose to sign again.",
        ),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow12-01",
        title: "The Empty Signature",
        dialogue: [
          DialogueLine.narrate(
            "The vows have four signatures and one unmarked space. Kaelis asks Numen not to erase the first version.",
          ),
          DialogueLine(
            "Kaelis",
            "Let them see how a true sentence became a lie.",
          ),
          DialogueLine(
            "Numen",
            "And the part where you brought us here yourself.",
          ),
          DialogueLine.narrate(
            "Outside someone has begun singing the kitchen song in a voice that is not quite singular.",
          ),
        ],
      ),
    ),
  ],
);

final vow13 = StoryChapter(
  id: "vow13",
  title: "The Witness in the Water",
  subtitle: "The Five Vows · Act 3 · The True Sentence",
  playerDominion: "TIDE",
  stages: [
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow13-01",
        title: "The Witness in the Water",
        dialogue: [
          DialogueLine.narrate(
            "The cistern reflects five people as one figure. When Kaelis steps away the reflection does not change.",
          ),
          DialogueLine(
            "Numen",
            "It is showing us a conclusion it reached before we arrived.",
          ),
          DialogueLine("You", "Can we make it show the evidence?"),
          DialogueLine("Numen", "We can make it stop being our only witness."),
        ],
      ),
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-090",
        title: "The Perfect Transcript",
        dialogue: [
          DialogueLine.narrate(
            "The transcript has every speaker agreeing. The words are exact. The pauses between them have been removed.",
          ),
          DialogueLine("The Sister", "That is where Ravenna changed her mind."),
          DialogueLine("Numen", "I recorded the silence as nothing."),
          DialogueLine(
            "You",
            "Then the record lost the most important answer.",
          ),
        ],
      ),
    ),
    vowBattle(
      chapter: 13,
      encounter: 1,
      player: "TIDE",
      enemy: "TIDE",
      name: "The Perfect Agreement",
      objective:
          "Defeat the constructs defending the altered transcript; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "Numen",
          "Keep the pauses. Even the ones that make us look uncertain.",
        ),
        DialogueLine("The Sister", "Especially those."),
      ],
      victory: [
        DialogueLine.narrate(
          "The complete recording sounds slower, less certain, alive. The reflection gains a seam through its center.",
        ),
        DialogueLine(
          "Numen",
          "There. We did not agree about what the warmth meant.",
        ),
        DialogueLine("You", "And she did not consent to what it became."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-213",
        title: "The Cantor's Evidence",
        dialogue: [
          DialogueLine.narrate(
            "The Cantor arrives with people whose pain has eased. No chain binds them. They ask why you would take the quiet away.",
          ),
          DialogueLine(
            "The Cantor",
            "You cannot rescue someone by refusing to hear their answer.",
          ),
          DialogueLine(
            "You",
            "We are asking whether they can give a different one tomorrow.",
          ),
          DialogueLine("The Cantor", "Then ask them. We will wait outside."),
        ],
      ),
    ),
    vowBattle(
      chapter: 13,
      encounter: 2,
      player: "TIDE",
      enemy: "GLOOM",
      name: "The Cistern's Chorus",
      objective:
          "Defeat the echo preventing a witness from leaving the cistern; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "The Sister",
          "One of them asked to step outside. The water would not let her.",
        ),
        DialogueLine("You", "Then we start by making room for that answer."),
      ],
      victory: [
        DialogueLine.narrate(
          "One witness leaves. Four choose to stay. The Cantor does not call the departing woman back.",
        ),
        DialogueLine("The Cantor", "Our mercy is unfinished too."),
        DialogueLine("You", "Keep that in your next song."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow13-01",
        title: "The Sentence Restored",
        dialogue: [
          DialogueLine.narrate(
            "Numen adds a clause to every vow: I remain someone who may choose otherwise. The ink divides the reflection into five.",
          ),
          DialogueLine("Kaelis", "Will a sentence do it?"),
          DialogueLine(
            "Numen",
            "No. A sentence tells us what we must do. I have mistaken those things before.",
          ),
          DialogueLine.narrate(
            "The corrected pages leave on five boats. Each carries the full record of why the correction was needed.",
          ),
        ],
      ),
    ),
  ],
);

final vow14 = StoryChapter(
  id: "vow14",
  title: "The Root That Said No",
  subtitle: "The Five Vows · Act 3 · The True Sentence",
  playerDominion: "VERDANCE",
  stages: [
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow14-01",
        title: "The Root That Said No",
        dialogue: [
          DialogueLine.narrate(
            "The nursery's roots have joined every tree to one ring. Their fruit ripens without water. The gardeners fear how well it works.",
          ),
          DialogueLine("Sproutling", "We have never fed so many people."),
          DialogueLine("You", "What happens if one tree wants different soil?"),
          DialogueLine(
            "Sproutling",
            "We tried moving one. The others screamed.",
          ),
        ],
      ),
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-013",
        title: "A Garden with No Edges",
        dialogue: [
          DialogueLine.narrate(
            "The keepers demand time to study the abundance. In the seed house roots close around the traveling pots.",
          ),
          DialogueLine(
            "Thornmaw",
            "A forest is not one tree repeated until the horizon gives up.",
          ),
          DialogueLine("You", "Can you reach them from below the city?"),
          DialogueLine("Thornmaw", "I can ask. The answer must be theirs."),
        ],
      ),
    ),
    vowBattle(
      chapter: 14,
      encounter: 1,
      player: "VERDANCE",
      enemy: "VERDANCE",
      name: "The Root-Ring Keepers",
      objective:
          "Defeat the keepers preventing the seedlings' removal; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "Sproutling",
          "The small pots first. They still have separate roots.",
        ),
        DialogueLine("You", "Then we keep it that way."),
      ],
      victory: [
        DialogueLine.narrate(
          "The gardeners carry seedlings through a passage the oldest tree opened beneath the wall. It has refused the ring from inside it.",
        ),
        DialogueLine("Thornmaw", "I should have trusted it to choose."),
        DialogueLine("Sproutling", "You can begin now."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-183",
        title: "The Cost of Separate Soil",
        dialogue: [
          DialogueLine.narrate(
            "Cutting the pale root-ring will lose this season's harvest. Keeping it will lose the next season's seeds.",
          ),
          DialogueLine("You", "We will need food from four cities."),
          DialogueLine("Kaelis", "Ashmar will send what it has."),
          DialogueLine("Sproutling", "It has so little."),
        ],
      ),
    ),
    vowBattle(
      chapter: 14,
      encounter: 2,
      player: "VERDANCE",
      enemy: "GLOOM",
      name: "The White Root",
      objective:
          "Defeat the echo binding the nursery to the root-ring; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "Kaelis",
          "Then we will be hungry separately, and help each other. Those are allowed together.",
        ),
        DialogueLine("You", "The gardeners are clear. Cut the binding."),
      ],
      victory: [
        DialogueLine.narrate(
          "The fruit falls before it ripens. Beneath it five kinds of seed remain. The gardeners collect them in separate baskets.",
        ),
        DialogueLine("Sproutling", "I wanted there to be no cost."),
        DialogueLine("You", "So did everyone who built the old locks."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow14-01",
        title: "An Ordinary Harvest",
        dialogue: [
          DialogueLine.narrate(
            "The first relief cart contains turnips. A note from Draxus says the army can manage on beans.",
          ),
          DialogueLine("Kaelis", "He is making an apology badly."),
          DialogueLine("You", "It still feeds people."),
          DialogueLine.narrate(
            "For the first time since the forge went cold Kaelis laughs without any other voice arriving with hers.",
          ),
        ],
      ),
    ),
  ],
);

final vow15 = StoryChapter(
  id: "vow15",
  title: "The Fifth Chair",
  subtitle: "The Five Vows · Act 3 · The True Sentence",
  playerDominion: "GLOOM",
  stages: [
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow15-01",
        title: "The Fifth Chair",
        dialogue: [
          DialogueLine.narrate(
            "A water-mirror carries Ravenna from the stair. The council reconvenes with Kaelis's iron chair empty. She stands beside it until Seraphel asks whether she intends to remain there all day.",
          ),
          DialogueLine(
            "Kaelis",
            "I do not know whether I am still welcome to sit.",
          ),
          DialogueLine(
            "Seraphel",
            "Then ask us. Do not turn our answer into something you punish yourself with.",
          ),
          DialogueLine("You", "Sit while we decide what comes next."),
        ],
      ),
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-170",
        title: "The Proposal of Four",
        dialogue: [
          DialogueLine.narrate(
            "The Inquisitor presents a cleaner binding with four vows. It names Ashmar a containment district and calls the omission necessary symmetry.",
          ),
          DialogueLine(
            "Numen",
            "Four is symmetrical. It is also the wrong number of cities.",
          ),
          DialogueLine("Inquisitor", "One of them betrayed the others."),
          DialogueLine(
            "Ravenna",
            "A city is not a woman, and a woman is not her worst answer.",
          ),
        ],
      ),
    ),
    vowBattle(
      chapter: 15,
      encounter: 1,
      player: "GLOOM",
      enemy: "DAWN",
      name: "The Fourfold Seal",
      objective:
          "Defeat the escort enforcing Ashmar's exclusion; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "Seraphel",
          "Remove the district order. Leave the witnesses their seats.",
        ),
        DialogueLine(
          "You",
          "We are not improving the old lie by making it smaller.",
        ),
      ],
      victory: [
        DialogueLine.narrate(
          "The fourfold diagram is kept beside the original as a warning. Kaelis returns to the iron chair without her command seal.",
        ),
        DialogueLine(
          "Ravenna",
          "Now we can hear you without the chair speaking first.",
        ),
        DialogueLine("Kaelis", "I should have tried this years ago."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-181",
        title: "A Convenient Monster",
        dialogue: [
          DialogueLine.narrate(
            "Below the table the withdrawn warmth gathers every accusation into a shape. It offers Kaelis a role everyone understands.",
          ),
          DialogueLine(
            "The Voice",
            "They would find it easier to forgive a monster than a neighbor who made a choice.",
          ),
          DialogueLine("Kaelis", "Yes. I would find it easier too."),
          DialogueLine("You", "Then let it remain difficult."),
        ],
      ),
    ),
    vowBattle(
      chapter: 15,
      encounter: 2,
      player: "GLOOM",
      enemy: "GLOOM",
      name: "The Shape of Blame",
      objective:
          "Defeat the echo feeding on the council's accusations; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine("Kaelis", "I am responsible. I am not all that happened."),
        DialogueLine("You", "We will keep both truths in the room."),
      ],
      victory: [
        DialogueLine.narrate(
          "The shape thins. Nobody applauds. Draxus places a relief ledger beside Kaelis and asks her to check the sums.",
        ),
        DialogueLine("Kaelis", "You are trusting me with fuel?"),
        DialogueLine("Draxus", "I am asking you to count it where I can see."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow15-01",
        title: "What a New Vow Costs",
        dialogue: [
          DialogueLine.narrate(
            "The corrected fifth place waits. Kaelis adds a clause: I will not make another person's silence into permission to save them.",
          ),
          DialogueLine("Ravenna", "That leaves you with fewer grand gestures."),
          DialogueLine("Kaelis", "I have a ledger to finish."),
          DialogueLine.narrate(
            "The second light returns, smaller than before. It keeps its own time.",
          ),
        ],
      ),
    ),
  ],
);
