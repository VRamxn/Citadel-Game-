import { useGame } from "../App";
import { FACTIONS, FACTION_COLORS, FACTION_LEADERS } from "../lib/game";

export function Guide() {
  const { chain } = useGame();
  return (
    <div className="guide">
      <h2>CITADEL</h2>
      <p>
        A dystopian post-human war game, fully on-chain. Survive, grow, and acquire <b>DRAKMA</b>. CITADEL are slow-play:
        raids take hours, sieges at least two days.
      </p>
      <h3>Start</h3>
      <ol>
        {!chain.isDev && <li>Connect a wallet on {chain.chain.name}.</li>}
        <li>
          <b>BRIDGE</b> → bring your original CITADEL and PILOT over from {chain.l1Name || "Ethereum"}, and claim your DRAKMA
          (your old balance plus an equal share for every holder).{" "}
          {chain.dep.faucet && chain.dep.faucet !== "0x0000000000000000000000000000000000000000" && "On a testnet, the BRIDGE and ASSETS tabs have faucets."}
        </li>
        <li>
          <b>ASSETS</b> → <i>lite…</i> a CITADEL: pick a faction, bring PILOT, click a tile. The golden core mines the most;
          it's also where the war is.
        </li>
        <li>
          Select your CITADEL: build a <b>FLEET ACADEMY</b>, then train <b>SIF GATTACA</b>. Build MINES for income and raise the
          CITADEL level to unlock everything else.
        </li>
        <li>
          Click an enemy: <b>RAID</b> steals unclaimed DK. Neighbours fight instantly; distant raids travel and anyone can
          resolve them on arrival. <b>Claim</b> your vault weekly — what's in it can be stolen.
        </li>
        <li>
          Earn FLEET POINTS by destroying fleet, mint next-generation PILOT, and <b>LAY SIEGE</b>: 48+ hourly waves; win with a
          PILOT and your CITADEL rises on their tile.
        </li>
      </ol>
      <h3>Factions</h3>
      {FACTIONS.map((f, i) => (
        <p key={f}>
          <b style={{ color: FACTION_COLORS[i] }}>{f}</b> <span className="dim">— {FACTION_LEADERS[i]}</span>
        </p>
      ))}
      <h3>Fleet</h3>
      <p>
        <b>SIF GATTACA</b> fast swarm raiders · <b>MHRUDVOG THROT</b> fortification · <b>DREBENTRAAKHT</b> siege ships that hit
        twice as hard in sieges · <b>DALAA MAX</b> scouts (needs ATOMIC ENGINE).
      </p>
      <h3>The map</h3>
      <p>
        Drag (or pinch) to move, wheel to zoom toward the cursor, <code>WASD</code>/arrows to pan, <code>c</code> to cycle
        your CITADEL, <code>f</code> for the whole grid. The minimap jumps anywhere; ⚠ flies to whatever is attacking you.
        The golden core and six outer mining fields produce the most DRAKMA.
      </p>
      <h3>Terminal</h3>
      <p>
        The CITADEL OS terminal below takes commands too: <code>help</code>, <code>raid 3 7 100</code>, <code>status 3</code>…
      </p>
      {chain.isDev && (
        <p className="dim">
          Local chain: switch between the 10 dev accounts and skip time with the buttons at the top right. Forty players are
          already spread across the grid.
        </p>
      )}
    </div>
  );
}
