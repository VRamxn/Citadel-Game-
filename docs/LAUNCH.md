# Launch: original NFTs on Ethereum, game on Base

CITADEL plays on **Base** (an OP Stack L2). The **original** CITADEL and PILOT stay in holders' hands: they sit in a
vault on Ethereum while their copies play on Base, and anyone can bring theirs home. Everything that can be decided by
a contract is: what a PILOT bought on mainnet is read on-chain at the moment it crosses, sovereigns take their seats
themselves, missing KULT are rolled by the contract, traits are locked once loaded, sieges pay whoever fights them,
and the treasury and every lever end up with the sovereigns' council.

| | Ethereum (L1) | Base (L2) |
|---|---|---|
| CITADEL GEN0 | original `0xaF08134eA12494dc3AAA7f1EFB23A8753B7F84c9` | copy, ids 0–1023, minted only by the bridge |
| PILOT GEN0 | original `0xD653B9f4ec70658402B9634E7E0eAFcc64138Cad` | copy, ids 0–2047, minted only by the bridge |
| GEN1+ CITADEL / PILOT | — | native, ids from 1024 / 2048, minted by the game |
| DRAKMA | old token, not used | **new** token: carry-over claim + council treasury + mining |
| Contracts | `CitadelVaultL1`, `DrakmaClaimRelayL1` | the game, `CitadelBridgeL2`, `DrakmaClaim`, `SovereignCouncil` |

## The bridge

- **Messenger:** OP Stack's canonical `CrossDomainMessenger`, with no third party in the path.
  - On Ethereum: `0x866E82a600A1414e583f7F13623F1aC5d58b0Afa` (Base) or `0xC34855F4De64F1840e5686e64278da901e261f20`
    (Base Sepolia).
  - On L2: the `0x4200…0007` predeploy.
- **In:** `vault.deposit(collection, ids, to)` locks originals on L1. A few minutes later the L2 bridge mints the same
  ids to `to` on Base.
- **Home:** `bridge.withdraw(collection, ids, to)` burns the copies on Base. The withdrawal is proven on L1 (about an
  hour later) and finalized after the challenge period (7 days), which releases the originals from the vault. The
  client's BRIDGE tab walks through prove and finalize.
- **No admin keys:** after `setL2Bridge` / `setL1Vault` both sides renounce ownership. Nobody can mint copies or
  release originals except through a deposit or withdrawal message.
- **Lit copies stay put:** a copy lit to the grid is held by the game. It has to be unlit before it can go home.

## PILOT: what they bought arrives with them, on-chain

When a PILOT is deposited, the vault reads the **original PILOT contract** on L1 and puts its record in the bridge
message. Nothing is copied by hand, and no admin can change it:

- **LEVEL** from `levels(id)`: 111 PILOT were upleveled on mainnet, six of them to level 9.
- **SOVEREIGNTY** from `getSovereign(id)` (which returns `isSovereign, chargeCount, kult`). There are 118 mainnet
  sovereigns: 56 born to RELIK and 62 seats bought with old DRAKMA. A sovereign **takes its seat in the collective the
  moment it arrives** (`Technocracy.seatArrival`, callable only by the bridge).
- **KULT** of a sovereign that bribed one (`chargeCount > 0`). Every other PILOT's KULT is rolled by `PilotNFT` itself
  from `keccak256("CITADEL PILOT", id)` with THE PILOT post's rarities (`rolledKult(id)` is a public view).
- **Seats for sale:** the original contract's `sovereignCounter` (seats sold on mainnet) travels with each deposit and
  counts against the 64 for sale, so mainnet buyers and new buyers share the same 64.

The record is applied on a PILOT's **first** arrival. After that its L2 state is its own (levels bought, seats won or
lost by overthrow) and it survives round trips.

SUBJUGATION and DEATH exist only in the original IPFS metadata, not on any chain. So they are loaded once from the
snapshot (`data/pilot-traits.bin`) and then **locked forever** (`lockTraits()`). Every PILOT is revealed there:
HERMETIC STRACHT + VOID is just the most common combination, about half the supply, as the rarities predict. 33 PILOT
are DEATH ("ETERNAL"). CITADEL traits are loaded from their metadata snapshot (`data/citadel-traits.bin`) and locked
the same way.

## DRAKMA

**Carry-over** (`DrakmaClaim` on Base; root built by `script/snapshot.mjs` → `data/claims.json`):
- **Old balances in people's wallets** (EOAs, including EIP-7702 delegated accounts, and Safe multisigs) carry over
  1:1, **up to 50M per wallet** (`maxCarryOver`). DRAKMA held by any other contract stays behind: the old EXORDIUM's
  undistributed rewards, the old PILOT contract's takings, pools.
- **Plus an equal flat share of 250,000 DK** for every such wallet that held old DRAKMA, an original CITADEL or an
  original PILOT. CITADEL still staked in the old EXORDIUM count for their staker.
- **The terms are on-chain:** `DrakmaClaim` stores `root`, `snapshotBlock`, `maxCarryOver` and `flatPerWallet`, and
  the script is in the repo. Anyone can rebuild the root from Ethereum at that block and check it.
- **Why not read balances live:** a Merkle snapshot is the one part that can't be a live on-chain read. Live reads
  would let anyone split old DRAKMA across wallets after the fact to slip under the cap.
- **Claiming:** Safes and other L1-only wallets claim through `DrakmaClaimRelayL1.claimTo(l2Recipient, …)` on
  Ethereum, which proves who they are through the rollup messenger.

**Community treasury:** 1,000,000,000 DK is minted to the GRID MAELSTROM council at deploy
(`COUNCIL_DK`). The deployer's minter role is granted and renounced in the same step. The council also receives the
game's fee share (25–30% of every sovereign seat, overthrow and bribe). It replaces the whitepaper's share "withheld by
the development team", and it moves only by sovereign vote: a proposal that calls `drakma.transfer`.

**Supply** (preview at the latest block, before the launch snapshot): about 2.8B carried over + 1B council treasury,
which leaves about 6.2B of the 10B cap for players to mine, loot and win over the game's life. Most game actions burn
DRAKMA, which frees cap again.

## Keeping the war moving

Anyone can settle the game's clocks, and the contracts pay for it:
- **Raids:** resolving an arrived raid pays 10% of its loot.
- **Sieges:** fighting due siege waves pays 250 DK per wave (`waveBounty`, a lever).
- **The keeper:** `keeper/keeper.ts` is a reference bot, but nothing depends on it running.

## Governance: hand it to the sovereigns

`script/HandToCouncil.s.sol` gives every remaining admin power to the council:
- TechTree and Technocracy ownership.
- `DEFAULT_ADMIN_ROLE` on DRAKMA, CITADEL, PILOT and MENTAT (the deployer renounces it).
- The game's ownership, which the council accepts with a proposal calling `acceptOwnership()`.

From then on every lever (rules, fleet stats, hotspots, seasons, module upgrades) changes only by sovereign vote.

## Deploy order

```sh
# data (already in the repo; re-run to rebuild)
script/fetch_pilots.sh && node script/pack_pilots.mjs             # PILOT metadata traits
RPC_URL=<archive RPC> node script/snapshot.mjs <block>            # DRAKMA carry-over at a fixed block

# 1. Base: the game (reads data/claims.json; loads and locks traits; funds the council)
TESTNET=false forge script script/DeployL2.s.sol --rpc-url base --account deployer --broadcast --verify
# 2. Ethereum: the vault and claim relay, pointed at step 1
L2_DEPLOYMENT=deployments/8453.json forge script script/DeployL1.s.sol --rpc-url mainnet --account deployer --broadcast --verify
# 3. Base: link the bridge and claim to step 2
L2_DEPLOYMENT=deployments/8453.json L1_DEPLOYMENT=deployments/1-l1.json \
  forge script script/LinkL2.s.sol --rpc-url base --account deployer --broadcast
# 4. when balancing is done: hand everything to the council
L2_DEPLOYMENT=deployments/8453.json forge script script/HandToCouncil.s.sol --rpc-url base --account deployer --broadcast
# client: commit deployments/*.json and data/claims.json; `npm --prefix web run build` publishes the claim list
```

On **Sepolia ↔ Base Sepolia** the same scripts deploy stand-ins for the original collections on Sepolia (the PILOT
stand-in has the same on-chain record functions), with a faucet (2 CITADEL + 2 PILOT per address), plus a DRAKMA
faucet on Base Sepolia. So the whole flow (deposit, play, withdraw, prove, finalize) can be tested before mainnet.
Locally, `script/DevDeploy.s.sol` runs both sides on one anvil chain, with a messenger that delivers instantly and the
first 140 PILOT mirroring their mainnet records.
