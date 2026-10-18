# Launch: original NFTs on Ethereum, game on Base

CITADEL plays on **Base** (an OP Stack L2). The **original** CITADEL and PILOT never leave holders' control
unbridged: they sit in a vault on Ethereum while their copies play on Base, and anyone can bring theirs home.

| | Ethereum (L1) | Base (L2) |
|---|---|---|
| CITADEL GEN0 | original `0xaF08134eA12494dc3AAA7f1EFB23A8753B7F84c9` | copy, ids 0–1023, minted only by the bridge |
| PILOT GEN0 | original `0xD653B9f4ec70658402B9634E7E0eAFcc64138Cad` | copy, ids 0–2047, minted only by the bridge |
| GEN1+ CITADEL / PILOT | — | native, ids from 1024 / 2048, minted by the game |
| DRAKMA | old token, not used | **new** token; old balances carried over by claim |
| Contracts | `CitadelVaultL1`, `DrakmaClaimRelayL1` | the game, `CitadelBridgeL2`, `DrakmaClaim` |

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

## What carries over

**PILOT keep what was bought on mainnet** (`data/pilot-traits.json`):
- **LEVEL** (0–9, paid in old DRAKMA), read from the original contract's `levels(id)`: 111 PILOT were upleveled.
- **SOVEREIGNTY**: 118 sovereigns, read from `getSovereign(id)`. That's 56 RELIK-born (`data/born-sovereigns.json`)
  and 62 seats bought with old DRAKMA. Sovereigns keep their KULT, and `Technocracy.seedSovereigns` fills their seats
  at launch. The 10 empty seats (8 born, 2 bought) can be bought or won by overthrow.
- **Revealed SUBJUGATION and DEATH** from the original metadata. PILOT that were never revealed (metadata name
  "PILOT <id>") get them rolled from `keccak256("CITADEL PILOT", id)` with THE PILOT post's rarities. That's a public,
  fixed formula nobody can steer, and the same goes for KULT on non-sovereigns.

**CITADEL** traits come from the IPFS metadata snapshot (`data/citadel-traits.json`).

**DRAKMA** (`script/snapshot.mjs` → `data/claims.json`), at one Ethereum block:
- **Old balances, 1:1, for DRAKMA in people's wallets only.** That means EOAs (including EIP-7702 delegated
  accounts) and Safe multisigs. DRAKMA held by any other contract stays behind: the old EXORDIUM's undistributed
  rewards, the old PILOT contract's takings, pools.
- **Plus an equal flat share** (`flatPerWallet`, default 250,000 DK) for every such wallet that held old DRAKMA, an
  original CITADEL or an original PILOT. CITADEL still staked in the old EXORDIUM count for their staker.
- **Claiming:** a Merkle claim on Base (`DrakmaClaim.claim`). Safes and other L1-only wallets claim through
  `DrakmaClaimRelayL1.claimTo(l2Recipient, …)` on Ethereum.
- **Exclusions:** `data/snapshot-config.json` can remove specific wallets.

## Deploy order

```sh
# data
script/fetch_pilots.sh && node script/pack_pilots.mjs        # PILOT traits + sovereigns
node script/snapshot.mjs <block>                              # DRAKMA claims at a fixed block; note the root

# 1. Base: the game (TESTNET=false on mainnet)
CLAIM_ROOT=0x… TESTNET=false forge script script/DeployL2.s.sol --rpc-url base --account deployer --broadcast --verify
# 2. Ethereum: the vault and claim relay, pointed at step 1
L2_DEPLOYMENT=deployments/8453.json forge script script/DeployL1.s.sol --rpc-url mainnet --account deployer --broadcast --verify
# 3. Base: link the bridge and claim to step 2
L2_DEPLOYMENT=deployments/8453.json L1_DEPLOYMENT=deployments/1-l1.json \
  forge script script/LinkL2.s.sol --rpc-url base --account deployer --broadcast
# client: commit deployments/*.json and data/claims.json; `npm --prefix web run build` publishes the claim list
```

On **Sepolia ↔ Base Sepolia** the same scripts deploy stand-ins for the original collections on Sepolia, with a
faucet (2 CITADEL + 2 PILOT per address), plus a DRAKMA faucet on Base Sepolia. So the whole flow (deposit, play,
withdraw, prove, finalize) can be tested before mainnet. Locally, `script/DevDeploy.s.sol` runs both sides on one
anvil chain with a messenger that delivers instantly.
