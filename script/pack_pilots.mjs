// Builds data/pilot-traits.bin (5 bytes per original PILOT id, for PilotNFT.setTraits) and data/pilot-traits.json.
//   inputs: data/pilots/<id>.json  (original metadata, script/fetch_pilots.sh)
//           data/pilot-onchain.json (level + sovereignty from the original contract)
// Revealed PILOT keep their SUBJUGATION and DEATH. PILOT never revealed (metadata name "PILOT <id>") get them rolled
// from keccak256("CITADEL PILOT", id) with THE PILOT post's rarities, as does every KULT except a sovereign's, which
// the original contract recorded. LEVEL and SOVEREIGNTY are what holders bought on mainnet.
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { keccak256, encodePacked } from "../web/node_modules/viem/_esm/index.js";

const SUBJ = ["HERMETIC STRACHT", "POTENTATE COERCION", "DREDGE NOBILITY", "ALKAHEST DRIFT", "CRHONA THROT", "SIF COMMANDER", "PSIONIC FUROR", "TECHNOCRAT ARMAMENT"];
const SUBJ_W = [1024, 512, 256, 128, 64, 32, 16, 16];
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
let revealed = 0, rolled = 0;
for (let id = 0; id < n; id++) {
  const f = `data/pilots/${id}.json`;
  if (!existsSync(f)) throw new Error(`missing ${f}: run script/fetch_pilots.sh`);
  const meta = JSON.parse(readFileSync(f, "utf8"));
  const attrs = Object.fromEntries(meta.attributes.map((a) => [a.trait_type, a.value]));
  const seed = BigInt(keccak256(encodePacked(["string", "uint256"], ["CITADEL PILOT", BigInt(id)])));
  const isRevealed = meta.name !== `PILOT ${id}`;
  let subj, death;
  if (isRevealed) {
    subj = SUBJ.indexOf(attrs.SUBJUGATION);
    if (subj < 0) throw new Error(`PILOT ${id}: unknown SUBJUGATION ${attrs.SUBJUGATION}`);
    death = attrs.DEATH !== undefined && attrs.DEATH !== "VOID";
    revealed++;
  } else {
    subj = pick(Number(seed % 2048n), SUBJ_W);
    death = Number((seed >> 32n) % 2048n) < 64;
    rolled++;
  }
  const oc = onchain[id];
  const kult = oc.sovereign ? oc.kult : pick(Number((seed >> 16n) % 2048n), KULT_W);
  out.set([subj, kult, oc.level, (oc.sovereign ? 1 : 0) | (death ? 2 : 0), 0], id * 5);
  table[id] = { name: meta.name, revealed: isRevealed, subjugation: SUBJ[subj], kult, level: oc.level, sovereign: oc.sovereign, death };
}
writeFileSync("data/pilot-traits.bin", out);
writeFileSync("data/pilot-traits.json", JSON.stringify(table, null, 1));
const sovereigns = Object.entries(table).filter(([, t]) => t.sovereign).map(([id]) => Number(id));
const born = new Set(JSON.parse(readFileSync("data/born-sovereigns.json", "utf8")).map((b) => b.pilot));
const bought = sovereigns.filter((id) => !born.has(id)).length;
writeFileSync("data/sovereigns.json", JSON.stringify({ ids: sovereigns, bought }));
console.log(`packed ${n} PILOT: ${revealed} revealed, ${rolled} rolled, ${sovereigns.length} sovereign (${bought} bought seats)`);
