import { useMemo } from "react";
import { useGame } from "../App";
import { SURVEILLANCE_STATE, hasTech, hexKey, hexesWithin } from "./game";
import type { Citadel } from "./world";

/** Fog of war: what the player's factions can see — 2 tiles around each of their CITADEL, +1 with SURVEILLANCE STATE,
 * +2 around a CITADEL hosting a MENTAT — plus anything their DALAA MAX scouted in the last 24h. The chain is public;
 * this is the client honouring the whitepaper's vision rules, not secrecy. */
export function useVision() {
  const { world, me, fog } = useGame();
  return useMemo(() => {
    const mine = [...world.citadels.values()].filter((c) => c.owner === me);
    const factions = new Set(mine.map((c) => c.faction));
    if (!fog || factions.size === 0) return { tiles: null as Set<string> | null, seen: (_: Citadel) => true };
    const tiles = new Set<string>();
    for (const c of world.citadels.values()) {
      if (c.ao !== 0 || !factions.has(c.faction)) continue;
      const r = 2 + (hasTech(world.techBits[c.faction] ?? 0n, SURVEILLANCE_STATE) ? 1 : 0) + (c.mentat > 0n ? 2 : 0);
      for (const t of hexesWithin(r)) tiles.add(hexKey(c.q + t.q, c.r + t.r));
    }
    const seen = (c: Citadel) =>
      tiles.has(hexKey(c.q, c.r)) || (world.scouted.get(c.id)?.at ?? 0) > world.now - 86400;
    return { tiles, seen };
  }, [world.citadels, world.techBits, world.scouted, world.now, me, fog]);
}
