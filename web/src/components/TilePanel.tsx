import { useEffect, useMemo, useState } from "react";
import { useGame } from "../App";
import {
  BRANCHES,
  BUILDINGS,
  BUILDING_EFFECT,
  ENGINES,
  FACTIONS,
  FACTION_COLORS,
  FLEET,
  FLEET_ROLE,
  FLEET_SHORT,
  KULT,
  SEKT,
  SHIELDS,
  SUBJUGATION,
  WEAPONS,
  defaultTileBps,
  fmtDk,
  fmtDuration,
  fmtPct,
  hexDistance,
  short,
  tileKey,
} from "../lib/game";
import type { Citadel } from "../lib/world";
import { pilotInfo, type PilotInfo } from "../lib/player";
import { useVision } from "../lib/vision";

type Detail = {
  vault: bigint;
  rate: bigint;
  research: bigint;
  garrison: readonly bigint[];
  training: readonly any[];
  construction: any;
  stats: any;
  pilots: PilotInfo[];
  fleetPoints: bigint;
  pilotCost: bigint;
  costs: [bigint, bigint][];
  mentatClaimed: boolean;
};

function useDetail(c?: Citadel) {
  const { chain, world } = useGame();
  const [d, setD] = useState<Detail>();
  useEffect(() => {
    if (!c) return setD(undefined);
    let live = true;
    (async () => {
      const id = c.id;
      const [vault, rate, research, garrison, training, construction, stats, pilotIds, fleetPoints, pilotCost] =
        await Promise.all([
          chain.read<bigint>("game", "vaultOf", [id]),
          chain.read<bigint>("game", "miningRate", [id]),
          chain.read<bigint>("game", "researchRate", [id]),
          chain.read<readonly bigint[]>("game", "garrisonOf", [id]),
          chain.read<readonly any[]>("game", "trainingOf", [id]),
          chain.read("game", "constructionOf", [id]),
          chain.read("game", "statsOf", [id]),
          chain.read<readonly bigint[]>("game", "pilotsOf", [id]),
          chain.read<bigint>("game", "fleetPoints", [id]),
          chain.read<bigint>("game", "pilotMintCost", [id]),
        ]);
      const pilots = await Promise.all(pilotIds.map((p) => pilotInfo(chain, p)));
      const costs = await Promise.all(
        c.levels.map((lv, b) =>
          lv >= 10 ? Promise.resolve([0n, 0n] as [bigint, bigint]) : chain.read<[bigint, bigint]>("game", "buildCost", [b, lv + 1]),
        ),
      );
      const mentatClaimed =
        c.generation === 0 && c.sekt === 0 ? await chain.read<boolean>("techTree", "relikMentatClaimed", [id]) : true;
      if (live)
        setD({ vault, rate, research, garrison, training, construction, stats, pilots, fleetPoints, pilotCost, costs, mentatClaimed });
    })().catch(() => {});
    return () => {
      live = false;
    };
  }, [c?.id, world.block]);
  return d;
}

export function TilePanel() {
  const { world, selected, ao } = useGame();
  if (!selected) return <p className="dim">Select a tile on the grid.</p>;
  const id = world.byTile.get(tileKey(ao, selected.q, selected.r));
  const c = id !== undefined ? world.citadels.get(id) : undefined;
  return c ? <CitadelView c={c} /> : <EmptyTile />;
}

function EmptyTile() {
  const { selected, player, world } = useGame();
  const t = selected!;
  const inGrid = hexDistance(t, { q: 0, r: 0 }) <= world.radius;
  return (
    <div>
      <h2>
        Tile ({t.q}, {t.r})
      </h2>
      <p>
        {inGrid ? (
          <>
            Mining multiple <b>{(defaultTileBps(t, world.radius) / 10000).toFixed(2)}×</b> · {hexDistance(t, { q: 0, r: 0 })} from the
            core
          </>
        ) : (
          "Beyond the grid."
        )}
      </p>
      {inGrid && player && player.walletCitadels.length > 0 && (
        <p className="dim">
          To light one of your CITADEL here, go to ASSETS → “lite”, then click this tile.
        </p>
      )}
      {inGrid && player && player.walletPilots.length > 0 && (
        <p className="dim">PILOT in your wallet can found a GEN1 CITADEL within 2 tiles of your faction (ASSETS → colonize).</p>
      )}
    </div>
  );
}

function CitadelView({ c }: { c: Citadel }) {
  const { me, world } = useGame();
  const { seen } = useVision();
  const d = useDetail(c);
  const own = c.owner === me;
  if (!seen(c))
    return (
      <div className="cv">
        <h2>Unidentified signal</h2>
        <p>
          Something is lit at ({c.q}, {c.r}), beyond your faction's sight. Send DALAA MAX to scout it, or strike blind.
        </p>
        <ForeignActions c={c} />
      </div>
    );
  const scout = world.scouted.get(c.id);
  const siege = [...world.sieges.values()].find((s) => s.target === c.id);
  return (
    <div className="cv">
      <h2 style={{ borderColor: FACTION_COLORS[c.faction] }}>
        CITADEL {c.id.toString()} <span className="tag">GEN{c.generation}</span>{" "}
        {c.generation === 0 && <span className="tag">{SEKT[c.sekt]}</span>}
        {c.doomRiot && <span className="tag red">DOOM RIOT</span>}
      </h2>
      <p>
        <b style={{ color: FACTION_COLORS[c.faction] }}>{FACTIONS[c.faction]}</b> · {own ? "yours" : short(c.owner)} · AO {c.ao} (
        {c.q}, {c.r}) · researching {BRANCHES[c.research]}
      </p>
      <div className="grid2">
        <span>SHIELD</span>
        <b>{SHIELDS[c.shield]}</b>
        <span>ENGINE</span>
        <b>{ENGINES[c.engine]}</b>
        <span>WEAPONS</span>
        <b>{WEAPONS[c.weapon]}</b>
        <span>TECH</span>
        <b>{BRANCHES[c.tech]}</b>
      </div>
      {siege && (
        <div className="siegebar">
          UNDER SIEGE by CITADEL {siege.origin.toString()} · wave {siege.waves} ·{" "}
          <meter min={0} max={10000} value={siege.progress} /> {fmtPct(siege.progress)}
        </div>
      )}
      {d && (
        <>
          <div className="grid2">
            <span>Production</span>
            <b>{fmtDk(d.rate)} DK/day</b>
            <span>Vault</span>
            <b>{own || scout ? `${fmtDk(own ? d.vault : scout!.vault)} DK` : "—"}</b>
            <span>Research</span>
            <b>{d.research.toString()} pts/day</b>
            <span>FLEET POINTS</span>
            <b>{d.fleetPoints.toString()}</b>
            <span>Offense / Defense</span>
            <b>
              +{fmtPct(d.stats.offBps)} / +{fmtPct(d.stats.defBps)}
            </b>
            <span>Structure</span>
            <b>{d.stats.structure.toString()} DP</b>
          </div>
          <Garrison own={own} d={d} scout={scout?.garrison} />
          <Pilots pilots={d.pilots} />
          {own ? <OwnActions c={c} d={d} /> : <ForeignActions c={c} />}
        </>
      )}
    </div>
  );
}

function Garrison({ own, d, scout }: { own: boolean; d: Detail; scout?: readonly bigint[] }) {
  const g = own ? d.garrison : scout;
  return (
    <div>
      <h3>Garrison {!own && scout && <span className="dim">(scout report)</span>}</h3>
      {g ? (
        <div className="units">
          {FLEET.map((f, i) => (
            <span key={f} title={FLEET_ROLE[i]}>
              {FLEET_SHORT[i]} <b>{g[i].toString()}</b>
            </span>
          ))}
        </div>
      ) : (
        <p className="dim">Unknown. Send DALAA MAX to scout it.</p>
      )}
    </div>
  );
}

function Pilots({ pilots }: { pilots: PilotInfo[] }) {
  if (!pilots.length) return null;
  return (
    <div>
      <h3>PILOT</h3>
      {pilots.map((p) => (
        <div key={String(p.id)} className="pilot">
          #{p.id.toString()} GEN{p.generation} · {SUBJUGATION[p.subjugation]} · {KULT[p.kult]} · L{p.level}
          {p.sovereign && <span className="tag gold">SOVEREIGN</span>}
          {p.death && <span className="tag red">DEATH</span>}
        </div>
      ))}
    </div>
  );
}

function OwnActions({ c, d }: { c: Citadel; d: Detail }) {
  const { chain, act, world, player } = useGame();
  const [n, setN] = useState<string[]>(["10", "10", "1", "10"]);
  const k = d.construction;
  const building = k.end > 0n;
  const left = Number(k.end) - world.now;
  const claimAt = Number(c.lastClaim) + Number(world.config?.claimInterval ?? 0);
  const id = c.id;
  return (
    <div>
      <h3>Buildings</h3>
      {building && (
        <div className="row">
          Building {BUILDINGS[k.building]} L{k.level} · {fmtDuration(left)}
          <button
            onClick={() =>
              act(`hurry ${BUILDINGS[k.building]}`, () => chain.write("game", "hurryBuild", [id]))
            }
          >
            hurry
          </button>
        </div>
      )}
      <table className="bld">
        <tbody>
          {BUILDINGS.map((b, i) => {
            const lv = c.levels[i];
            const [cost, time] = d.costs[i];
            const capped = i !== 0 && lv + 1 > 1 && lv + 1 > c.levels[0];
            return (
              <tr key={b} title={BUILDING_EFFECT[i]}>
                <td>{b}</td>
                <td>L{lv}</td>
                <td className="dim">{lv < 10 ? `${fmtDk(cost)} DK · ${fmtDuration(Number(time))}` : "max"}</td>
                <td>
                  <button
                    disabled={building || lv >= 10 || capped}
                    title={capped ? "Raise the CITADEL level first" : ""}
                    onClick={() => act(`build ${b} L${lv + 1}`, () => chain.write("game", "build", [id, i]))}
                  >
                    ▲
                  </button>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>

      <h3>Train fleet</h3>
      <table className="bld">
        <tbody>
          {FLEET.map((f, i) => {
            const ft = world.fleetTypes[i];
            const b = d.training[i];
            const queued = Number(b.total - b.done);
            const ready = c.levels[5] >= (ft?.academy ?? 1) && (i !== 3 || d.stats.dalaa);
            return (
              <tr key={f} title={`${FLEET_ROLE[i]} · OP ${ft?.op} DP ${ft?.dp} · carry ${ft?.carry}`}>
                <td>{FLEET_SHORT[i]}</td>
                <td className="dim">{ft ? `${fmtDk(ft.cost)} DK` : ""}</td>
                <td>
                  <input
                    value={n[i]}
                    size={4}
                    onChange={(e) => setN((x) => x.map((v, j) => (j === i ? e.target.value : v)))}
                  />
                </td>
                <td>
                  <button
                    disabled={!ready}
                    title={!ready ? (i === 3 ? "Needs ATOMIC ENGINE tech + academy" : `Needs FLEET ACADEMY L${ft?.academy}`) : ""}
                    onClick={() => act(`train ${n[i]} ${f}`, () => chain.write("game", "train", [id, i, BigInt(n[i] || "0")]))}
                  >
                    train
                  </button>
                  {queued > 0 && (
                    <button onClick={() => act(`hurry ${f}`, () => chain.write("game", "hurryTraining", [id, i]))}>
                      hurry {queued}
                    </button>
                  )}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>

      <h3>Command</h3>
      <div className="row wrap">
        <button
          disabled={world.now < claimAt}
          onClick={() => act(`claim ${fmtDk(d.vault)} DK`, () => chain.write("game", "claim", [id]))}
        >
          claim {world.now < claimAt ? `in ${fmtDuration(claimAt - world.now)}` : `${fmtDk(d.vault)} DK`}
        </button>
        <button
          disabled={d.fleetPoints < d.pilotCost}
          onClick={() => act("mint next-gen PILOT", () => chain.write("game", "mintPilot", [id]))}
        >
          mint GEN{c.generation + 1} PILOT ({d.pilotCost.toString()} FP)
        </button>
        <select
          value={c.research}
          onChange={(e) =>
            act(`research ${BRANCHES[Number(e.target.value)]}`, () => chain.write("game", "setResearch", [id, Number(e.target.value)]))
          }
        >
          {BRANCHES.map((b, i) => (
            <option key={b} value={i}>
              research: {b}
            </option>
          ))}
        </select>
        <select
          value={c.faction}
          onChange={(e) => act(`join ${FACTIONS[Number(e.target.value)]}`, () => chain.write("game", "setFaction", [id, Number(e.target.value)]))}
        >
          {FACTIONS.map((f, i) => (
            <option key={f} value={i}>
              faction: {f}
            </option>
          ))}
        </select>
        {c.mentat === 0n &&
          player?.walletMentats.map((m) => (
            <button key={String(m.id)} onClick={() => act(`attach MENTAT ${m.id}`, () => chain.write("game", "attachMentat", [id, m.id]))}>
              attach MENTAT #{m.id.toString()}
            </button>
          ))}
        {c.mentat > 0n && <span className="tag">MENTAT #{(c.mentat - 1n).toString()}</span>}
        {!d.mentatClaimed && (
          <button onClick={() => act(`claim MENTAT for RELIK ${id}`, () => chain.write("techTree", "claimRelikMentat", [id]))}>
            claim RELIK MENTAT
          </button>
        )}
        <button className="danger" onClick={() => act(`unlite CITADEL ${id}`, () => chain.write("game", "unlite", [id]))}>
          unlite
        </button>
      </div>
    </div>
  );
}

function ForeignActions({ c }: { c: Citadel }) {
  const { world, me, chain, act, player } = useGame();
  const mine = useMemo(() => [...world.citadels.values()].filter((x) => x.owner === me), [world.citadels, me]);
  const [from, setFrom] = useState<string>("");
  const [u, setU] = useState(["0", "0", "0", "0"]);
  const [pilot, setPilot] = useState("");
  const src = world.citadels.get(BigInt(from || (mine[0]?.id ?? 0n)));
  if (!mine.length) return <p className="dim">Light a CITADEL to the grid to interact with others.</p>;
  const units = u.map((x) => BigInt(x || "0"));
  const sameAo = !src || src.ao === c.ao;
  const dist = src ? hexDistance(src, c) + (sameAo ? 0 : Number(world.config?.aoGapTiles ?? 12)) : 0;
  const slowest = Math.max(...units.map((n, i) => (n > 0n ? world.fleetTypes[i]?.secsPerTile ?? 0 : 0)));
  const eta = (sameAo && dist <= 1) || world.config?.distortion ? 0 : dist * slowest;
  const ally = src && src.faction === c.faction;
  const s = src!.id;
  return (
    <div>
      <h3>Orders</h3>
      <div className="row wrap">
        from
        <select value={from || String(mine[0].id)} onChange={(e) => setFrom(e.target.value)}>
          {mine.map((m) => (
            <option key={String(m.id)} value={String(m.id)}>
              CITADEL {m.id.toString()} ({m.q},{m.r})
            </option>
          ))}
        </select>
        <span className="dim">
          {dist} tiles · {eta === 0 ? "instant (subgrid distortion)" : `ETA ${fmtDuration(eta)}`}
        </span>
      </div>
      <div className="units">
        {FLEET_SHORT.map((f, i) => (
          <label key={f}>
            {f}
            <input value={u[i]} size={5} onChange={(e) => setU((x) => x.map((v, j) => (j === i ? e.target.value : v)))} />
          </label>
        ))}
      </div>
      <div className="row wrap">
        <button className="red" onClick={() => act(`raid CITADEL ${c.id}`, () => chain.write("game", "raid", [s, c.id, units]))}>
          RAID
        </button>
        <button onClick={() => act(`scout CITADEL ${c.id}`, () => chain.write("game", "scout", [s, c.id, [0n, 0n, 0n, units[3]]]))}>
          SCOUT (DALAA only)
        </button>
        <button onClick={() => act(`reinforce CITADEL ${c.id}`, () => chain.write("game", "reinforce", [s, c.id, units]))}>
          REINFORCE{ally ? " ally" : ""}
        </button>
      </div>
      <div className="row wrap">
        <select value={pilot} onChange={(e) => setPilot(e.target.value)}>
          <option value="">siege without PILOT (level only)</option>
          {player?.walletPilots.map((p) => (
            <option key={String(p.id)} value={String(p.id)}>
              PILOT #{p.id.toString()} GEN{p.generation} {SUBJUGATION[p.subjugation]}
              {p.sovereign ? " ★" : ""}
            </option>
          ))}
        </select>
        <button
          className="red"
          onClick={() =>
            act(`SIEGE CITADEL ${c.id}`, () => chain.write("game", "siege", [s, c.id, units, pilot ? BigInt(pilot) + 1n : 0n]))
          }
        >
          LAY SIEGE
        </button>
      </div>
      <p className="dim small">
        A siege fights one wave per hour for at least 48 hours. With a PILOT, victory founds your own CITADEL on this
        tile; a failed GEN0 PILOT retreats, later generations die. Sovereign-hosting CITADEL can't be sieged.
      </p>
    </div>
  );
}
