# CITADEL rules (v0.2)

This is the ruleset the contracts in `src/` implement. Numbers come from the original design posts, archived in
[`docs/original/`](original/). Anything the posts never specified is marked **[designed]**: that's our call, and it's
the first thing to revisit in playtesting. Every number marked *lever* can be changed through
`setConfig` / `setFleetType` / `setBuildingCost` / `setTileBps` without redeploying. Today the deployer holds those
levers; the SOVEREIGN COLLECTIVE can take them over (see [Governance](#governance)).

Contents: [Assets](#assets) · [Grid](#grid) · [Mining](#mining) · [Buildings](#buildings) · [Fleet](#fleet) ·
[Battle](#battle) · [Raids](#raids) · [Scouting](#scouting) · [Reinforcement](#reinforcement) · [Siege](#siege) ·
[Generations](#generations) · [Tech tree](#tech-tree) · [MENTAT](#mentat) · [Warlord Technocracy](#warlord-technocracy) ·
[Governance](#governance) · [Seasons](#seasons-and-astronomical-objects) · [Known limits](#known-limits)

---

## Assets

| | Standard | Supply | Source |
|---|---|---|---|
| **CITADEL** | ERC-721 | 1024 GEN0, capped forever. GEN1+ are created in-game | Testnet copy carries the **real mainnet traits** of each id |
| **PILOT** | ERC-721 | 2048 GEN0. GEN1+ are minted in-game with FLEET POINTS | Traits: SUBJUGATION, KULT, LEVEL, SOVEREIGNTY, DEATH |
| **MENTAT** | ERC-721 | 128 GEN0 | Claimed by RELIK, or earned by completing tech branches |
| **DRAKMA (DK)** | ERC-20 | Capped at 10B | Mined, looted, and burned by most actions |

**SEKT** (CITADEL rarity) sets the DRAKMA and research multiplier: RELIK 16×, DROTH XYL 8×, IONSLAUGHT 4×, ELEKT 2×.

**Testnet faucet:** each address can claim once and gets 2 CITADEL, 2 PILOT and 5M DK (as in the alpha).
`grantCitadel(address, id)` gives a mainnet holder their own id.

## Grid

- Each astronomical object (AO) is a hexagon of tiles in axial coordinates `(q, r)` within radius 12 of `(0, 0)`
  (469 tiles).
- **Mining multiple per tile [designed]:** distance ≤1 from the core → 1.25×, ≤3 → 1.15×, ≤5 → 1.05×, else 1.00×
  (*lever* per tile; the posts gave 1×–1.25× with the center as the hotspot).
- **`lite(citadel, ao, q, r, faction, research, pilots[])`** places a GEN0 CITADEL on any free tile, with up to 8 PILOT
  (*lever*), and mining starts at once. Factions: 0 NETWORK STATE, 1 AUTONOMOUS ZONE, 2 SANCTION, 3 ANNEXATION.
  `setFaction` / `setResearch` change those later.
- **`unlite`** returns the CITADEL, PILOT and MENTAT, but not while any march or siege involves the CITADEL. The vault is
  paid out if a claim is available, otherwise it is forfeited **[designed]**. Garrison, training and any construction in
  progress are lost.
- **Building levels travel with the CITADEL.** They're kept per id while it's off the grid (`savedLevels`) and return
  when it's lit again, by whoever owns it then. The whitepaper: "a lvl 10 CITADEL [is] more valuable than a lvl 1
  CITADEL. This value can be extracted on secondary markets". Only being leveled in a siege wipes them.

## Mining

```
DK/day = baseDkPerDay (4,000) × SEKT multiplier × tile multiple × (1 + mining bonuses) ÷ 10^generation  (× 2 in a DOOM RIOT)
```

- With 4,000 base, the SEKT multipliers reproduce the EXORDIUM daily rates: 64k / 32k / 16k / 8k for GEN0.
- GEN1 produces a tenth as much (whitepaper: "GEN0 … 10X more DRAKMA than GEN1").
- **Mining bonuses:**
  - MINE: +10% per level.
  - DREDGE NOBILITY PILOT: +(20% + 2% × level), halved per PILOT generation.
  - HERMETIC STRACHT PILOT: the same, but only on hotspot tiles **[designed: "work hostile DRAKMA mines"]**.
  - MENTAT: +10% + 2% per level.
  - Unique abilities (MYSTERIUM, STROGOTHT, DREADNAUGHT) and faction tech.
- DK piles up in the CITADEL's **vault**, where it can be raided. **`claim`** mints the vault to the owner, at most
  once per 7 days per CITADEL (*lever*; alpha rule).

## Buildings

One construction at a time per CITADEL. Level L costs `base × COST[L]` DK and takes `time × TIME[L]`.
**`hurryBuild`** finishes it immediately for **2× the remaining share of its cost** (*lever* `hurryBps`).

| L | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| COST × | 1 | 2 | 4 | 7 | 12 | 20 | 33 | 55 | 90 | 150 |
| TIME × | 1 | 1.5 | 2 | 3 | 4 | 6 | 8 | 12 | 16 | 24 |

| Building | Base cost | Base time | Effect per level **[designed]** |
|---|---|---|---|
| CITADEL | 20,000 | 2h | Structure defense = 100 × (L+1)² DP; other buildings can't exceed the CITADEL level (level 1 is always allowed) |
| MINE | 10,000 | 1h | +10% DRAKMA |
| SHIELD | 15,000 | 1.5h | +10% shield power |
| ENGINE | 15,000 | 1.5h | +10% engine power |
| WEAPON SYSTEM | 15,000 | 1.5h | +10% weapon power |
| FLEET ACADEMY | 2,000 | 20m | Unlocks fleet types; +5% training speed per level above 1 |

**Score:** a GEN0 CITADEL is worth 50 points and a GEN1+ worth 10, plus the sum of building level². WALLET LEVEL =
⌊√score⌋ (whitepaper: non-linear).

## Fleet

| | OP | DP | Cost | Train | Academy | Carry | Speed (per tile) |
|---|---|---|---|---|---|---|---|
| SIF GATTACA (swarm) | 10 | 5 | 20 | 5m | 1 | 40 | 30m |
| MHRUDVOG THROT (fortification) | 5 | 40 | 40 | 15m | 2 | 20 | 45m |
| DREBENTRAAKHT (siege ship) | 500 | 250 | 800 | 60m | 5 | 200 | 60m |
| DALAA MAX (scout) | 2 | 2 | 8 | 2m | 1 + ATOMIC ENGINE tech | 5 | 10m |

- OP, DP, cost and training time for the first three come from the alpha post. **[designed]** DALAA MAX, carry,
  speed, and the academy requirements.
- Training is a queue per type: units appear one at a time. **`hurryTraining`** finishes the queue for 2× the
  remaining units' cost.
- A march moves at the speed of its slowest unit. Propulsion tech speeds it up.

## Battle

**[designed: the posts never gave a formula]**

```
attack  = Σ units × OP × (1 + weapon% + PILOT offense% + type bonuses)
defense = Σ garrison × DP × (1 + shield% × (1 + engine recharge%) + PILOT defense% + type bonuses + [THROT only: fortification 50%])
        + structure × (1 + shield% …)
```

- **Fortification:** only MHRUDVOG THROT fortify. The alpha post: THROT "can gain fortification bonus when stationed in a
  CITADEL". The whitepaper says fortified fleet is "at least 50% more powerful". This makes SIF raiders beat SIF
  garrisons, while THROT turtles beat raiders cost-efficiently. The 30-day simulation in `test/Playtest.t.sol` showed
  that fortifying every unit deadlocks equal players.
- **Raid outcome:** the stronger side wins and the loser loses every unit. The winner loses `(weaker / stronger)^1.5`
  of each unit type (a Lanchester-style curve), reduced by its engine's weapons-repair %. Losses round up.
- **Component stats** (base ability always active; *unique* ability needs the faction tech, see below):
  - **Shields (fleet defense):** DAG SGIATH 10%, XZCID MAGH 11%, TELUM RATIO 12%, UNGARDROTHH 15%, DSGRILL RATIO 17%,
    DASKENWAFT 20%, MYSTERIUM 25%, MARBHADH GREINE 35%.
  - **Engines (shield recharge / weapons repair):** HAG GOTOR 10/2.0, CHOBAKK 11/2.25, TELUM MAK 12/2.5,
    STROGOTHT 15/3.0, FULTACHT MAK 17/3.75, GLUASAD 20/4.75, DSGILL MAK 25/6.0, DREADNAUGHT 35/7.5.
  - **Weapons (fleet damage / secondary):** RRAKATAKHT FUROR 10/+5% SIF, AG HALMAHHER 11/+5% DREB, TELUM FUROR 12/+6% SIF,
    HALMAHHER FUROR 15/+7% SIF, DAG VERSTACKT 17/+7% DREB, VEERDACHT MAGH 20, MARBHADH GHXST 25/+10% DREB,
    DEI IUDICIUM 35.
  - Component power is ×(1 + 10% × building level) × MENTAT amplification, and halved for GEN1
    ("GEN0 … 2X multiple to shield, engine, and weapon system").
- **Unique abilities:**
  - VEERDACHT MAGH destroys 5% of attackers when defending and 2% of defenders when attacking.
  - DEI IUDICIUM makes 5% of attackers desert to the defender, every battle and every siege wave.
- **PILOT:** each one gives its CITADEL +(20% + 2% × level) offense and defense (THE PILOT post), halved per
  generation. SIF COMMANDER adds the same to offense again, CRHONA THROT to defense, PSIONIC FUROR to scouting (×5),
  ALKAHEST DRIFT to research (×5).
- **FLEET POINTS** = the DK value of enemy fleet you destroyed (alpha: "accrue when you destroy fleet").

## Raids

- **`raid(from, to, units)`** steals **unclaimed** DK from the target's vault. Survivors carry Σ survivors × carry.
- **Subgrid distortion:** a raid on an adjacent tile, or any raid while the whole grid is distorted (*lever*),
  resolves in the same transaction.
- Otherwise the fleet travels. Once it arrives, **anyone** can call `resolve(marchId)` and earn **10% of the loot**
  (*lever*). Survivors march home with the rest, and the return is landed with `resolve` too.
- **Defection:** a raid left unresolved for 24h after arrival (*lever*) defects. The attacking fleet joins the
  defender.
- A CITADEL with marches heading to or from it can't leave the grid.

## Scouting

**`scout(from, to, [0,0,0,n])`** sends DALAA MAX. Their scouting power, `n × (1 + scouting bonuses)`, is compared with
the defender's DALAA. On success a `ScoutReport` reveals the target's garrison, vault and building levels; the client
shows that intel for 24h. Losses follow the raid curve.

## Reinforcement

**`reinforce(from, to, units)`** sends fleet to any lit CITADEL, using raid travel rules. On arrival the units **join the
target's garrison**. There's no recall **[designed]**. A CITADEL under siege can't send reinforcements (whitepaper).

## Siege

- **`siege(from, to, units, pilot+1)`** marches an army, optionally led by a PILOT from your wallet. On arrival
  (instant if adjacent) the siege starts.
- **A CITADEL hosting a sovereign PILOT can't be sieged.**
- **Waves:** one battle per hour (*lever*); anyone calls `advanceSiege(id, maxWaves)`. Each wave:
  - Attack uses siege rules: DREBENTRAAKHT hit twice as hard, shield siege-defense bonuses apply, and the PILOT adds
    +(20% + 2% × level), ×2 if sovereign. The defense is the live garrison plus structure, so reinforcements and fleet
    the defender trains (and hurries) during the siege count.
  - Each side loses `10% × enemy power / own power` of its units (capped at all of them), reduced by weapons repair
    **[designed]**.
  - Progress moves by `maxSwing × (A − D)/(A + D)`, **doubled when negative** ("a losing siege will quickly lose its
    progress"). maxSwing = 100% / 48, so **48 waves (48h) is the fastest siege** (whitepaper).
- **Success (100%):** the target is **leveled**.
  - GEN0 CITADEL return to their owner's wallet with buildings reset; GEN1+ are destroyed.
  - Its PILOT and MENTAT go home, its vault goes to the attacker, and its garrison dies.
  - With a PILOT, the attacker **founds a new CITADEL on the tile** (GEN max(1, PILOT generation)) garrisoned by the
    surviving army. A DEATH PILOT starts a **DOOM RIOT** there: 2× production until that CITADEL is ejected.
  - Without a PILOT the army goes home and the tile is free.
- **Failure (0%, or the army dies):** the army is destroyed. A GEN0 PILOT retreats to its owner's wallet; later
  generations are destroyed (whitepaper).
- Anyone can `joinSiege` with more fleet, which travels to the siege. Several sieges can run at once.

## Generations

- **`mintPilot(citadel)`** spends FLEET POINTS on a PILOT of generation (CITADEL generation + 1). Cost =
  10,000 × 2^(PILOT already minted by this CITADEL) × 3^generation (*lever* base). Whitepaper: exponential in both.
- **`colonize(pilot, ao, q, r, faction)`** founds a GEN max(1, PILOT generation) CITADEL on a free tile within 2 of a
  CITADEL of that faction, for 250,000 DK (*lever*). No new GEN0 can ever be made.
- GEN1+ CITADEL roll ELEKT with components weighted to the weaker tiers and a random tech.

## Tech tree

- **Structure:** 8 branches and 53 technologies from the EXORDIUM post, discovered in order. Tech k of a branch costs
  100,000 × (k+1) points (*lever*).
- **Research:** every lit CITADEL researches one branch for its faction at
  `4,000 × SEKT ÷ 10^gen × (1 + ALKAHEST DRIFT bonus)` points per day, doubled on its own tech property.
- **RELIK keys:** a faction's branch only advances while a GEN0 **RELIK whose tech is that branch** is lit in the
  faction and researching it ("the RELIK hold the key"). That makes RELIK the most valuable, and most sieged, CITADEL.
- **Effects** (full list in `src/lib/Traits.sol`, library `Tech`, and in the client's TECH tab):
  - Each shield / engine / weapon has a tech that unlocks its *unique* ability for the faction.
  - Fleet techs give +10% to SIF / THROT / DREB.
  - ATOMIC ENGINE unlocks DALAA MAX; THREATCASTING gives MENTAT +50%.
  - The rest are faction-wide +1–5% to DRAKMA, offense, defense, fortification, speed or training.

## MENTAT

- Each GEN0 RELIK may claim one (`TechTree.claimRelikMentat`). When a faction completes a branch, the owner of a key
  RELIK researching it may claim one more.
- Lit into a CITADEL (`attachMentat`, one per CITADEL):
  - +25% + 5% per level to shield, engine and weapon power.
  - +10% + 2% per level DRAKMA.
  - Scouting bonus, and +2 vision in the client.
- Uplevel costs 250k × level DK.

## Warlord Technocracy

`Technocracy.sol` (THE WARLORD TECHNOCRACY post):

- **PILOT claim:** every GEN0 CITADEL may claim one PILOT for 64,000 DK. A RELIK's PILOT is **born sovereign**.
- **Sovereignty:** 128 seats = 64 born + 64 bought for **4M DK**.
- **Sovereign powers:** can't be sieged, leads sieges at 2×, and takes a cut of the DK sinks.
  - Seat purchases and overthrows pay 70% to the collective, 25% to the treasury, and burn 5%.
  - Collective shares are claimable every 30 days.
- **Bribes:** 100k DK to one of the 8 KULT, decaying after 90 days. Payout: 60% to the KULT's enrolled PILOT,
  30% treasury, 5% collective, 5% burned. A POTENTATE COERCION or TECHNOCRAT ARMAMENT sovereign counts each bribe twice
  **[designed: "provides boost to KULT"]**.
- **Overthrow:** any PILOT can take a sovereign's seat for **4M + 1M × active bribes**. The fallen sovereign is paid what
  it was owed first.
- **KULT payouts:** a PILOT enrolls with `registerKult` and claims its share of bribes to its KULT.

## Governance

`SovereignCouncil.sol`, called GRID MAELSTROM:

- Sovereign PILOT propose arbitrary calls and vote, one vote per seat. A majority of the seats filled at proposal time
  passes within 7 days, and anyone can then execute.
- To hand the levers over, the game owner calls `transferOwnership(council)` and the council passes a proposal calling
  `acceptOwnership()`.

## Seasons and astronomical objects

- **AOs:** AO 0 opens connected. The owner can open new AOs as **Isolated**, meaning no marches cross to or from them
  during their ladder season, and later **Connected**. Marches between connected AOs cost 12 extra tiles of distance.
- **Seasons:** `startSeason()` emits a new season number. Ladder rewards are tallied off-chain from events for now.

## Known limits

- **No real fog of war.** All chain state is public. The client enforces the whitepaper's vision rules (2 tiles,
  +1 SURVEILLANCE STATE, +2 with a MENTAT, scout reports), but true secrecy would need commit/reveal or ZK.
- **Randomness:** PILOT and GEN1 CITADEL traits use `prevrandao`. That's fine for a testnet; mainnet needs VRF.
- **Keeper:** siege waves processed late all use the garrison as it is when processed, so run the keeper
  (`keeper/keeper.ts`) to keep sieges hourly.
- **Not audited.** Admin levers sit with one key until handed to the council.
- **Gas** (`forge test --match-contract GasReport -vv`): lite ~300k · build ~210k · train ~165k · claim ~150k ·
  instant raid ~360k · send raid ~330k · resolve raid ~560k · resolve return ~70k · start siege ~340k · one siege wave
  ~300k (24 waves ~1M). That's fine on a testnet or an L2. The whitepaper's goal of "under 10 cents a day" for an
  active player needs an L2 ("Fully On-Chain / L2"), not Ethereum mainnet.
