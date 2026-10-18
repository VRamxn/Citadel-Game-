// Builds data/pilot-traits.bin (5 bytes per original PILOT id, for PilotNFT.setTraits) and data/pilot-traits.json.
//   inputs: data/pilots/<id>.json  (original metadata, script/fetch_pilots.sh)
//           data/pilot-onchain.json (level + sovereignty from the original contract)
// SUBJUGATION and DEATH come from each PILOT's original metadata (every PILOT's traits are revealed there: HERMETIC
// STRACHT + VOID is simply the most common combination, ~half the supply, as THE PILOT post's rarities predict).
// DEATH is any value other than VOID ("ETERNAL"). KULT was only ever recorded for sovereigns that bribed one (the original
// contract stores it); the rest roll from keccak256("CITADEL PILOT", id) with the post's rarities, a fixed public formula.
// LEVEL and SOVEREIGNTY are what holders bought on mainnet.
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { keccak256, encodePacked } from "../web/node_modules/viem/_esm/index.js";

const SUBJ = ["HERMETIC STRACHT", "POTENTATE COERCION", "DREDGE NOBILITY", "ALKAHEST DRIFT", "CRHONA THROT", "SIF COMMANDER", "PSIONIC FUROR", "TECHNOCRAT ARMAMENT"];
const KULT_W = [512, 256, 256, 256, 256, 256, 128, 128];
const pick = (roll, w) => {
  let acc = 0;
  for (let i = 0; i < 8; i++) if (roll < (acc += w[i])) return i;
  return 7;
};

const onchain = JSON.parse(readFileSync("data/pilot-onchain.json", "utf8"));
const n = Object.keys(onchain).length;
const out = Buffer.alloc(n * 5);
const table = {};
let named = 0;
for (let id = 0; id < n; id++) {
  const f = `data/pilots/${id}.json`;
  if (!existsSync(f)) throw new Error(`missing ${f}: run script/fetch_pilots.sh`);
  const meta = JSON.parse(readFileSync(f, "utf8"));
  const attrs = Object.fromEntries(meta.attributes.map((a) => [a.trait_type, a.value]));
  const seed = BigInt(keccak256(encodePacked(["string", "uint256"], ["CITADEL PILOT", BigInt(id)])));
  const subj = SUBJ.indexOf(attrs.SUBJUGATION);
  if (subj < 0) throw new Error(`PILOT ${id}: unknown SUBJUGATION ${attrs.SUBJUGATION}`);
  const death = attrs.DEATH !== undefined && attrs.DEATH !== "VOID";
  if (meta.name !== `PILOT ${id}`) named++;
  const oc = onchain[id];
  // a KULT is only on record for a sovereign that bribed one (chargeCount > 0); otherwise it's the unset default
  const recorded = oc.sovereign && oc.charges > 0;
  const kult = recorded ? oc.kult : pick(Number((seed >> 16n) % 2048n), KULT_W);
  out.set([subj, kult, oc.level, (oc.sovereign ? 1 : 0) | (death ? 2 : 0), 0], id * 5);
  table[id] = { name: meta.name, subjugation: SUBJ[subj], kult, kultRolled: !recorded, level: oc.level, sovereign: oc.sovereign, death };
}
writeFileSync("data/pilot-traits.bin", out);
writeFileSync("data/pilot-traits.json", JSON.stringify(table, null, 1));
const sovereigns = Object.entries(table).filter(([, t]) => t.sovereign).map(([id]) => Number(id));
const born = new Set(JSON.parse(readFileSync("data/born-sovereigns.json", "utf8")).map((b) => b.pilot));
const bought = sovereigns.filter((id) => !born.has(id)).length;
writeFileSync("data/sovereigns.json", JSON.stringify({ ids: sovereigns, bought }));
console.log(`packed ${n} PILOT (${named} named): ${table ? Object.values(table).filter((t) => t.death).length : 0} DEATH, ${sovereigns.length} sovereign (${bought} bought seats), KULT rolled for ${Object.values(table).filter((t) => t.kultRolled).length}`);
