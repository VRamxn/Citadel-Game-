import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";
import type { Address } from "viem";
import { Chain_, devAccounts, explainError, pickDeployment } from "./lib/chain";
import { WorldSync, emptyWorld, type World } from "./lib/world";
import { loadPlayer, type Player } from "./lib/player";
import { fmtDk, short, type Hex } from "./lib/game";
import { HexMap } from "./components/HexMap";
import { TilePanel } from "./components/TilePanel";
import { AssetsPanel } from "./components/AssetsPanel";
import { WarPanel } from "./components/WarPanel";
import { TechPanel } from "./components/TechPanel";
import { PoliticsPanel } from "./components/PoliticsPanel";
import { DispatchPanel } from "./components/DispatchPanel";
import { Terminal } from "./components/Terminal";
import { Guide } from "./components/Guide";
import { LadderPanel } from "./components/LadderPanel";
import { BridgePanel } from "./components/BridgePanel";

type Toast = { id: number; text: string; kind: "ok" | "err" | "busy" };

export type Ctx = {
  chain: Chain_;
  world: World;
  player?: Player;
  me?: Address;
  selected?: Hex;
  select: (h?: Hex) => void;
  placing?: Placing;
  setPlacing: (p?: Placing) => void;
  act: (label: string, fn: () => Promise<unknown>) => Promise<boolean>;
  refresh: () => void;
  log: (line: string) => void;
  fog: boolean;
  setFog: (f: boolean) => void;
  ao: number;
  setAo: (ao: number) => void;
  /** Ask the map to fly to a tile (and select it). */
  focus: (h: Hex & { ao?: number }) => void;
  focusReq?: { q: number; r: number; n: number };
};
export type Placing =
  | { kind: "lite"; citadelId: bigint; pilots: bigint[]; faction: number; research: number }
  | { kind: "colonize"; pilotId: bigint; faction: number };

const AppCtx = createContext<Ctx>(null as any);
export const useGame = () => useContext(AppCtx);

const TABS = ["TILE", "ASSETS", "BRIDGE", "WAR", "TECH", "POLITICS", "LADDER", "DISPATCH", "GUIDE"] as const;
type Tab = (typeof TABS)[number];

export function App() {
  const dep = useMemo(pickDeployment, []);
  if (!dep)
    return (
      <div className="boot">
        <h1>CITADEL OS</h1>
        <p>No deployment found. Deploy the contracts first (see the README), which writes deployments/&lt;chainId&gt;.json.</p>
        <pre>anvil &amp;{"\n"}forge script script/DevDeploy.s.sol --rpc-url local --broadcast</pre>
      </div>
    );
  return <Game dep={dep} />;
}

function Game({ dep }: { dep: NonNullable<ReturnType<typeof pickDeployment>> }) {
  const chain = useMemo(() => new Chain_(dep), [dep]);
  const sync = useMemo(() => new WorldSync(chain), [chain]);
  const [world, setWorld] = useState<World>(emptyWorld());
  const [player, setPlayer] = useState<Player>();
  const [me, setMe] = useState<Address>();
  const [selected, select] = useState<Hex>();
  const [placing, setPlacing] = useState<Placing>();
  const [tab, setTab] = useState<Tab>("GUIDE");
  const [toasts, setToasts] = useState<Toast[]>([]);
  const [termLines, setTermLines] = useState<string[]>(["CITADEL OS v0.2 — type `help`."]);
  const [err, setErr] = useState<string>();
  const [fog, setFog] = useState(true);
  const [ao, setAo] = useState(0);
  const [focusReq, setFocusReq] = useState<{ q: number; r: number; n: number }>();
  const busy = useRef(false);

  const log = useCallback((line: string) => setTermLines((l) => [...l.slice(-400), line]), []);

  const refresh = useCallback(async () => {
    if (busy.current) return;
    busy.current = true;
    try {
      const w = await sync.tick(chain.address);
      setWorld(w);
      setErr(undefined);
      if (chain.address) setPlayer(await loadPlayer(chain, chain.address));
    } catch (e) {
      setErr(explainError(e));
    } finally {
      busy.current = false;
    }
  }, [chain, sync]);

  useEffect(() => {
    if (chain.isDev && !chain.address) {
      const saved = Number(localStorageGet("citadel.dev") ?? 1);
      chain.useDevAccount(saved);
      setMe(chain.address);
    }
    refresh();
    const t = setInterval(refresh, chain.isDev ? 3000 : 12000);
    return () => clearInterval(t);
  }, [chain, refresh]);

  const toast = (text: string, kind: Toast["kind"]) => {
    const id = Math.random();
    setToasts((t) => [...t, { id, text, kind }]);
    if (kind !== "busy") setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 6000);
    return id;
  };

  const act = useCallback(
    async (label: string, fn: () => Promise<unknown>) => {
      const id = toast(`${label}…`, "busy");
      log(`> ${label}`);
      try {
        await fn();
        busy.current = false;
        await refresh(); // show the new state before saying done, so buttons can't act on stale state
        setToasts((t) => t.filter((x) => x.id !== id));
        toast(`${label}: done`, "ok");
        log(`  ok`);
        return true;
      } catch (e) {
        setToasts((t) => t.filter((x) => x.id !== id));
        const m = explainError(e);
        toast(`${label}: ${m}`, "err");
        log(`  error: ${m}`);
        return false;
      }
    },
    [log, refresh],
  );

  const onSelect = (h?: Hex) => {
    select(h);
    if (h) setTab("TILE");
  };

  // hostile marches and sieges headed at the player's CITADEL
  const myIds = new Set([...world.citadels.values()].filter((c) => c.owner === me).map((c) => c.id));
  const threats =
    [...world.marches.values()].filter((m) => (m.kind === 1 || m.kind === 4 || m.kind === 5) && myIds.has(m.target)).length +
    [...world.sieges.values()].filter((g) => myIds.has(g.target)).length;

  const ctx: Ctx = { chain, world, player, me, selected, select: onSelect, placing, setPlacing, act, refresh, log, fog, setFog, ao, setAo: (a: number) => {
    setAo(a);
    select(undefined);
  },
    focusReq,
    focus: (h) => {
      if (h.ao !== undefined && h.ao !== ao) setAo(h.ao);
      setFocusReq({ q: h.q, r: h.r, n: Math.random() });
      onSelect({ q: h.q, r: h.r });
    },
  };

  return (
    <AppCtx.Provider value={ctx}>
      <div className="app">
        <TopBar
          onAccount={(i) => {
            chain.useDevAccount(i);
            localStorageSet("citadel.dev", String(i));
            setMe(chain.address);
            setPlayer(undefined);
            refresh();
          }}
          onConnect={async () => {
            try {
              await chain.connectInjected();
              setMe(chain.address);
              refresh();
            } catch (e) {
              toast(explainError(e), "err");
            }
          }}
          err={err}
        />
        <main>
          <section className="map">
            <HexMap />
          </section>
          <aside className="side">
            <nav className="tabs">
              {TABS.map((t) => (
                <button key={t} className={t === tab ? "on" : ""} onClick={() => setTab(t)}>
                  {t}
                  {t === "WAR" && threats > 0 && <span className="alert"> {threats}</span>}
                </button>
              ))}
            </nav>
            <div className="panel">
              {tab === "TILE" && <TilePanel />}
              {tab === "ASSETS" && <AssetsPanel />}
              {tab === "WAR" && <WarPanel />}
              {tab === "TECH" && <TechPanel />}
              {tab === "POLITICS" && <PoliticsPanel />}
              {tab === "LADDER" && <LadderPanel />}
              {tab === "BRIDGE" && <BridgePanel />}
              {tab === "DISPATCH" && <DispatchPanel />}
              {tab === "GUIDE" && <Guide />}
            </div>
          </aside>
        </main>
        <Terminal lines={termLines} />
        <div className="toasts">
          {toasts.map((t) => (
            <div key={t.id} className={`toast ${t.kind}`}>
              {t.text}
            </div>
          ))}
        </div>
      </div>
    </AppCtx.Provider>
  );
}

function TopBar({ onAccount, onConnect, err }: { onAccount: (i: number) => void; onConnect: () => void; err?: string }) {
  const { chain, world, player, me, act } = useGame();
  const dev = chain.isDev;
  return (
    <header className="top">
      <div className="brand">
        <span className="logo">⬢</span> CITADEL OS
        <span className="dim"> · {dev ? "local anvil" : chain.chain.name} · block {world.block.toString()}</span>
        {world.now > 0 && <span className="dim"> · {new Date(world.now * 1000).toUTCString().slice(5, 22)} UTC</span>}
      </div>
      {err && <div className="neterr">⚠ {err}</div>}
      <div className="wallet">
        {dev && (
          <>
            <button onClick={() => act("skip 1 hour", () => chain.skip(3600))}>+1h</button>
            <button onClick={() => act("skip 1 day", () => chain.skip(86400))}>+1d</button>
            <select value={devAccounts.findIndex((a) => a.address === me)} onChange={(e) => onAccount(Number(e.target.value))}>
              {devAccounts.map((a, i) => (
                <option key={a.address} value={i}>
                  dev #{i} {short(a.address)}
                </option>
              ))}
            </select>
          </>
        )}
        {!dev && !me && <button className="primary" onClick={onConnect}>Connect wallet</button>}
        {me && (
          <span className="who">
            {short(me)}
            {player && (
              <>
                {" "}
                · <b className="dk">{fmtDk(player.dk)} DK</b> · LVL {player.level.toString()}
              </>
            )}
          </span>
        )}
      </div>
    </header>
  );
}

function localStorageGet(k: string) {
  try {
    return localStorage.getItem(k);
  } catch {
    return null;
  }
}
function localStorageSet(k: string, v: string) {
  try {
    localStorage.setItem(k, v);
  } catch {
    /* private mode */
  }
}
