// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Trait enums and their stat tables, taken from the original CITADEL design posts.
/// Enum order is the strength order from the EXORDIUM post (weakest first) and is relied on by the
/// lookup tables below and by script/pack_traits.py — do not reorder.
library Traits {
    // SEKT: RELIK, DROTH XYL, IONSLAUGHT, ELEKT
    uint8 internal constant SEKT_COUNT = 4;
    // SHIELD: DAG SGIATH, XZCID MAGH, TELUM RATIO, UNGARDROTHH, DSGRILL RATIO, DASKENWAFT, MYSTERIUM, MARBHADH GREINE
    uint8 internal constant SHIELD_MYSTERIUM = 6;
    // ENGINE: HAG GOTOR, CHOBAKK, TELUM MAK, STROGOTHT, FULTACHT MAK, GLUASAD, DSGILL MAK, DREADNAUGHT
    uint8 internal constant ENGINE_STROGOTHT = 3;
    uint8 internal constant ENGINE_DREADNAUGHT = 7;
    // WEAPON: RRAKATAKHT FUROR, AG HALMAHHER, TELUM FUROR, HALMAHHER FUROR, DAG VERSTACKT, VEERDACHT MAGH,
    //         MARBHADH GHXST, DEI IUDICIUM
    // TECH: PRESERVATIVE ALGORITHMS, MILITANT ALGORITHMS, ANTIMATTER ANNIHILATION, PROPULSION, POSTHUMANISM,
    //       ECOLOGICAL EXTRACTION, TECHNOCRACY, PROGINATOR PSI
    uint8 internal constant TRAIT_COUNT = 8;

    // PILOT SUBJUGATION, in the order (and rarity) of THE PILOT post
    uint8 internal constant SUBJ_HERMETIC_STRACHT = 0; // boosts mining on hostile (hotspot) grid
    uint8 internal constant SUBJ_POTENTATE_COERCION = 1;
    uint8 internal constant SUBJ_DREDGE_NOBILITY = 2; // boosts mining
    uint8 internal constant SUBJ_ALKAHEST_DRIFT = 3;
    uint8 internal constant SUBJ_CRHONA_THROT = 4; // boosts defense
    uint8 internal constant SUBJ_SIF_COMMANDER = 5; // boosts offense
    uint8 internal constant SUBJ_PSIONIC_FUROR = 6;
    uint8 internal constant SUBJ_TECHNOCRAT_ARMAMENT = 7;

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

    /// @notice A PILOT's bonus in basis points: 20% at level 0, +2% per level (THE PILOT post).
    function pilotBps(uint8 level) internal pure returns (uint256) {
        return 2000 + 200 * uint256(level);
    }
}
