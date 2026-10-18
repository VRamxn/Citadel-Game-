// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {GameStorage} from "./GameStorage.sol";
import {Hex} from "../lib/Hex.sol";
import {Traits, Tech} from "../lib/Traits.sol";
import {Rand} from "../lib/Rand.sol";

/// @notice Internal logic shared by CitadelGame and WarModule: derived stats, lazy settlement, placement and removal.
abstract contract GameBase is GameStorage, ReentrancyGuardTransient {
    /// @notice Everything a CITADEL brings to a fight or a mine, after traits, buildings, PILOT, MENTAT and tech.
    struct Stats {
        uint256 mineBps; // production bonus over 100%
        uint256 offBps;
        uint256 defBps;
        uint256 fortBps;
        uint256 repairBps;
        uint256 siegeDefBps;
        uint256 scoutBps;
        uint256 structure; // the CITADEL's own defense points
        uint256[4] typeOff;
        uint256[4] typeDef;
        uint256[4] speedBps;
        uint256[4] trainBps;
        bool veerdacht; // VEERDACHT MAGH unique
        bool deiIudicium; // DEI IUDICIUM unique
        bool dalaa; // can train DALAA MAX
    }

    event Lit(uint256 indexed citadelId, address indexed owner, uint8 ao, int16 q, int16 r, uint8 faction);
    event Unlit(uint256 indexed citadelId, address indexed owner, uint256 paidOut, uint256 forfeited);
    event Leveled(uint256 indexed citadelId, address indexed owner, bool destroyed);
    event BuildCompleted(uint256 indexed citadelId, uint8 building, uint8 level);
    event MarchSent(
        uint256 indexed marchId,
        MarchKind kind,
        uint256 indexed origin,
        uint256 indexed target,
        uint64 arriveAt,
        uint64[4] units
    );

    error NotCitadelOwner(uint256 citadelId);
    error NotLit(uint256 citadelId);
    error OffGrid();
    error TileOccupied();
    error AOClosed();
    error Unreachable();
    error BadFaction();
    error BadFleetType();
    error NoUnits();
    error NotEnoughUnits(uint8 fleetType);

    // ------------------------------------------------------------------ access

    function _owned(uint256 id) internal view returns (Citadel storage c) {
        c = _citadels[id];
        if (!c.lit || c.owner != msg.sender) revert NotCitadelOwner(id);
    }

    function _lit(uint256 id) internal view returns (Citadel storage c) {
        c = _citadels[id];
        if (!c.lit) revert NotLit(id);
    }

    function _alive(uint256 id, uint32 epoch) internal view returns (bool) {
        return _citadels[id].lit && epochOf[id] == epoch;
    }

    // ------------------------------------------------------------------ grid

    function _tileBps(uint8 ao, int16 q, int16 r) internal view returns (uint256) {
        uint32 o = _tileBpsOverride[Hex.key(ao, q, r)];
        if (o != 0) return o;
        uint256 d = Hex.fromCenter(q, r);
        if (d <= 1) return 12_500;
        if (d <= 3) return 11_500;
        if (d <= 5) return 10_500;
        return 10_000;
    }

    function _checkTile(uint8 ao, int16 q, int16 r) internal view returns (uint64 k) {
        if (aoState[ao] == AOState.Closed) revert AOClosed();
        if (Hex.fromCenter(q, r) > radius) revert OffGrid();
        k = Hex.key(ao, q, r);
        if (_occupant[k] != 0) revert TileOccupied();
    }

    /// @notice March distance in tiles between two CITADEL, across AOs if both are connected.
    function _distance(Citadel storage a, Citadel storage b) internal view returns (uint256) {
        uint256 d = Hex.distance(a.q, a.r, b.q, b.r);
        if (a.ao == b.ao) return d;
        if (aoState[a.ao] != AOState.Connected || aoState[b.ao] != AOState.Connected) revert Unreachable();
        return d + config.aoGapTiles;
    }

    function _instant(Citadel storage a, Citadel storage b) internal view returns (bool) {
        return config.distortion || (a.ao == b.ao && Hex.distance(a.q, a.r, b.q, b.r) <= 1);
    }

    // ------------------------------------------------------------------ stats

    function _stats(uint256 id) internal view returns (Stats memory s) {
        Citadel storage c = _citadels[id];
        uint64 bits = techTree.bits(c.faction);
        uint256 power = Traits.genPowerBps(c.generation);
        uint256 amp = BPS;
        if (c.mentat != 0) {
            Traits.MentatTraits memory m = mentatNft.traitsOf(c.mentat - 1);
            uint256 a = Traits.mentatAmpBps(m.level);
            uint256 mm = Traits.mentatMineBps(m.level);
            if (Tech.has(bits, Tech.THREATCASTING)) (a, mm) = (a * 3 / 2, mm * 3 / 2);
            amp += a;
            s.mineBps += mm;
            s.scoutBps += a;
        }
        uint8[6] memory lv = c.levels;
        uint256 shield = _scaled(Traits.shieldBps(c.shield), lv[B_SHIELD], power, amp);
        uint256 recharge = _scaled(Traits.engineRechargeBps(c.engine), lv[B_ENGINE], power, amp);
        s.repairBps = _scaled(Traits.engineRepairBps(c.engine), lv[B_ENGINE], power, amp);
        s.defBps = shield * (BPS + recharge) / BPS + c.pilotDef;
        s.offBps = _scaled(Traits.weaponBps(c.weapon), lv[B_WEAPON], power, amp) + c.pilotOff;
        (uint8 wt, uint256 wb) = Traits.weaponSecondary(c.weapon);
        s.typeOff[wt] += wb * power / BPS;
        s.fortBps = config.fortificationBps;
        s.typeDef[Traits.MHRUDVOG_THROT] += 2_500; // fortification specialists
        s.mineBps += c.pilotMine + 1_000 * uint256(lv[B_MINE]);
        s.scoutBps += c.pilotScout;
        s.structure = uint256(config.structureDp) * (uint256(lv[B_CITADEL]) + 1) ** 2 * power / BPS;

        if (Tech.has(bits, Tech.shieldTech(c.shield))) {
            uint8 sh = c.shield;
            if (sh == 0) s.siegeDefBps += 500;
            else if (sh == 1) s.siegeDefBps += 1_000;
            else if (sh == 2) s.defBps += 200;
            else if (sh == 3) s.siegeDefBps += 1_500;
            else if (sh == 4) s.defBps += 500;
            else if (sh == 5) s.typeDef[Traits.SIF_GATTACA] += 1_500;
            else if (sh == 6) s.mineBps += 500;
            else s.typeDef[Traits.SIF_GATTACA] += 2_500;
        }
        if (Tech.has(bits, Tech.engineTech(c.engine))) {
            uint8 en = c.engine;
            if (en == 0) s.fortBps += 100;
            else if (en == 1) s.fortBps += 200;
            else if (en == 2) s.repairBps += 100;
            else if (en == 3) s.mineBps += 100;
            else if (en == 4) s.repairBps += 250;
            else if (en == 5) s.fortBps += 500;
            else if (en == 6) s.repairBps += 500;
            else s.mineBps += 500;
        }
        if (Tech.has(bits, Tech.weaponTech(c.weapon))) {
            s.offBps += 500;
            s.veerdacht = c.weapon == Traits.WEAPON_VEERDACHT;
            s.deiIudicium = c.weapon == Traits.WEAPON_DEI_IUDICIUM;
        }
        _applyFactionTech(s, bits);
    }

    function _scaled(uint256 base, uint8 level, uint256 power, uint256 amp) private pure returns (uint256) {
        return base * (BPS + 1_000 * uint256(level)) / BPS * power / BPS * amp / BPS;
    }

    /// @dev Faction-wide technology bonuses (Tech library comments list each one).
    function _applyFactionTech(Stats memory s, uint64 bits) private pure {
        uint256 off;
        uint256 def;
        uint256 mine;
        if (Tech.has(bits, Tech.BIOADAPTIVE_RESONANCE)) _typeBoth(s, Traits.MHRUDVOG_THROT, 1_000);
        if (Tech.has(bits, Tech.APPLIED_GRAVITONICS)) off += 200;
        if (Tech.has(bits, Tech.GRAVITON_CANNON)) _typeBoth(s, Traits.DREBENTRAAKHT, 1_000);
        if (Tech.has(bits, Tech.PLASMA_ACCELERATION)) off += 200;
        if (Tech.has(bits, Tech.MOLECULAR_DISRUPTION)) off += 200;
        if (Tech.has(bits, Tech.QUANTUM_MECHANICS)) s.repairBps += 200;
        if (Tech.has(bits, Tech.SUBLIGHT_PROPULSION)) {
            for (uint8 t; t < FLEET_TYPES; ++t) {
                s.speedBps[t] += 500;
            }
        }
        if (Tech.has(bits, Tech.ATOMIC_ENGINE)) s.dalaa = true;
        if (Tech.has(bits, Tech.IONIC_ENGINE)) s.speedBps[Traits.SIF_GATTACA] += 500;
        if (Tech.has(bits, Tech.ARTIFICIAL_GRAVITY)) s.trainBps[Traits.DREBENTRAAKHT] += 200;
        if (Tech.has(bits, Tech.CRYOGENIC_TRANSPORT)) s.trainBps[Traits.DREBENTRAAKHT] += 1_000;
        if (Tech.has(bits, Tech.BIOGENETIC_ALGORITHMS)) def += 200;
        if (Tech.has(bits, Tech.NEURAL_GRAFTING)) _typeBoth(s, Traits.SIF_GATTACA, 1_000);
        if (Tech.has(bits, Tech.GRID_SENTIENT)) mine += 200;
        if (Tech.has(bits, Tech.XENO_SYMPATHY)) s.fortBps += 200;
        if (Tech.has(bits, Tech.BIOGENETIC_WARFARE)) off += 200;
        if (Tech.has(bits, Tech.HERMETIC_SYSTEMS)) def += 100;
        if (Tech.has(bits, Tech.TERRAFORMING)) mine += 200;
        if (Tech.has(bits, Tech.SYNTHETIC_CHEMISTRY)) mine += 200;
        if (Tech.has(bits, Tech.ATMOSPHERIC_ENGINEERING)) mine += 500;
        if (Tech.has(bits, Tech.POLYMORPHIC_ALGORITHMS)) {
            for (uint8 t; t < FLEET_TYPES; ++t) {
                s.trainBps[t] += 500;
            }
        }
        if (Tech.has(bits, Tech.CLONING_VATS)) s.trainBps[Traits.SIF_GATTACA] += 1_000;
        if (Tech.has(bits, Tech.BIOHACKING)) def += 200;
        if (Tech.has(bits, Tech.SEED_AI)) s.typeDef[Traits.SIF_GATTACA] += 500;
        if (Tech.has(bits, Tech.WARLORD_TECHNOCRACY)) mine += 500;
        if (Tech.has(bits, Tech.ECONOMETRIC_PROBE)) mine += 100;
        if (Tech.has(bits, Tech.SURVEILLANCE_STATE)) s.scoutBps += 1_000;
        if (Tech.has(bits, Tech.CYBERNATED_SENTIENCE)) (off, def) = (off + 200, def + 200);
        s.offBps += off;
        s.defBps += def;
        s.mineBps += mine;
    }

    function _typeBoth(Stats memory s, uint8 t, uint256 bps) private pure {
        s.typeOff[t] += bps;
        s.typeDef[t] += bps;
    }

    // ------------------------------------------------------------------ mining & settlement

    function _miningPerDay(Citadel storage c, Stats memory s) internal view returns (uint256) {
        uint256 tile = _tileBps(c.ao, c.q, c.r);
        uint256 bonus = BPS + s.mineBps + (tile > BPS ? c.pilotHermetic : 0);
        uint256 rate = uint256(config.baseDkPerDay) * Traits.sektMultiplier(c.sekt) * tile * bonus / (BPS * BPS)
            / Traits.genOutputDivisor(c.generation);
        return c.doomRiot ? rate * 2 : rate;
    }

    function _accrue(Citadel storage c, Stats memory s, uint256 until) private {
        if (until <= c.lastSync) return;
        c.vault += uint128(_miningPerDay(c, s) * (until - c.lastSync) / 1 days);
        c.lastSync = uint64(until);
    }

    /// @dev Settles mining into the vault, finished construction into levels and finished training into the garrison.
    function _sync(uint256 id) internal {
        Citadel storage c = _citadels[id];
        Stats memory s = _stats(id);
        Construction storage k = _construction[id];
        if (k.end != 0 && k.end <= block.timestamp) {
            _accrue(c, s, k.end);
            _completeConstruction(id);
            s = _stats(id);
        }
        _accrue(c, s, block.timestamp);
        for (uint8 t; t < FLEET_TYPES; ++t) {
            Batch storage b = _training[id][t];
            uint64 fin = _finished(b);
            if (fin > b.done) {
                _garrison[id][t] += fin - b.done;
                b.done = fin;
            }
        }
    }

    function _completeConstruction(uint256 id) internal {
        Construction memory k = _construction[id];
        Citadel storage c = _citadels[id];
        c.levels[k.building] = k.level;
        walletScore[c.owner] += 2 * uint256(k.level) - 1; // score counts level^2
        delete _construction[id];
        emit BuildCompleted(id, k.building, k.level);
    }

    function _finished(Batch memory b) internal view returns (uint64) {
        if (b.total == b.done) return b.done;
        uint256 n = (block.timestamp - b.start) / b.unitSecs;
        return n >= b.total ? b.total : uint64(n);
    }

    // ------------------------------------------------------------------ placement

    struct Spot {
        uint8 ao;
        int16 q;
        int16 r;
        uint8 faction;
        uint8 research;
    }

    /// @dev Puts a CITADEL already in game custody (with its PILOT) onto a free, checked tile.
    function _place(uint256 id, address owner_, Spot memory at, uint256[] memory pilots, bool doomRiot) internal {
        if (at.faction >= FACTIONS || at.research >= Tech.BRANCHES) revert BadFaction();
        uint64 k = _checkTile(at.ao, at.q, at.r);
        Traits.CitadelTraits memory t = citadelNft.traitsOf(id);

        Citadel storage c = _citadels[id];
        c.owner = owner_;
        c.lit = true;
        c.doomRiot = doomRiot;
        c.ao = at.ao;
        c.q = at.q;
        c.r = at.r;
        c.faction = at.faction;
        c.research = at.research;
        c.generation = t.generation;
        c.sekt = t.sekt;
        c.shield = t.shield;
        c.engine = t.engine;
        c.weapon = t.weapon;
        c.tech = t.tech;
        c.lastSync = uint64(block.timestamp);
        c.lastClaim = uint64(block.timestamp);
        _setPilotBonuses(c, owner_, pilots);
        _pilots[id] = pilots;
        _occupant[k] = id + 1;
        epochOf[id]++;
        walletScore[owner_] += _citadelScore(c);
        _registerResearch(id, c);
        emit Lit(id, owner_, at.ao, at.q, at.r, at.faction);
    }

    function _setPilotBonuses(Citadel storage c, address owner_, uint256[] memory pilots) private {
        uint256[6] memory v; // off, def, mine, hermetic, scout, research
        for (uint256 i; i < pilots.length; ++i) {
            Traits.PilotTraits memory p = pilotNft.traitsOf(pilots[i]);
            _pilotController[pilots[i]] = owner_;
            uint256 b = Traits.pilotBps(p.level, p.generation);
            v[0] += b;
            v[1] += b;
            if (p.subjugation == Traits.SUBJ_DREDGE_NOBILITY) v[2] += b;
            else if (p.subjugation == Traits.SUBJ_HERMETIC_STRACHT) v[3] += b;
            else if (p.subjugation == Traits.SUBJ_CRHONA_THROT) v[1] += b;
            else if (p.subjugation == Traits.SUBJ_SIF_COMMANDER) v[0] += b;
            else if (p.subjugation == Traits.SUBJ_PSIONIC_FUROR) v[4] += 5 * b;
            else if (p.subjugation == Traits.SUBJ_ALKAHEST_DRIFT) v[5] += 5 * b;
        }
        c.pilotOff = uint32(v[0]);
        c.pilotDef = uint32(v[1]);
        c.pilotMine = uint32(v[2]);
        c.pilotHermetic = uint32(v[3]);
        c.pilotScout = uint32(v[4]);
        c.pilotResearch = uint32(v[5]);
    }

    function _registerResearch(uint256 id, Citadel storage c) internal {
        bool key = c.generation == 0 && c.sekt == Traits.SEKT_RELIK && c.tech == c.research;
        techTree.register(id, c.faction, c.research, _researchPerDay(c), key);
    }

    /// @dev research/day = researchPerDay x SEKT / generation divisor x ALKAHEST DRIFT bonus, x2 on its own tech.
    function _researchPerDay(Citadel storage c) internal view returns (uint256 rate) {
        rate = uint256(config.researchPerDay) * Traits.sektMultiplier(c.sekt) / Traits.genOutputDivisor(c.generation)
            * (BPS + c.pilotResearch) / BPS;
        if (c.research == c.tech) rate *= 2;
    }

    function _buildCost(uint8 building, uint8 level) internal view returns (uint256 cost, uint256 time) {
        uint16[11] memory costMult = [uint16(0), 1, 2, 4, 7, 12, 20, 33, 55, 90, 150];
        uint16[11] memory timeMult = [uint16(0), 10, 15, 20, 30, 40, 60, 80, 120, 160, 240];
        cost = uint256(buildingBaseCost[building]) * costMult[level];
        time = uint256(buildingBaseTime[building]) * timeMult[level] / 10;
    }

    function _pilotMintCost(uint256 citadelId) internal view returns (uint256) {
        return uint256(config.pilotFleetPoints) * (2 ** uint256(pilotsMintedBy[citadelId]))
            * (3 ** uint256(_citadels[citadelId].generation));
    }

    /// @dev Takes a CITADEL off the grid and returns its NFTs. `destroyed` = leveled in a siege: GEN1+ CITADEL are
    /// burned. Returns the vault, which the caller pays out or forfeits.
    function _remove(uint256 id, bool destroyed) internal returns (uint256 vault) {
        Citadel storage c = _citadels[id];
        address owner_ = c.owner;
        vault = c.vault;
        uint256[] memory pilots = _pilots[id];
        uint256 mentat = c.mentat;

        techTree.unregister(id);
        walletScore[owner_] -= _citadelScore(c);
        delete _occupant[Hex.key(c.ao, c.q, c.r)];
        delete _citadels[id];
        delete _garrison[id];
        delete _training[id];
        delete _construction[id];
        delete _pilots[id];
        epochOf[id]++;

        if (destroyed && id >= citadelNft.MAX_CITADEL()) citadelNft.burn(id);
        else citadelNft.transferFrom(address(this), owner_, id);
        for (uint256 i; i < pilots.length; ++i) {
            delete _pilotController[pilots[i]];
            pilotNft.transferFrom(address(this), owner_, pilots[i]);
        }
        if (mentat != 0) {
            delete _mentatController[mentat - 1];
            mentatNft.transferFrom(address(this), owner_, mentat - 1);
        }
        if (destroyed) emit Leveled(id, owner_, id >= citadelNft.MAX_CITADEL());
    }

    /// @dev score = (GEN0 ? 50 : 10) + sum of building level^2. WALLET LEVEL = floor(sqrt(score)).
    function _citadelScore(Citadel storage c) internal view returns (uint256 s) {
        s = c.generation == 0 ? 50 : 10;
        for (uint8 b; b < BUILDINGS; ++b) {
            s += uint256(c.levels[b]) ** 2;
        }
    }

    /// @dev Mints a GEN1+ CITADEL with rolled traits into game custody and places it.
    function _found(address owner_, uint8 generation, Spot memory at, uint256 pilotId, bool doomRiot)
        internal
        returns (uint256 id)
    {
        Traits.CitadelTraits memory t = Rand.citadel(Rand.seed(_nonce++), generation);
        id = citadelNft.mintGenerated(address(this), t);
        uint256[] memory pilots = new uint256[](1);
        pilots[0] = pilotId;
        at.research = t.tech;
        _place(id, owner_, at, pilots, doomRiot);
    }

    // ------------------------------------------------------------------ fleet

    function _takeUnits(uint256 id, uint64[4] memory units) internal {
        if (units[0] == 0 && units[1] == 0 && units[2] == 0 && units[3] == 0) revert NoUnits();
        uint64[4] storage g = _garrison[id];
        for (uint8 t; t < FLEET_TYPES; ++t) {
            if (g[t] < units[t]) revert NotEnoughUnits(t);
            g[t] -= units[t];
        }
    }

    function _addUnits(uint256 id, uint64[4] memory units) internal {
        uint64[4] storage g = _garrison[id];
        for (uint8 t; t < FLEET_TYPES; ++t) {
            g[t] += units[t];
        }
    }

    /// @dev Travel time per tile of a fleet: its slowest unit, sped up by the sender's propulsion tech.
    function _secsPerTile(uint64[4] memory units, Stats memory s) internal view returns (uint256 slowest) {
        for (uint8 t; t < FLEET_TYPES; ++t) {
            if (units[t] == 0) continue;
            uint256 secs = uint256(fleetTypes[t].secsPerTile) * BPS / (BPS + s.speedBps[t]);
            if (secs > slowest) slowest = secs;
        }
    }

    function _value(uint64[4] memory units) internal view returns (uint256 v) {
        for (uint8 t; t < FLEET_TYPES; ++t) {
            v += uint256(units[t]) * fleetTypes[t].cost;
        }
    }

    function _isEmpty(uint64[4] memory u) internal pure returns (bool) {
        return u[0] == 0 && u[1] == 0 && u[2] == 0 && u[3] == 0;
    }

    function _hostsSovereign(uint256 id) internal view returns (bool) {
        uint256[] storage ps = _pilots[id];
        for (uint256 i; i < ps.length; ++i) {
            if (pilotNft.traitsOf(ps[i]).sovereign) return true;
        }
        return false;
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return Math.min(a, b);
    }
}
