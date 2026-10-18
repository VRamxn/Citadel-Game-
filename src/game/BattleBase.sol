// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {GameBase} from "./GameBase.sol";
import {Traits} from "../lib/Traits.sol";

/// @notice Combat math, events and errors shared by WarModule and SiegeModule.
abstract contract BattleBase is GameBase {
    event RaidResolved(
        uint256 indexed marchId,
        uint256 indexed attacker,
        uint256 indexed defender,
        bool attackerWon,
        uint64[4] attackerLost,
        uint64[4] defenderLost,
        uint256 loot,
        uint256 resolverFee
    );
    event ScoutReport(
        uint256 indexed marchId,
        uint256 indexed scout,
        uint256 indexed target,
        bool success,
        uint64[4] garrison,
        uint256 vault,
        uint8[6] levels
    );
    event Defected(uint256 indexed marchId, uint256 indexed attacker, uint256 indexed defender, uint64[4] units);
    event Reinforced(uint256 indexed marchId, uint256 indexed origin, uint256 indexed target, uint64[4] units);
    event MarchCompleted(uint256 indexed marchId);
    event MarchLost(uint256 indexed marchId);
    event SiegeStarted(uint256 indexed siegeId, uint256 indexed attacker, uint256 indexed target, uint256 pilot);
    event SiegeWave(
        uint256 indexed siegeId, uint32 wave, int32 progress, uint64[4] attackerLost, uint64[4] defenderLost
    );
    event SiegeJoined(uint256 indexed siegeId, uint64[4] units);
    event SiegeEnded(uint256 indexed siegeId, bool success, uint256 newCitadel);

    error SameCitadel();
    error BadMarch();
    error NotArrived(uint64 arriveAt);
    error ScoutsOnly();
    error Besieged();
    error SovereignProtected();
    error BadSiege();
    error NothingDue();

    function _releasePilot(uint256 pilotId, address to) internal {
        delete _pilotController[pilotId];
        pilotNft.transferFrom(address(this), to, pilotId);
    }

    /// @dev Pre-battle unique weapon effects. DEI IUDICIUM (defender): 5% of attackers desert to the defender.
    /// VEERDACHT MAGH: destroys 5% of the attackers when defending, 2% of the defenders when attacking.
    function _uniques(Stats memory sa, Stats memory sd, uint64[4] memory units, uint256 defId) internal {
        uint64[4] storage gar = _garrison[defId];
        for (uint8 t; t < FLEET_TYPES; ++t) {
            if (sd.deiIudicium) {
                uint64 desert = units[t] / 20;
                units[t] -= desert;
                gar[t] += desert;
            }
            if (sd.veerdacht) units[t] -= units[t] / 20;
            if (sa.veerdacht) gar[t] -= gar[t] / 50;
        }
    }

    function _attack(Stats memory sa, uint64[4] memory units, bool siege_) internal view returns (uint256 a) {
        for (uint8 t; t < FLEET_TYPES; ++t) {
            uint256 bonus = BPS + sa.offBps + sa.typeOff[t];
            if (siege_ && t == Traits.DREBENTRAAKHT) bonus += BPS; // siege ships hit fortifications twice as hard
            a += uint256(units[t]) * fleetTypes[t].op * bonus / BPS;
        }
    }

    function _defense(Stats memory sd, uint64[4] memory gar, bool siege_) internal view returns (uint256 d) {
        uint256 extra = siege_ ? sd.siegeDefBps : 0;
        for (uint8 t; t < FLEET_TYPES; ++t) {
            // Only MHRUDVOG THROT fortify (0xCITADEL alpha post); everything else defends at its base DP.
            uint256 fort = t == Traits.MHRUDVOG_THROT ? sd.fortBps : 0;
            d += uint256(gar[t]) * fleetTypes[t].dp * (BPS + fort + sd.defBps + sd.typeDef[t] + extra) / BPS;
        }
        d += sd.structure * (BPS + sd.defBps + extra) / BPS;
    }

    function _applyLosses(uint256 fromId, uint256 toId, uint64[4] memory attLost, uint64[4] memory defLost) internal {
        uint64[4] storage gar = _garrison[toId];
        for (uint8 t; t < FLEET_TYPES; ++t) {
            gar[t] -= defLost[t];
        }
        // FLEET POINTS = DK value of enemy fleet destroyed, in whole DK. Fighting yourself earns nothing, so FLEET
        // POINTS (and the PILOT they mint) can't simply be bought by feeding one of your CITADEL to another.
        if (_citadels[fromId].owner == _citadels[toId].owner) return;
        fleetPoints[fromId] += uint128(_value(defLost) / 1 ether);
        fleetPoints[toId] += uint128(_value(attLost) / 1 ether);
    }

    /// @dev (weaker / stronger)^1.5 in WAD, reduced by repairBps. Requires weaker <= stronger, stronger > 0.
    function _lossRatio(uint256 weaker, uint256 stronger, uint256 repairBps) internal pure returns (uint256) {
        uint256 r = weaker * WAD / stronger;
        uint256 loss = r * Math.sqrt(r * WAD) / WAD;
        return loss * (BPS - Math.min(repairBps, BPS)) / BPS;
    }

    /// @dev Units lost from a stack, rounding losses up so a winner can't take zero losses from a real fight.
    function _applyLoss(uint64 n, uint256 loss) internal pure returns (uint64) {
        if (loss == 0 || n == 0) return 0;
        return uint64(Math.min(Math.ceilDiv(uint256(n) * loss, WAD), n));
    }
}
