# CITADEL rules — v0.1 (alpha ruleset, hex grid)

This is the ruleset the contracts in `src/` implement. Numbers come from the original design posts
(archived in `docs/original/`). Anything the posts never specified is marked **[designed]**: it's our call
and the first thing to revisit in playtesting. Every number marked *lever* can be changed by the
game owner through `setConfig` / `setFleetType` / `setTileBps`, without redeploying.

## Grid

- A hexagon of hex tiles in axial coordinates `(q, r)`, centered on `(0, 0)`. The default radius is 12
  (469 tiles). Distance is the standard hex distance.
- Each tile has a mining multiple. **[designed]** default hotspot layout: distance ≤1 from center → 1.25×,
  ≤3 → 1.15×, ≤4 → 1.05×, else 1.00×. About 13% of tiles are boosted (the alpha post said "around 10%", with
  1×–1.25× and the center as the hotspot). Hotspots can be shifted per tile (*lever*).
- One CITADEL per tile. Placement is free (as in the alpha). Faction-territory rules come with siege.

## Lite / unlite

- `lite(citadel, q, r, faction, pilots[])` moves the CITADEL and up to 8 PILOT (*lever*) into the game
  contract. Mining starts immediately.
- `unlite` returns them. It isn't allowed while any raid or reinforcement is headed to or from the CITADEL.
  **[designed]** The vault is paid out if a claim is available; otherwise it is forfeited. Garrison and
  queued training are disbanded.
- `setFaction` may be called any time the CITADEL isn't engaged. The 4 factions are NETWORK STATE,
  AUTONOMOUS ZONE, SANCTION and ANNEXATION.

## Mining

```
DK/day = baseDkPerDay × SEKT multiplier × tile multiple × (1 + mining bonuses)
```

- `baseDkPerDay` = 4,000 (*lever*). Combined with the SEKT multipliers (RELIK 16, DROTH XYL 8, IONSLAUGHT 4,
  ELEKT 2), this reproduces the EXORDIUM daily rates of 64k / 32k / 16k / 8k.
- Mining bonuses: MYSTERIUM shield +5%, STROGOTHT engine +1%, DREADNAUGHT engine +5%,
  each DREDGE NOBILITY PILOT +(20% + 2%×level), each HERMETIC STRACHT PILOT the same but only on a
  hotspot tile **[designed: "work hostile DRAKMA mines"]**.
- DK accumulates in the CITADEL's **vault**, which can be raided. `claim` mints the vault to the owner at most
  once per 7 days per CITADEL (*lever*; alpha rule).

## Fleet

| | OP | DP | Cost | Train | Carry **[designed]** | Speed **[designed]** |
|---|---|---|---|---|---|---|
| SIF GATTACA | 10 | 5 | 20 DK | 5 min | 40 DK | 30 min/tile |
| MHRUDVOG THROT | 5 | 40 | 40 DK | 15 min | 20 DK | 45 min/tile |
| DREBENTRAAKHT | 500 | 250 | 800 DK | 60 min | 200 DK | 60 min/tile |

OP/DP/cost/train come from the alpha post. The posts describe speed and carry only in words ("fast",
"slow", "average carry"); 30 min/tile is the alpha's base speed. A march moves at its slowest unit.
Training is a queue per fleet type; units appear one at a time as their training finishes.

## Raids

- **Adjacent target (distance 1), or grid-wide distortion on:** resolves in the same transaction.
  Survivors and loot are home immediately. This is the "trench warfare" from the alpha post.
- **Otherwise:** the fleet travels `distance × speed`. Once it arrives, **anyone** can call `resolveRaid`
  and earn 10% of the loot (*lever*). Survivors travel back as a return march, and anyone can `completeMarch`
  it once it arrives; loot lands in the attacker's vault.
- **Defection:** a raid not resolved within 24h of arrival (*lever*) defects. The attacking fleet joins the
  defender's garrison.
- Raid reports are emitted as `RaidResolved` events.

## Battle **[designed — the posts never gave a formula]**

```
attack  = Σ(units × OP) × (1 + weapon% + Σ PILOT offense%)
defense = Σ(garrison × DP) × (1 + fortification 50% + shield% × (1 + engine recharge%) + Σ PILOT defense%)
```

- The stronger side wins and the loser loses every unit. A tie wipes out both sides.
- The winner loses `(weaker / stronger)^1.5` of each unit type (a Lanchester-style curve, as in Travian),
  reduced by its own engine's weapons-repair %. Losses round up.
- Survivors carry `Σ(survivors × carry)` DK out of the defender's vault.
- PILOT: each one gives +20% + 2%×level to both offense and defense of its CITADEL. A SIF COMMANDER also
  adds the same again to offense, and a CRHONA THROT adds it to defense (THE PILOT post).
- Shield/weapon base bonuses and engine recharge/repair are the "base ability" values from the EXORDIUM
  post. "Unique" abilities need the tech tree and aren't active yet.
- **FLEET POINTS** = DK value of the enemy fleet you destroyed (alpha: "accrue when you destroy fleet").
  They're recorded now and will be spent on minting GEN1 PILOT once siege ships.

## Reinforce

`reinforce(from, to, units)` sends fleet to any lit CITADEL, using the same travel rules as a raid. On
arrival the units **join the target's garrison** **[designed: v0.1 has no recall]**.

## Known limits of v0.1

- **No fog of war.** All chain state is public, so the whitepaper's 2-tile vision and the MENTAT
  intelligence network can only be enforced by the UI until we add a commit/reveal or ZK scheme.
- PILOT randomness on testnet comes from `prevrandao`, which is fine for a testnet but needs VRF before mainnet.
- `setConfig` and friends are controlled by a single owner key. The plan is to hand them to the
  SOVEREIGN COLLECTIVE.

## Roadmap (from the original posts)

1. **v0.1:** this.
2. **Siege:** 48h+ hourly battles with progress 0→100%, PILOT capture of grid, GEN1 PILOT via FLEET POINTS,
   sovereign siege immunity and 2× sovereign-led sieges.
3. **Warlord Technocracy:** sovereignty (64 seats at 4M DK), KULT bribes (100k, 90-day decay), overthrow
   (4M + bribes×1M), DK dispersement to the collective.
4. **Tech tree:** the 8 branches, RELIK keys, faction research, and unique shield/engine/weapon abilities.
5. **MENTAT, DALAA MAX, seasons and new AOs, CITADEL levels 0–10, mines, fleet academies.**
