// Names, enums and math mirrored from the contracts (src/lib/Traits.sol, src/game/GameStorage.sol).
// Keep the order of every list identical to the Solidity enums.

export const FACTIONS = ["NETWORK STATE", "AUTONOMOUS ZONE", "SANCTION", "ANNEXATION"] as const;
export const FACTION_COLORS = ["#e5484d", "#3fb950", "#a371f7", "#e8a33d"];
export const FACTION_LEADERS = [
  "THE STATIST · raid: GRID MAELSTROM",
  "THE FACTIONIST · raid: THE OCCUPY",
  "THE FANATIC · raid: THE INQUISITION",
  "THE PIN · raid: THE BREACH",
];
export const SEKT = ["RELIK", "DROTH XYL", "IONSLAUGHT", "ELEKT"];
export const SHIELDS = ["DAG SGIATH", "XZCID MAGH", "TELUM RATIO", "UNGARDROTHH", "DSGRILL RATIO", "DASKENWAFT", "MYSTERIUM", "MARBHADH GREINE"];
export const ENGINES = ["HAG GOTOR", "CHOBAKK", "TELUM MAK", "STROGOTHT", "FULTACHT MAK", "GLUASAD", "DSGILL MAK", "DREADNAUGHT"];
export const WEAPONS = ["RRAKATAKHT FUROR", "AG HALMAHHER", "TELUM FUROR", "HALMAHHER FUROR", "DAG VERSTACKT", "VEERDACHT MAGH", "MARBHADH GHXST", "DEI IUDICIUM"];
export const BRANCHES = ["PRESERVATIVE ALGORITHMS", "MILITANT ALGORITHMS", "ANTIMATTER ANNIHILATION", "PROPULSION", "POSTHUMANISM", "ECOLOGICAL EXTRACTION", "TECHNOCRACY", "PROGINATOR PSI"];
export const SUBJUGATION = ["HERMETIC STRACHT", "POTENTATE COERCION", "DREDGE NOBILITY", "ALKAHEST DRIFT", "CRHONA THROT", "SIF COMMANDER", "PSIONIC FUROR", "TECHNOCRAT ARMAMENT"];
export const SUBJUGATION_EFFECT = [
  "mining on hotspots",
  "bribes count twice",
  "mining",
  "research ×",
  "defense",
  "offense",
  "scouting ×",
  "bribes count twice",
];
export const KULT = ["KULT GEHEIM", "DØD ENGEL", "STALKROTH", "KULT GOR", "KLINGE", "DALK STRACHT", "YS DIABOLI", "GRÅTER DJEVEL"];
export const FLEET = ["SIF GATTACA", "MHRUDVOG THROT", "DREBENTRAAKHT", "DALAA MAX"];
export const FLEET_SHORT = ["SIF", "THROT", "DREB", "DALAA"];
export const FLEET_ROLE = ["swarm raider", "fortification", "siege ship", "scout"];
export const BUILDINGS = ["CITADEL", "MINE", "SHIELD", "ENGINE", "WEAPON SYSTEM", "FLEET ACADEMY"];
export const BUILDING_EFFECT = [
  "structure defense (level+1)², caps other buildings",
  "+10% DRAKMA per level",
  "+10% shield power per level",
  "+10% engine power per level",
  "+10% weapon power per level",
  "unlocks fleet, +5% training speed per level",
];
export const MARCH_KIND = ["", "RAID", "RETURN", "REINFORCE", "SCOUT", "SIEGE", "JOIN SIEGE"];

// Tech tree, in bit order (src/lib/Traits.sol, library Tech).
export const TECHS: [string, string][][] = [
  [["Teslaphoresis", "TELUM RATIO unique: +2% fleet defense"], ["Deflector shields", "DSGRILL RATIO unique: +5% fleet defense"], ["Preservational field", "DAG SGIATH unique: +5% siege defense"], ["Gravitational field", "UNGARDROTHH unique: +15% siege defense"], ["Grid disturbance engineering", "XZCID MAGH unique: +10% siege defense"], ["Obscurance calculus", "MYSTERIUM unique: +5% DRAKMA"], ["Bioadaptive resonance", "MHRUDVOG THROT +10%"]],
  [["Applied gravitonics", "+2% offense"], ["Graviton cannon", "DREBENTRAAKHT +10%"], ["Gravimetric torpedoes", "MARBHADH GHXST +5%"], ["Plasma acceleration", "+2% offense"], ["Plasma cannon", "RRAKATAKHT FUROR +5%"], ["Plasma torpedo", "TELUM FUROR +5%"], ["Plasma detonator", "HALMAHHER FUROR +5%"], ["Molecular disruption", "+2% offense"], ["Dag disruptor", "DAG VERSTACKT +5%"]],
  [["Plasma discharge", "HAG GOTOR unique: +1% fortification"], ["Plasma shard engine", "CHOBAKK unique: +2% fortification"], ["Plasma barrier discharge", "GLUASAD unique: +5% fortification"], ["Quantum mechanics", "+2% weapons repair"], ["Zero-point energy", "TELUM MAK unique: +1% repair"], ["Fermion field energy", "FULTACHT MAK unique: +2.5% repair"], ["Bosonic field energy", "DSGILL MAK unique: +5% repair"], ["Grid outgress", "STROGOTHT unique: +1% DRAKMA"], ["Dark matter distribution", "DREADNAUGHT unique: +5% DRAKMA"]],
  [["Sublight propulsion", "+5% fleet speed"], ["Atomic engine", "unlocks DALAA MAX"], ["Ionic engine", "+5% swarm speed"], ["Artificial gravity", "+2% siege ship production"], ["Cryogenic transport", "+10% siege ship production"], ["Quantum field theory", "DASKENWAFT unique: +15% swarm defense"], ["Collective excitation", "MARBHADH GREINE unique: +25% swarm defense"]],
  [["Biogenetic algorithms", "+2% defense"], ["Neural grafting", "SIF GATTACA +10%"], ["Grid-sentient algorithms", "+2% DRAKMA"], ["Xeno sympathy", "+2% fortification"], ["Biogenetic warfare", "+2% offense"], ["Retroviral plague", "VEERDACHT MAGH unique: destroys 5%/2% of the enemy"], ["Hermetic systems", "+1% shield defense"]],
  [["Terraforming", "+2% DRAKMA"], ["Synthetic chemistry", "+2% DRAKMA"], ["Atmospheric engineering", "+5% DRAKMA"]],
  [["Polymorphic algorithms", "+5% training speed"], ["Cloning vats", "+10% swarm production"], ["Biohacking", "+2% defense"], ["Seed AI", "+5% swarm defense"], ["Warlord technocracy", "+5% DRAKMA"], ["Econometric probe", "+1% DRAKMA"]],
  [["Surveillance state", "+1 vision, +10% scouting"], ["Threatcasting", "MENTAT effects +50%"], ["Cybernated sentience", "+2% offense & defense"], ["Psionic resonator", "AG HALMAHHER +5%"], ["Dissociative wave algorithms", "DEI IUDICIUM unique: 5% of attackers desert"]],
];
export const BRANCH_FIRST = [0, 7, 16, 25, 32, 39, 42, 48];
export const SURVEILLANCE_STATE = 48;

export const hasTech = (bits: bigint, i: number) => ((bits >> BigInt(i)) & 1n) === 1n;

// ---------------------------------------------------------------- hex math (axial, pointy-top)

export type Hex = { q: number; r: number };
export const hexDistance = (a: Hex, b: Hex) =>
  (Math.abs(a.q - b.q) + Math.abs(a.q + a.r - b.q - b.r) + Math.abs(a.r - b.r)) / 2;
export const hexKey = (q: number, r: number) => `${q},${r}`;

export function hexesWithin(radius: number): Hex[] {
  const out: Hex[] = [];
  for (let q = -radius; q <= radius; q++)
    for (let r = Math.max(-radius, -q - radius); r <= Math.min(radius, -q + radius); r++) out.push({ q, r });
  return out;
}

export const HEX_SIZE = 26;
export function hexToPixel({ q, r }: Hex) {
  return { x: HEX_SIZE * Math.sqrt(3) * (q + r / 2), y: HEX_SIZE * 1.5 * r };
}
export function hexCorners(cx: number, cy: number, size = HEX_SIZE) {
  const pts: string[] = [];
  for (let i = 0; i < 6; i++) {
    const a = (Math.PI / 180) * (60 * i - 30);
    pts.push(`${(cx + size * Math.cos(a)).toFixed(1)},${(cy + size * Math.sin(a)).toFixed(1)}`);
  }
  return pts.join(" ");
}

/** Default tile mining multiple in bps (GameBase._tileBps); overrides aren't visible without events. */
export function defaultTileBps(h: Hex) {
  const d = hexDistance(h, { q: 0, r: 0 });
  if (d <= 1) return 12500;
  if (d <= 3) return 11500;
  if (d <= 5) return 10500;
  return 10000;
}

// ---------------------------------------------------------------- formatting

export function fmtDk(wei: bigint, digits = 0) {
  const whole = Number(wei / 10n ** 14n) / 1e4;
  if (whole >= 1e9) return `${(whole / 1e9).toFixed(2)}B`;
  if (whole >= 1e6) return `${(whole / 1e6).toFixed(2)}M`;
  if (whole >= 1e4) return `${(whole / 1e3).toFixed(1)}k`;
  return whole.toFixed(digits);
}
export const fmtPct = (bps: number | bigint) => `${(Number(bps) / 100).toFixed(1)}%`;
export function fmtDuration(secs: number) {
  if (secs <= 0) return "now";
  const d = Math.floor(secs / 86400),
    h = Math.floor((secs % 86400) / 3600),
    m = Math.floor((secs % 3600) / 60),
    s = Math.floor(secs % 60);
  if (d) return `${d}d ${h}h`;
  if (h) return `${h}h ${m}m`;
  if (m) return `${m}m ${s}s`;
  return `${s}s`;
}
export const short = (a?: string) => (a ? `${a.slice(0, 6)}…${a.slice(-4)}` : "");
