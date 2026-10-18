import { useEffect, useMemo, useRef, useState, type KeyboardEvent, type PointerEvent, type WheelEvent } from "react";
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
  pixelToHex,
  tileKey,
  type Hex,
} from "../lib/game";
import { useVision } from "../lib/vision";
import type { Citadel } from "../lib/world";
import { Minimap } from "./Minimap";

const MARCH_COLORS = ["", "#ff6b6b", "#8ab4f8", "#3fb950", "#c9d1d9", "#ff3b3b", "#ff9b3b"];
const K_MAX = 3; // closest zoom (screen px per map unit)

type View = { x: number; y: number; k: number };

/** The grid. Tiles are drawn as a handful of batched paths (one per look) and clicks are resolved with hex math, so a
 * 4,000-tile map pans and zooms smoothly. Detail follows zoom: dots far out, hexes closer, labels closest. */
export function HexMap() {
  const g = useGame();
  const { world, me, selected, select, placing, setPlacing, act, chain, fog, setFog, ao, setAo, focusReq } = g;
  const wrap = useRef<HTMLDivElement>(null);
  const [size, setSize] = useState({ w: 800, h: 600 });
  const [view, setView] = useState<View>({ x: 0, y: 0, k: 0.5 });
  const [hover, setHover] = useState<Hex>();
  const [cycle, setCycle] = useState(0);
  const positioned = useRef(false);
  const pointers = useRef(new Map<number, { x: number; y: number }>());
  const gesture = useRef<{ moved: boolean; start?: { x: number; y: number; view: View }; pinch?: { d: number; k: number } }>({
    moved: false,
  });
  const { tiles: visible, seen } = useVision();

  const extent = (world.radius + 1) * HEX_SIZE * 1.75; // map half-size in map units
  const kMin = Math.min(size.w, size.h) / (2 * extent);
  const clamp = (v: View): View => {
    const k = Math.min(K_MAX, Math.max(kMin, v.k));
    return { k, x: Math.max(-extent, Math.min(extent, v.x)), y: Math.max(-extent, Math.min(extent, v.y)) };
  };

  // container size
  useEffect(() => {
    if (!wrap.current) return;
    const ro = new ResizeObserver(([e]) => setSize({ w: e.contentRect.width, h: e.contentRect.height }));
    ro.observe(wrap.current);
    return () => ro.disconnect();
  }, []);

  const inAo = useMemo(() => [...world.citadels.values()].filter((c) => c.ao === ao), [world.citadels, ao]);
  const mine = useMemo(() => inAo.filter((c) => c.owner === me), [inAo, me]);
  const myIds = useMemo(() => new Set(mine.map((c) => c.id)), [mine]);
  const threats = useMemo(
    () =>
      [...world.marches.values()]
        .filter((m) => (m.kind === 1 || m.kind === 4 || m.kind === 5) && myIds.has(m.target))
        .map((m) => world.citadels.get(m.target)!)
        .concat([...world.sieges.values()].filter((s) => myIds.has(s.target)).map((s) => world.citadels.get(s.target)!))
        .filter(Boolean),
    [world.marches, world.sieges, myIds, world.citadels],
  );

  const flyTo = (h: Hex, k?: number) => {
    const p = hexToPixel(h);
    setView((v) => clamp({ x: p.x, y: p.y, k: k ?? Math.max(v.k, 1.1) }));
  };

  // first position: your CITADEL, or the whole grid
  useEffect(() => {
    if (positioned.current || !world.ready || size.w < 50) return;
    positioned.current = true;
    if (mine[0]) flyTo(mine[0], 1.1);
    else setView({ x: 0, y: 0, k: kMin });
  }, [world.ready, size.w, mine.length]);

  // fly-to requests from panels and the terminal
  useEffect(() => {
    if (focusReq) flyTo(focusReq);
  }, [focusReq?.n]);

  // ---------------------------------------------------------------- tiles (batched)
  const tiles = useMemo(() => hexesWithin(world.radius), [world.radius]);
  const placeable = useMemo(() => {
    if (!placing) return null;
    const ok = new Set<string>();
    const friends = inAo.filter((c) => placing.kind === "colonize" && c.faction === placing.faction);
    for (const t of tiles) {
      if (world.byTile.has(tileKey(ao, t.q, t.r)) || world.aoStates[ao] === 0) continue;
      if (placing.kind === "colonize" && !friends.some((c) => hexDistance(c, t) <= 2)) continue;
      ok.add(hexKey(t.q, t.r));
    }
    return ok;
  }, [placing, tiles, world.byTile, inAo, world.aoStates, ao]);

  const tilePaths = useMemo(() => {
    const groups = new Map<string, string[]>();
    for (const t of tiles) {
      const { x, y } = hexToPixel(t);
      const fogged = visible && !visible.has(tileKey(ao, t.q, t.r));
      const can = placeable?.has(hexKey(t.q, t.r));
      const cls = `tile b${defaultTileBps(t, world.radius)}${fogged ? " fog" : ""}${can ? " can" : ""}${placing && !can ? " cant" : ""}`;
      const pts = hexCorners(x, y, HEX_SIZE - 1);
      let list = groups.get(cls);
      if (!list) groups.set(cls, (list = []));
      list.push(`M${pts.replace(/ /g, "L")}Z`);
    }
    return [...groups].map(([cls, d]) => ({ cls, d: d.join("") }));
  }, [tiles, visible, placeable, placing, ao, world.radius]);

  // ---------------------------------------------------------------- input
  const toMap = (clientX: number, clientY: number) => {
    const r = wrap.current!.getBoundingClientRect();
    return { x: view.x + (clientX - r.left - size.w / 2) / view.k, y: view.y + (clientY - r.top - size.h / 2) / view.k };
  };

  function clickAt(clientX: number, clientY: number) {
    const p = toMap(clientX, clientY);
    clickHex(pixelToHex(p.x, p.y));
  }

  // test hook for the e2e playtests (web/e2e): click any tile, on screen or not
  useEffect(() => {
    (window as any).__citadelMap = {
      click: (q: number, r: number) => clickHex({ q, r }),
      clickCitadel: (id: string) => {
        const c = world.citadels.get(BigInt(id));
        if (!c) throw new Error(`CITADEL ${id} not on the grid`);
        clickHex(c);
      },
    };
  });

  function clickHex(t: Hex) {
    if (hexDistance(t, { q: 0, r: 0 }) > world.radius) return;
    if (placing && placeable?.has(hexKey(t.q, t.r))) {
      const pl = placing;
      setPlacing(undefined);
      if (pl.kind === "lite")
        act(`lite CITADEL ${pl.citadelId} at (${t.q}, ${t.r})`, () =>
          chain.write("game", "lite", [pl.citadelId, ao, t.q, t.r, pl.faction, pl.research, pl.pilots]),
        );
      else
        act(`colonize (${t.q}, ${t.r}) with PILOT ${pl.pilotId}`, () =>
          chain.write("game", "colonize", [pl.pilotId, ao, t.q, t.r, pl.faction]),
        );
    }
    select(t);
  }

  function onWheel(e: WheelEvent) {
    const before = toMap(e.clientX, e.clientY);
    const k = Math.min(K_MAX, Math.max(kMin, view.k * Math.exp(-e.deltaY * 0.0015)));
    // keep the point under the cursor fixed
    setView(clamp({ k, x: before.x - (before.x - view.x) * (view.k / k), y: before.y - (before.y - view.y) * (view.k / k) }));
  }

  function onDown(e: PointerEvent) {
    if ((e.target as HTMLElement).closest(".maptools, .minimap, .aos, .placing")) return;
    wrap.current?.setPointerCapture(e.pointerId);
    pointers.current.set(e.pointerId, { x: e.clientX, y: e.clientY });
    gesture.current = { moved: false, start: { x: e.clientX, y: e.clientY, view } };
    if (pointers.current.size === 2) {
      const [a, b] = [...pointers.current.values()];
      gesture.current.pinch = { d: Math.hypot(a.x - b.x, a.y - b.y), k: view.k };
    }
  }
  function onMove(e: PointerEvent) {
    if (!pointers.current.has(e.pointerId)) {
      const p = toMap(e.clientX, e.clientY);
      setHover(pixelToHex(p.x, p.y));
      return;
    }
    pointers.current.set(e.pointerId, { x: e.clientX, y: e.clientY });
    const gs = gesture.current;
    if (gs.pinch && pointers.current.size >= 2) {
      const [a, b] = [...pointers.current.values()];
      gs.moved = true;
      setView((v) => clamp({ ...v, k: gs.pinch!.k * (Math.hypot(a.x - b.x, a.y - b.y) / gs.pinch!.d) }));
      return;
    }
    if (!gs.start) return;
    const dx = e.clientX - gs.start.x,
      dy = e.clientY - gs.start.y;
    if (Math.abs(dx) + Math.abs(dy) > 5) gs.moved = true;
    if (gs.moved) setView(clamp({ ...gs.start.view, x: gs.start.view.x - dx / view.k, y: gs.start.view.y - dy / view.k }));
  }
  function onUp(e: PointerEvent) {
    if (!pointers.current.has(e.pointerId)) return;
    const wasClick = !gesture.current.moved && pointers.current.size === 1;
    pointers.current.delete(e.pointerId);
    if (pointers.current.size < 2) gesture.current.pinch = undefined;
    if (pointers.current.size === 0) {
      if (wasClick) clickAt(e.clientX, e.clientY);
      gesture.current = { moved: false };
    }
  }
  function onKey(e: KeyboardEvent) {
    const step = 120 / view.k;
    const moves: Record<string, [number, number]> = {
      ArrowLeft: [-step, 0],
      a: [-step, 0],
      ArrowRight: [step, 0],
      d: [step, 0],
      ArrowUp: [0, -step],
      w: [0, -step],
      ArrowDown: [0, step],
      s: [0, step],
    };
    if (moves[e.key]) {
      e.preventDefault();
      setView((v) => clamp({ ...v, x: v.x + moves[e.key][0], y: v.y + moves[e.key][1] }));
    } else if (e.key === "+" || e.key === "=") setView((v) => clamp({ ...v, k: v.k * 1.25 }));
    else if (e.key === "-") setView((v) => clamp({ ...v, k: v.k / 1.25 }));
    else if (e.key === "c") nextMine();
    else if (e.key === "f") setView({ x: 0, y: 0, k: kMin });
    else if (e.key === "Escape") setPlacing(undefined);
  }
  function nextMine() {
    if (!mine.length) return;
    const c = mine[cycle % mine.length];
    setCycle((n) => n + 1);
    flyTo(c);
    select(c);
  }

  // ---------------------------------------------------------------- render
  const vb = { x: view.x - size.w / 2 / view.k, y: view.y - size.h / 2 / view.k, w: size.w / view.k, h: size.h / view.k };
  const onScreen = (c: Hex, pad = HEX_SIZE * 2) => {
    const p = hexToPixel(c);
    return p.x > vb.x - pad && p.x < vb.x + vb.w + pad && p.y > vb.y - pad && p.y < vb.y + vb.h + pad;
  };
  const detail = view.k < 0.45 ? "far" : view.k < 0.9 ? "mid" : "near";
  const besieged = new Set([...world.sieges.values()].map((s) => s.target));
  const hoverId = hover ? world.byTile.get(tileKey(ao, hover.q, hover.r)) : undefined;
  const hoverInGrid = hover && hexDistance(hover, { q: 0, r: 0 }) <= world.radius;
  const lineScale = 1 / Math.min(1, view.k);

  return (
    <div
      className="mapwrap"
      ref={wrap}
      tabIndex={0}
      onKeyDown={onKey}
      onWheel={onWheel}
      onPointerDown={onDown}
      onPointerMove={onMove}
      onPointerUp={onUp}
      onPointerCancel={onUp}
      onPointerLeave={() => setHover(undefined)}
    >
      <svg viewBox={`${vb.x} ${vb.y} ${vb.w} ${vb.h}`} className={detail} role="img" aria-label="CITADEL grid">
        <defs>
          <radialGradient id="core">
            <stop offset="0" stopColor="#e8a33d" stopOpacity="0.35" />
            <stop offset="1" stopColor="#e8a33d" stopOpacity="0" />
          </radialGradient>
        </defs>
        <circle cx={0} cy={0} r={HEX_SIZE * (world.radius / 4 + 4)} fill="url(#core)" />
        {tilePaths.map((p) => (
          <path key={p.cls} d={p.d} className={p.cls} />
        ))}
        {[...world.marches.values()].map((m) => {
          const a = world.citadels.get(m.origin);
          const tgtId = m.kind === 6 ? world.sieges.get(m.target)?.target : m.target;
          const b = tgtId !== undefined ? world.citadels.get(tgtId) : undefined;
          if (!a || !b || a.ao !== ao || b.ao !== ao) return null;
          const [from, to] = m.kind === 2 ? [b, a] : [a, b];
          const pa = hexToPixel(from),
            pb = hexToPixel(to);
          const f = Math.min(1, Math.max(0, (world.now - m.sentAt) / Math.max(1, Number(m.arriveAt) - m.sentAt)));
          return (
            <g key={String(m.id)} className="march" pointerEvents="none">
              <line x1={pa.x} y1={pa.y} x2={pb.x} y2={pb.y} stroke={MARCH_COLORS[m.kind]} strokeWidth={1.5 * lineScale} />
              <circle cx={pa.x + (pb.x - pa.x) * f} cy={pa.y + (pb.y - pa.y) * f} r={4 * lineScale} fill={MARCH_COLORS[m.kind]} />
            </g>
          );
        })}
        {inAo.map((c) =>
          onScreen(c) ? (
            <CitadelMark
              key={String(c.id)}
              c={c}
              own={c.owner === me}
              seen={seen(c)}
              besieged={besieged.has(c.id)}
              detail={detail}
              k={view.k}
            />
          ) : null,
        )}
        {selected && (
          <polygon
            points={hexCorners(hexToPixel(selected).x, hexToPixel(selected).y, HEX_SIZE - 1)}
            className="sel"
            strokeWidth={2.5 * lineScale}
            pointerEvents="none"
          />
        )}
      </svg>

      <div className="aos">
        {world.aoStates.map((st, i) =>
          st === 0 ? null : (
            <button key={i} className={i === ao ? "on" : ""} onClick={() => setAo(i)}>
              AO {i}
              {st === 1 ? " · isolated" : ""}
            </button>
          ),
        )}
      </div>

      <div className="maptools">
        <button title="zoom in (+)" onClick={() => setView((v) => clamp({ ...v, k: v.k * 1.4 }))}>
          +
        </button>
        <button title="zoom out (−)" onClick={() => setView((v) => clamp({ ...v, k: v.k / 1.4 }))}>
          −
        </button>
        <button title="whole grid (f)" onClick={() => setView({ x: 0, y: 0, k: kMin })}>
          ⤢
        </button>
        <button title="the core" onClick={() => flyTo({ q: 0, r: 0 }, 1)}>
          ◎
        </button>
        <button title="your CITADEL, one after another (c)" disabled={!mine.length} onClick={nextMine}>
          ⌖{mine.length > 1 ? mine.length : ""}
        </button>
        {threats.length > 0 && (
          <button
            className="red"
            title="under attack"
            onClick={() => {
              const t = threats[cycle % threats.length];
              setCycle((n) => n + 1);
              flyTo(t);
              select(t);
            }}
          >
            ⚠{threats.length}
          </button>
        )}
        <label title="fog of war">
          <input type="checkbox" checked={fog} onChange={(e) => setFog(e.target.checked)} /> fog
        </label>
      </div>

      <Minimap view={vb} onJump={(x, y) => setView((v) => clamp({ ...v, x, y }))} />

      {hoverInGrid && hover && (
        <div className="hoverinfo">
          ({hover.q}, {hover.r}) · {(defaultTileBps(hover, world.radius) / 10000).toFixed(2)}× ·{" "}
          {hexDistance(hover, { q: 0, r: 0 })} from core
          {hoverId !== undefined && ` · CITADEL ${hoverId}`}
        </div>
      )}
      {placing && (
        <div className="placing">
          Click a highlighted tile to {placing.kind === "lite" ? `lite CITADEL ${placing.citadelId}` : "found a CITADEL"}.{" "}
          <button onClick={() => setPlacing(undefined)}>cancel (esc)</button>
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
        <span className="dim">drag · wheel/pinch · WASD · c · f</span>
      </div>
    </div>
  );
}

function CitadelMark({
  c,
  own,
  seen,
  besieged,
  detail,
  k,
}: {
  c: Citadel;
  own: boolean;
  seen: boolean;
  besieged: boolean;
  detail: "far" | "mid" | "near";
  k: number;
}) {
  const { x, y } = hexToPixel(c);
  if (!seen)
    return detail === "far" ? (
      <circle cx={x} cy={y} r={Math.max(HEX_SIZE * 0.5, 3.5 / k)} className="unknown-far" strokeWidth={1.5 / k} />
    ) : (
      <text x={x} y={y + 5} className="unknown" data-citadel={String(c.id)}>
        ?
      </text>
    );
  const color = FACTION_COLORS[c.faction];
  const relik = c.sekt === 0 && c.generation === 0;
  if (detail === "far") {
    // far out, a CITADEL is a dot that stays a few screen pixels wide however small the tiles get
    const r = Math.max(HEX_SIZE * 0.55, 4 / k);
    return (
      <g className="cit" data-citadel={String(c.id)}>
        {besieged && <circle cx={x} cy={y} r={r * 1.8} className="besieged" />}
        <circle
          cx={x}
          cy={y}
          r={r}
          fill={color}
          stroke={own ? "#fff" : relik ? "#e8a33d" : "none"}
          strokeWidth={own || relik ? 2 / k : 0}
        />
      </g>
    );
  }
  const size = HEX_SIZE * (0.58 + Math.min(0.3, c.levels[0] * 0.03)) * (c.generation === 0 ? 1 : 0.8);
  return (
    <g className="cit" data-citadel={String(c.id)}>
      {besieged && <polygon points={hexCorners(x, y, HEX_SIZE - 3)} className="besieged" />}
      {relik && <polygon points={hexCorners(x, y, size + 4)} className="relik" />}
      <polygon points={hexCorners(x, y, size)} fill={color} className={own ? "own" : ""} opacity={c.generation === 0 ? 1 : 0.75} />
      {detail === "near" && (
        <text x={x} y={y + 3.5} className="cid">
          {String(c.id)}
        </text>
      )}
    </g>
  );
}
