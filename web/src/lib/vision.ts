import { useMemo, useRef } from "react";
import { useGame } from "../App";
import { SURVEILLANCE_STATE, hasTech, hexesWithin, tileKey } from "./game";
import type { Citadel } from "./world";

/** Fog of war: what the player's factions can see — 2 tiles around each of their CITADEL, +1 with SURVEILLANCE STATE,
 * +2 around a CITADEL hosting a MENTAT — plus anything their DALAA MAX scouted in the last 24h. The chain is public;
 * this is the client honouring the whitepaper's vision rules, not secrecy. */
export function useVision() {
  const { world, me, fog } = useGame();
  const last = useRef<Set<string> | null>(null);
  return useMemo(() => {
    const mine = [...world.citadels.values()].filter((c) => c.owner === me);
    const factions = new Set(mine.map((c) => c.faction));
    if (!fog || factions.size === 0) return { tiles: null as Set<string> | null, seen: (_: Citadel) => true };
    const tiles = new Set<string>();
    for (const c of world.citadels.values()) {
      if (!factions.has(c.faction)) continue;
      const r = 2 + (hasTech(world.techBits[c.faction] ?? 0n, SURVEILLANCE_STATE) ? 1 : 0) + (c.mentat > 0n ? 2 : 0);
      for (const t of hexesWithin(r)) tiles.add(tileKey(c.ao, c.q + t.q, c.r + t.r));
    }
    // keep the previous Set when nothing changed, so the terrain doesn't redraw on every world refresh
    const prev = last.current;
    const same = prev && prev.size === tiles.size && [...tiles].every((k) => prev.has(k));
    if (!same) last.current = tiles;
    const stable = last.current!;
    const seen = (c: Citadel) =>
      stable.has(tileKey(c.ao, c.q, c.r)) || (world.scouted.get(c.id)?.at ?? 0) > world.now - 86400;
    return { tiles: stable, seen };
  }, [world.citadels, world.techBits, world.scouted, world.now, me, fog]);
}
