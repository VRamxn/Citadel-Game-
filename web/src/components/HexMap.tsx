import { useMemo, useRef, useState, type PointerEvent, type WheelEvent } from "react";
import { useGame } from "../App";
import {
  FACTION_COLORS,
  HEX_SIZE,
  defaultTileBps,
  hexCorners,
  hexDistance,
  hexKey,
  hexToPixel,
  hexesWithin,
  type Hex,
} from "../lib/game";
import { useVision } from "../lib/vision";

const MARCH_COLORS = ["", "#ff6b6b", "#8ab4f8", "#3fb950", "#c9d1d9", "#ff3b3b", "#ff9b3b"];

export function HexMap() {
  const { world, me, selected, select, placing, setPlacing, act, chain, fog, setFog } = useGame();
  const [view, setView] = useState({ x: 0, y: 0, k: 1 });
  const { tiles: visible, seen } = useVision();
  const drag = useRef<{ x: number; y: number; vx: number; vy: number; moved: boolean } | null>(null);
  const svg = useRef<SVGSVGElement>(null);
  const tiles = useMemo(() => hexesWithin(world.radius), [world.radius]);

  const mine = useMemo(() => [...world.citadels.values()].filter((c) => c.owner === me), [world.citadels, me]);

  const besieged = useMemo(() => new Set([...world.sieges.values()].map((s) => s.target)), [world.sieges]);

  const placeable = useMemo(() => {
    if (!placing) return null;
    const ok = new Set<string>();
    for (const t of tiles) {
      if (world.byTile.has(hexKey(t.q, t.r))) continue;
      if (placing.kind === "colonize") {
        const near = [...world.citadels.values()].some(
          (c) => c.ao === 0 && c.faction === placing.faction && hexDistance(c, t) <= 2,
        );
        if (!near) continue;
      }
      ok.add(hexKey(t.q, t.r));
    }
    return ok;
  }, [placing, tiles, world.byTile, world.citadels]);

  const extent = (world.radius + 1) * HEX_SIZE * 1.45;

  function onClickTile(t: Hex) {
    if (drag.current?.moved) return;
    if (placing && placeable?.has(hexKey(t.q, t.r))) {
      const p = placing;
      setPlacing(undefined);
      if (p.kind === "lite")
        act(`lite CITADEL ${p.citadelId} at (${t.q}, ${t.r})`, () =>
          chain.write("game", "lite", [p.citadelId, 0, t.q, t.r, p.faction, p.research, p.pilots]),
        );
      else
        act(`colonize (${t.q}, ${t.r}) with PILOT ${p.pilotId}`, () =>
          chain.write("game", "colonize", [p.pilotId, 0, t.q, t.r, p.faction]),
        );
      select(t);
      return;
    }
    select(t);
  }

  function onWheel(e: WheelEvent) {
    const k = Math.min(4, Math.max(0.35, view.k * (e.deltaY < 0 ? 1.15 : 1 / 1.15)));
    setView((v) => ({ ...v, k }));
  }
  function onDown(e: PointerEvent) {
    drag.current = { x: e.clientX, y: e.clientY, vx: view.x, vy: view.y, moved: false };
  }
  function onMove(e: PointerEvent) {
    const d = drag.current;
    if (!d || !svg.current) return;
    const scale = (extent * 2) / svg.current.clientWidth / view.k;
    const dx = (e.clientX - d.x) * scale,
      dy = (e.clientY - d.y) * scale;
    if (Math.abs(dx) + Math.abs(dy) > 4) d.moved = true;
    if (d.moved) setView((v) => ({ ...v, x: d.vx - dx, y: d.vy - dy }));
  }
  function onUp() {
    setTimeout(() => (drag.current = null), 0);
  }

  const half = extent / view.k;
  const viewBox = `${view.x - half} ${view.y - half} ${half * 2} ${half * 2}`;

  return (
    <div className="mapwrap">
      <svg
        ref={svg}
        viewBox={viewBox}
        onWheel={onWheel}
        onPointerDown={onDown}
        onPointerMove={onMove}
        onPointerUp={onUp}
        onPointerLeave={onUp}
        role="img"
        aria-label="CITADEL grid"
      >
        <defs>
          <radialGradient id="core">
            <stop offset="0" stopColor="#e8a33d" stopOpacity="0.35" />
            <stop offset="1" stopColor="#e8a33d" stopOpacity="0" />
          </radialGradient>
        </defs>
        <circle cx={0} cy={0} r={HEX_SIZE * 9} fill="url(#core)" />
        {tiles.map((t) => {
          const { x, y } = hexToPixel(t);
          const k = hexKey(t.q, t.r);
          const bps = defaultTileBps(t);
          const fogged = visible && !visible.has(k);
          const can = placeable?.has(k);
          return (
            <polygon
              key={k}
              data-tile={k}
              points={hexCorners(x, y, HEX_SIZE - 1)}
              className={`tile b${bps}${fogged ? " fog" : ""}${can ? " can" : ""}${placing && !can ? " cant" : ""}`}
              onClick={() => onClickTile(t)}
            />
          );
        })}
        {[...world.marches.values()].map((m) => {
          const a = world.citadels.get(m.origin);
          const tgtId = m.kind === 6 ? world.sieges.get(m.target)?.target : m.target;
          const b = tgtId !== undefined ? world.citadels.get(tgtId) : undefined;
          if (!a || !b || a.ao || b.ao) return null;
          const [from, to] = m.kind === 2 ? [b, a] : [a, b];
          const pa = hexToPixel(from),
            pb = hexToPixel(to);
          const span = Math.max(1, Number(m.arriveAt) - m.sentAt);
          const f = Math.min(1, Math.max(0, (world.now - m.sentAt) / span));
          const dx = pa.x + (pb.x - pa.x) * f,
            dy = pa.y + (pb.y - pa.y) * f;
          return (
            <g key={String(m.id)} className="march" onClick={() => select(to)}>
              <line x1={pa.x} y1={pa.y} x2={pb.x} y2={pb.y} stroke={MARCH_COLORS[m.kind]} />
              <circle cx={dx} cy={dy} r={4} fill={MARCH_COLORS[m.kind]} />
            </g>
          );
        })}
        {[...world.citadels.values()].map((c) => {
          if (c.ao !== 0) return null;
          const { x, y } = hexToPixel(c);
          if (!seen(c))
            return (
              <text key={String(c.id)} x={x} y={y + 5} className="unknown" data-citadel={String(c.id)} onClick={() => onClickTile(c)}>
                ?
              </text>
            );
          const own = c.owner === me;
          const size = HEX_SIZE * (0.58 + Math.min(0.3, c.levels[0] * 0.03)) * (c.generation === 0 ? 1 : 0.8);
          return (
            <g key={String(c.id)} className="cit" data-citadel={String(c.id)} onClick={() => onClickTile(c)}>
              {besieged.has(c.id) && <polygon points={hexCorners(x, y, HEX_SIZE - 3)} className="besieged" />}
              {c.sekt === 0 && c.generation === 0 && <polygon points={hexCorners(x, y, size + 4)} className="relik" />}
              <polygon
                points={hexCorners(x, y, size)}
                fill={FACTION_COLORS[c.faction]}
                className={own ? "own" : ""}
                opacity={c.generation === 0 ? 1 : 0.75}
              />
              <text x={x} y={y + 3.5} className="cid">
                {String(c.id)}
              </text>
            </g>
          );
        })}
        {selected && (
          <polygon
            points={hexCorners(hexToPixel(selected).x, hexToPixel(selected).y, HEX_SIZE - 1)}
            className="sel"
            pointerEvents="none"
          />
        )}
      </svg>
      <div className="maptools">
        <button onClick={() => setView((v) => ({ ...v, k: Math.min(4, v.k * 1.3) }))}>+</button>
        <button onClick={() => setView((v) => ({ ...v, k: Math.max(0.35, v.k / 1.3) }))}>−</button>
        <button
          onClick={() => {
            const c = mine[0];
            const p = c ? hexToPixel(c) : { x: 0, y: 0 };
            setView({ x: p.x, y: p.y, k: c ? 2 : 1 });
          }}
        >
          ⌖
        </button>
        <label>
          <input type="checkbox" checked={fog} onChange={(e) => setFog(e.target.checked)} /> fog
        </label>
      </div>
      {placing && (
        <div className="placing">
          Click a highlighted tile to {placing.kind === "lite" ? `lite CITADEL ${placing.citadelId}` : "found a CITADEL"}.{" "}
          <button onClick={() => setPlacing(undefined)}>cancel</button>
        </div>
      )}
      <div className="legend">
        {["NETWORK STATE", "AUTONOMOUS ZONE", "SANCTION", "ANNEXATION"].map((f, i) => (
          <span key={f}>
            <i style={{ background: FACTION_COLORS[i] }} /> {f}
          </span>
        ))}
        <span className="hot">⬡ RELIK</span>
        <span className="hot">▮ hotspot</span>
      </div>
    </div>
  );
}
