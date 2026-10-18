# CITADEL — Consolidated Game Spec

Compiled from all 9 design posts by THE STATIST (thestatist.substack.com, Jan 2022 – May 2023).
Raw text of each post is in this folder (`01-…` through `10-…`). Where posts disagree, the **later post wins** and the conflict is noted under "Conflicts".

---

## 1. Concept

- Dystopian post-human, slow-play, multiplayer war/strategy game. Influences: 80s MUDs, Civilization, Myst, Catan (placement).
- Fully on-chain (Ethereum): all assets, rules, and outcomes. Target: 1–2 actions/day for most players, 2–20 for heavy players, < $0.10 gas/day.
- Core loop: light CITADEL to GRID → mine DRAKMA → train FLEET → raid neighbors / defend → upgrade → (later) siege and expand.
- Players cooperate in FACTIONS. Lore delivered via the daily **CITADEL DISPATCH**, written by the faction leaders and read inside **CITADEL OS** (a text terminal UI).

## 2. Assets

### CITADEL (ERC-721)
- Genesis: **1024** 1/1 CITADEL, free mint. Genesis is capped forever.
- Can: light to grid & mine, uplevel lvl0 → lvl10 (DRAKMA, on-chain), upgrade shield / engine / weapon system, build mines (count ∝ CITADEL level), build FLEET academies, recruit FLEET, mint next-gen PILOT with FLEET POINTS, raid, siege, unlock tech-tree branches.
- **Generations:** GEN0 has 2× shield/engine/weapon power and 10× the DRAKMA output of GEN1. Each later generation is "dramatically" weaker.
- **Passive stats:** SEASON, GENERATION (from mint conditions) + random traits. Immutable.
- On-chain traits that matter in play: SEKT, tech property, shield, engine, weapon system.

### SEKT (CITADEL rarity tier)
| SEKT | Count | % | Multiplier | Exordium DK/day | Exordium total |
|---|---|---|---|---|---|
| RELIK | 64 | 6.25% | 16× | 64,000 | 9.6M |
| DROTH XYL | 128 | 12.5% | 8× | 32,000 | 4.8M |
| IONSLAUGHT | 256 | 25% | 4× | 16,000 | 2.4M |
| ELEKT | 576 | 56.25% | 2× | 8,000 | 1.2M |

The multiplier applies to both prelude DRAKMA and research points.

**RELIK** = first 64 CITADEL (auctioned). They hold the keys to the tech tree, act as faction research centers, get multiplied DAO votes and proposal rights, and can freely claim MENTAT. Designed to be the most-protected and most-sieged CITADEL.

### PILOT (ERC-721)
- **2048** total: 1024 claimable by CITADEL holders (64,000 DK each, CITADEL must be staked), 1024 public (≈0.125 ETH, up to 5 per tx).
- Required to siege-and-capture. Can also found a CITADEL on unclaimed faction grid. GEN0 is indestructible (it retreats when a siege fails). GEN1+ are destroyed if a siege fails.
- Generation chain: GEN0 CITADEL → mints GEN1 PILOT → founds GEN1 CITADEL → …
- Multiple PILOT can be stacked into one CITADEL.
- **5 on-chain properties:** SOVEREIGNTY, SUBJUGATION, KULT, LEVEL, DEATH.

**LEVEL** (0–9): upgrade cost = 100,000 DK × target level. Each level adds +2% to all three multipliers.
| Lvl | Cost | Offense / Defense / Subjugation bonus |
|---|---|---|
| 0 | — | 20% |
| 1 | 100k | 22% |
| 2 | 200k | 24% |
| … | +100k/lvl | +2%/lvl |
| 9 | 900k | 38% |

Offense applies to fleet in a raid/siege. Defense applies when the PILOT is fortified in a CITADEL.

**SUBJUGATION** (occupation; count out of 2048):
| Subjugation | Count | Boost |
|---|---|---|
| HERMETIC STRACHT | 1024 | hostile DRAKMA mines |
| POTENTATE COERCION | 512 | KULT |
| DREDGE NOBILITY | 256 | DRAKMA extraction |
| ALKAHEST DRIFT | 128 | tech-tree research |
| CRHONA THROT | 64 | defensive fleet |
| SIF COMMANDER | 32 | offensive fleet |
| PSIONIC FUROR | 16 | intelligence network |
| TECHNOCRAT ARMAMENT | 16 | KULT |

**KULT** (faction-like political/aesthetic trait): KULT GEHEIM 512, DØD ENGEL 256, STALKROTH 256, KULT GOR 256, KLINGE 256, DALK STRACHT 256, YS DIABOLI 128, GRÅTER DJEVEL 128.

**DEATH PILOT:** 64, randomly distributed. When one wins a siege it triggers a **DOOM RIOT**: 2× productivity for its CITADEL until that CITADEL is ejected from the grid.

### MENTAT (ERC-721, first expansion)
- Intelligence network: unlocks battle reports you wouldn't otherwise get, reveals hidden enemy grid, and amplifies the shield/engine/weapon/DK production of the CITADEL it's lit to. Upgradable on-chain. Benefits the whole faction.
- 128 GEN0 at full-game start (64 claimable by RELIK owners per the whitepaper). Unlocked by the *Threatcasting* tech. Future gens are emitted by RELIK when a tech branch completes.

### DRAKMA / DK / Ð (ERC-20)
- Total supply: **10B**. Finite and deflationary (part of spent DK is periodically burned).
- Earned by mining and raiding. Spent on upgrades, fleet, mines, speed-ups ("hurry"), NFT purchases.
- Split: prelude staking distribution / dev-team reserve / treasury governed by the DAO **GRID MAELSTROM**.
- Exordium: 2.5B distributed by SEKT. Leftovers burned. 100M bonus to the first faction to complete the tech tree. 400M to the Discord ACE and PILOT roles on day 64.
- Design intent: players choose between *extracting* DK and *reinvesting* it to build a near-unsiegeable dominant CITADEL.

## 3. World

### GRID
- Tiles on the surface of DRAKMA-rich **Astronomical Objects (AOs)**. The game starts with 1 AO.
- Each tile has a mining multiple of **1.0×–1.25×**. About 10% of tiles (starting at the grid center) are **hotspots**. Hotspots shift over time and are ultimately controlled by the Sovereign Collective.
- A CITADEL sees a **2-tile radius** and shares that vision with its faction. Visible CITADEL can be attacked.
- **Capture** (whitepaper): enemy un-staked grid touching your faction's grid takes 2 real-time days, auto-lights, and gets a temporary DK multiplier at 100% production. Unclaimed grid starts at 25% production and is not auto-lit.
- **Subgrid distortion** (alpha): adjacent CITADEL can be raided with **zero travel time**, which leaves the defender no window to reinforce. This creates "trench warfare" along faction borders. Occasionally the whole grid distorts (all-out war, possibly unannounced).

### Seasons / Ladder
- When an AO saturates, a new AO opens, isolated from the old ones for that ladder season. When the season ends, rewards are given by rank and achievements, and the AOs connect so cross-AO sieges and support become possible.
- New, less-productive grid is added for new players so they compete at a similar level.

## 4. Actions

### Lite / Claim / Withdraw
- Light NFTs to the grid to enter play (PvP). Mining starts immediately. Light CITADEL and PILOT tile by tile.
- Claim moves the earned DK out of the CITADEL (DK left inside can be raided). Alpha rule: **one claim per CITADEL per week**.
- You can claim and stay in, or claim and leave. A CITADEL under siege can't leave.
- Alpha uses one "approve all" for CITADEL + PILOT + DK.

### Train FLEET (alpha numbers; explicitly subject to balancing)
| Fleet | Role | OP | DP | Cost | Train time |
|---|---|---|---|---|---|
| SIF GATTACA | swarm infantry, all-round raider, fast, avg carry | 10 | 5 | 20 DK | 5 min |
| MHRUDVOG THROT | defender, fortification bonus, slow | 5 | 40 | 40 DK | 15 min |
| DREBENTRAAKHT | siege ship, breaks shields/weapons/engine, slow | 500 | 250 | 800 DK | 1 h |
| DALAA MAX | scout: fast, cheap, low OP/DP, low carry | — | — | — | — (not in alpha) |

Fleet attributes: offense, defense, **carry** (DK looted per unit), **speed**. FLEET ACADEMY is the first structure: it enables training, is upgradeable, acts as the CITADEL's research hub, and unlocks more academy types as the CITADEL levels.

### Raid
- Steals **unclaimed** DK from the target CITADEL. Surviving attackers fill their carry slots on the way home.
- Adjacent (distorted) raids resolve **instantly**.
- Non-adjacent raids take travel time (alpha: **30 min per tile**, each way). On arrival **anyone** can call resolve and gets **10% of the loot**. Expected to turn into a bot/keeper market.
- **Defection:** a raid left unresolved for 24h makes the attacking fleet defect to the defender.
- Raid reports are emitted as on-chain events and shown in the defender's UI.

### Reinforce
- Send fleet to any CITADEL (yours, your faction's, anyone's). Uses the same travel time as a raid. This rewards clustering into defensive blocks and walling off productive CITADEL.

### Fortify
- Station fleet in a CITADEL. Fortified fleet is **≥50% stronger** than attacking fleet. Upgrading the shield adds to this.

### Siege (whitepaper; NOT in alpha v0.1)
- Takes ≥48h. Progress runs 0→100%, with one battle per hour that moves it ± depending on how lopsided the result is. At 100% the CITADEL is leveled. The attacker takes all its DK and, if a PILOT was sent, the grid tile (the PILOT forms a new CITADEL there).
- Without a PILOT a siege can only level the target, not capture it.
- At 0% the siege fails: GEN0 PILOT retreats, GEN1+ PILOT is destroyed.
- Multiple simultaneous sieges are allowed. A CITADEL under siege **can't send reinforcements**, so pinning a faction with many sieges at once is an intended strategy.
- The defender can train and hurry fleet inside the CITADEL with DK. Attackers can add fleet, but it has to travel.
- Outcome factors: fleet ratio + the CITADEL's weapon system, shield, and engine.
- A CITADEL hosting a **sovereign** PILOT can't be sieged until that sovereign is overthrown. A sovereign-led siege gets **2× offense**.

### FLEET POINTS & WALLET LEVEL
- FLEET POINTS are spent to mint the next-gen PILOT. Cost scales **exponentially** with generation and with the number of PILOT that CITADEL has already minted.
- WALLET LEVEL is non-linear, based on a game score = Σ(owned resources × resource level). Resources: CITADEL level, mines, shield, engine, weapon system, fleet academies.

## 5. CITADEL Components

Base ability is active from the start. The "unique" ability is unlocked via the tech tree. The hierarchy is fixed; values may be rebalanced.

**Shields:** DAG SGIATH 10% fleet def (+5% siege def) · XZCID MAGH 11% (+10% siege def) · TELUM RATIO 12% (+2% fleet def) · UNGARDROTHH 15% (+15% siege def) · DSGRILL RATIO 17% (+5% fleet def) · DASKENWAFT 20% (+15% swarm def) · MYSTERIUM 25% (+5% DK prod) · MARBHADH GREINE 35% (+25% swarm def)

**Engines** (shield recharge / weapons repair / unique): HAG GOTOR 10/2.0/+1% fort · CHOBAKK 11/2.25/+2% fort · TELUM MAK 12/2.5/+1% repair · STROGOTHT 15/3.0/+1% DK · FULTACHT MAK 17/3.75/+2.5% repair · GLUASAD 20/4.75/+5% fort · DSGILL MAK 25/6.0/+5% repair · DREADNAUGHT 35/7.5/+5% DK

**Weapon systems** (fleet dmg / secondary): RRAKATAKHT FUROR 10%/5% swarm · AG HALMAHHER 11%/5% siege · TELUM FUROR 12%/6% swarm · HALMAHHER FUROR 15%/7% swarm · DAG VERSTACKT 17%/7% siege · VEERDACHT MAGH 20%/unique: 5% attackers & 2% defenders destroyed · MARBHADH GHXST 25%/10% siege · DEI IUDICIUM 35%/unique: 5% of attacking fleet desert to defender each wave

## 6. Tech Tree (Exordium version: 8 branches)

Rules: research is faction-wide and collaborative. A branch only unlocks for a faction once a **RELIK with that tech property is staked to it**. Techs within a branch are linear (no skipping). Each tech has levels 0–9, and reaching 9 unlocks the next layer. A CITADEL researching its own tech property gets **2× research**. Research points = DRAKMA earned (SEKT multiplier applies). Staking or withdrawing a subset of CITADEL resets your tech multiplier.

| Branch | # CITADEL | Techs → unlocks |
|---|---|---|
| Preservative Algorithms | 512 | Teslaphoresis→TELUM RATIO · Deflector shields→DSGRILL RATIO · Preservational field→DAG SGIATH · Gravitational field→UNGARDROTHH · Grid disturbance eng.→XZCID MAGH · Obscurance calculus→MYSTERIUM · Bioadaptive resonance→**MHRUDVOG THROT** |
| Militant Algorithms | 256 | Applied gravitonics · Graviton cannon→**DREBENTRAAKHT** · Gravimetric torpedoes→MARBHADH GHXST · Plasma acceleration · Plasma cannon→RRAKATAKHT FUROR · Plasma torpedo→TELUM FUROR · Plasma detonator→HALMAHHER FUROR · Molecular disruption · Dag disruptor→DAG VERSTACKT |
| Antimatter Annihilation | 128 | Plasma discharge→HAG GOTOR · Plasma shard engine→CHOBAKK · Plasma barrier discharge→GLUASAD · Quantum mechanics · Zero-point energy→TELUM MAK · Fermion field→FULTACHT MAK · Bosonic field→DSGILL MAK · Grid outgress→STROGOTHT · Dark matter distribution→DREADNAUGHT |
| Propulsion | 64 | Sublight propulsion · Atomic engine→**DALAA MAX** · Ionic engine→+5% swarm speed · Artificial gravity→+2% siege prod · Cryogenic transport→+10% siege prod · Quantum field theory→DASKENWAFT · Collective excitation→MARBHADH GREINE |
| Posthumanism | 32 | Biogenetic algorithms · Neural grafting→**SIF GATTACA** · Grid-sentient algorithms→+2% DK · Xeno sympathy→+2% fortification · Biogenetic warfare · Retroviral plague→VEERDACHT MAGH · Hermetic systems→+1% shield def |
| Ecological Extraction | 16 | Terraforming · Synthetic chemistry→+2% DK · Atmospheric engineering→+5% DK |
| Technocracy | 8 | Polymorphic algorithms · Cloning vats→+10% swarm prod · Biohacking · Seed AI (+5% swarm def, fleet academy) · Warlord technocracy→political system · Econometric probe→+1% DK |
| Proginator Psi | 8 | Surveillance state · Threatcasting→**MENTAT** · Cybernated sentience · Psionic resonator→AG HALMAHHER · Dissociative wave algorithms→DEI IUDICIUM |

(The May 2022 post had an earlier 7-branch draft with Sanskrit key names. See `03-relik-sekt-tech-tree.txt`.)

## 7. Factions

Four at launch. You choose one when lighting a CITADEL, can switch freely, and players can create new factions later.
| Faction | Leader | Raid name | Flavor |
|---|---|---|---|
| THE NETWORK STATE | THE STATIST | GRID MAELSTROM | ruthless ruling power, squeezes others to the outer grid |
| THE AUTONOMOUS ZONE | THE FACTIONIST | THE OCCUPY | every CITADEL sovereign; liberty zealots |
| THE SANCTION | THE FANATIC | THE INQUISITION | brutal purge of the grid |
| THE ANNEXATION | THE PIN | THE BREACH | convict-led syndicate; sworn enemy of THE SANCTION |

## 8. Politics: WARLORD TECHNOCRACY

- **SOVEREIGN COLLECTIVE** = 128 sovereign PILOT. 64 are born sovereign (claimed via RELIK) + 64 seats bought at **4M DK** each, first come first served.
- Sovereigns control the economic levers (on-chain rule tweaks, hotspots), receive a cut of DK sinks (claimable every 30 days), are siege-immune, and lead sieges at 2×.
- **Bribe:** 100k DK to one of the 8 KULT, decays after **90 days**. Payout: 60% to PILOT in that KULT / 25% treasury / 5% collective / 5% burned. *(Only 95% is listed in the source.)*
- **Overthrow cost** = 4M + (active bribes × 10 × 100k) → 0 bribes 4M, 4 bribes 8M, 8 bribes 12M. Sovereignty/overthrow payments: 70% collective / 25% treasury / 5% burned.
- KULTs are meant to act as a check on sovereigns: an under-bribed KULT is incentivized to overthrow rival-KULT sovereigns.

## 9. CITADEL OS commands (as shipped, 2022)
```
approve <id> / stake <faction>, <tech>, <ids…> / claim / withdraw <ids…>
mint pilot / mint pilots <n> / claim pilot <citadel id>
approve drakma <amt> / uplevel pilot <id> / sovereign <pilot id>
overthrow <sovereign id> with <pilot id> / bribe <kult> <sovereign id> / check pilot <id>
link citadel   (unlocks the Discord)
```

## 10. Timeline
- 2022-01-30 whitepaper · 2022-04 genesis mint announced · 2022-08-27 → 2023-01-28 EXORDIUM (staking/mining) · 2022-11-05 PILOT public mint · 2023-05 0xCITADEL alpha v0.1 on Goerli (sovereigns only: 2 CITADEL, 2 PILOT, 5M DK each). Siege was not in the alpha.

---

## Conflicts between posts (pick one when you build)

| Topic | Earlier | Later |
|---|---|---|
| Travel time per tile | 1 h (whitepaper) | 30 min + zero-time adjacent distortion (alpha) |
| PILOT attack bonus | +50% (whitepaper) | +20% base, +2%/level (PILOT post, alpha) |
| Sovereign seat / overthrow base | 5M DK (PILOT post) | 4M DK (Technocracy, OS posts) |
| FLEET POINTS earned by | recruiting fleet (whitepaper) | destroying fleet in battle (alpha) |
| Re-minting a destroyed PILOT | "same amount of DRAKMA" | elsewhere it's FLEET POINTS with exponential cost |
| Claim frequency | any time (whitepaper, Exordium) | once per week per CITADEL (alpha) |
| Launch fleet types | 4 (incl. DALAA MAX) | 3 in alpha |
| Tech branches | 7 (May 2022 draft) | 8 (Exordium) |
| Exordium distribution | 2.4B | 2.5B |
| MENTAT supply | 64 free to RELIK | 128 GEN0 at full-game start |

## Not specified anywhere (you'll need to design these)
- The actual combat formula: how OP/DP, fortification, shield/engine/weapon %, and PILOT multipliers combine, and the per-hour siege % swing.
- Carry and speed values per fleet type. DALAA MAX stats.
- Costs and times for CITADEL lvl0→10 upgrades, mines, academies, and shield/engine/weapon upgrades.
- Base mining rate per CITADEL in the full game (Exordium rates were staking rewards). Mine output.
- Grid size/shape, AO geometry, hotspot placement algorithm.
- FLEET POINTS amounts and the exponential PILOT mint curve.
- What "shield recharge" and "weapons repair" mean mechanically.
- How MENTAT amplification, KULT power, and subjugation boosts are quantified (beyond the flat 20%+).
- Wallet-level curve, ladder rewards, DAO mechanics.
