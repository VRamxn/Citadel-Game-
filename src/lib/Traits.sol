// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Trait enums and their stat tables, taken from the original CITADEL design posts.
/// Enum order is the strength order from the EXORDIUM post (weakest first) and is relied on by the
/// lookup tables below, by script/pack_traits.py and by the web client — do not reorder.
library Traits {
    // SEKT: RELIK, DROTH XYL, IONSLAUGHT, ELEKT
    uint8 internal constant SEKT_RELIK = 0;
    uint8 internal constant SEKT_ELEKT = 3;
    uint8 internal constant SEKT_COUNT = 4;
    // SHIELD: DAG SGIATH, XZCID MAGH, TELUM RATIO, UNGARDROTHH, DSGRILL RATIO, DASKENWAFT, MYSTERIUM, MARBHADH GREINE
    // ENGINE: HAG GOTOR, CHOBAKK, TELUM MAK, STROGOTHT, FULTACHT MAK, GLUASAD, DSGILL MAK, DREADNAUGHT
    // WEAPON: RRAKATAKHT FUROR, AG HALMAHHER, TELUM FUROR, HALMAHHER FUROR, DAG VERSTACKT, VEERDACHT MAGH,
    //         MARBHADH GHXST, DEI IUDICIUM
    uint8 internal constant WEAPON_VEERDACHT = 5;
    uint8 internal constant WEAPON_DEI_IUDICIUM = 7;
    // TECH: PRESERVATIVE ALGORITHMS, MILITANT ALGORITHMS, ANTIMATTER ANNIHILATION, PROPULSION, POSTHUMANISM,
    //       ECOLOGICAL EXTRACTION, TECHNOCRACY, PROGINATOR PSI
    uint8 internal constant TRAIT_COUNT = 8;

    // PILOT SUBJUGATION, in the order (and rarity) of THE PILOT post
    uint8 internal constant SUBJ_HERMETIC_STRACHT = 0; // boosts mining on hostile (hotspot) grid
    uint8 internal constant SUBJ_POTENTATE_COERCION = 1; // KULT: cheaper bribes
    uint8 internal constant SUBJ_DREDGE_NOBILITY = 2; // boosts mining
    uint8 internal constant SUBJ_ALKAHEST_DRIFT = 3; // boosts research
    uint8 internal constant SUBJ_CRHONA_THROT = 4; // boosts defense
    uint8 internal constant SUBJ_SIF_COMMANDER = 5; // boosts offense
    uint8 internal constant SUBJ_PSIONIC_FUROR = 6; // intelligence: boosts scouting
    uint8 internal constant SUBJ_TECHNOCRAT_ARMAMENT = 7; // KULT: cheaper bribes

    // Fleet types
    uint8 internal constant SIF_GATTACA = 0; // swarm
    uint8 internal constant MHRUDVOG_THROT = 1; // fortification
    uint8 internal constant DREBENTRAAKHT = 2; // siege
    uint8 internal constant DALAA_MAX = 3; // scout

    struct CitadelTraits {
        uint8 generation;
        uint8 sekt;
        uint8 shield;
        uint8 engine;
        uint8 weapon;
        uint8 tech;
        bool exists;
    }

    struct PilotTraits {
        uint8 generation;
        uint8 subjugation;
        uint8 kult;
        uint8 level;
        bool sovereign;
        bool death;
    }

    struct MentatTraits {
        uint8 generation;
        uint8 level;
    }

    /// @notice DRAKMA multiplier per SEKT (EXORDIUM post).
    function sektMultiplier(uint8 sekt) internal pure returns (uint256) {
        return [uint256(16), 8, 4, 2][sekt];
    }

    /// @notice Shield base fleet-defense bonus, in basis points.
    function shieldBps(uint8 shield) internal pure returns (uint256) {
        return [uint256(1000), 1100, 1200, 1500, 1700, 2000, 2500, 3500][shield];
    }

    /// @notice Engine shield recharge, in basis points. Interpreted as a multiplier on the shield bonus.
    function engineRechargeBps(uint8 engine) internal pure returns (uint256) {
        return [uint256(1000), 1100, 1200, 1500, 1700, 2000, 2500, 3500][engine];
    }

    /// @notice Engine weapons repair, in basis points. Interpreted as a reduction of this CITADEL's fleet losses.
    function engineRepairBps(uint8 engine) internal pure returns (uint256) {
        return [uint256(200), 225, 250, 300, 375, 475, 600, 750][engine];
    }

    /// @notice Weapon system base fleet-damage bonus, in basis points.
    function weaponBps(uint8 weapon) internal pure returns (uint256) {
        return [uint256(1000), 1100, 1200, 1500, 1700, 2000, 2500, 3500][weapon];
    }

    /// @notice Weapon secondary base ability: (fleet type it boosts, bps). Swarm = SIF GATTACA, siege = DREBENTRAAKHT.
    function weaponSecondary(uint8 weapon) internal pure returns (uint8 fleetType, uint256 bps) {
        uint8[8] memory t = [SIF_GATTACA, DREBENTRAAKHT, SIF_GATTACA, SIF_GATTACA, DREBENTRAAKHT, 0, DREBENTRAAKHT, 0];
        uint16[8] memory b = [uint16(500), 500, 600, 700, 700, 0, 1000, 0];
        return (t[weapon], b[weapon]);
    }

    /// @notice A PILOT's bonus in basis points: 20% at level 0, +2% per level (THE PILOT post).
    /// Each generation after GEN0 is half as strong as the one before.
    function pilotBps(uint8 level, uint8 generation) internal pure returns (uint256) {
        return (2000 + 200 * uint256(level)) >> generation;
    }

    /// @notice A MENTAT amplifies its CITADEL's shield, engine and weapon system by this much.
    function mentatAmpBps(uint8 level) internal pure returns (uint256) {
        return 2500 + 500 * uint256(level);
    }

    /// @notice A MENTAT's DRAKMA production bonus.
    function mentatMineBps(uint8 level) internal pure returns (uint256) {
        return 1000 + 200 * uint256(level);
    }

    /// @notice GEN0 has 2x the shield/engine/weapon power of GEN1 (whitepaper); halves each generation.
    function genPowerBps(uint8 generation) internal pure returns (uint256) {
        return generation >= 14 ? 1 : 10_000 >> generation;
    }

    /// @notice GEN0 produces 10x the DRAKMA of GEN1 (whitepaper); /10 each generation.
    function genOutputDivisor(uint8 generation) internal pure returns (uint256) {
        return 10 ** uint256(generation > 6 ? 6 : generation);
    }
}

/// @notice The CITADEL tech tree: 8 branches, 53 technologies, from the EXORDIUM post.
/// A faction's progress is a 64-bit mask; bit i = technology i researched.
library Tech {
    uint256 internal constant BRANCHES = 8;
    uint256 internal constant TOTAL = 53;

    // branch 0 — PRESERVATIVE ALGORITHMS
    uint8 internal constant TESLAPHORESIS = 0; // TELUM RATIO unique
    uint8 internal constant DEFLECTOR_SHIELDS = 1; // DSGRILL RATIO unique
    uint8 internal constant PRESERVATIONAL_FIELD = 2; // DAG SGIATH unique
    uint8 internal constant GRAVITATIONAL_FIELD = 3; // UNGARDROTHH unique
    uint8 internal constant GRID_DISTURBANCE = 4; // XZCID MAGH unique
    uint8 internal constant OBSCURANCE_CALCULUS = 5; // MYSTERIUM unique
    uint8 internal constant BIOADAPTIVE_RESONANCE = 6; // MHRUDVOG THROT +10%
    // branch 1 — MILITANT ALGORITHMS
    uint8 internal constant APPLIED_GRAVITONICS = 7; // +2% offense
    uint8 internal constant GRAVITON_CANNON = 8; // DREBENTRAAKHT +10%
    uint8 internal constant GRAVIMETRIC_TORPEDOES = 9; // MARBHADH GHXST +5%
    uint8 internal constant PLASMA_ACCELERATION = 10; // +2% offense
    uint8 internal constant PLASMA_CANNON = 11; // RRAKATAKHT FUROR +5%
    uint8 internal constant PLASMA_TORPEDO = 12; // TELUM FUROR +5%
    uint8 internal constant PLASMA_DETONATOR = 13; // HALMAHHER FUROR +5%
    uint8 internal constant MOLECULAR_DISRUPTION = 14; // +2% offense
    uint8 internal constant DAG_DISRUPTOR = 15; // DAG VERSTACKT +5%
    // branch 2 — ANTIMATTER ANNIHILATION
    uint8 internal constant PLASMA_DISCHARGE = 16; // HAG GOTOR unique
    uint8 internal constant PLASMA_SHARD_ENGINE = 17; // CHOBAKK unique
    uint8 internal constant PLASMA_BARRIER = 18; // GLUASAD unique
    uint8 internal constant QUANTUM_MECHANICS = 19; // +2% weapons repair
    uint8 internal constant ZERO_POINT_ENERGY = 20; // TELUM MAK unique
    uint8 internal constant FERMION_FIELD = 21; // FULTACHT MAK unique
    uint8 internal constant BOSONIC_FIELD = 22; // DSGILL MAK unique
    uint8 internal constant GRID_OUTGRESS = 23; // STROGOTHT unique
    uint8 internal constant DARK_MATTER = 24; // DREADNAUGHT unique
    // branch 3 — PROPULSION
    uint8 internal constant SUBLIGHT_PROPULSION = 25; // +5% fleet speed
    uint8 internal constant ATOMIC_ENGINE = 26; // unlocks DALAA MAX
    uint8 internal constant IONIC_ENGINE = 27; // +5% swarm speed
    uint8 internal constant ARTIFICIAL_GRAVITY = 28; // +2% siege ship production
    uint8 internal constant CRYOGENIC_TRANSPORT = 29; // +10% siege ship production
    uint8 internal constant QUANTUM_FIELD_THEORY = 30; // DASKENWAFT unique
    uint8 internal constant COLLECTIVE_EXCITATION = 31; // MARBHADH GREINE unique
    // branch 4 — POSTHUMANISM
    uint8 internal constant BIOGENETIC_ALGORITHMS = 32; // +2% defense
    uint8 internal constant NEURAL_GRAFTING = 33; // SIF GATTACA +10%
    uint8 internal constant GRID_SENTIENT = 34; // +2% DK
    uint8 internal constant XENO_SYMPATHY = 35; // +2% fortification
    uint8 internal constant BIOGENETIC_WARFARE = 36; // +2% offense
    uint8 internal constant RETROVIRAL_PLAGUE = 37; // VEERDACHT MAGH unique
    uint8 internal constant HERMETIC_SYSTEMS = 38; // +1% shield defense
    // branch 5 — ECOLOGICAL EXTRACTION
    uint8 internal constant TERRAFORMING = 39; // +2% DK
    uint8 internal constant SYNTHETIC_CHEMISTRY = 40; // +2% DK
    uint8 internal constant ATMOSPHERIC_ENGINEERING = 41; // +5% DK
    // branch 6 — TECHNOCRACY
    uint8 internal constant POLYMORPHIC_ALGORITHMS = 42; // +5% training speed
    uint8 internal constant CLONING_VATS = 43; // +10% swarm production
    uint8 internal constant BIOHACKING = 44; // +2% defense
    uint8 internal constant SEED_AI = 45; // +5% swarm defense
    uint8 internal constant WARLORD_TECHNOCRACY = 46; // +5% DK
    uint8 internal constant ECONOMETRIC_PROBE = 47; // +1% DK
    // branch 7 — PROGINATOR PSI
    uint8 internal constant SURVEILLANCE_STATE = 48; // +1 vision radius (client)
    uint8 internal constant THREATCASTING = 49; // MENTAT effects +50%
    uint8 internal constant CYBERNATED_SENTIENCE = 50; // +2% offense & defense
    uint8 internal constant PSIONIC_RESONATOR = 51; // AG HALMAHHER +5%
    uint8 internal constant DISSOCIATIVE_WAVE = 52; // DEI IUDICIUM unique

    /// @notice First tech index and tech count of each branch.
    function branch(uint256 b) internal pure returns (uint256 first, uint256 count) {
        uint8[8] memory f = [0, 7, 16, 25, 32, 39, 42, 48];
        uint8[8] memory c = [7, 9, 9, 7, 7, 3, 6, 5];
        return (f[b], c[b]);
    }

    function has(uint64 bits, uint8 tech) internal pure returns (bool) {
        return bits & (uint64(1) << tech) != 0;
    }

    /// @notice Tech that unlocks each shield's unique ability.
    function shieldTech(uint8 shield) internal pure returns (uint8) {
        return [
            PRESERVATIONAL_FIELD,
            GRID_DISTURBANCE,
            TESLAPHORESIS,
            GRAVITATIONAL_FIELD,
            DEFLECTOR_SHIELDS,
            QUANTUM_FIELD_THEORY,
            OBSCURANCE_CALCULUS,
            COLLECTIVE_EXCITATION
        ][shield];
    }

    function engineTech(uint8 engine) internal pure returns (uint8) {
        return [
            PLASMA_DISCHARGE,
            PLASMA_SHARD_ENGINE,
            ZERO_POINT_ENERGY,
            GRID_OUTGRESS,
            FERMION_FIELD,
            PLASMA_BARRIER,
            BOSONIC_FIELD,
            DARK_MATTER
        ][engine];
    }

    function weaponTech(uint8 weapon) internal pure returns (uint8) {
        return [
            PLASMA_CANNON,
            PSIONIC_RESONATOR,
            PLASMA_TORPEDO,
            PLASMA_DETONATOR,
            DAG_DISRUPTOR,
            RETROVIRAL_PLAGUE,
            GRAVIMETRIC_TORPEDOES,
            DISSOCIATIVE_WAVE
        ][weapon];
    }
}
