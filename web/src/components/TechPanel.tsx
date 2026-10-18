import { useEffect, useState } from "react";
import { useGame } from "../App";
import { BRANCHES, BRANCH_FIRST, FACTIONS, FACTION_COLORS, TECHS, hasTech } from "../lib/game";

type Pool = { points: bigint; rate: bigint; keys: bigint; completed: bigint; next: bigint };

export function TechPanel() {
  const { chain, world, me, act } = useGame();
  const myFaction = [...world.citadels.values()].find((c) => c.owner === me)?.faction ?? 0;
  const [faction, setFaction] = useState(myFaction);
  const [pools, setPools] = useState<Pool[]>([]);

  useEffect(() => {
    Promise.all(
      BRANCHES.map(async (_, b) => {
        const [points, rate, keys, completed] = await chain.read<[bigint, bigint, bigint, bigint]>("techTree", "pool", [faction, b]);
        const next = await chain.read<bigint>("techTree", "nextCost", [faction, b]);
        return { points, rate, keys, completed, next };
      }),
    ).then(setPools, () => {});
  }, [faction, world.block]);

  const bits = world.techBits[faction] ?? 0n;
  return (
    <div>
      <h2>Tech tree</h2>
      <div className="row wrap">
        {FACTIONS.map((f, i) => (
          <button key={f} className={i === faction ? "on" : ""} style={{ borderColor: FACTION_COLORS[i] }} onClick={() => setFaction(i)}>
            {f}
          </button>
        ))}
      </div>
      <p className="dim small">
        Every lit CITADEL researches one branch for its faction. A branch only advances while a RELIK whose tech is that
        branch is researching it — the RELIK holds the key. Technologies unlock in order.
      </p>
      {BRANCHES.map((b, i) => {
        const p = pools[i];
        return (
          <div key={b} className="branch">
            <h3>
              {b}{" "}
              {p && (
                <span className="dim">
                  · {p.points.toLocaleString()} pts · {p.rate.toLocaleString()}/day · {p.keys > 0n ? `🔑×${p.keys}` : "no RELIK key"}
                  {p.next > 0n && ` · next at ${p.next.toLocaleString()}`}
                </span>
              )}
            </h3>
            {p && p.next === 0n &&
              [...world.citadels.values()]
                .filter((c) => c.owner === me && c.faction === faction && c.generation === 0 && c.sekt === 0 && c.tech === i && c.research === i)
                .map((c) => (
                  <button
                    key={String(c.id)}
                    onClick={() => act(`claim branch MENTAT with RELIK ${c.id}`, () => chain.write("techTree", "claimBranchMentat", [i, c.id]))}
                  >
                    claim branch MENTAT (RELIK {c.id.toString()})
                  </button>
                ))}
            <ol>
              {TECHS[i].map(([name, effect], k) => (
                <li key={name} className={hasTech(bits, BRANCH_FIRST[i] + k) ? "done" : ""} title={effect}>
                  {name} <span className="dim">— {effect}</span>
                </li>
              ))}
            </ol>
          </div>
        );
      })}
    </div>
  );
}
