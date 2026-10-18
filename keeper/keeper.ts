// CITADEL keeper: resolves arrived marches and fights due siege waves, so raids never sit until they defect and sieges
// progress on time. Resolving a raid pays the keeper the resolver fee (10% of the loot), so anyone can run one.
//
//   KEEPER_KEY=0x... RPC_URL=https://... node keeper/keeper.ts [deployments/11155111.json]
//
// Uses viem from web/node_modules (run `npm --prefix web install` first). Node >= 23 runs TypeScript directly.
import { readFileSync } from "node:fs";
import { createPublicClient, createWalletClient, http, parseEventLogs, type Address, type Hex } from "../web/node_modules/viem/_esm/index.js";
import { privateKeyToAccount } from "../web/node_modules/viem/_esm/accounts/index.js";
import gameAbi from "../web/src/abi/game.ts";

const depPath = process.argv[2] ?? "deployments/31337.json";
const dep = JSON.parse(readFileSync(depPath, "utf8"));
const rpc = process.env.RPC_URL ?? (dep.chainId === 31337 ? "http://127.0.0.1:8545" : "https://ethereum-sepolia-rpc.publicnode.com");
const key = (process.env.KEEPER_KEY ??
  // anvil account #9 — local chain only
  (dep.chainId === 31337 ? "0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6" : undefined)) as Hex;
if (!key) throw new Error("set KEEPER_KEY");
const interval = Number(process.env.INTERVAL ?? (dep.chainId === 31337 ? 5 : 30)) * 1000;
const maxWaves = BigInt(process.env.MAX_WAVES ?? 24);

const chain = { id: dep.chainId, name: "citadel", nativeCurrency: { name: "ETH", symbol: "ETH", decimals: 18 }, rpcUrls: { default: { http: [rpc] } } } as const;
const pub = createPublicClient({ chain, transport: http(rpc) });
const account = privateKeyToAccount(key);
const wallet = createWalletClient({ account, chain, transport: http(rpc) });
const game = dep.game as Address;

const openMarches = new Set<bigint>();
const openSieges = new Set<bigint>();
let from = BigInt(dep.block ?? 0);

async function scan() {
  const head = await pub.getBlockNumber();
  for (let s = from; s <= head; s += 9_000n) {
    const e = s + 8_999n < head ? s + 8_999n : head;
    const logs = parseEventLogs({ abi: gameAbi as any, logs: await pub.getLogs({ address: game, fromBlock: s, toBlock: e }) }) as any[];
    for (const l of logs) {
      if (l.eventName === "MarchSent") openMarches.add(l.args.marchId);
      if (l.eventName === "SiegeStarted") openSieges.add(l.args.siegeId);
    }
  }
  from = head + 1n;
}

async function send(functionName: string, args: unknown[], label: string) {
  try {
    const call = { address: game, abi: gameAbi as any, functionName, args, account };
    const { request } = await pub.simulateContract(call);
    const gas = ((await pub.estimateContractGas(call)) * 13n) / 10n;
    const hash = await wallet.writeContract({ ...(request as any), gas });
    const r = await pub.waitForTransactionReceipt({ hash });
    console.log(new Date().toISOString(), label, r.status, hash);
  } catch (e: any) {
    console.log(new Date().toISOString(), label, "skipped:", e.shortMessage ?? e.message);
  }
}

async function tick() {
  await scan();
  const now = (await pub.getBlock()).timestamp;
  const cfg = (await pub.readContract({ address: game, abi: gameAbi as any, functionName: "getConfig" })) as any;
  for (const id of [...openMarches]) {
    const m = (await pub.readContract({ address: game, abi: gameAbi as any, functionName: "march", args: [id] })) as any;
    if (m.done) openMarches.delete(id);
    else if (m.arriveAt <= now) await send("resolve", [id], `resolve march ${id}`);
  }
  for (const id of [...openSieges]) {
    const g = (await pub.readContract({ address: game, abi: gameAbi as any, functionName: "siegeOf", args: [id] })) as any;
    if (!g.active) {
      openSieges.delete(id);
      continue;
    }
    const due = (now - g.start) / BigInt(cfg.siegeWaveSecs);
    if (due > BigInt(g.waves)) await send("advanceSiege", [id, maxWaves], `advance siege ${id} (${due - BigInt(g.waves)} due)`);
  }
}

console.log(`keeper ${account.address} on chain ${dep.chainId}, game ${game}, every ${interval / 1000}s`);
for (;;) {
  await tick().catch((e) => console.error("tick failed:", e.shortMessage ?? e.message));
  await new Promise((r) => setTimeout(r, interval));
}
