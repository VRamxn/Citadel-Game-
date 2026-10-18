import { useEffect, useMemo, useRef } from "react";
import { HEX_SIZE, defaultTileBps, hexDistance, hexesWithin, hexKey, hexToPixel, tileKey, type Hex } from "../lib/game";

const FILL: Record<number, string> = {
  10000: "#0f141b",
  10500: "#16140f",
  11000: "#1e1a10",
  11500: "#241c0e",
  12000: "#2e220d",
  12500: "#3a2a0e",
};
const STROKE = "#1b232e";
const CACHE_SCALE = 0.16; // px per map unit of the whole-map bitmap used when zoomed far out

type Look = { fill: string; alpha: number; can: boolean };
type Props = {
  radius: number;
  ao: number;
  view: { x: number; y: number; w: number; h: number; k: number }; // map-space rect + zoom
  size: { w: number; h: number }; // screen px
  visible: Set<string> | null; // fog: tiles in sight (null = no fog)
  placeable: Set<string> | null; // tiles you may place on (null = not placing)
};

/** The grid's terrain on a canvas. Up close it draws only the tiles on screen; far out it blits a cached bitmap of the
 * whole map, so a 19,000-tile grid pans and zooms smoothly. */
export function Terrain({ radius, ao, view, size, visible, placeable }: Props) {
  const canvas = useRef<HTMLCanvasElement>(null);
  const extent = (radius + 1) * HEX_SIZE * 1.75;

  const look = useMemo(() => {
    const bps = new Map<string, number>();
    return (t: Hex): Look => {
      const k = hexKey(t.q, t.r);
      let b = bps.get(k);
      if (b === undefined) bps.set(k, (b = defaultTileBps(t, radius)));
      const can = !!placeable?.has(k);
      const fogged = !!visible && !visible.has(tileKey(ao, t.q, t.r));
      return { fill: can ? "#10301a" : FILL[b] ?? FILL[10000], alpha: placeable && !can ? 0.35 : fogged ? 0.32 : 1, can };
    };
  }, [radius, ao, visible, placeable]);

  // whole-map bitmap for far zoom
  const cache = useMemo(() => {
    const px = Math.ceil(2 * extent * CACHE_SCALE);
    const c = document.createElement("canvas");
    c.width = c.height = px;
    const g = c.getContext("2d")!;
    g.setTransform(CACHE_SCALE, 0, 0, CACHE_SCALE, extent * CACHE_SCALE, extent * CACHE_SCALE);
    const groups = new Map<string, { look: Look; tiles: Hex[] }>();
    for (const t of hexesWithin(radius)) {
      const l = look(t);
      const key = `${l.fill}${l.alpha}${l.can}`;
      let b = groups.get(key);
      if (!b) groups.set(key, (b = { look: l, tiles: [] }));
      b.tiles.push(t);
    }
    for (const { look: l, tiles } of groups.values()) drawBatch(g, tiles, l, false);
    return c;
  }, [radius, look, extent]);

  useEffect(() => {
    const cv = canvas.current;
    if (!cv) return;
    const dpr = window.devicePixelRatio || 1;
    if (cv.width !== Math.round(size.w * dpr) || cv.height !== Math.round(size.h * dpr)) {
      cv.width = Math.round(size.w * dpr);
      cv.height = Math.round(size.h * dpr);
    }
    const g = cv.getContext("2d")!;
    g.setTransform(1, 0, 0, 1, 0, 0);
    g.clearRect(0, 0, cv.width, cv.height);
    // map -> screen: (m - view.origin) * k * dpr
    g.setTransform(view.k * dpr, 0, 0, view.k * dpr, -view.x * view.k * dpr, -view.y * view.k * dpr);
    if (view.k < 0.32) {
      g.imageSmoothingEnabled = true;
      g.drawImage(cache, -extent, -extent, 2 * extent, 2 * extent);
      return;
    }
    const stroke = view.k >= 0.45;
    const rowH = HEX_SIZE * 1.5,
      colW = HEX_SIZE * Math.sqrt(3);
    const r0 = Math.max(-radius, Math.floor(view.y / rowH) - 1);
    const r1 = Math.min(radius, Math.ceil((view.y + view.h) / rowH) + 1);
    const batches = new Map<string, { look: Look; tiles: Hex[] }>();
    for (let r = r0; r <= r1; r++) {
      const q0 = Math.max(-radius, Math.floor(view.x / colW - r / 2) - 1);
      const q1 = Math.min(radius, Math.ceil((view.x + view.w) / colW - r / 2) + 1);
      for (let q = q0; q <= q1; q++) {
        const t = { q, r };
        if (hexDistance(t, { q: 0, r: 0 }) > radius) continue;
        const l = look(t);
        const key = `${l.fill}${l.alpha}${l.can}`;
        let b = batches.get(key);
        if (!b) batches.set(key, (b = { look: l, tiles: [] }));
        b.tiles.push(t);
      }
    }
    for (const { look: l, tiles } of batches.values()) drawBatch(g, tiles, l, stroke);
  }, [view.x, view.y, view.k, view.w, view.h, size.w, size.h, cache, look, radius, extent]);

  return <canvas ref={canvas} className="terrain" style={{ width: size.w, height: size.h }} />;
}

const CORNERS = Array.from({ length: 6 }, (_, i) => {
  const a = (Math.PI / 180) * (60 * i - 30);
  return [(HEX_SIZE - 1) * Math.cos(a), (HEX_SIZE - 1) * Math.sin(a)];
});

/** All tiles of one look in a single path: one fill (and one stroke) per batch instead of per tile. */
function drawBatch(g: CanvasRenderingContext2D, tiles: Hex[], l: Look, stroke: boolean) {
  g.beginPath();
  for (const t of tiles) {
    const { x, y } = hexToPixel(t);
    g.moveTo(x + CORNERS[0][0], y + CORNERS[0][1]);
    for (let i = 1; i < 6; i++) g.lineTo(x + CORNERS[i][0], y + CORNERS[i][1]);
    // back to the first corner rather than closePath(), which gets slow on a path with thousands of subpaths
    g.lineTo(x + CORNERS[0][0], y + CORNERS[0][1]);
  }
  g.globalAlpha = l.alpha;
  g.fillStyle = l.fill;
  g.fill();
  if (stroke || l.can) {
    g.strokeStyle = l.can ? "#3fb950" : STROKE;
    g.lineWidth = l.can ? 1.5 : 1;
    g.stroke();
  }
  g.globalAlpha = 1;
}
