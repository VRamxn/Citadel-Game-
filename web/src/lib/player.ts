import { parseAbiItem, type Address } from "viem";
import type { Chain_ } from "./chain";

export type PilotInfo = {
  id: bigint;
  generation: number;
  subjugation: number;
  kult: number;
  level: number;
  sovereign: boolean;
  death: boolean;
};
export type CitadelTraits = { generation: number; sekt: number; shield: number; engine: number; weapon: number; tech: number };
export type Player = {
  address: Address;
  dk: bigint;
  eth: bigint;
  score: bigint;
  level: bigint;
  walletCitadels: { id: bigint; traits: CitadelTraits; pilotClaimed: boolean }[];
  walletPilots: PilotInfo[];
  walletMentats: { id: bigint; level: number }[];
  dripped: boolean;
};

const transfer = parseAbiItem("event Transfer(address indexed from, address indexed to, uint256 indexed tokenId)");

type OwnedCache = { from: bigint; ids: Set<bigint> };
const ownedCache = new Map<string, OwnedCache>();
const traitCache = new Map<string, CitadelTraits>();

/** Token ids `who` received, scanned incrementally (only new blocks each call), then filtered by current ownerOf. */
async function owned(c: Chain_, token: "citadel" | "pilot" | "mentat", who: Address): Promise<bigint[]> {
  const key = `${c.dep.chainId}:${c.dep[token]}:${who}`.toLowerCase();
  const cache = ownedCache.get(key) ?? { from: BigInt(c.dep.block ?? 0), ids: new Set<bigint>() };
  const head = await c.pub.getBlockNumber();
  for (let s = cache.from; s <= head; s += 9_000n) {
    const e = s + 8_999n < head ? s + 8_999n : head;
    const logs = await c.pub.getLogs({ address: c.dep[token], event: transfer, args: { to: who }, fromBlock: s, toBlock: e });
    for (const l of logs) cache.ids.add(l.args.tokenId!);
  }
  cache.from = head + 1n;
  ownedCache.set(key, cache);
  const out: bigint[] = [];
  await Promise.all(
    [...cache.ids].map(async (id) => {
      try {
        const o = await c.read<Address>(token, "ownerOf", [id]);
        if (o.toLowerCase() === who.toLowerCase()) out.push(id);
      } catch {
        /* burned */
      }
    }),
  );
  return out.sort((a, b) => (a < b ? -1 : 1));
}

async function citadelTraits(c: Chain_, id: bigint): Promise<CitadelTraits> {
  const k = `${c.dep.chainId}:${id}`;
  if (!traitCache.has(k)) traitCache.set(k, (await c.read("citadel", "traitsOf", [id])) as CitadelTraits);
  return traitCache.get(k)!;
}

export async function pilotInfo(c: Chain_, id: bigint): Promise<PilotInfo> {
  const t = (await c.read("pilot", "traitsOf", [id])) as any;
  return { id, ...t };
}

export async function loadPlayer(c: Chain_, who: Address): Promise<Player> {
  const [dk, eth, score, level, cits, pils, ments, dripped] = await Promise.all([
    c.read<bigint>("drakma", "balanceOf", [who]),
    c.pub.getBalance({ address: who }),
    c.read<bigint>("game", "walletScore", [who]),
    c.read<bigint>("game", "walletLevel", [who]),
    owned(c, "citadel", who),
    owned(c, "pilot", who),
    owned(c, "mentat", who),
    c.read<boolean>("faucet", "dripped", [who]).catch(() => true),
  ]);
  const walletCitadels = await Promise.all(
    cits.map(async (id) => ({
      id,
      traits: await citadelTraits(c, id),
      pilotClaimed: id < 1024n ? await c.read<boolean>("technocracy", "citadelClaimedPilot", [id]) : true,
    })),
  );
  const walletPilots = await Promise.all(pils.map((id) => pilotInfo(c, id)));
  const walletMentats = await Promise.all(
    ments.map(async (id) => ({ id, level: Number(((await c.read("mentat", "traitsOf", [id])) as any).level) })),
  );
  return { address: who, dk, eth, score, level, walletCitadels, walletPilots, walletMentats, dripped };
}
