import { parseEventLogs, type Address, type Log } from "viem";
import { abis, type Chain_ } from "./chain";
import { FACTIONS, FLEET_SHORT, MARCH_KIND, BUILDINGS, hexKey } from "./game";

export type Citadel = {
  id: bigint;
  owner: Address;
  lit: boolean;
  doomRiot: boolean;
  ao: number;
  q: number;
  r: number;
  faction: number;
  research: number;
  generation: number;
  sekt: number;
  shield: number;
  engine: number;
  weapon: number;
  tech: number;
  lastSync: bigint;
  lastClaim: bigint;
  pilotOff: number;
  pilotDef: number;
  pilotMine: number;
  pilotHermetic: number;
  pilotScout: number;
  pilotResearch: number;
  incoming: number;
  outgoing: number;
  besieged: number;
  vault: bigint;
  mentat: bigint;
  levels: readonly number[];
};

export type March = {
  id: bigint;
  kind: number;
  done: boolean;
  arriveAt: bigint;
  origin: bigint;
  target: bigint;
  units: readonly bigint[];
  loot: bigint;
  sender: Address;
  pilot: bigint;
  sentAt: number; // block time the march was sent (for drawing progress)
};

export type Siege = {
  id: bigint;
  active: boolean;
  attacker: Address;
  faction: number;
  origin: bigint;
  target: bigint;
  pilot: bigint;
  start: bigint;
  waves: number;
  progress: number;
  units: readonly bigint[];
};

export type ScoutReport = { at: number; garrison: readonly bigint[]; vault: bigint; levels: readonly number[] };
export type Dispatch = { block: bigint; text: string; tone: "war" | "siege" | "politics" | "grid" };

export type World = {
  ready: boolean;
  block: bigint;
  now: number;
  radius: number;
  config: any;
  fleetTypes: any[];
  citadels: Map<bigint, Citadel>;
  byTile: Map<string, bigint>; // AO 0 only, for the map
  marches: Map<bigint, March>;
  sieges: Map<bigint, Siege>;
  techBits: bigint[];
  scouted: Map<bigint, ScoutReport>; // by target, reports by any of the player's CITADEL
  dispatch: Dispatch[];
};

export const emptyWorld = (): World => ({
  ready: false,
  block: 0n,
  now: 0,
  radius: 12,
  config: undefined,
  fleetTypes: [],
  citadels: new Map(),
  byTile: new Map(),
  marches: new Map(),
  sieges: new Map(),
  techBits: [0n, 0n, 0n, 0n],
  scouted: new Map(),
  dispatch: [],
});

const LOG_CHUNK = 9_000n;

/** Keeps a World in sync with the chain by reading new game events and re-reading what they touched. */
export class WorldSync {
  w: World = emptyWorld();
  private from: bigint;
  private sentAt = new Map<bigint, number>();
  private blockTimes = new Map<bigint, number>();

  constructor(private chain: Chain_) {
    this.from = BigInt(chain.dep.block ?? 0);
  }

  async tick(player?: Address): Promise<World> {
    const c = this.chain;
    const head = await c.pub.getBlock();
    const touched = new Set<bigint>();
    const marchIds = new Set<bigint>();
    const siegeIds = new Set<bigint>();

    if (!this.w.ready) {
      const [radius, config, ...fleet] = await Promise.all([
        c.read<number>("game", "radius"),
        c.read("game", "getConfig"),
        ...[0, 1, 2, 3].map((t) => c.read("game", "fleetTypes", [t])),
      ]);
      this.w.radius = Number(radius);
      this.w.config = config;
      this.w.fleetTypes = fleet.map((f: any) => ({
        op: Number(f[0]),
        dp: Number(f[1]),
        carry: Number(f[2]),
        secsPerTile: Number(f[3]),
        trainSecs: Number(f[4]),
        academy: Number(f[5]),
        cost: f[6] as bigint,
      }));
    }

    // ---- new events
    const logs: Log[] = [];
    for (let start = this.from; start <= head.number!; start += LOG_CHUNK) {
      const end = start + LOG_CHUNK - 1n < head.number! ? start + LOG_CHUNK - 1n : head.number!;
      logs.push(...(await c.pub.getLogs({ address: [c.dep.game, c.dep.technocracy], fromBlock: start, toBlock: end })));
    }
    this.from = head.number! + 1n;
    const events = [
      ...parseEventLogs({ abi: abis.game as any, logs: logs.filter((l) => l.address.toLowerCase() === c.dep.game.toLowerCase()) }),
      ...parseEventLogs({ abi: abis.technocracy as any, logs: logs.filter((l) => l.address.toLowerCase() === c.dep.technocracy.toLowerCase()) }),
    ] as any[];
    await this.loadBlockTimes(events.map((e) => e.blockNumber as bigint));

    for (const e of events) {
      const a = e.args ?? {};
      for (const k of ["citadelId", "attacker", "defender", "origin", "target", "scout"])
        if (typeof a[k] === "bigint" && !(k === "target" && e.eventName === "MarchSent" && a.kind === 6)) touched.add(a[k]);
      if (e.eventName === "MarchSent") {
        marchIds.add(a.marchId);
        this.sentAt.set(a.marchId, this.blockTimes.get(e.blockNumber) ?? Number(head.timestamp));
      }
      if (["MarchCompleted", "MarchLost", "RaidResolved", "Defected", "Reinforced", "ScoutReport"].includes(e.eventName) && a.marchId)
        marchIds.add(a.marchId);
      if (["SiegeStarted", "SiegeWave", "SiegeEnded", "SiegeJoined"].includes(e.eventName)) siegeIds.add(a.siegeId);
      if (e.eventName === "ScoutReport" && a.success && player && this.w.citadels.get(a.scout)?.owner === player)
        this.w.scouted.set(a.target, {
          at: this.blockTimes.get(e.blockNumber) ?? 0,
          garrison: a.garrison,
          vault: a.vault,
          levels: a.levels,
        });
      const line = this.describe(e);
      if (line) this.w.dispatch.unshift({ block: e.blockNumber, text: line[0], tone: line[1] });
    }
    this.w.dispatch = this.w.dispatch.slice(0, 300);

    // ---- re-read what changed (everything on the first load)
    const ids = this.w.ready ? touched : new Set([...touched, ...this.w.citadels.keys()]);
    for (const id of this.w.citadels.keys()) if (!this.w.ready) ids.add(id);
    await Promise.all(
      [...ids].map(async (id) => {
        const s = (await c.read("game", "citadel", [id])) as any;
        const prev = this.w.citadels.get(id);
        if (prev && prev.ao === 0) this.w.byTile.delete(hexKey(prev.q, prev.r));
        if (!s.lit) {
          this.w.citadels.delete(id);
          return;
        }
        const cit: Citadel = { ...s, id, levels: [...s.levels] };
        this.w.citadels.set(id, cit);
        if (cit.ao === 0) this.w.byTile.set(hexKey(cit.q, cit.r), id);
      }),
    );
    // marches: re-read new/changed and every still-open one whose arrival has passed
    for (const [id, m] of this.w.marches) if (!m.done && Number(m.arriveAt) <= Number(head.timestamp) + 5) marchIds.add(id);
    await Promise.all(
      [...marchIds].map(async (id) => {
        const m = (await c.read("game", "march", [id])) as any;
        if (m.done) this.w.marches.delete(id);
        else this.w.marches.set(id, { ...m, id, sentAt: this.sentAt.get(id) ?? Number(head.timestamp) });
      }),
    );
    for (const [id] of this.w.sieges) siegeIds.add(id);
    await Promise.all(
      [...siegeIds].map(async (id) => {
        const g = (await c.read("game", "siegeOf", [id])) as any;
        if (!g.active) this.w.sieges.delete(id);
        else this.w.sieges.set(id, { ...g, id, waves: Number(g.waves), progress: Number(g.progress) });
      }),
    );
    this.w.techBits = await Promise.all([0, 1, 2, 3].map((f) => c.read<bigint>("techTree", "bits", [f])));

    this.w.block = head.number!;
    this.w.now = Number(head.timestamp);
    this.w.ready = true;
    // fresh containers so React memos keyed on them recompute
    return {
      ...this.w,
      citadels: new Map(this.w.citadels),
      byTile: new Map(this.w.byTile),
      marches: new Map(this.w.marches),
      sieges: new Map(this.w.sieges),
      scouted: new Map(this.w.scouted),
      dispatch: [...this.w.dispatch],
    };
  }

  private async loadBlockTimes(blocks: bigint[]) {
    const need = [...new Set(blocks)].filter((b) => !this.blockTimes.has(b)).slice(-200);
    await Promise.all(
      need.map(async (b) => {
        const blk = await this.chain.pub.getBlock({ blockNumber: b });
        this.blockTimes.set(b, Number(blk.timestamp));
      }),
    );
  }

  blockTime(b: bigint) {
    return this.blockTimes.get(b);
  }

  private name(id: bigint) {
    const c = this.w.citadels.get(id);
    return c ? `CITADEL ${id} [${FACTIONS[c.faction]}]` : `CITADEL ${id}`;
  }

  private describe(e: any): [string, Dispatch["tone"]] | undefined {
    const a = e.args ?? {};
    const u = (units: readonly bigint[]) =>
      units
        .map((n, i) => (n > 0n ? `${n} ${FLEET_SHORT[i]}` : ""))
        .filter(Boolean)
        .join(", ") || "nothing";
    switch (e.eventName) {
      case "Lit":
        return [`${this.name(a.citadelId)} lit to the grid at (${a.q}, ${a.r}) for the ${FACTIONS[a.faction]}.`, "grid"];
      case "Unlit":
        return [`CITADEL ${a.citadelId} went dark.`, "grid"];
      case "Leveled":
        return [`CITADEL ${a.citadelId} was LEVELED${a.destroyed ? " and destroyed" : ""}.`, "siege"];
      case "Colonized":
        return [`A PILOT founded CITADEL ${a.citadelId}.`, "grid"];
      case "RaidResolved":
        return [
          `${this.name(a.attacker)} raided ${this.name(a.defender)}: ${a.attackerWon ? "VICTORY" : "REPELLED"}. ` +
            `Lost ${u(a.attackerLost)} / killed ${u(a.defenderLost)}. Loot ${(Number(a.loot / 10n ** 18n)).toLocaleString()} DK.`,
          "war",
        ];
      case "Defected":
        return [`An unresolved raid from ${this.name(a.attacker)} DEFECTED to ${this.name(a.defender)}.`, "war"];
      case "ScoutReport":
        return [`DALAA MAX from CITADEL ${a.scout} ${a.success ? "returned intelligence on" : "were shot down over"} CITADEL ${a.target}.`, "war"];
      case "MarchSent":
        return a.kind === 2 ? undefined : [`${MARCH_KIND[a.kind]} launched from CITADEL ${a.origin} → ${a.kind === 6 ? `siege ${a.target}` : `CITADEL ${a.target}`}: ${u(a.units)}.`, "war"];
      case "SiegeStarted":
        return [`SIEGE! CITADEL ${a.attacker} has encircled ${this.name(a.target)}${a.pilot > 0n ? `, led by PILOT ${a.pilot - 1n}` : ""}.`, "siege"];
      case "SiegeEnded":
        return [`Siege ${a.siegeId} ${a.success ? `SUCCEEDED${a.newCitadel > 0n ? ` — CITADEL ${a.newCitadel} rises from the ruins` : ""}` : "FAILED"}.`, "siege"];
      case "BuildCompleted":
        return undefined;
      case "PilotMinted":
        return [`CITADEL ${a.citadelId} spent ${a.fleetPointsSpent} FLEET POINTS on a GEN${a.generation} PILOT.`, "grid"];
      case "SovereignSeated":
        return [`PILOT ${a.pilotId} bought a seat in the SOVEREIGN COLLECTIVE.`, "politics"];
      case "Overthrown":
        return [`INSURGENCY: PILOT ${a.insurgentId} overthrew sovereign ${a.sovereignId}.`, "politics"];
      case "Bribed":
        return [`Sovereign ${a.pilotId} bribed a KULT (${a.activeBribes} active).`, "politics"];
      case "PilotClaimed":
        return [`CITADEL ${a.citadelId} claimed PILOT ${a.pilotId}${a.sovereign ? ", born SOVEREIGN" : ""}.`, "politics"];
      case "BuildStarted":
        return undefined;
      default:
        return undefined;
    }
  }
}

export { BUILDINGS };
