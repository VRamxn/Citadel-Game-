import { useEffect, useState } from "react";
import { useGame } from "../App";
import { BRANCHES, ENGINES, FACTIONS, FACTION_COLORS, KULT, SEKT, SHIELDS, SUBJUGATION, SUBJUGATION_EFFECT, WEAPONS, fmtDk } from "../lib/game";

export function AssetsPanel() {
  const { chain, player, me, world, act, setPlacing, focus } = useGame();
  const [approved, setApproved] = useState<boolean[]>();
  const [lite, setLite] = useState<{ id: bigint; faction: number; research: number; pilots: bigint[] }>();
  const [colFaction, setColFaction] = useState(0);

  useEffect(() => {
    if (!me) return;
    Promise.all(
      (["citadel", "pilot", "mentat"] as const).map((t) => chain.read<boolean>(t, "isApprovedForAll", [me, chain.dep.game])),
    ).then(setApproved, () => {});
  }, [me, world.block]);

  if (!me) return <p>Connect a wallet to see your assets.</p>;
  if (!player) return <p className="dim">Loading…</p>;
  const mine = [...world.citadels.values()].filter((c) => c.owner === me);
  const allApproved = approved?.every(Boolean);

  return (
    <div>
      <h2>Your assets</h2>
      <p>
        <b className="dk">{fmtDk(player.dk)} DK</b> · score {player.score.toString()} · WALLET LEVEL {player.level.toString()} ·{" "}
        {(Number(player.eth) / 1e18).toFixed(3)} ETH
      </p>
      {!player.dripped && (
        <button className="primary" onClick={() => act("testnet faucet", () => chain.write("faucet", "drip"))}>
          Claim starter kit: 2 CITADEL, 2 PILOT, 5M DK
        </button>
      )}
      {approved && !allApproved && (
        <div className="row wrap">
          <span className="dim">The game needs approval to hold your NFTs while they're on the grid:</span>
          {(["citadel", "pilot", "mentat"] as const).map(
            (t, i) =>
              !approved[i] && (
                <button key={t} onClick={() => act(`approve ${t}`, () => chain.write(t, "setApprovalForAll", [chain.dep.game, true]))}>
                  approve {t.toUpperCase()}
                </button>
              ),
          )}
        </div>
      )}

      <h3>On the grid</h3>
      {mine.length === 0 && <p className="dim">None yet.</p>}
      {mine.map((c) => (
        <div key={String(c.id)} className="item click" onClick={() => focus(c)}>
          <i className="dot" style={{ background: FACTION_COLORS[c.faction] }} /> CITADEL {c.id.toString()} · ({c.q},{c.r}) · L
          {c.levels[0]} · {FACTIONS[c.faction]}
          {c.besieged > 0 && <span className="tag red">BESIEGED</span>}
        </div>
      ))}

      <h3>CITADEL in wallet</h3>
      {player.walletCitadels.length === 0 && <p className="dim">None.</p>}
      {player.walletCitadels.map(({ id, traits: t, pilotClaimed, levels }) => (
        <div key={String(id)} className="item">
          <div>
            <b>CITADEL {id.toString()}</b> GEN{t.generation} {t.generation === 0 && SEKT[t.sekt]} · {SHIELDS[t.shield]} /{" "}
            {ENGINES[t.engine]} / {WEAPONS[t.weapon]} · {BRANCHES[t.tech]}
            {levels.some((l) => l > 0) && <span className="dim"> · levels {levels.join("/")}</span>}
          </div>
          <div className="row wrap">
            <button onClick={() => setLite({ id, faction: 0, research: t.tech, pilots: [] })}>lite…</button>
            {!pilotClaimed && (
              <button onClick={() => act(`claim PILOT for CITADEL ${id}`, () => chain.write("technocracy", "claimPilot", [id]))}>
                claim PILOT (64k DK)
              </button>
            )}
            {t.generation === 0 && t.sekt === 0 && <RelikMentat id={id} />}
          </div>
          {lite?.id === id && (
            <div className="form">
              <label>
                faction
                <select value={lite.faction} onChange={(e) => setLite({ ...lite, faction: Number(e.target.value) })}>
                  {FACTIONS.map((f, i) => (
                    <option key={f} value={i}>
                      {f}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                research
                <select value={lite.research} onChange={(e) => setLite({ ...lite, research: Number(e.target.value) })}>
                  {BRANCHES.map((b, i) => (
                    <option key={b} value={i}>
                      {b}
                      {i === t.tech ? " (2×)" : ""}
                    </option>
                  ))}
                </select>
              </label>
              <div>
                PILOT to bring:
                {player.walletPilots.map((p) => (
                  <label key={String(p.id)} className="chk">
                    <input
                      type="checkbox"
                      checked={lite.pilots.includes(p.id)}
                      onChange={(e) =>
                        setLite({
                          ...lite,
                          pilots: e.target.checked ? [...lite.pilots, p.id] : lite.pilots.filter((x) => x !== p.id),
                        })
                      }
                    />
                    #{p.id.toString()} {SUBJUGATION[p.subjugation]}
                  </label>
                ))}
              </div>
              <button
                className="primary"
                disabled={!allApproved}
                onClick={() => {
                  setPlacing({ kind: "lite", citadelId: id, pilots: lite.pilots, faction: lite.faction, research: lite.research });
                  setLite(undefined);
                }}
              >
                choose a tile on the map →
              </button>
            </div>
          )}
        </div>
      ))}

      <h3>PILOT in wallet</h3>
      {player.walletPilots.length === 0 && <p className="dim">None.</p>}
      {player.walletPilots.map((p) => (
        <div key={String(p.id)} className="item">
          <div>
            <b>PILOT {p.id.toString()}</b> GEN{p.generation} · {SUBJUGATION[p.subjugation]} ({SUBJUGATION_EFFECT[p.subjugation]}) ·{" "}
            {KULT[p.kult]} · L{p.level}
            {p.sovereign && <span className="tag gold">SOVEREIGN</span>}
            {p.death && <span className="tag red">DEATH</span>}
          </div>
          <div className="row wrap">
            {p.level < 9 && (
              <button onClick={() => act(`uplevel PILOT ${p.id}`, () => chain.write("pilot", "uplevel", [p.id]))}>
                uplevel ({(p.level + 1) * 100}k DK)
              </button>
            )}
            <select value={colFaction} onChange={(e) => setColFaction(Number(e.target.value))}>
              {FACTIONS.map((f, i) => (
                <option key={f} value={i}>
                  {f}
                </option>
              ))}
            </select>
            <button
              disabled={!allApproved}
              onClick={() => setPlacing({ kind: "colonize", pilotId: p.id, faction: colFaction })}
              title="Found a GEN1 CITADEL on free grid within 2 tiles of your faction (250k DK)"
            >
              colonize…
            </button>
          </div>
        </div>
      ))}

      <h3>MENTAT in wallet</h3>
      {player.walletMentats.length === 0 && <p className="dim">None. RELIK owners can claim one; factions earn more by completing tech branches.</p>}
      {player.walletMentats.map((m) => (
        <div key={String(m.id)} className="item">
          <b>MENTAT {m.id.toString()}</b> L{m.level}
          {m.level < 9 && (
            <button onClick={() => act(`uplevel MENTAT ${m.id}`, () => chain.write("mentat", "uplevel", [m.id]))}>
              uplevel ({(m.level + 1) * 250}k DK)
            </button>
          )}
          <span className="dim"> · attach it from a CITADEL's panel</span>
        </div>
      ))}
    </div>
  );
}

function RelikMentat({ id }: { id: bigint }) {
  const { chain, act, world } = useGame();
  const [claimed, setClaimed] = useState(true);
  useEffect(() => {
    chain.read<boolean>("techTree", "relikMentatClaimed", [id]).then(setClaimed, () => {});
  }, [id, world.block]);
  if (claimed) return null;
  return (
    <button onClick={() => act(`claim MENTAT for RELIK ${id}`, () => chain.write("techTree", "claimRelikMentat", [id]))}>
      claim MENTAT
    </button>
  );
}
