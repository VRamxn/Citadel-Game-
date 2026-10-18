import { useEffect, useState } from "react";
import type { Address } from "viem";
import { useGame } from "../App";
import { FACTIONS, FACTION_COLORS, fmtDk, short } from "../lib/game";

type Row = { owner: Address; score: bigint; level: bigint; fp: bigint; citadels: number; rate: bigint; factions: Set<number> };

/** The season ladder: every wallet on the grid ranked by score (CITADEL + building levels²), with FLEET POINTS. */
export function LadderPanel() {
  const { chain, world, me } = useGame();
  const [rows, setRows] = useState<Row[]>([]);
  const [season, setSeason] = useState<number>();

  useEffect(() => {
    (async () => {
      const by = new Map<Address, Row>();
      await Promise.all(
        [...world.citadels.values()].map(async (c) => {
          const [fp, rate] = await Promise.all([
            chain.read<bigint>("game", "fleetPoints", [c.id]),
            chain.read<bigint>("game", "miningRate", [c.id]),
          ]);
          const r = by.get(c.owner) ?? { owner: c.owner, score: 0n, level: 0n, fp: 0n, citadels: 0, rate: 0n, factions: new Set() };
          r.fp += fp;
          r.rate += rate;
          r.citadels++;
          r.factions.add(c.faction);
          by.set(c.owner, r);
        }),
      );
      await Promise.all(
        [...by.values()].map(async (r) => {
          [r.score, r.level] = await Promise.all([
            chain.read<bigint>("game", "walletScore", [r.owner]),
            chain.read<bigint>("game", "walletLevel", [r.owner]),
          ]);
        }),
      );
      setRows([...by.values()].sort((a, b) => (b.score === a.score ? Number(b.fp - a.fp) : Number(b.score - a.score))));
      setSeason(Number(await chain.read("game", "season")));
    })().catch(() => {});
  }, [world.block]);

  const factionTotals = FACTIONS.map((_, f) => rows.filter((r) => r.factions.has(f)).reduce((n, r) => n + r.citadels, 0));
  return (
    <div>
      <h2>Ladder · season {season ?? "…"}</h2>
      <div className="row wrap">
        {FACTIONS.map((f, i) => (
          <span key={f} className="tag" style={{ color: FACTION_COLORS[i], borderColor: FACTION_COLORS[i] }}>
            {f} {factionTotals[i]}
          </span>
        ))}
      </div>
      <table className="bld ladder">
        <thead>
          <tr>
            <td>#</td>
            <td>wallet</td>
            <td>LVL</td>
            <td>score</td>
            <td>FP</td>
            <td>CIT</td>
            <td>DK/day</td>
          </tr>
        </thead>
        <tbody>
          {rows.map((r, i) => (
            <tr key={r.owner} className={r.owner === me ? "me" : ""}>
              <td>{i + 1}</td>
              <td>
                {[...r.factions].map((f) => (
                  <i key={f} className="dot" style={{ background: FACTION_COLORS[f] }} />
                ))}{" "}
                {r.owner === me ? "you" : short(r.owner)}
              </td>
              <td>{r.level.toString()}</td>
              <td>{r.score.toString()}</td>
              <td>{r.fp.toString()}</td>
              <td>{r.citadels}</td>
              <td>{fmtDk(r.rate)}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <p className="dim small">
        Score = 50 per GEN0 CITADEL (10 per later generation) + the sum of building level². WALLET LEVEL = √score. Season
        rewards are tallied from this ladder when a season ends.
      </p>
    </div>
  );
}
