import { useEffect, useRef, useState, type KeyboardEvent } from "react";
import { useGame } from "../App";
import { BUILDINGS, FACTIONS, FLEET_SHORT, fmtDk, tileKey } from "../lib/game";

const HELP = `commands:
  mine                              your CITADEL on the grid
  status <id>                       a CITADEL's state
  drip                              testnet starter kit
  lite <id> <q> <r> <faction 0-3> [research 0-7] [pilot ...]
  build <id> <citadel|mine|shield|engine|weapon|academy>
  hurry <id>                        finish construction now
  train <id> <sif|throt|dreb|dalaa> <n>
  claim <id>
  raid <from> <to> <sif> [throt] [dreb] [dalaa]
  scout <from> <to> <dalaa>
  reinforce <from> <to> <sif> [throt] [dreb] [dalaa]
  siege <from> <to> <sif> <throt> <dreb> <dalaa> [pilot]
  resolve <march>      advance <siege>
  dispatch             news       skip <hours> (local chain)       clear`;

export function Terminal({ lines }: { lines: string[] }) {
  const g = useGame();
  const [input, setInput] = useState("");
  const [open, setOpen] = useState(() => window.innerWidth > 900);
  const [hist, setHist] = useState<string[]>([]);
  const [hi, setHi] = useState(-1);
  const end = useRef<HTMLDivElement>(null);
  const [cleared, setCleared] = useState(0);
  useEffect(() => {
    end.current?.scrollIntoView({ block: "nearest" });
  }, [lines.length]);

  async function run(cmd: string) {
    const { chain, act, log, world, me } = g;
    const [op, ...a] = cmd.trim().split(/\s+/);
    const n = (i: number, d = 0n) => (a[i] !== undefined ? BigInt(a[i]) : d);
    const units = (from: number) => [n(from), n(from + 1), n(from + 2), n(from + 3)];
    log(`citadel os > ${cmd}`);
    try {
      switch (op) {
        case "":
          return;
        case "help":
          return HELP.split("\n").forEach(log);
        case "clear":
          return setCleared(lines.length + 1);
        case "mine":
          for (const c of world.citadels.values())
            if (c.owner === me) log(`  CITADEL ${c.id} (${c.q},${c.r}) ${FACTIONS[c.faction]} L${c.levels[0]} vault ${fmtDk(c.vault)}+`);
          return;
        case "status": {
          const id = n(0);
          const c = world.citadels.get(id);
          if (!c) return log("  not on the grid");
          const [v, gar, rate] = await Promise.all([
            chain.read<bigint>("game", "vaultOf", [id]),
            chain.read<readonly bigint[]>("game", "garrisonOf", [id]),
            chain.read<bigint>("game", "miningRate", [id]),
          ]);
          log(`  CITADEL ${id} GEN${c.generation} ${FACTIONS[c.faction]} at (${c.q},${c.r}) owner ${c.owner}`);
          log(`  levels ${BUILDINGS.map((b, i) => `${b.split(" ")[0]} ${c.levels[i]}`).join(" · ")}`);
          if (c.owner === me) log(`  vault ${fmtDk(v)} DK · ${fmtDk(rate)} DK/day · garrison ${gar.map((x, i) => `${x} ${FLEET_SHORT[i]}`).join(" ")}`);
          return;
        }
        case "drip":
          return void (await act("drip", () => chain.write("faucet", "drip")));
        case "lite":
          return void (await act(`lite ${a[0]}`, () =>
            chain.write("game", "lite", [n(0), g.ao, Number(a[1]), Number(a[2]), Number(a[3]), Number(a[4] ?? 0), a.slice(5).map(BigInt)]),
          ));
        case "build": {
          const b = BUILDINGS.findIndex((x) => x.toLowerCase().startsWith((a[1] ?? "").toLowerCase()));
          if (b < 0) return log("  unknown building");
          return void (await act(`build ${BUILDINGS[b]}`, () => chain.write("game", "build", [n(0), b])));
        }
        case "hurry":
          return void (await act("hurry", () => chain.write("game", "hurryBuild", [n(0)])));
        case "train": {
          const t = FLEET_SHORT.findIndex((x) => x.toLowerCase() === (a[1] ?? "").toLowerCase());
          if (t < 0) return log("  unknown fleet type");
          return void (await act(`train ${a[2]} ${FLEET_SHORT[t]}`, () => chain.write("game", "train", [n(0), t, n(2)])));
        }
        case "claim":
          return void (await act("claim", () => chain.write("game", "claim", [n(0)])));
        case "raid":
          return void (await act(`raid ${a[1]}`, () => chain.write("game", "raid", [n(0), n(1), units(2)])));
        case "scout":
          return void (await act(`scout ${a[1]}`, () => chain.write("game", "scout", [n(0), n(1), [0n, 0n, 0n, n(2)]])));
        case "reinforce":
          return void (await act(`reinforce ${a[1]}`, () => chain.write("game", "reinforce", [n(0), n(1), units(2)])));
        case "siege":
          return void (await act(`siege ${a[1]}`, () =>
            chain.write("game", "siege", [n(0), n(1), units(2), a[6] !== undefined ? n(6) + 1n : 0n]),
          ));
        case "resolve":
          return void (await act(`resolve ${a[0]}`, () => chain.write("game", "resolve", [n(0)])));
        case "advance":
          return void (await act(`advance ${a[0]}`, () => chain.write("game", "advanceSiege", [n(0), 24n])));
        case "dispatch":
          return world.dispatch.slice(0, 12).forEach((d) => log(`  ${d.text}`));
        case "skip":
          if (!chain.isDev) return log("  only on the local chain");
          return void (await act(`skip ${a[0]}h`, () => chain.skip(Number(a[0] ?? 1) * 3600)));
        case "goto": {
          const id = world.byTile.get(tileKey(g.ao, Number(a[0]), Number(a[1])));
          g.select({ q: Number(a[0]), r: Number(a[1]) });
          return log(id !== undefined ? `  CITADEL ${id}` : "  empty tile");
        }
        default:
          return log(`  unknown command: ${op} (try help)`);
      }
    } catch (e) {
      log(`  error: ${e instanceof Error ? e.message : String(e)}`);
    }
  }

  function onKey(e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === "Enter") {
      const cmd = input;
      setInput("");
      setHist((h) => [cmd, ...h].slice(0, 50));
      setHi(-1);
      run(cmd);
    } else if (e.key === "ArrowUp") {
      const i = Math.min(hist.length - 1, hi + 1);
      setHi(i);
      setInput(hist[i] ?? "");
    } else if (e.key === "ArrowDown") {
      const i = Math.max(-1, hi - 1);
      setHi(i);
      setInput(i < 0 ? "" : hist[i]);
    }
  }

  return (
    <footer className={`term ${open ? "" : "closed"}`}>
      <div className="termbar" onClick={() => setOpen(!open)}>
        CITADEL OS terminal {open ? "▾" : "▸"}
      </div>
      {open && (
        <>
          <div className="termout">
            {lines.slice(cleared).map((l, i) => (
              <div key={i}>{l}</div>
            ))}
            <div ref={end} />
          </div>
          <div className="termin">
            <span>citadel os &gt;</span>
            <input value={input} onChange={(e) => setInput(e.target.value)} onKeyDown={onKey} spellCheck={false} aria-label="terminal command" />
          </div>
        </>
      )}
    </footer>
  );
}
