# CITADEL

An open-source, community continuation of **CITADEL**, the dystopian post-human war game on Ethereum. The original
team (THE NETWORK STATE / Maelstrom) published the design between 2022 and 2023, ran the EXORDIUM and the PILOT
mint, and shipped a Goerli alpha before disbanding. This repo builds the game they described, fully on-chain, on a
**hexagonal grid**, and makes it playable in the browser.

- **Rules and every number:** [`docs/RULES.md`](docs/RULES.md)
- **Original design posts:** [`docs/original/`](docs/original/) (whitepaper, EXORDIUM, tech tree, PILOT, WARLORD
  TECHNOCRACY, CITADEL OS, 0xCITADEL alpha) and a merged spec, [`GAME-SPEC.md`](docs/original/GAME-SPEC.md)

## What's in the game

- **Grid:** light CITADEL and PILOT to a hex grid. The golden core mines the most DRAKMA, and that's where the war is.
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

The client is **CITADEL OS**: a hex map with fog of war, panels for every action, the CITADEL DISPATCH news feed, and a
terminal (`raid 3 7 100`, `status 3`, `help`).

## Layout

| Path | What |
|---|---|
| `src/game/` | The game: `CitadelGame` (one address, all state) routes calls to `EconomyModule`, `WarModule`, `SiegeModule` and `ViewModule` by delegatecall (split only for the 24KB size limit) |
| `src/*.sol` | `CitadelNFT`, `PilotNFT`, `MentatNFT`, `Drakma`, `TechTree`, `Technocracy`, `SovereignCouncil`, `TestnetFaucet` |
| `src/lib/` | Trait tables and the tech tree (`Traits.sol`), hex math, trait rolls |
| `script/` | `Deploy.s.sol` (Sepolia), `DevDeploy.s.sol` (local world with 8 seeded players), `Stack.sol` (shared wiring), `pack_traits.py` |
| `test/` | Unit tests per system, plus `Playtest.t.sol`, a 30-day 8-player economic simulation |
| `web/` | CITADEL OS client (Vite + React + viem) |
| `keeper/` | Bot that resolves arrived marches and fights due siege waves |

## Play locally (five minutes)

Requires [Foundry](https://getfoundry.sh) (`mise install` picks up the pinned version) and Node ≥ 23.

```sh
git clone --recursive https://github.com/VRamxn/Citadel-Game-.git && cd Citadel-Game-
anvil &                                                          # local chain
forge script script/DevDeploy.s.sol --rpc-url local --broadcast  # deploy + seed 8 players
npm --prefix web install && npm --prefix web run dev             # http://localhost:5173
node keeper/keeper.ts &                                          # optional: auto-resolve marches and sieges
```

On the local chain the client signs with anvil's dev accounts: pick one at the top right (#9 starts fresh), and use
**+1h / +1d** to move time. Open **GUIDE** in the client for a walkthrough.

## Deploy to Sepolia

1. **Snapshot the mainnet CITADEL traits.** This is a one-time download, and the Pinata gateway rate-limits, so it
   takes a while:
   ```sh
   mkdir -p data/raw
   for i in $(seq 0 1023); do
     curl -sL "https://gateway.pinata.cloud/ipfs/QmXXC2PHUeiFtUFVdLNnYodWUNdZnK2jbT8prE6R51mGT6/$i" -o data/raw/$i.json
     sleep 0.5
   done
   python3 script/pack_traits.py   # -> data/citadel-traits.bin (commit it)
   ```
   If `data/citadel-traits.bin` is already in the repo, skip this step.
2. **Fund a deployer** with Sepolia ETH (the full deploy is ~60M gas), then import its key into Foundry's encrypted
   keystore:
   ```sh
   cast wallet import deployer --interactive
   export SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com ETHERSCAN_API_KEY=...
   ```
3. **Deploy:**
   ```sh
   forge script script/Deploy.s.sol --rpc-url sepolia --account deployer --broadcast --verify
   ```
   This writes `deployments/11155111.json`. Commit it: the client reads it to find the contracts.
4. **Publish the client:** the `pages` workflow builds `web/` to GitHub Pages on every push to `main` (enable Pages →
   "GitHub Actions" in the repo settings).
5. **Run a keeper** so raids and sieges settle on time. It earns the resolver fee:
   ```sh
   KEEPER_KEY=0x... RPC_URL=$SEPOLIA_RPC_URL node keeper/keeper.ts deployments/11155111.json
   ```

Give a mainnet holder their own CITADEL id on testnet with `TestnetFaucet.grantCitadel(address, id)`.

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
