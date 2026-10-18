import { useGame } from "../App";

export function DispatchPanel() {
  const { world } = useGame();
  return (
    <div>
      <h2>CITADEL DISPATCH</h2>
      <p className="dim small">
        An illegal terminal in the NETWORK STATE relays the day's sieges, raids and political shifts, straight from the chain.
      </p>
      {world.dispatch.length === 0 && <p className="dim">No news yet.</p>}
      <ul className="dispatch">
        {world.dispatch.map((d, i) => (
          <li key={i} className={d.tone}>
            <span className="dim">#{d.block.toString()}</span> {d.text}
          </li>
        ))}
      </ul>
    </div>
  );
}
