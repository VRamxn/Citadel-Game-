# CITADEL

An open-source, community continuation of **CITADEL**, the dystopian post-human war game on Ethereum. The original
team (THE NETWORK STATE / Maelstrom) published the design between 2022 and 2023, ran the EXORDIUM and the PILOT
mint, and shipped a Goerli alpha before disbanding. This repo builds the game they described, fully on-chain,
on a **hexagonal grid**.

- Ruleset and formulas: [`docs/RULES.md`](docs/RULES.md)
- Original design posts (whitepaper, EXORDIUM, PILOT, WARLORD TECHNOCRACY, alpha): [`docs/original/`](docs/original/)

## Status: v0.1, testnet

Implements the 0xCITADEL alpha ruleset: lite CITADEL + PILOT to the grid, mine DRAKMA, train fleet,
raid (instant against neighbors, travelling otherwise), reinforce, claim. Siege, sovereignty and the tech tree
are next. See the roadmap in `docs/RULES.md`.

| Contract | What it is |
|---|---|
| `CitadelGame` | The game. Hex grid, mining, training, raids, marches |
| `CitadelNFT` | Testnet CITADEL #0–1023 with the **real mainnet traits** loaded on-chain |
| `PilotNFT` | Testnet PILOT with on-chain SUBJUGATION / KULT / LEVEL; uplevel for 100k×level DK |
| `Drakma` | DK, capped at 10B |
| `TestnetFaucet` | One-time starter kit per address: 2 CITADEL, 2 PILOT, 5M DK |

## Develop

Requires [Foundry](https://getfoundry.sh) (`mise install` picks up the pinned version).

```sh
forge build
forge test
```

## Deploy to Sepolia

1. Snapshot the mainnet CITADEL traits (one-time; the Pinata gateway rate-limits, so this takes a while):
   ```sh
   mkdir -p data/raw
   for i in $(seq 0 1023); do
     curl -sL "https://gateway.pinata.cloud/ipfs/QmXXC2PHUeiFtUFVdLNnYodWUNdZnK2jbT8prE6R51mGT6/$i" -o data/raw/$i.json
     sleep 0.5
   done
   python3 script/pack_traits.py   # -> data/citadel-traits.bin
   ```
2. Fund a deployer with Sepolia ETH (about 0.05 ETH covers the ~47M gas deploy), then import its key into
   Foundry's encrypted keystore so it never sits in a file:
   ```sh
   cast wallet import deployer --interactive
   cp .env.example .env   # add an Etherscan key to verify
   source .env
   ```
3. Deploy:
   ```sh
   forge script script/Deploy.s.sol --rpc-url sepolia --account deployer --broadcast --verify
   ```
   Addresses are written to `deployments/11155111.json`.

Give a mainnet holder their own CITADEL id on testnet with `TestnetFaucet.grantCitadel(address, id)`.

## Playing from the command line (until the hex UI exists)

```sh
cast send $FAUCET "drip()" --account me
cast send $CITADEL "setApprovalForAll(address,bool)" $GAME true --account me
cast send $PILOT   "setApprovalForAll(address,bool)" $GAME true --account me
cast send $GAME "lite(uint256,int16,int16,uint8,uint256[])" <citadelId> <q> <r> <faction 0-3> "[<pilotId>]" --account me
cast send $GAME "train(uint256,uint8,uint64)" <citadelId> 0 100 --account me     # 100 SIF GATTACA
cast send $GAME "raid(uint256,uint256,uint64[3])" <from> <to> "[100,0,0]" --account me
cast call $GAME "vaultOf(uint256)(uint256)" <citadelId>
```

## License

Code: MIT (see LICENSE). CITADEL art, names and lore were created by the original team. NFT holders hold commercial rights to
their own NFTs, per the original terms.
