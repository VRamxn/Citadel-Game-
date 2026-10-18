// Builds the DRAKMA carry-over claim at one Ethereum block: the old DRAKMA in people's wallets 1:1 (EOAs and Safe
// multisigs; DRAKMA held by any other contract stays behind), plus an equal flat share for every such wallet that held
// old DRAKMA, an original CITADEL or an original PILOT.
//   node script/snapshot.mjs [block]   (default: latest)   RPC_URL=... to override the mainnet RPC
// Writes data/claims.json: { block, root, flatPerWallet, wallets, total, claims: { address: { amount, proof } } }.
// Leaves are OpenZeppelin standard Merkle leaves of (address, uint256), as DrakmaClaim verifies.
import { readFileSync, writeFileSync } from "node:fs";
import { createPublicClient, http, keccak256, encodeAbiParameters, concat, parseAbi, getAddress } from "../web/node_modules/viem/_esm/index.js";
import { mainnet } from "../web/node_modules/viem/_esm/chains/index.js";

const DK = "0x927ce35c89ab901eEfBC0675336Ae4A31e658B0e";
const CITADEL = "0xaF08134eA12494dC3AAA7f1EFB23A8753B7F84c9";
const PILOT = "0xD653B9f4ec70658402B9634E7E0eAFcc64138Cad";
const EXORDIUM = "0xFBF5a1F788E5F107D25Fc0824ed5E105b90fE027";
const abi = parseAbi([
  "function balanceOf(address) view returns (uint256)",
  "function ownerOf(uint256) view returns (address)",
  "function totalSupply() view returns (uint256)",
  "function getCitadelStaker(uint256) view returns (address)",
  "function getThreshold() view returns (uint256)",
]);
const RPCS = process.env.RPC_URL
  ? [process.env.RPC_URL]
  : ["https://ethereum-rpc.publicnode.com", "https://eth.drpc.org", "https://1rpc.io/eth", "https://eth.llamarpc.com"];
const clients = RPCS.map((u) => createPublicClient({ chain: mainnet, transport: http(u, { batch: { batchSize: 10, wait: 50 }, retryCount: 2 }) }));
let turn = 0;
// public RPCs rate-limit: spread calls across several and retry with backoff
async function withRetry(fn) {
  for (let attempt = 0; ; attempt++) {
    const c = clients[turn++ % clients.length];
    try {
      return await fn(c);
    } catch (e) {
      // a revert is a real answer (e.g. "not a Safe"); anything else is the network, so try again
      if (/revert/i.test(e.shortMessage ?? e.message ?? "") || attempt >= 12) throw e;
      await new Promise((r) => setTimeout(r, 500 * (attempt + 1)));
    }
  }
}
const client = clients[0];
const config = JSON.parse(readFileSync("data/snapshot-config.json", "utf8"));
const excluded = new Set(Object.keys(config.exclude).map((a) => a.toLowerCase()));
const block = process.argv[2] ? BigInt(process.argv[2]) : await client.getBlockNumber();
const read = (address, functionName, args = []) =>
  withRetry((c) => c.readContract({ address, abi, functionName, args, blockNumber: block }));
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function inBatches(items, fn, size = 20) {
  const out = [];
  for (let i = 0; i < items.length; i += size) {
    out.push(...(await Promise.all(items.slice(i, i + size).map(fn))));
    await sleep(150);
  }
  return out;
}

// old DRAKMA holders: candidate list from Blockscout, balances read at the snapshot block
async function dkHolders() {
  const out = [];
  let params = "";
  for (;;) {
    const res = await fetch(`https://eth.blockscout.com/api/v2/tokens/${DK}/holders${params}`, { headers: { "user-agent": "curl/8" } });
    const d = await res.json();
    out.push(...d.items.map((i) => i.address.hash));
    if (!d.next_page_params) return out;
    params = "?" + new URLSearchParams(d.next_page_params).toString();
    await sleep(300);
  }
}

console.log(`snapshot at block ${block}`);
const balances = new Map();
const candidates = await dkHolders();
const bals = await inBatches(candidates, (a) => read(DK, "balanceOf", [a]));
candidates.forEach((a, i) => bals[i] > 0n && balances.set(a.toLowerCase(), bals[i]));
console.log(`old DRAKMA: ${balances.size} holders`);

const wallets = new Set(balances.keys());
const citadelOwners = await inBatches([...Array(1024).keys()], async (id) => {
  const o = await read(CITADEL, "ownerOf", [BigInt(id)]);
  return o.toLowerCase() === EXORDIUM.toLowerCase() ? read(EXORDIUM, "getCitadelStaker", [BigInt(id)]) : o;
});
const pilotSupply = Number(await read(PILOT, "totalSupply"));
const pilotOwners = await inBatches([...Array(pilotSupply).keys()], (id) => read(PILOT, "ownerOf", [BigInt(id)]));
for (const o of [...citadelOwners, ...pilotOwners]) wallets.add(o.toLowerCase());
console.log(`NFT holders: ${new Set(citadelOwners.map((a) => a.toLowerCase())).size} CITADEL, ${new Set(pilotOwners.map((a) => a.toLowerCase())).size} PILOT`);

// people's wallets only: EOAs (incl. EIP-7702 delegated code 0xef0100...) and Safe multisigs; other contracts are out
const kind = new Map();
await inBatches([...wallets], async (w) => {
  const code = await withRetry((c) => c.getCode({ address: w, blockNumber: block }));
  if (!code || code === "0x" || code.startsWith("0xef0100")) return kind.set(w, "wallet");
  // a Safe answers getThreshold(); any other contract reverts or returns nothing
  try {
    await read(w, "getThreshold");
    kind.set(w, "safe");
  } catch {
    kind.set(w, "contract");
  }
});
const flat = BigInt(config.flatPerWallet) * 10n ** 18n;
const claims = [];
const leftOut = [];
for (const w of wallets) {
  if (excluded.has(w) || kind.get(w) === "contract") {
    if (balances.get(w)) leftOut.push([w, balances.get(w), config.exclude[getAddress(w)] ?? "contract"]);
    continue;
  }
  claims.push([getAddress(w), (balances.get(w) ?? 0n) + flat]);
}
claims.sort((a, b) => (a[0].toLowerCase() < b[0].toLowerCase() ? -1 : 1));

// OpenZeppelin StandardMerkleTree: leaf = keccak(keccak(abi.encode(address, uint256))), sorted pairs
const leaf = ([a, v]) => keccak256(keccak256(encodeAbiParameters([{ type: "address" }, { type: "uint256" }], [a, v])));
const hashPair = (x, y) => keccak256(concat(BigInt(x) < BigInt(y) ? [x, y] : [y, x]));
let level = claims.map(leaf);
const layers = [level];
while (level.length > 1) {
  const next = [];
  for (let i = 0; i < level.length; i += 2) next.push(i + 1 < level.length ? hashPair(level[i], level[i + 1]) : level[i]);
  layers.push((level = next));
}
const root = level[0];
const proofOf = (index) => {
  const proof = [];
  for (let l = 0; l < layers.length - 1; l++) {
    const sib = index ^ 1;
    if (sib < layers[l].length) proof.push(layers[l][sib]);
    index >>= 1;
  }
  return proof;
};
const total = claims.reduce((s, [, v]) => s + v, 0n);
const out = { block: block.toString(), root, flatPerWallet: config.flatPerWallet, wallets: claims.length, total: total.toString(), claims: {} };
claims.forEach(([a, v], i) => (out.claims[a] = { amount: v.toString(), proof: proofOf(i) }));
writeFileSync("data/claims.json", JSON.stringify(out, null, 1));
console.log(`root ${root}\n${claims.length} wallets, ${(Number(total / 10n ** 18n)).toLocaleString()} DRAKMA claimable (cap 10B)`);
const dk = (v) => Number(v / 10n ** 18n).toLocaleString();
console.log(`left out (not people's wallets): ${leftOut.length}, ${dk(leftOut.reduce((s, [, b]) => s + b, 0n))} DK`);
for (const [a, b, why] of leftOut.sort((x, y) => (y[1] > x[1] ? 1 : -1)).slice(0, 8)) console.log(`  ${a} ${dk(b)} DK (${why})`);
console.log("largest claims:");
for (const [a, v] of [...claims].sort((x, y) => (y[1] > x[1] ? 1 : -1)).slice(0, 8)) console.log(`  ${a} ${dk(v)} DK (${kind.get(a.toLowerCase())})`);
