// Copies contract ABIs from Foundry's out/ into src/abi/. The game is one address that routes to several modules,
// so its ABI is the union of the router and every module (minus the modules' own `selectors()` helper).
import { readFileSync, writeFileSync } from "node:fs";

const out = new URL("../../out/", import.meta.url);
const read = (file, name) => JSON.parse(readFileSync(new URL(`${file}/${name}.json`, out))).abi;
const sig = (e) => `${e.type}:${e.name}(${(e.inputs ?? []).map((i) => i.type).join(",")})`;

const parts = [
  read("CitadelGame.sol", "CitadelGame"),
  read("EconomyModule.sol", "EconomyModule"),
  read("WarModule.sol", "WarModule"),
  read("SiegeModule.sol", "SiegeModule"),
  read("ViewModule.sol", "ViewModule"),
];
const seen = new Map();
for (const abi of parts)
  for (const e of abi) {
    if (e.type === "constructor" || e.type === "fallback" || e.name === "selectors") continue;
    seen.set(sig(e), e);
  }
const write = (name, abi) =>
  writeFileSync(new URL(`../src/abi/${name}.ts`, import.meta.url), `export default ${JSON.stringify(abi, null, 1)} as const;\n`);

write("game", [...seen.values()]);
for (const [file, name, as] of [
  ["Drakma.sol", "Drakma", "drakma"],
  ["CitadelNFT.sol", "CitadelNFT", "citadel"],
  ["PilotNFT.sol", "PilotNFT", "pilot"],
  ["MentatNFT.sol", "MentatNFT", "mentat"],
  ["TechTree.sol", "TechTree", "techTree"],
  ["Technocracy.sol", "Technocracy", "technocracy"],
  ["SovereignCouncil.sol", "SovereignCouncil", "council"],
  ["TestnetFaucet.sol", "TestnetFaucet", "faucet"],
])
  write(as, read(file, name));
console.log(`game ABI: ${seen.size} entries`);
