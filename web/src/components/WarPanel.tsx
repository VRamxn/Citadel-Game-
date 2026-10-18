import { useGame } from "../App";
import { FLEET_SHORT, MARCH_KIND, fmtDk, fmtDuration, fmtPct } from "../lib/game";

const units = (u: readonly bigint[]) =>
  u
    .map((n, i) => (n > 0n ? `${n} ${FLEET_SHORT[i]}` : ""))
    .filter(Boolean)
    .join(" · ");

export function WarPanel() {
  const { world, me, chain, act, focus } = useGame();
  const mineIds = new Set([...world.citadels.values()].filter((c) => c.owner === me).map((c) => c.id));
  const marches = [...world.marches.values()].sort((a, b) => Number(a.arriveAt - b.arriveAt));
  const sieges = [...world.sieges.values()];
  const wave = Number(world.config?.siegeWaveSecs ?? 3600);
  const involves = (o: bigint, t: bigint) => mineIds.has(o) || mineIds.has(t);

  return (
    <div>
      <h2>Sieges</h2>
      {sieges.length === 0 && <p className="dim">No active sieges.</p>}
      {sieges.map((s) => {
        const due = Math.floor((world.now - Number(s.start)) / wave) - s.waves;
        const t = world.citadels.get(s.target);
        return (
          <div key={String(s.id)} className={`item ${involves(s.origin, s.target) ? "hl" : ""}`}>
            <div>
              <b>Siege {s.id.toString()}</b>: CITADEL {s.origin.toString()} → {s.target.toString()}
              {s.pilot > 0n && ` · PILOT ${s.pilot - 1n}`}
            </div>
            <div>
              <meter min={0} max={10000} value={Math.max(0, s.progress)} /> {fmtPct(Math.max(0, s.progress))} · wave{" "}
              {s.waves} · army {units(s.units)}
            </div>
            <div className="row">
              {t && <button onClick={() => focus(t)}>show on map</button>}
              <button
                disabled={due <= 0}
                onClick={() => act(`advance siege ${s.id}`, () => chain.write("game", "advanceSiege", [s.id, 24n]))}
              >
                {due > 0 ? `fight ${Math.min(due, 24)} due wave${due > 1 ? "s" : ""}` : `next wave in ${fmtDuration(wave - ((world.now - Number(s.start)) % wave))}`}
              </button>
            </div>
          </div>
        );
      })}

      <h2>Marches</h2>
      {marches.length === 0 && <p className="dim">The grid is quiet.</p>}
      {marches.map((m) => {
        const left = Number(m.arriveAt) - world.now;
        const fee = Number(world.config?.resolverFeeBps ?? 0);
        return (
          <div key={String(m.id)} className={`item ${involves(m.origin, m.target) ? "hl" : ""}`}>
            <div>
              <b>
                #{m.id.toString()} {MARCH_KIND[m.kind]}
              </b>{" "}
              {m.kind === 2 ? `→ home CITADEL ${m.origin}` : `CITADEL ${m.origin} → ${m.kind === 6 ? `siege ${m.target}` : `CITADEL ${m.target}`}`}
              {m.loot > 0n && ` · carrying ${fmtDk(m.loot)} DK`}
            </div>
            <div className="dim">{units(m.units)}</div>
            <div className="row">
              {world.citadels.get(m.kind === 2 ? m.origin : m.target) && m.kind !== 6 && (
                <button onClick={() => focus(world.citadels.get(m.kind === 2 ? m.origin : m.target)!)}>show</button>
              )}
              {left > 0 ? (
                <span>arrives in {fmtDuration(left)}</span>
              ) : (
                <button className="primary" onClick={() => act(`resolve march ${m.id}`, () => chain.write("game", "resolve", [m.id]))}>
                  resolve{m.kind === 1 ? ` (earn ${fee / 100}% of loot)` : ""}
                </button>
              )}
            </div>
          </div>
        );
      })}
      <p className="dim small">
        Anyone can resolve an arrived march or fight due siege waves. Resolving a raid pays {Number(world.config?.resolverFeeBps ?? 0) / 100}% of its
        loot. A raid left unresolved for {fmtDuration(Number(world.config?.defectionWindow ?? 0))} defects to the defender.
      </p>
    </div>
  );
}
