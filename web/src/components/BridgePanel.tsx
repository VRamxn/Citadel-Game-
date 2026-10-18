import { useEffect, useState } from "react";
import type { Address, Hash } from "viem";
import { publicActionsL1, publicActionsL2, walletActionsL1 } from "viem/op-stack";
import { createWalletClient, custom } from "viem";
import { useGame } from "../App";
import { fmtDk } from "../lib/game";

const CITADEL_IDS = 1024;
const PILOT_IDS = 1140; // minted on mainnet
type Claim = { amount: string; proof: Hash[] };
type Pending = { hash: Hash; what: string; at: number };

const store = {
  get: (k: string) => {
    try {
      return JSON.parse(localStorage.getItem(k) ?? "[]");
    } catch {
      return [];
    }
  },
  set: (k: string, v: unknown) => {
    try {
      localStorage.setItem(k, JSON.stringify(v));
    } catch {
      /* private mode */
    }
  },
};

/** Original CITADEL and PILOT cross from Ethereum into a vault and play on L2; the DRAKMA carry-over is claimed here. */
export function BridgePanel() {
  const { chain, me, player, act, world } = useGame();
  const l1 = chain.l1;
  const local = l1?.dep.chainId === chain.dep.chainId;
  const [originals, setOriginals] = useState<{ citadels: bigint[]; pilots: bigint[] }>();
  const [scanning, setScanning] = useState(false);
  const [pick, setPick] = useState<Set<string>>(new Set());
  const [claim, setClaim] = useState<Claim | null>();
  const [claimed, setClaimed] = useState<boolean>();
  const [approved, setApproved] = useState<[boolean, boolean]>([false, false]);
  const pendingKey = `citadel.withdrawals.${chain.dep.chainId}.${me}`;
  const [pending, setPending] = useState<Pending[]>(() => store.get(pendingKey));

  // the carry-over claim list is published with the client (data/claims.json -> web/public/claims.json)
  useEffect(() => {
    if (!me) return;
    fetch("./claims.json")
      .then((r) => (r.ok ? r.json() : null))
      .then((j) => {
        if (!j) return setClaim(null);
        const k = Object.keys(j.claims).find((a) => a.toLowerCase() === me.toLowerCase());
        setClaim(k ? j.claims[k] : null);
      })
      .catch(() => setClaim(null));
    chain.read<boolean>("claim", "claimed", [me]).then(setClaimed, () => {});
  }, [me, world.block]);

  useEffect(() => {
    if (!me || !l1) return;
    Promise.all([
      chain.readL1<boolean>("citadelOriginal", "isApprovedForAll", [me, l1.dep.vault]),
      chain.readL1<boolean>("pilotOriginal", "isApprovedForAll", [me, l1.dep.vault]),
    ]).then(([a, b]) => setApproved([a, b]), () => {});
  }, [me, world.block]);

  async function scan() {
    if (!me || !l1) return;
    setScanning(true);
    const owned = async (name: "citadelOriginal" | "pilotOriginal", n: number) => {
      const out: bigint[] = [];
      for (let start = 0; start < n; start += 100) {
        const ids = Array.from({ length: Math.min(100, n - start) }, (_, i) => BigInt(start + i));
        const owners = await Promise.all(ids.map((id) => chain.readL1<Address>(name, "ownerOf", [id]).catch(() => undefined)));
        owners.forEach((o, i) => o?.toLowerCase() === me.toLowerCase() && out.push(ids[i]));
      }
      return out;
    };
    try {
      setOriginals({ citadels: await owned("citadelOriginal", CITADEL_IDS), pilots: await owned("pilotOriginal", PILOT_IDS) });
    } finally {
      setScanning(false);
    }
  }

  const picked = (kind: "c" | "p") => [...pick].filter((k) => k[0] === kind).map((k) => BigInt(k.slice(1)));
  const toggle = (k: string) => setPick((s) => (s.has(k) ? (s.delete(k), new Set(s)) : new Set(s.add(k))));

  async function deposit() {
    for (const [kind, coll, name] of [["c", 0, "citadelOriginal"], ["p", 1, "pilotOriginal"]] as const) {
      const ids = picked(kind);
      if (!ids.length) continue;
      if (!approved[coll]) await chain.writeL1(name, "setApprovalForAll", [l1!.dep.vault, true]);
      await chain.writeL1("vault", "deposit", [coll, ids, me]);
    }
    setPick(new Set());
    setOriginals(undefined);
  }

  async function sendHome(coll: 0 | 1, ids: bigint[]) {
    const receipt = await chain.write("bridge", "withdraw", [coll, ids, me]);
    if (!local) {
      const next = [...pending, { hash: receipt.transactionHash, what: `${coll ? "PILOT" : "CITADEL"} ${ids.join(", ")}`, at: Date.now() }];
      setPending(next);
      store.set(pendingKey, next);
    }
  }

  if (!me) return <p>Connect a wallet to bridge.</p>;
  if (!l1) return <p className="dim">No vault is deployed for this network yet.</p>;
  const copies = {
    citadels: player?.walletCitadels.filter((c) => c.id < 1024n).map((c) => c.id) ?? [],
    pilots: player?.walletPilots.filter((p) => p.id < 2048n).map((p) => p.id) ?? [],
  };

  return (
    <div>
      <h2>DRAKMA carry-over</h2>
      {claim === undefined && <p className="dim">Checking the snapshot…</p>}
      {claim === null && <p className="dim">This wallet isn't in the snapshot of old DRAKMA, CITADEL and PILOT holders.</p>}
      {claim && (
        <div className="item">
          <b>{fmtDk(BigInt(claim.amount))} DRAKMA</b> — your old DRAKMA balance plus the equal share every holder gets.
          <div className="row">
            {claimed ? (
              <span className="tag">CLAIMED</span>
            ) : (
              <button className="primary" onClick={() => act("claim DRAKMA", () => chain.write("claim", "claim", [BigInt(claim.amount), claim.proof]))}>
                claim
              </button>
            )}
          </div>
          <p className="dim small">A Safe or other wallet that only exists on {chain.l1Name} claims through the relay contract there, naming an address on {chain.chain.name} to receive it.</p>
        </div>
      )}

      <h2>Originals on {chain.l1Name}</h2>
      <p className="dim small">
        Your original CITADEL and PILOT go into the vault on {chain.l1Name} and appear in this wallet on {chain.chain.name} a few
        minutes later. Their traits, levels and sovereignty come with them. Bring them home any time.
      </p>
      <div className="row wrap">
        <button onClick={scan} disabled={scanning}>
          {scanning ? "scanning…" : "find my originals"}
        </button>
        {l1.dep.originalsFaucet && l1.dep.originalsFaucet !== "0x0000000000000000000000000000000000000000" && (
          <button onClick={() => act("testnet originals", () => chain.writeL1("originalsFaucet", "drip"))}>
            testnet: get 2 CITADEL + 2 PILOT
          </button>
        )}
      </div>
      {originals && (
        <div className="item">
          {originals.citadels.length + originals.pilots.length === 0 && <span className="dim">None in this wallet on {chain.l1Name}.</span>}
          {originals.citadels.map((id) => (
            <label key={`c${id}`} className="chk">
              <input type="checkbox" checked={pick.has(`c${id}`)} onChange={() => toggle(`c${id}`)} /> CITADEL {id.toString()}
            </label>
          ))}
          {originals.pilots.map((id) => (
            <label key={`p${id}`} className="chk">
              <input type="checkbox" checked={pick.has(`p${id}`)} onChange={() => toggle(`p${id}`)} /> PILOT {id.toString()}
            </label>
          ))}
          {pick.size > 0 && (
            <button className="primary" onClick={() => act(`bridge ${pick.size} to ${chain.chain.name}`, deposit)}>
              bridge {pick.size} to {chain.chain.name}
            </button>
          )}
        </div>
      )}

      <h2>Bridged copies in this wallet</h2>
      {copies.citadels.length + copies.pilots.length === 0 && (
        <p className="dim">None. (Copies lit to the grid have to be unlit before they can go home.)</p>
      )}
      {copies.citadels.map((id) => (
        <div key={`c${id}`} className="row">
          CITADEL {id.toString()}
          <button onClick={() => act(`send CITADEL ${id} home`, () => sendHome(0, [id]))}>send home</button>
        </div>
      ))}
      {copies.pilots.map((id) => (
        <div key={`p${id}`} className="row">
          PILOT {id.toString()}
          <button onClick={() => act(`send PILOT ${id} home`, () => sendHome(1, [id]))}>send home</button>
        </div>
      ))}

      {!local && <Withdrawals pending={pending} setPending={(p) => (setPending(p), store.set(pendingKey, p))} />}
    </div>
  );
}

/** OP Stack withdrawals: wait for the L2 output, prove on L1, wait out the challenge period, finalize on L1. */
function Withdrawals({ pending, setPending }: { pending: Pending[]; setPending: (p: Pending[]) => void }) {
  const { chain, act, me } = useGame();
  const [status, setStatus] = useState<Record<string, string>>({});
  const l1 = chain.l1!;
  const l1Pub = l1.pub.extend(publicActionsL1());
  const l2Pub = chain.pub.extend(publicActionsL2());

  useEffect(() => {
    pending.forEach(async (p) => {
      try {
        const receipt = await chain.pub.getTransactionReceipt({ hash: p.hash });
        const s = await l1Pub.getWithdrawalStatus({ receipt, targetChain: chain.chain, chain: undefined } as any);
        setStatus((x) => ({ ...x, [p.hash]: s }));
      } catch {
        setStatus((x) => ({ ...x, [p.hash]: "unknown" }));
      }
    });
  }, [pending.length]);

  const l1Wallet = () =>
    createWalletClient({ account: me!, chain: l1.chain, transport: custom((window as any).ethereum) }).extend(walletActionsL1());

  async function prove(p: Pending) {
    const receipt = await chain.pub.getTransactionReceipt({ hash: p.hash });
    const [withdrawal] = (await import("viem/op-stack")).getWithdrawals(receipt);
    const output = await l1Pub.waitToProve({ receipt, targetChain: chain.chain, chain: undefined } as any);
    const args = await l2Pub.buildProveWithdrawal({ ...(output as any), withdrawal });
    await (window as any).ethereum.request({ method: "wallet_switchEthereumChain", params: [{ chainId: `0x${l1.chain.id.toString(16)}` }] });
    const hash = await l1Wallet().proveWithdrawal(args as any);
    await l1Pub.waitForTransactionReceipt({ hash });
  }

  async function finalize(p: Pending) {
    const receipt = await chain.pub.getTransactionReceipt({ hash: p.hash });
    const [withdrawal] = (await import("viem/op-stack")).getWithdrawals(receipt);
    await (window as any).ethereum.request({ method: "wallet_switchEthereumChain", params: [{ chainId: `0x${l1.chain.id.toString(16)}` }] });
    const hash = await l1Wallet().finalizeWithdrawal({ targetChain: chain.chain as any, withdrawal } as any);
    await l1Pub.waitForTransactionReceipt({ hash });
    setPending(pending.filter((x) => x.hash !== p.hash));
  }

  if (!pending.length) return null;
  return (
    <div>
      <h2>On the way home</h2>
      <p className="dim small">
        Withdrawals from {chain.chain.name} are proven on {chain.l1Name} about an hour after you send them, then finalized after the
        rollup's challenge period (7 days), when the originals are released from the vault.
      </p>
      {pending.map((p) => {
        const s = status[p.hash] ?? "checking";
        return (
          <div key={p.hash} className="item">
            <b>{p.what}</b> · <span className="dim">{s}</span>
            <div className="row">
              {s === "ready-to-prove" && <button onClick={() => act("prove withdrawal", () => prove(p))}>prove on {chain.l1Name}</button>}
              {s === "ready-to-finalize" && (
                <button className="primary" onClick={() => act("finalize withdrawal", () => finalize(p))}>
                  release from vault
                </button>
              )}
              {s === "finalized" && <button onClick={() => setPending(pending.filter((x) => x.hash !== p.hash))}>done</button>}
            </div>
          </div>
        );
      })}
    </div>
  );
}
