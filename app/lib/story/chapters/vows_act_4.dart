import '../story_data.dart';

import '../vow_encounters.dart';

// Act 4: A Distance Freely Chosen. Actual chapter-five continuity governs.

final vow16 = StoryChapter(
  id: "vow16",
  title: "The City of Separate Fires",
  subtitle: "The Five Vows · Act 4 · A Distance Freely Chosen",
  playerDominion: "PYRE",
  stages: [
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow16-01",
        title: "The City of Separate Fires",
        dialogue: [
          DialogueLine.narrate(
            "The Cantor's procession enters Ashmar with blankets, fuel, and no weapons the guards can recognize. Half the city welcomes it.",
          ),
          DialogueLine("The Cantor", "We have brought enough for everyone."),
          DialogueLine(
            "Kaelis",
            "Then leave enough for the people who will not join you.",
          ),
          DialogueLine("The Cantor", "Show us where they live."),
        ],
      ),
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-056",
        title: "The Panic at the Kiln",
        dialogue: [
          DialogueLine.narrate(
            "Draxus closes the inner streets. Families split between the procession and kiln begin calling each other prisoners.",
          ),
          DialogueLine("Draxus", "I cannot tell who is still themselves."),
          DialogueLine(
            "Kaelis",
            "Then ask a smaller question. Who is trying to go home?",
          ),
          DialogueLine("You", "Start by opening their street."),
        ],
      ),
    ),
    vowBattle(
      chapter: 16,
      encounter: 1,
      player: "PYRE",
      enemy: "PYRE",
      name: "The Closed Streets",
      objective:
          "Defeat the blockade separating the city's families; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "Kaelis",
          "Nobody is required to stand on our side to pass.",
        ),
        DialogueLine("You", "Keep the route clear in both directions."),
      ],
      victory: [
        DialogueLine.narrate(
          "People cross toward both fires. Some carry blankets from the procession to neighbors who refused it. Nobody stops them.",
        ),
        DialogueLine("Draxus", "I have no formation for this."),
        DialogueLine("Kaelis", "Then stand where someone can ask for help."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-215",
        title: "Enough for Everyone",
        dialogue: [
          DialogueLine.narrate(
            "At the great forge a white flame climbs without fuel. The Cantor turns to it with the same alarm you feel.",
          ),
          DialogueLine(
            "The Cantor",
            "We offered warmth. We did not offer the city.",
          ),
          DialogueLine(
            "The Voice",
            "We could hold all of you. None would need to stand outside again.",
          ),
          DialogueLine("You", "And the people who want the door?"),
        ],
      ),
    ),
    vowBattle(
      chapter: 16,
      encounter: 2,
      player: "PYRE",
      enemy: "GLOOM",
      name: "The Hearth without an Outside",
      objective:
          "Defeat the echo drawing the district into one flame; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "Kaelis",
          "I know that warmth. I know how much it leaves unsaid.",
        ),
        DialogueLine(
          "The Cantor",
          "Then we will help you keep it from taking them.",
        ),
      ],
      victory: [
        DialogueLine.narrate(
          "The white flame breaks into sparks. The Cantor carries a burned child to the doctor who treated the stoker.",
        ),
        DialogueLine("The Cantor", "You were right about the door."),
        DialogueLine("Kaelis", "You were right about the blankets."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow16-01",
        title: "What the Procession Leaves",
        dialogue: [
          DialogueLine.narrate(
            "The procession departs smaller. Some remain because they have found work. Others leave because they found the quiet they wanted.",
          ),
          DialogueLine("You", "We have not ended this."),
          DialogueLine(
            "Kaelis",
            "No. We have kept a city able to argue tomorrow.",
          ),
          DialogueLine.narrate(
            "Above the cold forge hundreds of separate fires answer the night.",
          ),
        ],
      ),
    ),
  ],
);

final vow17 = StoryChapter(
  id: "vow17",
  title: "The Measure of a Voice",
  subtitle: "The Five Vows · Act 4 · A Distance Freely Chosen",
  playerDominion: "TIDE",
  stages: [
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow17-01",
        title: "The Measure of a Voice",
        dialogue: [
          DialogueLine.narrate(
            "Numen builds five beacons with different intervals. The seal must carry an answer without smoothing away the person who sent it.",
          ),
          DialogueLine(
            "Numen",
            "Agreement should travel. Identity should not have to travel with it.",
          ),
          DialogueLine("You", "Can you do that?"),
          DialogueLine(
            "Numen",
            "I can test whether I have failed before we put cities inside it.",
          ),
        ],
      ),
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-127",
        title: "The Patient Machine",
        dialogue: [
          DialogueLine.narrate(
            "The tide-engine waits for identical answers before proceeding. It was designed by someone who feared errors more than silence.",
          ),
          DialogueLine("Numen", "That someone was me."),
          DialogueLine(
            "The Sister",
            "I have noticed a pattern in your introductions.",
          ),
          DialogueLine("Numen", "I am trying to end it without falsifying it."),
        ],
      ),
    ),
    vowBattle(
      chapter: 17,
      encounter: 1,
      player: "TIDE",
      enemy: "TIDE",
      name: "The Engine of One Answer",
      objective:
          "Defeat the archive constructs blocking the separate beacon signals; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "You",
          "We keep all five intervals, even if the machine calls them noise.",
        ),
        DialogueLine("Numen", "Especially if it calls them noise."),
      ],
      victory: [
        DialogueLine.narrate(
          "The engine accepts a staggered sequence. Five lamps remain five lamps. The water between them is dark and ordinary.",
        ),
        DialogueLine("Numen", "A successful absence."),
        DialogueLine("You", "Put that in the engineering report."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-172",
        title: "A Single Golden Signal",
        dialogue: [
          DialogueLine.narrate(
            "The Concord's relay replaces Seraphel's answer with a permanent yes. Its engineers call it a precaution against her being absent.",
          ),
          DialogueLine("Seraphel", "If I am absent, send someone to ask why."),
          DialogueLine("Inquisitor", "The seal cannot wait on a person."),
          DialogueLine("Seraphel", "Then it is already the wrong seal."),
        ],
      ),
    ),
    vowBattle(
      chapter: 17,
      encounter: 2,
      player: "TIDE",
      enemy: "DAWN",
      name: "The Permanent Assent",
      objective:
          "Defeat the relay wardens preserving the false signal; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine("Seraphel", "Let it go dark until I answer."),
        DialogueLine("You", "The others know how to wait now."),
      ],
      victory: [
        DialogueLine.narrate(
          "One lamp goes out. Four carry the strain without joining. When Seraphel answers her light returns in its imperfect rhythm.",
        ),
        DialogueLine("Numen", "It can survive a pause."),
        DialogueLine("Seraphel", "Now teach it to survive an honest no."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow17-01",
        title: "The Missing Distance",
        dialogue: [
          DialogueLine.narrate(
            "It cannot. At a full refusal the signals meet in the empty center and become one. Numen marks the failure in red.",
          ),
          DialogueLine("Kaelis", "What keeps the center empty?"),
          DialogueLine(
            "Numen",
            "Someone must carry the distance while the others renew. Outside the warmth, able to leave it.",
          ),
          DialogueLine.narrate(
            "Kaelis reads the measurement twice. This time she asks everyone else to read it with her.",
          ),
        ],
      ),
    ),
  ],
);

final vow18 = StoryChapter(
  id: "vow18",
  title: "The Place Left Empty",
  subtitle: "The Five Vows · Act 4 · A Distance Freely Chosen",
  playerDominion: "DAWN",
  stages: [
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow18-01",
        title: "The Place Left Empty",
        dialogue: [
          DialogueLine.narrate(
            "Seraphel prepares to step into the empty center. Her halo fits the measurement perfectly. That is what frightens her.",
          ),
          DialogueLine("Seraphel", "I was made for this shape."),
          DialogueLine("You", "That does not decide whether you must take it."),
          DialogueLine(
            "Seraphel",
            "I know. I am waiting to discover whether I believe myself.",
          ),
        ],
      ),
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-171",
        title: "The Kindest Command",
        dialogue: [
          DialogueLine.narrate(
            "The Concord kneels and thanks her for a sacrifice she has not offered. Their gratitude fills the garden like a locked gate.",
          ),
          DialogueLine("Inquisitor", "The people need you."),
          DialogueLine(
            "Seraphel",
            "They needed me yesterday. I was allowed to be a person then.",
          ),
          DialogueLine(
            "You",
            "Stand up. Let her answer without your knees on the scale.",
          ),
        ],
      ),
    ),
    vowBattle(
      chapter: 18,
      encounter: 1,
      player: "DAWN",
      enemy: "DAWN",
      name: "The Grateful Guard",
      objective:
          "Defeat the guard enforcing Seraphel's presumed sacrifice; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "Seraphel",
          "I am not refusing mercy. I am refusing your ownership of it.",
        ),
        DialogueLine("You", "Clear a path back out of the circle."),
      ],
      victory: [
        DialogueLine.narrate(
          "The guard stands. Seraphel steps away and discovers that the world has not ended because she wanted to remain in it.",
        ),
        DialogueLine("Seraphel", "No."),
        DialogueLine("You", "We heard you."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-041",
        title: "An Old Warden's Habit",
        dialogue: [
          DialogueLine.narrate(
            "Through the water-mirror Ravenna watches Thornmaw send a root into the circle. He meant to spare them the question. It is the same mistake in an older shape.",
          ),
          DialogueLine("Thornmaw", "I know how to wait."),
          DialogueLine(
            "Ravenna",
            "You also know how to mistake waiting for a life.",
          ),
          DialogueLine("You", "Will you withdraw it if we ask?"),
        ],
      ),
    ),
    vowBattle(
      chapter: 18,
      encounter: 2,
      player: "DAWN",
      enemy: "VERDANCE",
      name: "The Root in the Empty Place",
      objective:
          "Defeat the rootbound guardians keeping the center occupied; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine("Thornmaw", "Yes. I can withdraw it."),
        DialogueLine(
          "Ravenna",
          "Then do. We are practicing a different answer.",
        ),
      ],
      victory: [
        DialogueLine.narrate(
          "The root lifts. Grass survived beneath it. Thornmaw says nothing for a long time, and nobody fills the silence for him.",
        ),
        DialogueLine("Thornmaw", "I would like to see the orchard again."),
        DialogueLine("You", "We will make that possible too."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow18-01",
        title: "A Volunteer with Witnesses",
        dialogue: [
          DialogueLine.narrate(
            "Kaelis asks for the outer watch. The costs are read before she offers: distance, the loss of shared warmth, and no promise of return.",
          ),
          DialogueLine(
            "Kaelis",
            "I am not paying for a pardon. If you make it that, refuse me.",
          ),
          DialogueLine("Seraphel", "We may still ask you to stay."),
          DialogueLine("Kaelis", "I know. That is what makes this a choice."),
        ],
      ),
    ),
  ],
);

final vow19 = StoryChapter(
  id: "vow19",
  title: "The Distance Between Hands",
  subtitle: "The Five Vows · Act 4 · A Distance Freely Chosen",
  playerDominion: "GLOOM",
  stages: [
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow19-01",
        title: "The Distance Between Hands",
        dialogue: [
          DialogueLine.narrate(
            "The vows descend the well-kept stair. Ravenna remains at the stone. Her sister carries the fifth light; Thornmaw walks beside her instead of in front.",
          ),
          DialogueLine("Ravenna", "There is still time to choose differently."),
          DialogueLine("Kaelis", "Read the cost again."),
          DialogueLine("Numen", "All of it."),
        ],
      ),
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-213",
        title: "The Consequence Remains",
        dialogue: [
          DialogueLine.narrate(
            "The chamber remembers the Unanswered. Old weather gathers around every promise, waiting to discover which will become another prison.",
          ),
          DialogueLine(
            "The First Caller",
            "It is what I left behind. Do not call it fate to spare my feelings.",
          ),
          DialogueLine("You", "We will not."),
          DialogueLine(
            "The Sister",
            "And we will not put someone back in my place to make the story tidy.",
          ),
        ],
      ),
    ),
    vowBattle(
      chapter: 19,
      encounter: 1,
      player: "GLOOM",
      enemy: "GLOOM",
      name: "The Weather of Old Promises",
      objective:
          "Defeat the remnant surrounding the new binding; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "Ravenna",
          "The old stone stays held until the new seal answers. We do not gamble with the people above.",
        ),
        DialogueLine("You", "We make room without letting go too early."),
      ],
      victory: [
        DialogueLine.narrate(
          "The weather breaks against five separate lights. The stair remains visible through it, every lamp still burning.",
        ),
        DialogueLine("Thornmaw", "A way back. We remembered."),
        DialogueLine("Kaelis", "Keep remembering after I have gone."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-215",
        title: "The Last Warm Offer",
        dialogue: [
          DialogueLine.narrate(
            "Beyond the lattice the Voice offers Kaelis the sound of her city before the forge died. Every hammer is exactly where she remembers it.",
          ),
          DialogueLine(
            "The Voice",
            "We could return what you lost. We could make the cold mean something.",
          ),
          DialogueLine(
            "Kaelis",
            "It already means people needed fuel. I do not need a god to make their hunger important.",
          ),
          DialogueLine("The Voice", "We did not want you to suffer alone."),
        ],
      ),
    ),
    vowBattle(
      chapter: 19,
      encounter: 2,
      player: "GLOOM",
      enemy: "GLOOM",
      name: "The Warmth That Will Not Release",
      objective:
          "Defeat the echo holding the outer causeway; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "Kaelis",
          "Then let me stand apart without calling it abandonment.",
        ),
        DialogueLine("You", "We will answer from here."),
      ],
      victory: [
        DialogueLine.narrate(
          "Kaelis opens her hand. The warmth leaves. She steps onto the outer causeway with an ordinary coal, knowing it will eventually go out.",
        ),
        DialogueLine("The Voice", "We do not understand."),
        DialogueLine("Kaelis", "Neither did I. Keep listening."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow19-01",
        title: "The Fifth Distance",
        dialogue: [
          DialogueLine.narrate(
            "The lattice closes around an empty center. Kaelis is beyond its warmth, her red light distinct. The binding holds. Ravenna rises from the stone.",
          ),
          DialogueLine("The Sister", "Are you coming upstairs?"),
          DialogueLine(
            "Ravenna",
            "Slowly. I have spent a great deal of time planning a dignified answer.",
          ),
          DialogueLine.narrate(
            "Thornmaw takes the flask. Nobody crowns the person who stood apart. They write down how to ask whether she still chooses it.",
          ),
        ],
      ),
    ),
  ],
);

final vow20 = StoryChapter(
  id: "vow20",
  title: "The Morning They Chose Again",
  subtitle: "The Five Vows · Act 4 · A Distance Freely Chosen",
  playerDominion: "VERDANCE",
  stages: [
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow20-01",
        title: "The Morning They Chose Again",
        dialogue: [
          DialogueLine.narrate(
            "On the first morning everyone wakes before the beacons. Quiet has been mistaken for safety often enough that nobody celebrates yet.",
          ),
          DialogueLine("Numen", "The outer watch has answered."),
          DialogueLine("You", "What did she say?"),
          DialogueLine("Numen", "That the coal is nearly out. And yes, today."),
        ],
      ),
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-009",
        title: "The Return of Ordinary Need",
        dialogue: [
          DialogueLine.narrate(
            "The orchard withholds renewal while a relief cart is trapped behind a militia toll. The seal dims. Nobody proposes forcing the orchard to answer.",
          ),
          DialogueLine(
            "Sproutling",
            "We promised to feed people. They are stopping the food.",
          ),
          DialogueLine("You", "Then we know which part needs fixing."),
          DialogueLine(
            "Seraphel",
            "A vow should lead us toward the work, not replace it.",
          ),
        ],
      ),
    ),
    vowBattle(
      chapter: 20,
      encounter: 1,
      player: "VERDANCE",
      enemy: "VERDANCE",
      name: "The Last Toll of the Old Road",
      objective:
          "Defeat the militia delaying the relief cart; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "You",
          "Let the cart through. Nobody has to swear anything to eat.",
        ),
        DialogueLine("Sproutling", "I will tell the orchard we remembered."),
      ],
      victory: [
        DialogueLine.narrate(
          "The cart crosses. A green beacon answers after breakfast. Across the valleys four other lights keep their different intervals.",
        ),
        DialogueLine(
          "Thornmaw",
          "I am at the orchard. It has grown badly in several places.",
        ),
        DialogueLine("You", "Will you stay?"),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "SF002-214",
        title: "A Door at the Guesthouse",
        dialogue: [
          DialogueLine.narrate(
            "The Cantor left a letter naming a village that chose the Communion. Every signature differs. All the signatures end at the same moment.",
          ),
          DialogueLine(
            "The Cantor",
            "We have learned to leave the door open. We ask you to visit those who choose to stay.",
          ),
          DialogueLine("Numen", "There is an echo in the paper."),
          DialogueLine(
            "You",
            "Then we clear the echo before we decide what the people mean.",
          ),
        ],
      ),
    ),
    vowBattle(
      chapter: 20,
      encounter: 2,
      player: "VERDANCE",
      enemy: "GLOOM",
      name: "The Uninvited Refrain",
      objective:
          "Defeat the echo following the Communion's invitation; reduce the enemy to 0 Health.",
      pre: [
        DialogueLine(
          "Seraphel",
          "A choice made freely still deserves a witness.",
        ),
        DialogueLine(
          "You",
          "And a witness must be able to hear an unwelcome answer.",
        ),
      ],
      victory: [
        DialogueLine.narrate(
          "The echo fades. The signatures remain. The village is real, and no army stands outside waiting to be defeated.",
        ),
        DialogueLine("Numen", "I cannot mark this resolved."),
        DialogueLine("You", "Leave the page open."),
      ],
    ),
    StoryStage.read(
      StoryBeat(
        artAsset: "STORY-vow20-01",
        title: "Five Cups and an Empty Chair",
        dialogue: [
          DialogueLine.narrate(
            "Ravenna takes tea in the garden. Her sister leaves before sunset to see another city. Thornmaw sends an account of the orchard, including every mistake.",
          ),
          DialogueLine(
            "Kaelis",
            "I can hear morning birds from here. Tell me which ones they are.",
          ),
          DialogueLine("You", "I will ask. Will you answer tomorrow?"),
          DialogueLine("Kaelis", "Ask me tomorrow."),
          DialogueLine.narrate(
            "Five cups stand on the table. One cools beside an empty chair. Beyond the valleys a village sings in a single gentle voice. You pack the invitation, and go to listen.",
          ),
        ],
      ),
    ),
  ],
);
