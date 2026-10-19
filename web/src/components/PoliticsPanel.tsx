import { useEffect, useState } from "react";
import { encodeFunctionData, type Hex } from "viem";
import { useGame } from "../App";
import { abis } from "../lib/chain";
import { KULT, fmtDk, short } from "../lib/game";
import { pilotInfo, type PilotInfo } from "../lib/player";

type Mine = PilotInfo & { bribes: bigint; collective: bigint; kult: number; kultOwed: bigint; registered: boolean; where: string };

export function PoliticsPanel() {
  const { chain, world, me, player, act } = useGame();
  const [count, setCount] = useState<[bigint, bigint]>([0n, 0n]);
  const [treasury, setTreasury] = useState<bigint>(0n);
  const [pilots, setPilots] = useState<Mine[]>([]);
  const [target, setTarget] = useState("");
  const [cost, setCost] = useState<bigint>();
  const [kult, setKult] = useState(0);
  const [props, setProps] = useState<any[]>([]);
  const [draft, setDraft] = useState({ fn: "distortion", value: "true", desc: "" });

  useEffect(() => {
    (async () => {
      const [sc, bought, orig] = await Promise.all([
        chain.read<bigint>("technocracy", "sovereignCount"),
        chain.read<bigint>("technocracy", "boughtSeats"),
        chain.read<bigint>("technocracy", "originalBought"),
      ]);
      setCount([sc, bought + orig]);
      setTreasury(await chain.read<bigint>("drakma", "balanceOf", [chain.dep.council]));
      if (!me || !player) return;
      const lit = [...world.citadels.values()].filter((c) => c.owner === me);
      const litPilots = (
        await Promise.all(lit.map(async (c) => ((await chain.read<bigint[]>("game", "pilotsOf", [c.id])) as bigint[]).map((p) => [p, `CITADEL ${c.id}`] as [bigint, string])))
      ).flat();
      const all: [bigint, string][] = [...player.walletPilots.map((p) => [p.id, "wallet"] as [bigint, string]), ...litPilots];
      setPilots(
        await Promise.all(
          all.map(async ([id, where]) => {
            const info = await pilotInfo(chain, id);
            const [bribes, collective, kultOwed, registered] = await Promise.all([
              chain.read<bigint>("technocracy", "activeBribes", [id]),
              chain.read<bigint>("technocracy", "pendingCollective", [id]),
              chain.read<bigint>("technocracy", "pendingKult", [id]),
              chain.read<boolean>("technocracy", "kultRegistered", [id]),
            ]);
            return { ...info, bribes, collective, kultOwed, registered, where };
          }),
        ),
      );
      const n = Number(await chain.read<bigint>("council", "proposalCount"));
      setProps(await Promise.all(Array.from({ length: n }, (_, i) => chain.read("council", "proposal", [BigInt(i)]).then((p: any) => ({ ...p, id: i })))));
    })().catch(() => {});
  }, [me, player, world.block]);

  useEffect(() => {
    if (!target) return setCost(undefined);
    chain.read<bigint>("technocracy", "overthrowCost", [BigInt(target)]).then(setCost, () => setCost(undefined));
  }, [target, world.block]);

  const sovereigns = pilots.filter((p) => p.sovereign);
  const commoners = pilots.filter((p) => !p.sovereign);

  function proposalData(): Hex {
    const c = { ...world.config };
    if (draft.fn === "distortion") c.distortion = draft.value === "true";
    else c[draft.fn] = BigInt(draft.value);
    return encodeFunctionData({ abi: abis.game as any, functionName: "setConfig", args: [c] });
  }

  return (
    <div>
      <h2>WARLORD TECHNOCRACY</h2>
      <p>
        SOVEREIGN COLLECTIVE: <b>{count[0].toString()}</b>/128 seats · {count[1].toString()}/64 bought
      </p>
      <p className="dim small">
        Sovereign PILOT can't be sieged in their CITADEL, lead sieges at 2×, and take a cut of every seat purchase,
        overthrow and bribe. Seats cost 4M DK; any PILOT can overthrow a sovereign for 4M + 1M per active bribe.
      </p>

      <h3>Your sovereigns</h3>
      {sovereigns.length === 0 && <p className="dim">None.</p>}
      {sovereigns.map((p) => (
        <div key={String(p.id)} className="item">
          <b>PILOT {p.id.toString()}</b> ({p.where}) · {p.bribes.toString()} active bribes · owed {fmtDk(p.collective)} DK
          <div className="row wrap">
            <select value={kult} onChange={(e) => setKult(Number(e.target.value))}>
              {KULT.map((k, i) => (
                <option key={k} value={i}>
                  {k}
                </option>
              ))}
            </select>
            <button onClick={() => act(`bribe ${KULT[kult]}`, () => chain.write("technocracy", "bribe", [kult, p.id]))}>bribe (100k DK)</button>
            <button onClick={() => act("claim collective share", () => chain.write("technocracy", "claimCollective", [p.id]))}>
              claim share
            </button>
          </div>
        </div>
      ))}

      <h3>Your other PILOT</h3>
      {commoners.length === 0 && <p className="dim">None.</p>}
      {commoners.map((p) => (
        <div key={String(p.id)} className="item">
          <b>PILOT {p.id.toString()}</b> ({p.where}) · {KULT[p.kult]}
          {p.registered && ` · KULT share ${fmtDk(p.kultOwed)} DK`}
          <div className="row wrap">
            <button disabled={count[1] >= 64n} onClick={() => act(`seat PILOT ${p.id}`, () => chain.write("technocracy", "becomeSovereign", [p.id]))}>
              buy a seat (4M DK)
            </button>
            {target && (
              <button className="red" onClick={() => act(`overthrow ${target}`, () => chain.write("technocracy", "overthrow", [BigInt(target), p.id]))}>
                overthrow #{target} ({cost !== undefined ? fmtDk(cost) : "?"} DK)
              </button>
            )}
            {!p.registered ? (
              <button onClick={() => act("join KULT payouts", () => chain.write("technocracy", "registerKult", [p.id]))}>join KULT payouts</button>
            ) : (
              p.kultOwed > 0n && (
                <button onClick={() => act("claim KULT share", () => chain.write("technocracy", "claimKult", [p.id]))}>claim KULT share</button>
              )
            )}
          </div>
        </div>
      ))}
      <label>
        sovereign to overthrow (PILOT id){" "}
        <input value={target} size={6} onChange={(e) => setTarget(e.target.value.replace(/\D/g, ""))} />
      </label>

      <h2>GRID MAELSTROM council</h2>
      <p>
        Treasury: <b className="dk">{fmtDk(treasury)} DRAKMA</b> — spent only by sovereign vote (propose a{" "}
        <code>drakma.transfer</code>).
      </p>
      <p className="dim small">
        Sovereigns vote on the game's levers (one vote per seat; a majority of seats passes). The council controls the game
        once its owner hands over ownership.
      </p>
      {props.map((p) => (
        <div key={p.id} className="item">
          <b>#{p.id}</b> {p.description || "(no description)"} · {p.yes}/{p.seats} yes · {p.no} no · by {short(p.proposer)}
          {p.executed ? <span className="tag">EXECUTED</span> : null}
          <div className="row wrap">
            {sovereigns.map((s) => (
              <span key={String(s.id)}>
                <button onClick={() => act(`vote yes #${p.id}`, () => chain.write("council", "vote", [BigInt(p.id), s.id, true]))}>
                  yes as {s.id.toString()}
                </button>
                <button onClick={() => act(`vote no #${p.id}`, () => chain.write("council", "vote", [BigInt(p.id), s.id, false]))}>no</button>
              </span>
            ))}
            {!p.executed && (
              <button onClick={() => act(`execute #${p.id}`, () => chain.write("council", "execute", [BigInt(p.id)]))}>execute</button>
            )}
          </div>
        </div>
      ))}
      {sovereigns.length > 0 && world.config && (
        <div className="form">
          <b>Propose a lever change</b>
          <select value={draft.fn} onChange={(e) => setDraft({ ...draft, fn: e.target.value })}>
            {Object.keys(world.config).map((k) => (
              <option key={k}>{k}</option>
            ))}
          </select>
          <input value={draft.value} onChange={(e) => setDraft({ ...draft, value: e.target.value })} placeholder="new value" />
          <input value={draft.desc} onChange={(e) => setDraft({ ...draft, desc: e.target.value })} placeholder="why" />
          <button
            onClick={() =>
              act("propose", () => chain.write("council", "propose", [sovereigns[0].id, chain.dep.game, proposalData(), draft.desc]))
            }
          >
            propose as PILOT {sovereigns[0].id.toString()}
          </button>
        </div>
      )}
    </div>
  );
}
