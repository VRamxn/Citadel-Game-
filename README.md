# CITADEL

An open-source, community continuation of **CITADEL**, the dystopian post-human war game on Ethereum. The original
team (THE NETWORK STATE / Maelstrom) published the design between 2022 and 2023, ran the EXORDIUM and the PILOT
mint, and shipped a Goerli alpha before disbanding. This repo builds the game they described, fully on-chain, on a
**hexagonal grid**, and makes it playable in the browser.

- **Rules and every number:** [`docs/RULES.md`](docs/RULES.md)
- **Original design posts:** [`docs/original/`](docs/original/) (whitepaper, EXORDIUM, tech tree, PILOT, WARLORD
  TECHNOCRACY, CITADEL OS, 0xCITADEL alpha) and a merged spec, [`GAME-SPEC.md`](docs/original/GAME-SPEC.md)

## What's in the game

- **Grid:** light CITADEL and PILOT to a 19,441-tile hex grid, sized so the 1,024 GEN0 and the generations they spawn
  saturate it around the third generation. The golden core and six outer mining fields produce the
  most DRAKMA, and that's where the war is.
- **Economy:** mine DRAKMA; build MINES, SHIELD / ENGINE / WEAPON SYSTEM, FLEET ACADEMY and CITADEL levels; hurry with DK.
- **Fleet:** train SIF GATTACA raiders, MHRUDVOG THROT fortifications, DREBENTRAAKHT siege ships and DALAA MAX scouts.
- **War:**
  - Raid, which is instant against neighbors (subgrid distortion). Distant raids travel, and anyone can resolve them
    for 10% of the loot; unresolved raids defect.
  - Scout and reinforce.
  - Lay **siege**: 48+ hourly waves. A PILOT-led victory founds your CITADEL on the ruins.
- **Generations:** FLEET POINTS mint GEN1+ PILOT, which colonize faction grid or capture tiles in sieges.
- **Tech tree:** 8 branches, 53 technologies, researched by factions and unlocked by RELIK keys.
- **MENTAT** intelligence network; **WARLORD TECHNOCRACY** (sovereign seats, KULT bribes, overthrows); the
  **GRID MAELSTROM** council of sovereigns that can take over the game's levers.
- **Seasons:** new astronomical objects open in isolation, then join the war.

The client is **CITADEL OS**: a hex map built for a big world (zoom to cursor, drag and pinch, WASD, a minimap,
level-of-detail rendering, jump to your CITADEL, to threats or to the core) with fog of war, panels for every action, the CITADEL DISPATCH news feed, and a
terminal (`raid 3 7 100`, `status 3`, `help`).

## Layout

| Path | What |
|---|---|
| `src/game/` | The game: `CitadelGame` (one address, all state) routes calls to `EconomyModule`, `WarModule`, `SiegeModule` and `ViewModule` by delegatecall (split only for the 24KB size limit) |
| `src/*.sol` | `CitadelNFT`, `PilotNFT` (bridged originals + native GEN1+), `MentatNFT`, `Drakma`, `DrakmaClaim`, `TechTree`, `Technocracy`, `SovereignCouncil`, testnet faucets |
| `src/bridge/` | `CitadelVaultL1` (Ethereum), `CitadelBridgeL2` (Base), `LocalMessenger` (local/tests) |
| `src/lib/` | Trait tables and the tech tree (`Traits.sol`), hex math, trait rolls |
| `script/` | `DeployL2` / `DeployL1` / `LinkL2` (launch), `DevDeploy` (local world), `Stack.sol` (shared wiring), trait packers and the DRAKMA `snapshot.mjs` |
| `test/` | Unit tests per system, plus `Playtest.t.sol`, a 30-day 8-player economic simulation |
| `web/` | CITADEL OS client (Vite + React + viem) |
| `keeper/` | Bot that resolves arrived marches and fights due siege waves |

## Play locally (five minutes)

Requires [Foundry](https://getfoundry.sh) (`mise install` picks up the pinned version) and Node ≥ 23.

```sh
git clone --recursive https://github.com/VRamxn/Citadel-Game-.git && cd Citadel-Game-
anvil &                                                          # local chain
forge script script/DevDeploy.s.sol --rpc-url local --broadcast --gas-estimate-multiplier 300  # deploy + seed 128 players (~8 min)
npm --prefix web install && npm --prefix web run dev             # http://localhost:5173
node keeper/keeper.ts &                                          # optional: auto-resolve marches and sieges
```

On the local chain the client signs with anvil's dev accounts: pick one at the top right, and use **+1h / +1d** to move
time. Both sides of the bridge run on the same local chain: the BRIDGE tab's testnet faucet hands out stand-in originals
to bridge in. Open **GUIDE** in the client for a walkthrough.

## Launch: originals on Ethereum, game on Base

The game runs on **Base**. Holders bridge their **original** CITADEL and PILOT from Ethereum through a vault (the
canonical OP Stack messenger, no admin keys) and bring them home whenever they like. PILOT keep the levels and
sovereignty they bought on mainnet. DRAKMA is a new token: old balances held in people's wallets carry over 1:1,
plus an equal share for every holder wallet, through a Merkle claim. GEN1+ CITADEL and PILOT are native to Base.

Deploy order, the snapshot scripts and what carries over: [`docs/LAUNCH.md`](docs/LAUNCH.md). On Sepolia ↔ Base
Sepolia the same scripts deploy stand-ins for the originals, with faucets, so the whole flow can be tested first.

## Develop

```sh
forge test                                       # unit tests
forge test --match-contract Playtest -vv         # 30-day balance simulation (prints a report)
npm --prefix web run abis                        # after changing contracts: refresh the client ABIs
npm --prefix web run build
```

## Status

The game runs on a local chain, and the client is tested end to end against it. It is **not audited**. PILOT and
GEN1 CITADEL traits use block randomness, which is fine for a testnet but needs VRF before anything of value depends on
it. Most balance numbers the posts never specified are marked **[designed]** in the rules; expect them to move as
people play.

## License

Code: MIT (see LICENSE). CITADEL art, names and lore were created by the original team. NFT holders hold commercial
rights to their own NFTs, per the original terms.
