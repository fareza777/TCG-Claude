"""Reproducible, individually authored Five Vows catalog. No random designs."""
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ANCHOR = 'epic fantasy trading card game illustration, painterly digital art, dramatic cinematic lighting, rich saturated colors, detailed brushwork, clean composition with clear focal subject, atmospheric depth, no text, no watermark, no border, no frame'
PALETTES = [
 'verdant forest tones, emerald and moss green palette, bioluminescent accents, moonlit canopy',
 'volcanic orange and crimson palette, ember glow, ash-filled air, heat shimmer',
 'deep ocean blues and teals, arcane cyan glow, mist and water spray',
 'golden hour light, ivory and gold palette, radiant halos, marble and banners',
 'deep violet and black palette, pale moonlight, thorns and shadow tendrils',
]
FACTIONS = ['VERDANCE','PYRE','TIDE','DAWN','GLOOM']
cards=[]
faction=0
REVISIONS = json.loads((ROOT/'data/cards/set02_revisions.json').read_text(encoding='utf-8'))['cards']

def target(kind):
 if kind=='self': return {'select':'SELF'}
 if kind=='you': return {'select':'SELF_PLAYER'}
 if kind=='opponent': return {'select':'OPPONENT_PLAYER'}
 if kind=='any': return {'select':'CHOOSE','owner':'ANY','filter':{'type':'UNIT_OR_PLAYER'}}
 if kind in ('friend','enemy'): return {'select':'CHOOSE','owner':'SELF' if kind=='friend' else 'OPPONENT','filter':{'type':'UNIT'}}
 if kind in ('allies','others','enemies'):
  return {'select':'ALL','owner':'SELF' if kind in ('allies','others') else 'OPPONENT','filter':{'type':'UNIT',**({'excludeSelf':True} if kind=='others' else {})}}
 raise ValueError(f'Unknown target scope: {kind!r}')

def ops(code):
 result=[]; text=[]
 for atom in filter(None,code.split(';')):
  parts=atom.split(':'); op=parts[0]; n=int(parts[1]) if len(parts)>1 and parts[1].isdigit() else 0
  who=parts[1] if op in ('bounce','destroy') else parts[2] if len(parts)>2 else None
  label={'self':'this unit','friend':'target friendly unit','enemy':'target enemy unit','any':'any target','you':'you','opponent':'your opponent','allies':'each friendly unit','others':'each other friendly unit','enemies':'each enemy unit'}.get(who,who)
  if op=='draw': e={'op':'DRAW','amount':n}; t=f'Draw {n} card'+('s' if n!=1 else '')+'.'
  elif op=='heal':
   recipient=who or 'you'; e={'op':'HEAL','amount':n,'target':target(recipient)}; t=f'{"Your opponent gains" if recipient=="opponent" else "You gain"} {n} health.'
  elif op=='burn': e={'op':'DEAL_DAMAGE','amount':n,'target':target(who)}; t=f'You take {n} damage.' if who=='you' else f'Deal {n} damage to {label}.'
  elif op=='grow': e={'op':'ADD_COUNTER','amount':n,'target':target(who)}; t=f'Put {n} +1/+1 counter'+('s' if n!=1 else '')+f' on {label}.'
  elif op=='renew':
   e={'op':'RENEW','amount':n,'target':target(who)}
   t=f'Renew {n} on {label} '+(f'(remove up to {n} damage from each; put a +1/+1 counter on each unit that had damage removed).' if who in ('allies','others','enemies') else f'(remove up to {n} damage from it; if any damage is removed, put a +1/+1 counter on it).')
  elif op=='buff':
   m,g=parts[1].split('/'); e={'op':'BUFF','might':int(m),'guard':int(g),'target':target(who)}; t=f'{label.capitalize()} gets +{m}/+{g} until end of turn.'
  elif op=='grant': e={'op':'GRANT_KEYWORD','keyword':parts[1].upper(),'target':target(who)}; t=f'{label.capitalize()} gains {parts[1].capitalize()} until end of turn.'
  elif op=='bounce': e={'op':'RETURN_TO_HAND','target':target(who)}; t=f'Return {label} to its owner\'s hand.'
  elif op=='destroy': e={'op':'DESTROY','target':target(who)}; t=f'Destroy {label}.'
  elif op=='discard': e={'op':'DISCARD','target':target('opponent')}; t='Your opponent discards the first card in their hand.'
  elif op=='counter': e={'op':'COUNTER_SPELL'}; t='Counter the spell directly beneath this on the Chain unless it is uncounterable.'
  elif op=='aether': e={'op':'GAIN_AETHER','amount':n,'dominion':FACTIONS[faction]}; t=f'Add {n} {FACTIONS[faction].title()} Aether to your pool until end of turn.'
  elif op=='search': e={'op':'SEARCH_DECK','filter':{'type':parts[1]},'destination':'HAND'}; t=f'Put the first {parts[1].lower()} in your deck into your hand.'
  elif op=='token':
   name,m,g,keys=parts[1].split('/'); e={'op':'CREATE_TOKEN','amount':n or int(parts[2]),'token':{'name':name,'might':int(m),'guard':int(g),'dominion':[FACTIONS[faction]],'keywords':keys.upper().split(',') if keys else []}}; t=f'Create {e["amount"]} {m}/{g} {name} unit token'+('s' if e['amount']!=1 else '')+(f' with {keys.capitalize()}' if keys else '')+'.'
  else: raise ValueError(atom)
  result.append(e); text.append(t)
 return result,' '.join(text)

def add(name,cost,might=None,guard=None,keywords='',enter='',vow='',death='',scene='',spell=False,rite=False):
 revision=REVISIONS.get(f'SF002-{len(cards)+1:03}',{})
 cost=revision.get('cost',cost); might=revision.get('might',might); guard=revision.get('guard',guard)
 keywords=revision.get('keywords',keywords); enter=revision.get('enter',enter); vow=revision.get('vow',vow); death=revision.get('death',death)
 local=len(cards)-faction*43
 rarity='COMMON' if local<21 else 'UNCOMMON' if local<33 else 'RARE' if local<40 else 'EPIC' if local==40 else 'LEGENDARY'
 c={'id':f'SF002-{len(cards)+1:03}','name':name,'dominion':[FACTIONS[faction]],'type':'RITE' if rite else 'RITUAL' if spell else 'UNIT','rarity':rarity,'cost':{FACTIONS[faction]:min(2,cost),'generic':max(0,cost-2)},'keywords':keywords.upper().split(',') if keywords else [],'effects':[]}
 text=[k.replace('_',' ').capitalize()+'.' for k in c['keywords']]
 if not spell and not rite: c.update(might=might,guard=guard,subtype='Vowbound '+('Guardian' if guard>might else 'Vanguard'))
 for code,trigger,prefix in [(enter,'ON_CAST' if spell or rite else 'ON_ENTER_ARENA','' if spell or rite else 'When {name} enters play, '),(vow,'ON_VOW','Vow — At the start of your next turn, if this unit is still in play: '),(death,'ON_DEATH','When this unit dies: ')]:
  if code:
   effects,t=ops(code)
   if trigger=='ON_ENTER_ARENA': t=t[0].lower()+t[1:]
   c['effects'].append({'trigger':trigger,'effects':effects}); text.append(prefix+t)
 c['text']=' '.join(text)
 c['flavor']=f'The {name.lower()} keeps a promise where the old world broke.'
 c['art_prompt']=f'{ANCHOR}, {scene}, one distinct focal subject, panoramic landscape 5:3, all humanoids fully clothed in layered robes and full armor, closed helmets or faces entirely hidden inside dark hoods, no exposed skin, {PALETTES[faction]}'
 cards.append(c)

def well(name,scene):
 add(name,0,0,1,scene=scene)
 cards[-1].update(type='WELLSPRING',text=f'Exert: Add 1 {FACTIONS[faction].title()} Aether.',effects=[],keywords=[])
 for key in ('might','guard','subtype','cost'): cards[-1].pop(key,None)

def u(name,c,m,g,k='',e='',v='',d='',s=''): add(name,c,m,g,k,e,v,d,s)
def r(name,c,e,s,instant=False): add(name,c,enter=e,scene=s,spell=True,rite=instant)

# VERDANCE: survival, deliberate growth, and bodies left behind.
well('Rootpact Wellspring','a spring issuing from five interwoven living roots around a luminous emerald shard')
u('Seedvault Moth',1,1,1,'soar',s='a translucent moth carrying one glowing seed above an abandoned seed vault')
u('Mossburrow Tender',1,1,2,e='heal:1',s='a mossy badger tending a tiny fern beneath an overturned stone urn')
u('Thornbound Pledger',2,2,2,v='grow:1:self',s='a thorn-armored wooden automaton tying a green oath ribbon around its wrist')
u('Barkbridge Ox',2,1,4,'bulwark',s='an immense bark-plated ox bracing a broken bridge with its shoulders')
u('Canopy Threader',2,2,1,'intercept',e='heal:2',s='a six-legged leaf insect weaving a silver web across a canopy gap')
u('Bramble Courier',3,3,2,'rush',s='an antlered bramble fox leaping across ruined milestone pillars')
u('Reservoir Tortoise',3,1,5,e='renew:2:friend',s='a tortoise with clear medicinal water pooled in its deeply carved shell')
u('Nursery Stag',3,2,3,v='token:Sapling/1/1/:1',s='an ancient stag guarding a single sapling inside its circular antlers')
u('Riftbank Grazer',4,3,4,e='heal:2',s='a shaggy green aurochs grazing at the edge of a luminous earth fissure')
u('Spore Testament',4,2,4,d='draw:1',s='a walking mushroom archive scattering luminous spores from parchmentlike gills')
u('Crownroot Ape',5,4,5,'rampage',s='a towering root-furred ape wearing a crown of wind-bent forest branches')
u('Last Acorn Keeper',5,3,5,v='draw:1',s='a stone-and-vine guardian sheltering an enormous golden acorn against falling ash')
r('Bind the Splinter',1,'buff:1/2:friend','a thick vine binding together a fractured wooden shield',True)
r('Mending Dew',1,'renew:2:friend','a single dew drop restoring a split emerald leaf',True)
r('Take Root',2,'grow:1:friend;heal:2','a root system gripping a cracked green shard under moonlit soil')
r('Seedward Offering',2,'token:Sapling/1/1/:2','two newborn saplings pushing through a ceremonial clay bowl')
r('Forest Census',3,'search:UNIT;heal:2','a spiral of living tree rings revealing animal tracks in green light')
r('Thicket Reprisal',3,'burn:4:enemy','a cage of thorn branches closing around an invading iron construct',True)
r('Unbroken Growth',3,'buff:2/2:friend;grant:rampage:friend','a massive fresh branch bursting through a stone prison',True)
r('Return to the Nursery',4,'bounce:enemy;token:Sapling/1/1/:1','an overgrown path curling an intruding armored silhouette away from a seed nursery')
u('Pollen Oathbearer',2,1,3,'soar',v='heal:3',s='a golden pollen elemental holding a sealed floral oath above a white blossom')
u('Understory Broker',3,2,3,e='search:WELLSPRING',s='a fully hooded forest trader exchanging a crystal vial beside concealed root doors')
u('Scarbark Medic',3,2,4,e='renew:3:friend',s='a wooden medic grafting luminous bark onto a damaged tree spirit')
u('Rootwake Heron',4,3,3,'soar',v='grow:1:others',s='an emerald heron rising from reeds while roots ripple outward beneath the water')
u('Grove Debtkeeper',4,3,4,e='token:Sapling/1/1/:1',d='heal:2',s='a faceless root construct carrying a balance of stone seed weights')
u('Briar Archive',4,1,6,'bulwark',v='draw:2',s='a moving bookcase made of thorned branches protecting green crystal tablets')
u('Rainshard Mammoth',6,5,6,'intercept',v='heal:4',s='a broad tusked mammoth with rainwater pouring from emerald crystals along its back')
u('Verdant Rescuer',5,3,5,e='renew:2:allies',s='a giant ivy mantis sheltering wounded forest beasts beneath leaflike forearms')
r('Canopy Arbitration',2,'grant:intercept:friend;buff:0/3:friend','a lattice of giant leaves intercepting burning stones in midair',True)
r('Ancestral Germination',4,'token:Sapling/1/1/:3;heal:2','three ancient seeds opening around a broken ancestral tree ring')
r('Quiet Reclamation',4,'destroy:enemy;heal:2','a rusted invader consumed by a spiral of roots and pale mushrooms')
r('Oath of Shelter',3,'buff:0/2:allies;renew:1:allies','an immense dome of overlapping leaves glowing above a forest refuge',True)
u('Ringwood Arbiter',5,4,5,v='grow:1:allies',s='an upright ringwood giant planting a staff at a gathering of smaller forest spirits')
u('Sapheart Phoenix',5,3,4,'soar',d='token:Sapling/1/1/:2',s='a phoenix made of leaves unraveling into two germinating seeds over a charred grove')
u('Promise of the Hollow',6,4,7,e='draw:1',v='heal:5',s='a hollow tree titan with a luminous sanctuary visible through its chest')
u('Thorncourt Champion',5,4,4,'venom,intercept',s='a tall thorn-armored mantis holding a leaf spear before a wild briar throne')
u('Earthmemory Colossus',7,6,7,v='search:UNIT;grow:1:self',s='a slow colossal forest golem carrying fossilized tree rings across its shoulders')
r('Five Seeds Remain',5,'token:Sapling/1/1/:4;draw:1','four seedlings surrounding one glowing unopened seed in an ancient circular garden')
r('Grove Renewal',4,'renew:3:allies;draw:1','silver rain healing several cracked tree spirits beneath a vast moonlit canopy',True)
u('Oathroot Behemoth',7,6,8,'rampage',v='grow:1:others;heal:3',s='a colossal ancient bear beast with bark armor and living luminous roots, standing over a shattered stone oath altar in a mossy forest')
u('Asha, Keeper of the Last Seed',6,4,6,'alert',e='token:Sapling/1/1/:2',v='grow:1:others',s='a fully hooded figure in closed green armor holding the final glowing seed within a circle of living roots')
u('The Forest That Remembered',8,7,8,'intercept',e='heal:4',d='token:Sapling/1/1/:3',s='a whole walking island of ancient forest shaped into a vast guardian emerging from a rift')

# PYRE: fragile pressure, measured burn, and a dangerous delay before payoff.
faction=1
well('Emberpact Wellspring','a black basalt spring of liquid ember beneath five suspended iron vow rings')
u('Coalnest Skitter',1,2,1,s='a coal-black six-legged skitter climbing out of a hot obsidian nest')
u('Ashbell Witness',1,1,1,d='burn:1:opponent',s='a tiny ember elemental ringing a cracked iron bell on an ash mound')
u('Cinder Oathling',2,2,2,'rush',s='a nimble flame salamander racing between half-buried oath stones')
u('Kilnshield Porter',2,1,3,'intercept',s='a fully enclosed soot-black automaton carrying a kiln-door shield')
u('Sparkscript Adept',2,3,2,v='burn:1:opponent',s='a hooded flame scholar tracing a glowing rune in drifting sparks')
u('Lava Ford Hound',3,3,3,e='burn:1:opponent',s='a basalt hound with bright lava veins crossing a cooling river of magma')
u('Ashwing Scavenger',3,3,2,'soar',s='a long-winged ash vulture carrying a molten chain above a volcanic canyon')
u('Furnace Pledger',3,3,3,v='buff:2/0:self',s='a fully armored furnace guardian pressing a flaming seal into a stone tablet')
u('Slaghide Ram',4,4,3,'rampage',s='a heavy iron ram shedding glowing slag as it charges a broken gate')
u('Charcoal Reliquary',4,2,4,d='draw:1;burn:1:opponent',s='a walking charcoal reliquary with a coal heart and locked brass drawers')
u('Bellowsback Drake',5,4,4,'soar,rush',s='a winged drake with leatherlike bellows expanding along its burning spine')
u('Cooled-Iron Custodian',5,4,5,v='grow:1:self',s='a towering iron custodian cooling a newly forged oath chain in a black pool')
r('Measured Spark',1,'burn:2:enemy','a precise needle of fire striking a joint in a hostile construct',True)
r('Temper the Seam',1,'renew:1:friend','liquid orange metal mending one seam in a damaged iron shield',True)
r('Stoke Courage',2,'buff:3/0:friend','three roaring sparks igniting within the chest of a sealed red armor',True)
r('Forge Cinders',2,'token:Cinder/1/1/rush:1;burn:1:opponent','a small living cinder leaping from an anvil toward a distant volcanic fortress')
r('Ashen Inventory',3,'draw:2;burn:1:you','an obsidian ledger glowing painfully hot inside thick iron gauntlets')
r('Lava Lash',3,'burn:3:any','a curved whip of lava arching across a dark volcanic arena',True)
r('Break the Rivets',3,'burn:5:enemy','a focused furnace blast scattering the rivets of a massive iron guardian')
r('Last Furnace Breath',4,'burn:2:enemies','a horizontal wave of furnace heat sweeping a line of invading silhouettes')
u('Redglass Harrier',2,2,1,'swiftstrike',v='burn:1:opponent',s='a bird of sharp red glass perched on a smoking iron oath stake')
u('Crucible Salvager',3,2,3,e='draw:1',s='a closed-helm smith automaton lifting a glowing artifact from a crucible')
u('Emberchain Warden',3,2,4,e='burn:1:enemy',s='a fully armored chain warden swinging a single link of molten iron')
u('Firesworn Basilisk',4,4,3,'venom',s='a six-eyed basalt basilisk with poisonous green fire leaking between its scales')
u('Cinderwake Charger',4,4,2,'rush,rampage',s='an incandescent war boar leaving a wake of sparks across an ash field')
u('Ashen Convener',4,3,3,v='token:Cinder/1/1/rush:2',s='a faceless ember priest calling two cinder spirits from an iron bowl')
u('Ironrain Roc',6,5,4,'soar',e='burn:1:enemies',s='an immense iron-feathered roc scattering white-hot fragments over a broken bridge')
u('Sealbreaker Golem',5,4,5,e='burn:2:enemy',s='a glowing golem breaking a red wax-like magma seal on a colossal gate')
r('Shelter in the Coals',2,'buff:1/2:friend;renew:1:friend','a protective ring of coals enclosing a dented bronze guardian',True)
r('Cinder Coronation',3,'buff:2/0:allies','a crown-shaped wave of fire passing over an armored legion',True)
r('Refine the Offering',4,'burn:4:enemy;draw:1','a flaming shard purified within three concentric iron tongs')
r('Smelt the Hesitation',4,'burn:3:opponent;token:Cinder/1/1/rush:1','a flame elemental tearing through a discarded iron mask')
u('Oathbrand Juggernaut',5,5,4,'rampage',v='burn:3:opponent',s='a squat siege juggernaut with an enormous glowing vow brand across its front plate')
u('Sootwing Testament',5,3,4,'soar',d='burn:2:opponent;draw:1',s='a soot phoenix dissolving into an illuminated brass testament tablet')
u('Furnaceheart Regent',6,5,5,e='token:Cinder/1/1/rush:2',s='a regal living furnace flanked by two tiny cinder attendants on a volcanic dais')
u('Basalt Duelist',5,4,4,'swiftstrike,alert',s='a fully enclosed basalt duelist holding twin red-hot short blades beneath falling ash')
u('Last Kiln Titan',7,6,6,e='burn:2:enemies',s='a towering kiln titan opening its blazing doors above a battlefield of broken machines')
r('Unseal the Caldera',5,'burn:4:opponent;burn:2:enemies','five ancient iron locks opening over the glowing throat of a caldera')
r('Forged Anew',4,'renew:3:allies;buff:1/0:allies','an entire line of scarred iron guardians restored by a passing river of molten metal',True)
u('Emberseal Sentinel',7,6,7,'aegis_2',v='burn:3:opponent;draw:1',s='an imposing helmeted spear and shield guard in fully enclosed volcanic plate armor guarding a glowing ember seal in a basalt fortress')
u('Korr, the Banked Inferno',6,5,5,'rush',v='burn:2:enemies',s='a closed-helmet champion in heavy crimson armor containing a banked inferno behind chained breastplates')
u('The Flame That Waited',8,7,7,'soar',e='burn:3:opponent',v='grow:2:self',s='a gigantic patient flame dragon coiled around five cold iron oath pillars')

# TIDE: tempo and card selection; its delayed promises can be interrupted.
faction=2
well('Tidepact Wellspring','a circular tidal pool reflecting five cyan moons around a submerged crystal oath')
u('Glassfin Drifter',1,1,2,s='a delicate transparent glassfin ray gliding through a drowned marble arch')
u('Mistpost Gull',1,1,1,'soar',v='heal:1',s='a pale mist gull perched on a cyan postal buoy in an empty sea')
u('Pearlbound Listener',2,1,3,v='draw:1',s='a nautilus construct holding a luminous pearl against its spiral shell')
u('Currentstep Crab',2,2,2,'ambush',s='a turquoise crab poised sideways on an underwater stair with rapid currents streaming past')
u('Drowned Bell Diver',2,2,1,e='heal:2',s='a fully sealed antique diving suit carrying a bell from a sunken chapel')
u('Wakeglass Skate',3,2,3,'soar',s='a broad-winged glass skate throwing cyan reflections across a stormy sea')
u('Reefseal Custodian',3,1,4,'intercept',v='grow:1:self',s='a coral-armored custodian guarding a round reef seal beneath breaking waves')
u('Inkcurrent Scribe',3,2,2,e='draw:1',s='a cuttlefish scribe arranging luminous ink glyphs around a submerged tablet')
u('Breakwater Turtle',4,2,6,'bulwark',s='a gigantic sea turtle whose shell forms a breakwater around a cyan beacon')
u('Tidal Promisekeeper',4,3,4,v='heal:3',s='a water elemental holding two ends of an unbroken blue oath cord')
u('Stormwake Serpent',5,4,5,'soar',s='a long turquoise sea serpent leaping through a circular ocean storm')
u('Sunken Archive Walker',5,3,5,d='draw:2',s='a walking submerged archive with blue glass shelves and drifting pages of light')
r('Turn Aside',1,'buff:0/3:friend','a curved wall of water diverting a black spear from a glass guardian',True)
r('Seal the Fracture',1,'renew:3:friend','cyan water filling a fracture in a translucent shell',True)
r('Recall the Undertow',2,'bounce:enemy','an undertow spiral carrying a hostile stone automaton away from a reef',True)
r('Sound the Depth',2,'search:UNIT','a narrow cyan sounding beam descending toward a single hidden deep-sea creature')
r('Borrowed Current',2,'aether:2;draw:1','two cyan current ribbons twisting around a glass aether vessel')
r('Mistbound Reprieve',3,'bounce:enemy;heal:2','a wall of cool fog turning back an armored invader at a harbor entrance')
r('Tidal Reading',3,'draw:2','two rippling water lenses revealing an ancient underwater inscription')
r('Wavebreak Rebuke',3,'burn:3:enemy;draw:1','a concentrated wave breaking against a jagged enemy construct',True)
u('Foamcoil Advocate',2,1,2,e='bounce:enemy',s='a small foam serpent uncoiling around an overturned anchor on a reef')
u('Chartkeeper Eel',3,2,3,v='search:WELLSPRING',s='a bioluminescent eel swimming through a three-dimensional map of tidal currents')
u('Reefheart Restorer',3,1,5,e='renew:3:friend',s='a coral golem pouring restorative blue water into a cracked pearl guardian')
u('Moonwake Albatross',4,3,3,'soar',v='draw:1',s='a wide-winged albatross outlined by a cyan moon above dark tidal ridges')
u('Tidechain Bailiff',4,3,4,e='bounce:enemy',s='a sealed diving automaton pulling a cyan chain from beneath a drowned courthouse')
u('Undercurrent Envoy',4,2,4,e='draw:1;heal:2',s='a hooded ocean envoy carrying a glowing vial inside a submerged blue cathedral')
u('Whirlpool Warden',6,4,7,'intercept',v='draw:1',s='a monumental water warden standing inside the calm center of a whirlpool')
u('Marrowreef Leviathan',5,4,5,e='heal:3',d='draw:1',s='a long leviathan with coral ribs drifting over a deep ocean graveyard')
r('Glasswater Refusal',2,'counter','a perfect pane of cyan water shattering an incoming spell into droplets',True)
r('Reefward Passage',3,'grant:soar:friend;buff:1/1:friend','a spiraling water passage lifting a reef guardian high above the sea',True)
r('Drowned Testimony',4,'draw:2;heal:3','two luminous memory pearls rising from a ruined underwater tribunal')
r('Ebbing Formation',4,'bounce:enemy;buff:0/2:allies','a disciplined wall of retreating waves surrounding a line of blue constructs',True)
u('Mirrorwake Arbiter',5,3,5,e='bounce:enemy',v='draw:1',s='a faceless glass arbiter standing between two opposing mirror waves')
u('Chronotidal Manta',5,3,4,'soar,alert',s='a huge manta ray casting clocklike rings of cyan light across the seafloor')
u('Pearl Testament',6,4,6,e='draw:2',s='an enormous pearl-shell creature carrying a sealed crystalline ocean testament')
u('Abyssal Oathkeeper',5,3,6,'aegis_1',v='grow:1:others',s='a dark abyssal guardian wrapped in cyan oath cords among deep-sea vents')
u('Breaker of Still Seas',7,5,7,e='bounce:enemy;draw:1',s='a colossal angular sea beast splitting a perfectly still ocean surface')
r('Ocean Remembers',5,'bounce:enemy;draw:2','a vast wave revealing an intact drowned city inside its translucent wall')
r('Return of the Blue',4,'renew:2:allies;draw:1;heal:2','a cyan tide washing through a shattered reef and sealing its wounds',True)
u('Tideglass Custodian',7,5,8,'intercept',e='bounce:enemy',v='draw:2',s='a monumental pearl and coral construct holding a luminous tideglass prism in its hands beneath towering cyan waves')
u('Neris, Keeper of the Ebb',7,4,6,'soar',e='draw:1',v='bounce:enemies',s='a fully hooded keeper in layered blue robes standing on a floating glass skiff at the center of a retreating ocean')
u('The Sea Beneath the Sea',8,6,8,'soar',e='heal:5',v='draw:2',s='a luminous second ocean shaped like a vast whale rising beneath the dark upper sea')

# DAWN: ordered protection and patient counters, with fewer reach effects.
faction=3
well('Dawnpact Wellspring','an ivory fountain pouring golden light through five sealed marble vow arches')
u('Lanternseed Wisp',1,1,1,'soar',e='heal:1',s='a tiny golden wisp inside a seed-shaped lantern over white marble steps')
u('Ivoryline Recruit',1,1,2,'alert',s='a fully enclosed ivory-armored recruit carrying a square shield along a sunrise wall')
u('Sunseal Pledger',2,2,2,v='heal:2',s='a closed-helmet sun knight pressing a golden seal into a blank ivory tablet')
u('Gatepost Gargoyle',3,1,5,'bulwark',s='a squat ivory gargoyle wrapped around a golden gatepost above a sunlit courtyard')
u('Bannerthread Falcon',2,2,1,'soar',s='a golden mechanical falcon trailing a narrow ivory banner across the sunrise')
u('Marbleway Escort',3,2,3,'intercept',e='heal:1',s='a full-plate escort shielding an unseen traveler on a white marble road')
u('Oathbell Attendant',3,2,3,v='grow:1:self',s='a faceless ivory automaton carrying a small golden bell beneath an arch')
u('Candlecourt Scribe',3,1,3,e='draw:1',s='a deeply hooded scribe copying radiant shapes beneath a court of suspended candles')
u('Goldwall Defender',4,2,4,'aegis_1',s='a gold-plated defender locking its broad shield into a shining marble wall')
u('Heliograph Lancer',4,3,3,'swiftstrike',s='a fully enclosed lancer with a sunlight-reflecting spear on an ivory causeway')
u('Morningvault Gryphon',5,4,4,'soar,intercept',s='a white gryphon with brass feathers guarding a golden vault at sunrise')
u('Promisebearer Golem',5,3,6,v='grow:1:others',s='a tall marble golem carrying a radiant banner before a row of smaller guardians')
r('Hold the Line',1,'buff:0/4:friend','a single ivory shield holding firm against a shower of black stone fragments',True)
r('Restorative Light',1,'renew:1:friend;heal:1','a narrow sunbeam repairing a hairline crack in an ivory guardian',True)
r('Equal Measure',2,'buff:1/1:friend;heal:2','balanced golden scales illuminating a shield and a small lantern',True)
r('Lantern Muster',2,'token:Lantern/1/1/alert:2','two tiny golden lantern guardians stepping out of a white marble alcove')
r('Read the Covenant',3,'draw:1;heal:4','a closed golden covenant scroll opening into a halo above a marble reading desk')
r('Disarm the Intruder',3,'burn:3:enemy;heal:2','a white shield locking a dark blade while a ray of gold strikes its owner',True)
r('Judgment at Daybreak',4,'destroy:enemy','a single beam of dawn breaking apart a hostile obsidian statue')
r('Radiant Formation',3,'buff:1/1:allies','a row of ivory shields catching one continuous band of morning sunlight',True)
u('Vigilant Surveyor',2,1,3,'alert',v='search:WELLSPRING',s='a fully armored ivory surveyor studying a golden measuring instrument on a wall')
u('Lanterncourt Medic',3,2,4,e='renew:2:friend',s='a hooded medic in layered white robes holding a golden lantern over dented armor')
u('Sunward Castellan',3,2,3,'aegis_1',v='heal:3',s='a closed-helm castellan beneath white banners at the top of a sunlit tower')
u('Dawnwing Witness',4,2,4,'soar',e='draw:1',s='an ivory clockwork owl with a golden memory crystal between its talons')
u('Oathmarble Phalanx',4,3,4,'alert',v='grow:1:self',s='three interlocked marble guardians shown as one central phalanx construct')
u('Brass Testamentkeeper',4,2,5,d='token:Lantern/1/1/alert:2',s='a brass automaton opening its chest to release two tiny radiant lanterns')
u('Highgate Guardian',6,4,7,'intercept,aegis_1',s='a towering fully enclosed guardian blocking a white marble gate with a huge gold shield')
u('Daybreak Standard',5,3,5,e='heal:3',v='draw:1',s='a living ivory banner construct planting its golden pole on a ruined sunrise battlement')
r('Sheltering Decree',2,'grant:intercept:friend;buff:0/2:friend','a golden circular decree forming a protective shell around a white armored sentinel',True)
r('Ordered Reinforcement',3,'grow:1:friend;token:Lantern/1/1/alert:1','one golden lantern arriving beside a strengthened ivory shield wall')
r('Sunlit Inquiry',4,'draw:2;heal:2','two golden prisms revealing a hidden oath seal beneath marble dust')
r('Restore the Bastion',4,'renew:2:allies;heal:3','radiant light rebuilding a damaged ivory bastion from its central lantern',True)
u('Covenant Arbiter',5,3,6,e='heal:4',v='grow:1:allies',s='a massive faceless marble judge holding a golden covenant ring above assembled shields')
u('Sunforge Seraph',5,3,4,'soar,swiftstrike',s='a nonhuman angular brass seraph with six blade-shaped golden wings over a marble forge')
u('Ivory Debtwarden',6,4,6,e='destroy:enemy',s='an ivory warden pointing a long golden key toward a broken hostile construct')
u('Firstlight Basilisk',5,3,5,'alert,aegis_2',s='a white stone basilisk with golden eyes turning toward the first beam of morning')
u('Fivebell Colossus',7,5,8,v='heal:5;draw:1',s='a colossal marble walker with five golden bells hanging from its broad shoulders')
r('The Gate Remains',5,'token:Lantern/1/1/alert:3;grow:1:allies','three radiant lanterns holding a white gate closed against a tide of shadow')
r('A Dawn Unbroken',4,'renew:3:allies;buff:0/2:allies','a continuous golden dawn illuminating repaired ivory guardians on a high wall',True)
u('Sunseal Bastion',7,5,8,'alert,aegis_2',v='grow:1:others;heal:4',s='a mobile ivory bastion with a blazing golden vow seal and a single great shield')
u('Seren, Keeper of the First Light',6,4,6,'alert',e='heal:4',v='draw:2',s='a fully veiled keeper in closed ivory armor holding a golden lantern before the unopened gates of morning')
u('The Dawn That Chose to Stay',8,6,9,'intercept',e='token:Lantern/1/1/alert:2',v='grow:1:others',s='a vast golden sunrise elemental sheltering a tiny marble city inside its ring-shaped body')

# GLOOM: attrition, death value and evasion; avoids endless graveyard loops.
faction=4
well('Gloompact Wellspring','a black moonlit pool with five violet oath stones suspended beneath the surface')
u('Mourning Wick',1,1,1,d='heal:2',s='a tiny violet candle spirit bending over an extinguished candle in a thorn garden')
u('Veilburrow Rat',1,2,1,'dread',s='a shadow rat carrying a torn veil through a moonlit stone burrow')
u('Thornveil Pledger',2,2,2,v='burn:1:opponent;heal:1',s='a fully hooded violet oathbearer wrapping a thorn cord around a sealed black urn')
u('Gravepost Watcher',2,1,3,'venom',s='a long-legged violet spider perched on a cracked grave marker under pale moonlight')
u('Hollowwing Bat',2,1,2,'soar,leech',s='a translucent shadow bat with one pale crystal suspended inside its hollow chest')
u('Duskmire Collector',3,2,3,e='discard',s='a faceless mire collector gathering discarded sealed letters in a black reed marsh')
u('Pallid Oathhound',3,3,3,'leech',s='a pale ghost hound following a luminous violet oath cord between dark gravestones')
u('Veilglass Mourner',3,1,4,d='draw:1',s='a hooded glass mourner sheltering a violet memory lantern beneath a thorn arch')
u('Nightbarrow Drake',4,3,3,'soar,dread',s='a shadow drake with torn mist wings circling a black burial mound')
u('Blackroot Reclaimer',4,3,4,v='burn:2:opponent;heal:1',s='a black root beast lifting a broken violet shrine from a moonlit bog')
u('Griefbound Golem',5,4,5,d='burn:2:opponent',s='a heavy obsidian golem with chains of dim violet lanterns draped over its shoulders')
u('Moonless Debtkeeper',5,3,5,v='draw:1;burn:1:you',s='a faceless debtkeeper weighing one violet shard against an empty black bowl')
r('Pain Remembered',1,'burn:1:enemy;burn:1:opponent;heal:1','a violet needle of remembered pain piercing the shadow of an iron construct',True)
r('Stitch the Veil',1,'renew:1:friend;burn:1:opponent','silver thread closing a tear in a violet shadow cloak',True)
r('Borrow a Breath',2,'burn:2:opponent;heal:2','a small pale breath drawn from one black lantern into another',True)
r('Thornwake Echo',2,'token:Echo/1/1/dread:1;draw:1','a single violet echo emerging from a cracked mirror covered in thorns')
r('Unburden',2,'discard;heal:1','a sealed black letter sinking into a pool of pale moonlight')
r('Nightglass Reading',3,'draw:2;burn:2:you','two sharp violet memory panes floating above a bleeding black crystal')
r('Cut the Tether',4,'destroy:enemy','a violet thorn blade severing the luminous tether of a hostile statue',True)
r('Gloaming Swell',3,'buff:1/0:allies;grant:dread:allies','long violet shadows surging beneath a row of moonlit thorn constructs',True)
u('Moth of the Closed Door',2,1,2,'soar',d='draw:1',s='a black moth with a keyhole-shaped violet wing pattern before a sealed stone door')
u('Urnwatch Custodian',3,2,4,v='token:Echo/1/1/dread:1',s='a hooded iron custodian opening a moonlit funeral urn to release a small violet echo')
u('Pallid Stitcher',3,2,3,e='renew:3:friend;burn:1:you',s='a fully hooded stitcher repairing a translucent beast with glowing violet thread')
u('Sablewing Herald',4,3,4,'soar',v='discard',s='a sable-feathered nonhuman herald carrying a sealed violet decree above a thorn court')
u('Graveglass Bailiff',4,3,4,e='burn:2:opponent;heal:1',s='a faceless black glass bailiff holding an hourglass of pale violet sand')
u('Quietus Archivist',4,2,4,e='draw:1',d='heal:2',s='a hooded archivist shelving glowing violet urns inside a black subterranean library')
u('Thornmoon Devourer',6,5,5,'leech,dread',s='a vast thorn-covered shadow beast swallowing a pale reflection of the moon')
u('Vigil of the Nameless',5,3,5,e='token:Echo/1/1/dread:1',d='token:Echo/1/1/dread:1',s='a faceless obsidian vigil keeper attended by one small violet echo near an unmarked grave')
r('Veil of Venom',2,'grant:venom:friend;buff:0/1:friend','a violet venom veil settling over the thorns of a small shadow guardian',True)
r('Moonlit Audit',3,'discard;draw:1','a moonbeam revealing a single missing page in an obsidian ledger')
r('A Promise Collected',4,'destroy:enemy;burn:1:you;heal:2','a closed violet gauntlet collecting a broken oath ring from a fallen stone invader')
r('Shadows Reassembled',4,'token:Echo/1/1/dread:2;heal:3','two disconnected shadows rebuilding themselves beneath a pale crescent moon')
u('Thorncourt Arbiter',5,4,5,'dread',v='discard;heal:2',s='a towering faceless thorn judge seated on a black crescent-shaped court bench')
u('Elegywing Revenant',5,3,4,'soar,leech',d='token:Echo/1/1/dread:1',s='a nonhuman violet revenant unfolding long translucent wings over an empty urn')
u('Obsidian Testament',6,4,6,e='draw:2;burn:2:you',s='an enormous obsidian archive beast with a glowing testament sealed in its ribcage')
u('Nightroot Duellist',5,3,5,'venom,alert',s='a fully covered thorn duellist holding a pale hooked blade beneath twisted moonlit roots')
u('Keeper of the Empty Throne',7,5,7,e='destroy:enemy',v='heal:4',s='a giant faceless iron keeper guarding an empty black throne wrapped in violet chains')
r('The Last Toll',5,'burn:3:opponent;heal:3;discard','a cracked black bell sending one visible violet shock ring across a silent graveyard')
r('Renew the Veil',4,'renew:3:allies;grant:dread:allies','silver moon threads mending an entire curtain of living violet shadows',True)
u('Moonveil Testamentkeeper',7,5,7,'soar,leech',v='draw:1;discard',s='a colossal faceless moonveil wraith holding an obsidian testament above a field of violet lanterns')
u('Veyra, Keeper of the Unsaid',6,4,6,'dread',e='discard',v='token:Echo/1/1/dread:2',s='a fully veiled keeper in layered black robes sealing an unspoken promise inside a violet glass orb')
u('The Night That Kept Its Word',8,6,8,'soar',e='burn:3:opponent;heal:3',d='draw:2',s='a vast ring-shaped night spirit embracing a tiny field of violet oath lanterns beneath a hidden moon')

assert len(cards)==215,len(cards)
assert cards[40]['name']=='Oathroot Behemoth'
assert cards[83]['name']=='Emberseal Sentinel'
assert cards[126]['name']=='Tideglass Custodian'

# Individual story actions, deliberately separate from the shared style anchor.
# These are cinematic events, never a faction-wide standing-character template.
ART_ACTIONS = [
'''Water erupts through the five roots as a buried oath shard wakes beneath an abandoned orchard.
The moth dodges falling vault masonry while carrying the last seed toward a crack of daylight.
The badger pushes the overturned urn upright as a fern curls back from frost.
The wooden pledger knots its ribbon while bracing a collapsing thorn barricade against iron arrows.
The ox catches a collapsing bridge with its back as tiny concealed travelers escape above.
The insect throws a web between two branches to catch a falling armored messenger.
The fox leaps a shattered milestone while a pursuer crashes through thorns behind it.
The tortoise tips its shell pool into a wounded guardian while rubble falls into the water.
The stag charges between burning trunks with the protected sapling held inside its antlers.
The aurochs tears glowing roots free from a widening rift with its horns.
The mushroom archive bursts open while fleeing an axe strike, releasing its final memory spores.
The ape tears an iron portcullis from a nursery gate in a shower of stone chips.
The keeper dives across falling ash to catch the enormous acorn before it strikes a broken stair.
Living vines whip around the shield fracture at the instant a second blow lands.
A dew drop hits the leaf wound and the split visibly closes beneath its surface tension.
Roots burst sideways through compacted soil and anchor a sliding green shard.
Two saplings force their way out of a cracked clay bowl as its fragments lift into the air.
Luminous tree rings rotate above fresh tracks inside a dark hollow-tree archive.
Thorn branches slam shut around the iron invader, scattering sparks and snapped cables.
A new branch punches through the prison wall and knocks its stone blocks into sunlight.
The forest path buckles like a wave and drives the armored intruder away from the nursery.
The pollen elemental whirls between closing petals to carry the floral seal out of a storm.
The concealed trader slides a vial through a root door as floodwater fills the underground market.
The wooden medic staples living bark across a wounded tree spirit during an ongoing siege.
The heron beats upward through a broken greenhouse roof as awakened roots lift allies below.
The debtkeeper catches a falling seed weight before the whole hanging nursery tilts into a chasm.
The moving archive folds its thorn shelves around tablets as fire sweeps its hollow chamber.
The mammoth turns into a stone avalanche and catches the first boulders on rain-slick tusks.
The mantis sweeps its leaf arms over wounded beasts while a bridge of vines forms behind them.
Overlapping leaves snap into a defensive lattice as flaming stones strike and burst above a refuge.
Three ancient seeds split in sequence and their roots lift the broken ancestral ring.
Roots pull the rusted invader down through flagstones as mushrooms flare along its seams.
The leaf dome closes just before a rain of sparks reaches the forest refuge.
The arbiter drives its staff into stone and a ring of roots rises beneath the assembled spirits.
The leaf phoenix unravels mid-flight, sending two seeds through a charred window into safe soil.
The hollow titan turns its open chest sanctuary away from an incoming black spear.
The mantis champion lunges across the briar throne steps and pins an iron blade with its thorn spear.
The colossus wades through a landslide, exposing luminous fossil rings as its shoulders split the rock.
Four seedlings burst upward around the final seed as a ruined garden floor gives way.
Silver rain hits shattered bark and joins its splinters while forest beasts rush past.
An ancient bark-armored bear plants one immense paw on the broken oath altar, a rare monumental hero composition.
The hooded keeper reaches across a collapsing root bridge to place the final seed in living soil.
The forest island rises bodily from the rift and carries fleeing creatures above the collapsing shoreline.''',
'''A buried basalt spring breaks open inside a ruined foundry and molten light races through five iron rings.
The skitter springs from its hot nest at an invading boot, showering black grit toward the lens.
The ember witness pulls the bell rope as its own coal body breaks into the warning sparks.
The salamander ricochets between oath stones and lunges through the gap beneath an iron gate.
The porter catches a tumbling furnace door on its shield while smaller workers escape behind it.
The hooded adept draws a seal through moving sparks while ducking a shower of broken glass.
The hound vaults the last cold stone of a magma ford as the river rises behind it.
The ash vulture banks violently between canyon walls with a molten chain swinging from its claws.
The furnace pledger slams a red-hot seal onto the tablet while a siege hammer strikes its shoulder.
The slag ram impacts the gate headfirst and glowing rivets fly into a dust cloud.
The reliquary crashes down a foundry stair and releases its coal heart into drifting memory sparks.
The drake dives out of a broken chimney with its bellows blazing and claws extended toward a siege engine.
The custodian quenches the oath chain in a black pool while molten scale bursts off its links.
A needle of fire strikes the moving joint exactly as an enemy construct swings its arm.
Liquid metal races along the broken shield seam while an arrow shatters against its repaired edge.
Three chest sparks flare and drive the armored figure into a forward charge through furnace smoke.
The living cinder kicks free of an anvil strike as a distant fortress wall glows from the impact.
The blazing ledger forces thick gauntlets apart and two inventory plates spin into the air.
The lava whip strikes a basalt column and its glowing arc continues through the exploding stone.
White-hot pressure blows rivets out of the enemy guardian before its next step can land.
A furnace blast rolls across the floor of an iron factory and folds the invaders backward.
The glass harrier dives from the oath stake and shears through a hanging chain with its wing.
The salvager pulls the artifact clear just as the crucible cracks and a molten wave spills outward.
The warden swings one burning chain link through a falling wall to hook a trapped ally.
The basilisk lunges from beneath broken foundry tiles as green fire hisses through its teeth.
The war boar charges down a steep ash chute and plows through an iron shield line.
The faceless convener overturns the iron bowl and two cinder spirits race across the floor.
The iron roc dives through a storm cloud and showers a siege bridge with incandescent feathers.
The golem tears the magma seal apart while the gate behind it bends from the released heat.
The coal ring snaps closed around a dented guardian as its armor seam fuses back together.
A crown-shaped fire wave rolls through a moving armored legion and ignites their raised weapons.
Three iron tongs snap around the corrupted shard and its outer shell explodes into hot fragments.
A flame elemental bursts through the discarded mask and races toward a siege banner.
The juggernaut hits a barricade at an angle and stamps its glowing brand into the collapsing stone.
The soot phoenix loses a wing to a spear and turns its falling ashes into one final testament flare.
The regent opens its furnace chest and two cinder attendants leap out onto the battlefield.
The basalt duelist slides under a descending blade and crosses its red-hot swords into a counterstrike.
The kiln titan forces open its doors and a blast lifts broken machines off the foundry floor.
Five caldera locks fail in a chain reaction and a column of fire tears through the crater roof.
A molten channel floods between scarred guardians and visibly reseals the moving armor plates.
A helmeted sentinel plants spear and shield before an ember seal, a rare monumental hero composition.
The crimson champion breaks its own chest chains and banks the unleashed fire toward approaching enemies.
The giant dragon uncoils one loop from the cold oath pillars and its first breath lights the dark factory valley.''',
'''The low tide reveals five submerged oath stones as a cyan spring erupts through the floor of a drowned observatory.
The glassfin ray turns sharply through a collapsed arch as an anchor strikes the sand behind it.
The mist gull snatches a sealed message from a tilting buoy moments before a wave swallows it.
The nautilus presses the pearl to its shell and reflected memories spiral across the surrounding water.
The crab sidesteps a descending spear on a flooded stair and snaps its claw onto the shaft.
The sealed diver kicks upward with the recovered bell while the chapel roof collapses below.
The glass skate banks over a breaking storm wave and its cyan reflection flashes across a pursuing ship.
The custodian braces the reef seal against a pounding wave while coral shards spin around its shield.
The cuttlefish jets backward through an archive aisle while its last ink glyphs remain suspended as a map.
The turtle turns its shell into the incoming storm surge and shelters a harbor beacon in its wake.
The elemental stretches across a widening canal to keep both ends of the blue oath cord joined.
The serpent leaps from a submerged canyon and twists through the eye of the gathering storm.
The archive walker loses a glass shelf in a collision and releases two memory pages into the current.
The curved water shield catches a spear point and bends its trajectory into a nearby stone column.
Cyan water floods a shell fracture and seals it while the damaged creature rolls away from danger.
The undertow lifts an enemy automaton off its feet and sweeps it backward through scattered reef debris.
The sounding beam cuts through silt and reveals a sleeping creature in a forgotten harbor reservoir.
Two current ribbons tear free of a broken turbine and coil inside a glass aether vessel.
The fog wall drives a charging invader off the harbor road while luminous water closes behind an escaping ally.
Two water lenses rotate inside a flooded chamber and reveal writing as sediment falls away.
A breaking wave slams a hostile construct sideways through the splintering deck of a wreck.
The foam serpent snaps out from under the overturned anchor and pulls a larger foe into a returning tide.
The eel darts through a rotating current map as a hidden blue spring opens beneath the chart chamber.
The coral restorer pours water into a cracked pearl guardian while holding back a collapsing reef tunnel.
The albatross dives through the cyan moon reflection and retrieves a memory pearl from the wave crest.
The sealed bailiff hauls a chain taut and drags a hostile golem out of the drowned courthouse doorway.
The hooded envoy leaps from a sinking stair to protect a vial as the submerged cathedral tilts.
The water warden thrusts both arms outward and arrests a shipwreck inside the whirlpool wall.
The leviathan rolls above the abyssal graveyard, catching falling coral fragments between its glowing ribs.
The water pane fractures an incoming spell into suspended droplets as its pressure wave crosses a glass bridge.
A spiraling passage lifts a reef guardian above a wave at the moment the shoreline disappears.
Two memory pearls burst upward from a collapsed tribunal and project their final testimony through the water.
A wall of waves folds around a retreating formation and carries the pursuer backward.
The glass arbiter steps between colliding mirror waves and forces one wave back toward its source.
The manta banks through a seafloor ravine and its clocklike light rings stop falling silt in midwater.
The pearl creature opens its shell during a deep-sea quake and releases two brilliant memory ribbons.
The abyssal keeper hauls its oath cords across a vent eruption and raises smaller guardians out of boiling water.
The angular sea beast breaches under a becalmed wreck and splits its reflection into towering wave walls.
The ocean wave curls over a collapsing seawall, showing the intact drowned city inside its moving water.
The returning cyan tide races through broken coral and seals the reef just before the next wave lands.
A pearl-and-coral custodian presents its luminous tideglass prism beneath a wave arch, a rare monumental hero composition.
The hooded keeper steers a glass skiff across the exposed seabed as the surrounding sea retreats in a colossal circle.
The whale-shaped lower ocean surges through a crack in the upper sea and lifts a shattered harbor into blue light.''',
'''The first sunbeam enters an abandoned aqueduct and wakes an ivory fountain beneath five golden oath arches.
The lantern wisp swings through a broken window to relight a refuge while rain lashes the marble outside.
The ivory recruit slides its square shield beneath falling masonry to protect an ally behind the wall.
The sun knight seals the tablet while kneeling under a barrage that showers the golden steps with dust.
The gargoyle locks its wings around a bending gatepost as the courtyard gate shudders under impact.
The mechanical falcon banks between snapped banners and carries a new signal over the besieged wall.
The escort shoulders an incoming stone aside and drives the concealed traveler toward an open stair.
The bell attendant swings its bell through a burst of dust as a row of fallen guardians begins to rise.
The hooded scribe catches a falling covenant page while candles whirl in the ruined court draft.
The defender drives its shield into a breach just as enemy spears strike the newly joined golden wall.
The lancer vaults a broken causeway rail and flashes reflected sunlight into an approaching construct.
The gryphon dives from the morning vault and intercepts a dark flying creature above the city roofs.
The banner golem plants its pole into a sliding barricade and pulls smaller guardians up behind it.
The ivory shield catches a spray of jagged stone at the instant its bracing arm pushes forward.
A tight sunbeam crosses an armor crack and restores it while the guardian struggles to its feet.
The scales flare as one side drops and the balancing light strengthens a battered shield.
Two tiny lantern guardians leap from a marble alcove to block a charging shadow at ankle height.
The covenant scroll bursts open in a dark refuge and warm light spreads across extinguished lanterns.
A shield traps the intruder blade while a concentrated ray strikes the hostile gauntlet and drives it back.
The first dawn beam tears through a hostile obsidian statue and its fragments scatter across the court.
A moving shield line pivots in unison and joins separate sunlight reflections into a single radiant wall.
The armored surveyor braces a golden instrument on a shattered parapet and reveals a hidden spring below.
The hooded medic reaches through a shield gap to repair an ally while arrows strike the surrounding stone.
The castellan pulls a damaged banner upright and seals a gate breach under the first sunbeam.
The clockwork owl dodges a black arrow and carries its memory crystal through a collapsing tower window.
The phalanx construct turns as one body to absorb a side charge that breaks the marble pavement.
The testamentkeeper falls forward and releases two lanterns through its opening brass chest.
The highgate guardian drops its huge shield into the threshold as a siege stone crashes against it.
The living standard carries its glowing pole through blowing ash and relights the refuge road behind it.
The circular decree intercepts descending projectiles and bends them away from the white sentinel.
One new lantern skids into the broken shield line as gold light welds the front shield together.
Two prisms rotate in a dust-filled vault and reveal the hidden seal through the marble floor.
Radiant light bursts from the central lantern and races along the broken bastion stones under siege.
The arbiter raises its covenant ring over moving shields as a shockwave rolls down the tribunal stairs.
The brass seraph folds two blade wings to dive through a forge roof and strike an invading machine.
The debtwarden turns its long golden key and the hostile construct cracks open at every locked joint.
The white basilisk rears against a shadow charge as the first sunbeam catches its golden eyes.
The fivebell colossus steps over a ruined wall and its swinging bells drive the falling dust outward.
Three lantern guardians push the gate closed while violet shadows pour across its lower threshold.
A long dawn beam washes across battered guardians as they rise behind the repaired high wall.
The mobile bastion rams its great shield into a breach while the sunseal flares across its front tower.
The fully veiled keeper carries the first lantern through a shattered gate while the city emerges behind her.
The sunrise elemental curls its ring body around a tiny city and catches the collapsing sky on its outer arc.''',
'''Moonlight descends into a deserted cistern and draws five violet oath stones up through the black water.
The candle spirit bends into the wind to relight a dead wick as its own flame breaks into pale sparks.
The shadow rat darts under a closing crypt door with the torn veil dragging behind it.
The hooded oathbearer draws the thorn cord tight while the sealed urn lifts off a fractured altar.
The spider drops from a grave marker and fixes a glowing venom thread across an intruder path.
The hollow bat dives through a broken chapel window and draws a pale light ribbon into its crystal chest.
The faceless collector hooks a sealed letter out of floodwater while the reed marsh swallows a ruined road.
The ghost hound leaps between tilted gravestones and catches a severed oath cord in its jaws.
The glass mourner falls beneath a collapsing arch and releases its protected memory lantern upward.
The shadow drake dives along the burial mound and folds its mist wings through a narrow crypt opening.
The root beast tears a fallen shrine out of the bog as pale light drains from a distant invader.
The obsidian golem catches a heavy siege blow and its broken lantern chains erupt into violet sparks.
The debtkeeper tips the empty bowl and draws a painful memory shard out of the moonless air.
A violet pain needle strikes the moving enemy shadow and a pale thread returns from the impact.
Silver thread stitches the torn cloak shut while a violet backlash lashes toward the pursuer.
A pale breath tears free of one black lantern and relights a second lantern across a crypt passage.
The violet echo crashes through a thorn mirror and carries one reflected memory into the open air.
The sealed letter sinks through moonlit water and a dark pressure releases from the hovering oath ring.
Two memory panes split out of a black crystal and their sharp light cuts through the surrounding fog.
A thorn blade severs the hostile statue tether at the moment its suspended body begins to fall.
Violet shadows surge under a running formation and rise into terrifying shapes ahead of their feet.
The moth slips through the keyhole just before the stone door closes over a burst of moonlight.
The iron custodian throws open the funeral urn during a crypt collapse and a violet echo escapes the dust.
The hooded stitcher pulls luminous thread through a wounded beast while its own lantern dims in payment.
The sable herald banks between thorn towers and drops a sealed decree into a withdrawing enemy camp.
The black glass bailiff flips its hourglass and pale sand lashes across a fleeing invader shadow.
The hooded archivist catches a falling memory urn while a broken library shelf folds into darkness.
The shadow devourer lunges up through bog water and bites through the moon reflection on its surface.
The vigil keeper takes a blow beside an unmarked grave and a new echo rises from the impact crater.
The venom veil whips around a thorn guardian as an incoming blade catches on its poisoned edge.
A moonbeam lifts the missing ledger page out of a locked obsidian drawer and exposes its empty space.
The violet gauntlet crushes the collected oath ring and a hostile stone invader fractures in the background.
Two disconnected shadows drag themselves together across broken flagstones and rise beside a moonlit refuge.
The faceless arbiter sweeps its thorn staff across the court and tears a sealed promise out of the enemy ranks.
The violet revenant dives through an empty urn and its trailing wing leaves a small echo behind.
The archive beast splits its ribcage open and two forbidden memory ribbons tear painfully into the air.
The covered duellist hooks an incoming blade aside and steps through moonlit roots into a precise counterstroke.
The iron keeper pulls the throne chains tight and crushes the hostile construct trying to cross its threshold.
The cracked bell strikes once and a violet shock ring extinguishes distant enemy lanterns before returning pale light.
Silver moon threads race across torn living shadows as they sweep together through a shattered courtyard.
The moonveil wraith snaps its testament open above the battlefield and pulls discarded promises into the rising pages.
The fully veiled keeper seals the orb with both covered hands while two unspoken echoes force their way into the room.
The vast night spirit catches a falling field of oath lanterns inside its ring as its outer shadow tears away.'''
]
COMPOSITIONS = [
 'ground-level wide lens, diagonal motion from near foreground into a deep environment, visible debris crossing the lens',
 'high three-quarter overhead view, strong asymmetric geometry, action cutting across the scene rather than a centered pose',
 'tight cinematic crop on the action and its material consequence, environment visible through layered foreground shapes',
 'distant wide shot with a small subject against immense architecture, clear action silhouette and strong depth',
 'low side-tracking angle at the instant of impact, stretched perspective and a clear path through the setting',
 'view from behind the protected object or ally, action beyond the foreground, faces concealed',
 'top-down oblique view through broken architecture, dramatically contrasting scale between subject and environment',
 'waterline or floor-level perspective with large foreground texture, subject moving across the middle distance',
 'compressed long-lens view through environmental layers, suspended consequence visible behind the subject',
 'off-center medium-wide composition, strong negative space in the direction of travel, environmental storytelling',
 'close view of a material transformation with a distant battlefield consequence, no centered standing figure',
 'bird-eye establishing perspective interrupted by one forceful diagonal action, vivid scale contrast',
]
LORE = [
 'In Sylvaris after the five doors are shut, living roots and seed refuges support a new seal sustained by freely chosen promises rather than another trapped keeper.',
 'In Ashmar after the five doors are shut, foundry crews forge oath rings and protect relief routes; every use of leaked Aether makes keeping the new seal a deliberate risk.',
 'In Meridine after the five doors are shut, custodians preserve separate memories against the Cantor\'s offer of effortless shared rest; tideglass records the cost of a promise.',
 'In Aurelia after the five doors are shut, gatekeepers and courts must learn that an honest watch is chosen, not commanded; the new seal needs willing defenders.',
 'In Nyxhollow after Ravenna relieves her sister at the stone and Thornmaw chooses to tend the lamps, the next watch must remain a choice; the Communion offers an easy but dangerous end to loneliness.',
]
UNIT_LOCALS = list(range(1,13))+list(range(21,29))+list(range(33,38))+list(range(40,43))
UNIT_SUBTYPES = [
 'Moth Spirit|Badger Tender|Treefolk Pledger|Ox Guardian|Insect Weaver|Fox Courier|Tortoise Healer|Elk Guardian|Aurochs Beast|Fungus Archive|Ape Beast|Treefolk Keeper|Pollen Elemental|Hooded Trader|Treefolk Medic|Heron Spirit|Root Construct|Living Archive|Mammoth Guardian|Mantis Rescuer|Treefolk Arbiter|Leaf Phoenix|Treefolk Sanctuary|Mantis Champion|Earth Colossus|Bear Behemoth|Sylvaris Keeper|Living Forest',
 'Coal Skitter|Ember Witness|Flame Salamander|Iron Porter|Hooded Adept|Basalt Hound|Ash Vulture|Furnace Guardian|Slag Ram|Living Reliquary|Furnace Drake|Iron Custodian|Glass Harrier|Forge Salvager|Chain Warden|Fire Basilisk|Ember Boar|Hooded Convener|Iron Roc|Sealbreaker Golem|Oathbrand Juggernaut|Soot Phoenix|Furnace Regent|Armored Duelist|Kiln Titan|Armored Sentinel|Ashmar Champion|Ancient Flame Dragon',
 'Glass Ray|Mist Gull|Pearl Nautilus|Current Crab|Sealed Diver|Glass Skate|Coral Custodian|Cuttlefish Scribe|Sea Turtle|Water Elemental|Sea Serpent|Living Archive|Foam Serpent|Chart Eel|Coral Restorer|Moon Albatross|Sealed Bailiff|Hooded Envoy|Whirlpool Warden|Reef Leviathan|Glass Arbiter|Tidal Manta|Pearl Creature|Abyssal Keeper|Breaker Leviathan|Pearl Coral Construct|Meridine Keeper|Ocean Whale Spirit',
 'Lantern Wisp|Armored Recruit|Armored Pledger|Ivory Gargoyle|Mechanical Falcon|Armored Escort|Bell Automaton|Hooded Scribe|Armored Defender|Armored Lancer|Morning Gryphon|Banner Golem|Armored Surveyor|Hooded Medic|Armored Castellan|Clockwork Owl|Phalanx Construct|Brass Automaton|Highgate Guardian|Living Standard|Marble Arbiter|Brass Seraph|Ivory Warden|Stone Basilisk|Bell Colossus|Mobile Bastion|Aurelia Keeper|Sunrise Elemental',
 'Candle Spirit|Shadow Rat|Hooded Pledger|Grave Spider|Hollow Bat|Mire Collector|Ghost Hound|Glass Mourner|Shadow Drake|Blackroot Beast|Obsidian Golem|Faceless Debtkeeper|Veil Moth|Iron Custodian|Hooded Stitcher|Sable Herald|Glass Bailiff|Hooded Archivist|Thorn Devourer|Vigil Keeper|Thorn Arbiter|Winged Revenant|Archive Beast|Covered Duelist|Iron Thronekeeper|Moonveil Wraith|Nyxhollow Keeper|Ancient Night Spirit',
]
for f, subtypes in enumerate(UNIT_SUBTYPES):
 names=subtypes.split('|')
 assert len(names)==len(UNIT_LOCALS),(f,len(names))
 for local,subtype in zip(UNIT_LOCALS,names): cards[f*43+local]['subtype']=subtype
HERO_IDENTITIES = {
 'Asha, Keeper of the Last Seed':'Asha is a local Sylvaris seed-refuge keeper, always fully hooded in closed green armor with a living root circlet; her two sapling companions and their strengthened roots express her rules. She is a new custodian, not a replacement for the original champion.',
 'Korr, the Banked Inferno':'Korr is an Ashmar relief-forge champion in heavy closed crimson plate and a chained furnace breastplate; his immediate charge expresses Rush and the later controlled fire wave expresses the Vow. Never show an uncovered face.',
 'Neris, Keeper of the Ebb':'Neris is Meridine\'s fully hooded blue-robed memory custodian on a tideglass skiff; a memory pearl is recovered now, and only her surviving promise later sends hostile formations back with the ebb.',
 'Seren, Keeper of the First Light':'Seren is Aurelia\'s fully veiled ivory-armored lantern keeper; a refuge recovers when her light arrives and two memory lights return only after her voluntary watch survives. Her face and all skin remain concealed.',
 'Veyra, Keeper of the Unsaid':'Veyra is Nyxhollow\'s fully veiled black-robed custodian of an unopened violet orb; a hostile letter is surrendered on arrival and two independent echoes emerge only after her chosen watch survives. She does not replace Ravenna at the stone.',
}
FLAVOR_OVERRIDES=json.loads((ROOT/'data/cards/set02_flavor.json').read_text(encoding='utf-8'))['cards']
for f, block in enumerate(ART_ACTIONS):
 actions=block.splitlines()
 assert len(actions)==43,(FACTIONS[f],len(actions))
 for local, action in enumerate(actions):
  c=cards[f*43+local]
  composition=COMPOSITIONS[(local*5+f*3)%len(COMPOSITIONS)]
  if c['type']=='WELLSPRING':
   composition='extreme-wide location establishing shot, environment as the protagonist, distinct architecture and flowing resource, no posed character'
  elif c['id'] in ('SF002-041','SF002-084','SF002-127'):
   composition='monumental hero composition with tactile material detail and strong environmental scale, matching the approved concept subject'
  elif c['type'] in ('RITE','RITUAL'):
   composition+='; depict the spell event at its decisive impact, not a person posing with magic'
  c['art_intent']=action
  c['art_composition']=composition
  # Card flavor describes its own narrative moment, rather than a repeated
  # sentence with the name swapped. These are authored actions, not statistics.
  c['flavor']=FLAVOR_OVERRIDES.get(c['id'],action.replace(', a rare monumental hero composition.','.'))
  rules=c['text'] or 'Its printed might and guard describe a physical combatant with no extra triggered magic.'
  mechanical=[]
  flat=[effect for b in c['effects'] for effect in b['effects']]
  if any(e['op']=='RENEW' for e in flat): mechanical.append('Make the wound and its physical mending visible; the restored guardian becomes stronger only because real damage was removed, never depict an unwounded target receiving free growth.')
  if any(b['trigger']=='ON_VOW' for b in c['effects']): mechanical.append('Show a threatened oath cord, seal or defended duty persevering under pressure; its later reward is earned by this permanent surviving until its next turn, once per Arena stay, not by a decorative glow.')
  if any(e['op']=='CREATE_TOKEN' for e in flat): mechanical.append('Show the specific small companions being created, distinguishable from the main source; their species and number follow the rules context.')
  if any(b['trigger']=='ON_DEATH' for b in c['effects']): mechanical.append('The source\'s damage or breaking form matters: its final departing gift is its death payoff, not an unrelated victory pose.')
  if c['type'] in ('RITE','RITUAL'): mechanical.append('Depict the exact spell event and its affected subject; healing restores, damage impacts, recall pushes the enemy away, and drawing/searching reveals a tangible memory or supply.')
  if not mechanical: mechanical.append('The physical movement and equipment communicate the printed combat role and keywords without inventing an unsupported magical ability.')
  identity=HERO_IDENTITIES.get(c['name'],'')
  c['art_narrative']=f'{c["name"]} is a {c.get("subtype",c["type"].lower())} of {FACTIONS[f].title()} in The Five Vows. {LORE[f]} This depicted moment belongs to the card because: {action} '+ ' '.join(mechanical)+f' Rules context (semantic only, never image lettering): {rules} Flavor context: {c["flavor"]} '+identity
  # Keep the original individual subject/location, then articulate what happens.
  c['art_prompt']+=f'. NARRATIVE EVENT: {action} CINEMATOGRAPHY: {composition}. STORY AND MECHANICAL MEANING: {c["art_narrative"]} Dynamic physical action and environmental consequences; no generic character lineup, no repeated studio portrait backdrop. All rules, names and flavor are semantic guidance only: absolutely no typography, lettering, numerals or UI in the image.'
document={'set':{'code':'SF002','name':'The Five Vows','total':215,'mechanics':{'Vow':'Once each time this unit enters play, at the start of your next turn if it is still in play.','Renew':'Remove up to N damage from the specified unit; if any is removed, add one +1/+1 counter.'}},'cards':cards}
output=json.dumps(document,indent=2,ensure_ascii=False)+'\n'
for path in ('data/cards/set02.json','app/assets/data/set02.json'):
 destination=ROOT/path
 temporary=destination.with_suffix('.json.tmp')
 temporary.write_text(output,encoding='utf-8')
 os.replace(temporary,destination)
print(f'Authored {len(cards)} cards and individual art prompts.')
