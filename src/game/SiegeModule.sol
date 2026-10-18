// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {BattleBase} from "./BattleBase.sol";
import {GameStorage} from "./GameStorage.sol";
import {Traits} from "../lib/Traits.sol";

/// @title CITADEL siege battles. A siege fights one wave per siegeWaveSecs; progress runs 0 -> 100% and the siege
/// ends in capture/leveling at 100% or failure at 0%. Runs by delegatecall from CitadelGame against its storage.
contract SiegeModule is BattleBase {
    constructor() GameStorage(msg.sender) {}

    function selectors() external pure returns (bytes4[] memory s) {
        s = new bytes4[](1);
        s[0] = this.advanceSiege.selector;
    }

    /// @notice Fight every siege wave that is due (up to maxWaves). Callable by anyone.
    function advanceSiege(uint256 siegeId, uint256 maxWaves) external nonReentrant {
        Siege storage g = _sieges[siegeId];
        if (!g.active) revert BadSiege();
        uint256 due = (block.timestamp - g.start) / config.siegeWaveSecs;
        if (due <= g.waves) revert NothingDue();
        if (!_alive(g.target, g.targetEpoch)) {
            _endSiege(siegeId, false, true);
            return;
        }

        _sync(g.target);
        bool originAlive = _alive(g.origin, g.originEpoch);
        Stats memory sa;
        if (originAlive) sa = _stats(g.origin);
        Stats memory sd = _stats(g.target);
        uint256 pilotMult = BPS;
        if (g.pilot != 0) {
            Traits.PilotTraits memory p = pilotNft.traitsOf(g.pilot - 1);
            pilotMult += Traits.pilotBps(p.level, p.generation);
            if (p.sovereign) pilotMult *= 2;
        }
        uint256 n = Math.min(due - g.waves, maxWaves);
        for (uint256 i; i < n; ++i) {
            g.waves++;
            if (_wave(siegeId, g, sa, sd, pilotMult)) return;
        }
    }

    /// @dev One hourly siege battle. Each side loses attrition x (enemy power / own power) of its units, capped at all
    /// of them. Progress moves by maxSwing x (A - D) / (A + D) — twice as fast when the siege is losing — where
    /// maxSwing makes siegeMinWaves the fastest possible siege. Returns true if the siege ended.
    function _wave(uint256 siegeId, Siege storage g, Stats memory sa, Stats memory sd, uint256 pilotMult)
        private
        returns (bool)
    {
        uint64[4] memory units = g.units;
        _uniques(sa, sd, units, g.target);
        uint64[4] memory gar = _garrison[g.target];
        uint256 atk = _attack(sa, units, true) * pilotMult / BPS;
        uint256 def = _defense(sd, gar, true);

        uint256 attr = config.siegeAttritionBps;
        uint256 attFrac = atk == 0 ? WAD : Math.min(WAD, attr * def * WAD / (atk * BPS));
        uint256 defFrac = def == 0 ? WAD : Math.min(WAD, attr * atk * WAD / (def * BPS));
        attFrac = attFrac * (BPS - Math.min(sa.repairBps, BPS)) / BPS;
        defFrac = defFrac * (BPS - Math.min(sd.repairBps, BPS)) / BPS;
        uint64[4] memory attLost;
        uint64[4] memory defLost;
        for (uint8 t; t < FLEET_TYPES; ++t) {
            attLost[t] = _roundLoss(units[t], attFrac);
            defLost[t] = _roundLoss(gar[t], defFrac);
            units[t] -= attLost[t];
        }
        g.units = units;
        _applyLosses(g.origin, g.target, attLost, defLost);
        // FLEET POINTS from a siege go to the origin even if it was leveled meanwhile; harmless.

        int256 maxSwing = int256(Math.ceilDiv(BPS, config.siegeMinWaves));
        int256 delta = maxSwing * (int256(atk) - int256(def)) / int256(atk + def + 1);
        if (delta < 0) delta *= 2;
        int256 p = int256(g.progress) + delta;
        if (p > int256(BPS)) p = int256(BPS);
        g.progress = int32(p);
        emit SiegeWave(siegeId, g.waves, g.progress, attLost, defLost);

        if (p >= int256(BPS)) {
            _endSiege(siegeId, true, false);
            return true;
        }
        if (p <= 0 || _isEmpty(units)) {
            _endSiege(siegeId, false, false);
            return true;
        }
        return false;
    }

    function _roundLoss(uint64 n, uint256 frac) private pure returns (uint64) {
        return uint64(Math.min((uint256(n) * frac + WAD / 2) / WAD, n));
    }

    /// @dev success: the target is leveled, its vault goes to the attacker and, with a PILOT, a new CITADEL is founded
    /// on its tile with the surviving army as garrison. failure: the army is destroyed; a GEN0 PILOT retreats to its
    /// owner's wallet, later generations are destroyed. targetGone: the target left the grid; everyone goes home.
    function _endSiege(uint256 siegeId, bool success, bool targetGone) private {
        Siege storage g = _sieges[siegeId];
        g.active = false;
        uint256 origin = g.origin;
        bool originAlive = _alive(origin, g.originEpoch);
        uint256 newCitadel;

        if (targetGone) {
            if (g.pilot != 0) _releasePilot(g.pilot - 1, g.attacker);
            if (originAlive) {
                _addUnits(origin, g.units);
                _citadels[origin].outgoing--;
            }
            emit SiegeEnded(siegeId, false, 0);
            return;
        }

        Citadel storage d = _citadels[g.target];
        d.besieged--;
        if (success) {
            (uint8 ao, int16 q, int16 r) = (d.ao, d.q, d.r);
            uint256 vault = _remove(g.target, true);
            if (vault != 0) drakma.mint(g.attacker, vault);
            if (g.pilot != 0) {
                uint256 pid = g.pilot - 1;
                Traits.PilotTraits memory p = pilotNft.traitsOf(pid);
                delete _pilotController[pid];
                newCitadel = _found(
                    g.attacker, p.generation == 0 ? 1 : p.generation, Spot(ao, q, r, g.faction, 0), pid, p.death
                );
                _addUnits(newCitadel, g.units);
            } else if (originAlive) {
                _addUnits(origin, g.units); // the army marches home over the ruins
            }
        } else if (g.pilot != 0) {
            uint256 pid = g.pilot - 1;
            if (pilotNft.traitsOf(pid).generation == 0) {
                _releasePilot(pid, g.attacker);
            } else {
                delete _pilotController[pid];
                pilotNft.burn(pid);
            }
        }
        if (originAlive) _citadels[origin].outgoing--;
        emit SiegeEnded(siegeId, success, newCitadel);
    }
}
