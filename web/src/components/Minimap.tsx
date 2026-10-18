import { useMemo, useRef, type PointerEvent } from "react";
import { useGame } from "../App";
import { FACTION_COLORS, HEX_SIZE, fieldCentres, hexToPixel } from "../lib/game";
import { useVision } from "../lib/vision";

const SIZE = 168;

/** The whole AO at a glance: hotspots, every CITADEL you can see, and the viewport. Click or drag to move the view. */
export function Minimap({ view, onJump }: { view: { x: number; y: number; w: number; h: number }; onJump: (x: number, y: number) => void }) {
  const { world, me, ao } = useGame();
  const { seen } = useVision();
  const svg = useRef<SVGSVGElement>(null);
  const dragging = useRef(false);
  const R = world.radius;
  const half = (R + 1) * HEX_SIZE * 1.75;

  const outline = useMemo(() => {
    // the grid's outer hexagon: the six corner tiles
    const corners = [
      { q: R, r: -R },
      { q: R, r: 0 },
      { q: 0, r: R },
      { q: -R, r: R },
      { q: -R, r: 0 },
      { q: 0, r: -R },
    ].map(hexToPixel);
    return corners.map((p) => `${p.x},${p.y}`).join(" ");
  }, [R]);
  const fields = useMemo(() => fieldCentres(R).map(hexToPixel), [R]);
  const fieldR = (R >= 18 ? Math.floor(R / 9) : 1) * HEX_SIZE * 1.6;
  const coreR = (R >= 24 ? Math.floor(R / 12) : 1) * 2 * HEX_SIZE * 1.6;

  function jump(e: PointerEvent) {
    const r = svg.current!.getBoundingClientRect();
    onJump(((e.clientX - r.left) / r.width) * 2 * half - half, ((e.clientY - r.top) / r.height) * 2 * half - half);
  }

  return (
    <div className="minimap">
      <svg
        ref={svg}
        width={SIZE}
        height={SIZE}
        viewBox={`${-half} ${-half} ${2 * half} ${2 * half}`}
        onPointerDown={(e) => {
          dragging.current = true;
          (e.target as Element).setPointerCapture?.(e.pointerId);
          jump(e);
        }}
        onPointerMove={(e) => dragging.current && jump(e)}
        onPointerUp={() => (dragging.current = false)}
        role="img"
        aria-label="minimap"
      >
        <polygon points={outline} className="mm-grid" />
        <circle cx={0} cy={0} r={coreR} className="mm-hot" />
        {fields.map((p, i) => (
          <circle key={i} cx={p.x} cy={p.y} r={fieldR} className="mm-field" />
        ))}
        {[...world.citadels.values()].map((c) => {
          if (c.ao !== ao || !seen(c)) return null;
          const p = hexToPixel(c);
          const own = c.owner === me;
          return <circle key={String(c.id)} cx={p.x} cy={p.y} r={own ? HEX_SIZE * 1.6 : HEX_SIZE * 1.1} fill={own ? "#fff" : FACTION_COLORS[c.faction]} />;
        })}
        <rect x={view.x} y={view.y} width={view.w} height={view.h} className="mm-view" />
      </svg>
    </div>
  );
}
