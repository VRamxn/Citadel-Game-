// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {BattleBase} from "./BattleBase.sol";
import {GameStorage} from "./GameStorage.sol";
import {Traits} from "../lib/Traits.sol";

/// @title CITADEL war: raids, scouting, reinforcement and sieges.
/// @notice Runs only by delegatecall from CitadelGame, against its storage. Calling it directly does nothing useful.
///
/// Every march travels `distance x seconds-per-tile of its slowest unit`, except against an adjacent CITADEL (subgrid
/// distortion) or while the whole grid is distorted, when it resolves in the same transaction. Arrived marches are
/// settled by anyone through `resolve`, and sieges by anyone through `advanceSiege`.
contract WarModule is BattleBase {
    constructor() GameStorage(msg.sender) {}

    function selectors() external pure returns (bytes4[] memory s) {
        s = new bytes4[](6);
        s[0] = this.raid.selector;
        s[1] = this.scout.selector;
        s[2] = this.reinforce.selector;
        s[3] = this.siege.selector;
        s[4] = this.joinSiege.selector;
        s[5] = this.resolve.selector;
    }

    // ================================================================ orders

    /// @notice Raid another CITADEL's unclaimed DK.
    /// @return marchId 0 if the raid resolved instantly.
    function raid(uint256 fromId, uint256 toId, uint64[4] calldata units) external nonReentrant returns (uint256) {
        (Citadel storage a, Citadel storage d) = _orderPair(fromId, toId);
        _sync(fromId);
        _takeUnits(fromId, units);
        if (_instant(a, d)) {
            _sync(toId);
            Fight memory f;
            f.units = units;
            uint256 carried = _raidBattle(0, fromId, toId, f, false);
            _addUnits(fromId, f.units);
            a.vault += uint128(carried);
            return 0;
        }
        a.outgoing++;
        d.incoming++;
        return _send(MarchKind.Raid, fromId, toId, units, _travel(fromId, a, d, units), 0);
    }

    /// @notice Send DALAA MAX to read a CITADEL's garrison, vault and buildings (a ScoutReport event).
    function scout(uint256 fromId, uint256 toId, uint64[4] calldata units) external nonReentrant returns (uint256) {
        if (units[0] != 0 || units[1] != 0 || units[2] != 0) revert ScoutsOnly();
        (Citadel storage a, Citadel storage d) = _orderPair(fromId, toId);
        _sync(fromId);
        _takeUnits(fromId, units);
        if (_instant(a, d)) {
            _sync(toId);
            _addUnits(fromId, _scoutBattle(0, fromId, toId, units));
            return 0;
        }
        a.outgoing++;
        d.incoming++;
        return _send(MarchKind.Scout, fromId, toId, units, _travel(fromId, a, d, units), 0);
    }

    /// @notice Send fleet to any lit CITADEL (yours, your faction's, anyone's). The units join its garrison.
    /// A CITADEL under siege can't send reinforcements.
    function reinforce(uint256 fromId, uint256 toId, uint64[4] calldata units) external nonReentrant returns (uint256) {
        (Citadel storage a, Citadel storage d) = _orderPair(fromId, toId);
        if (a.besieged != 0) revert Besieged();
        _sync(fromId);
        _takeUnits(fromId, units);
        if (_instant(a, d)) {
            _addUnits(toId, units);
            emit Reinforced(0, fromId, toId, units);
            return 0;
        }
        d.incoming++;
        return _send(MarchKind.Reinforce, fromId, toId, units, _travel(fromId, a, d, units), 0);
    }

    /// @notice Lay siege to a CITADEL. Bring a PILOT (from your wallet, pilotId + 1; 0 = none) to capture the tile
    /// and found a CITADEL on it; without one a successful siege only levels the target.
    function siege(uint256 fromId, uint256 toId, uint64[4] calldata units, uint256 pilot)
        external
        nonReentrant
        returns (uint256)
    {
        (Citadel storage a, Citadel storage d) = _orderPair(fromId, toId);
        if (_hostsSovereign(toId)) revert SovereignProtected();
        _sync(fromId);
        _takeUnits(fromId, units);
        if (pilot != 0) {
            pilotNft.transferFrom(msg.sender, address(this), pilot - 1);
            _pilotController[pilot - 1] = msg.sender;
        }
        a.outgoing++;
        if (_instant(a, d)) {
            _startSiege(0, fromId, toId, units, pilot, msg.sender);
            return 0;
        }
        d.incoming++;
        return _send(MarchKind.Siege, fromId, toId, units, _travel(fromId, a, d, units), pilot);
    }

    /// @notice Send more fleet to an active siege. They travel to the besieged CITADEL.
    function joinSiege(uint256 siegeId, uint256 fromId, uint64[4] calldata units)
        external
        nonReentrant
        returns (uint256)
    {
        Siege storage g = _sieges[siegeId];
        if (!g.active) revert BadSiege();
        Citadel storage a = _owned(fromId);
        Citadel storage d = _lit(g.target);
        _sync(fromId);
        _takeUnits(fromId, units);
        if (_instant(a, d)) {
            for (uint8 t; t < FLEET_TYPES; ++t) {
                g.units[t] += units[t];
            }
            emit SiegeJoined(siegeId, units);
            return 0;
        }
        uint256 marchId = _send(MarchKind.SiegeJoin, fromId, siegeId, units, _travel(fromId, a, d, units), 0);
        _marches[marchId].targetEpoch = g.targetEpoch;
        return marchId;
    }

    // ================================================================ settlement (anyone)

    /// @notice Settle an arrived march: fight a raid, read a scout, start a siege, or land returning / reinforcing
    /// fleet. Resolving a raid pays the caller resolverFeeBps of the loot.
    function resolve(uint256 marchId) external nonReentrant {
        March storage m = _marches[marchId];
        if (m.kind == MarchKind.None || m.done) revert BadMarch();
        if (block.timestamp < m.arriveAt) revert NotArrived(m.arriveAt);
        m.done = true;
        MarchKind kind = m.kind;

        if (kind == MarchKind.Return) {
            if (_alive(m.origin, m.originEpoch)) {
                Citadel storage home = _citadels[m.origin];
                home.outgoing--;
                home.vault += m.loot;
                _addUnits(m.origin, m.units);
                emit MarchCompleted(marchId);
            } else {
                emit MarchLost(marchId);
            }
            return;
        }
        if (kind == MarchKind.SiegeJoin) {
            Siege storage g = _sieges[m.target];
            if (g.active) {
                for (uint8 t; t < FLEET_TYPES; ++t) {
                    g.units[t] += m.units[t];
                }
                emit SiegeJoined(m.target, m.units);
            } else {
                _returnHome(marchId, m, 0);
            }
            return;
        }

        bool targetAlive = _alive(m.target, m.targetEpoch);
        if (targetAlive) _citadels[m.target].incoming--;

        if (kind == MarchKind.Reinforce) {
            if (targetAlive) {
                _addUnits(m.target, m.units);
                emit Reinforced(marchId, m.origin, m.target, m.units);
            } else {
                _returnHome(marchId, m, 0);
            }
            return;
        }

        // Raid, Scout and Siege marches are outgoing for their origin until they come home.
        if (!targetAlive) {
            if (kind == MarchKind.Siege && m.pilot != 0) _releasePilot(m.pilot - 1, m.sender);
            _returnHome(marchId, m, 0);
            return;
        }
        _sync(m.target);
        if (kind == MarchKind.Siege) {
            if (_hostsSovereign(m.target)) {
                if (m.pilot != 0) _releasePilot(m.pilot - 1, m.sender);
                _returnHome(marchId, m, 0);
            } else {
                _startSiege(marchId, m.origin, m.target, m.units, m.pilot, m.sender);
            }
            return;
        }
        if (kind == MarchKind.Raid && block.timestamp > uint256(m.arriveAt) + config.defectionWindow) {
            _addUnits(m.target, m.units);
            if (_alive(m.origin, m.originEpoch)) _citadels[m.origin].outgoing--;
            emit Defected(marchId, m.origin, m.target, m.units);
            return;
        }
        _fightArrived(marchId, m, kind);
    }

    function _fightArrived(uint256 marchId, March storage m, MarchKind kind) private {
        Fight memory f;
        f.units = m.units;
        uint256 carried;
        if (kind == MarchKind.Raid) carried = _raidBattle(marchId, m.origin, m.target, f, true);
        else f.units = _scoutBattle(marchId, m.origin, m.target, f.units);
        uint64[4] memory survivors = f.units;
        if (_isEmpty(survivors)) {
            if (_alive(m.origin, m.originEpoch)) _citadels[m.origin].outgoing--;
            return;
        }
        m.units = survivors;
        _returnHome(marchId, m, carried);
    }

    // ================================================================ internals: orders

    function _orderPair(uint256 fromId, uint256 toId) private view returns (Citadel storage a, Citadel storage d) {
        if (fromId == toId) revert SameCitadel();
        a = _owned(fromId);
        d = _lit(toId);
    }

    function _travel(uint256 fromId, Citadel storage a, Citadel storage d, uint64[4] memory units)
        private
        view
        returns (uint256)
    {
        return _distance(a, d) * _secsPerTile(units, _stats(fromId));
    }

    function _send(
        MarchKind kind,
        uint256 origin,
        uint256 target,
        uint64[4] memory units,
        uint256 travel,
        uint256 pilot
    ) private returns (uint256 marchId) {
        marchId = ++marchCount;
        uint64 arriveAt = uint64(block.timestamp + travel);
        March storage m = _marches[marchId];
        m.kind = kind;
        m.arriveAt = arriveAt;
        m.origin = origin;
        m.target = target;
        m.originEpoch = epochOf[origin];
        m.targetEpoch = kind == MarchKind.SiegeJoin ? 0 : epochOf[target];
        m.units = units;
        m.sender = msg.sender;
        m.pilot = pilot;
        emit MarchSent(marchId, kind, origin, target, arriveAt, units);
    }

    /// @dev Turn an arrived march around: survivors (and loot) travel back the way they came.
    function _returnHome(uint256 marchId, March storage m, uint256 loot) private {
        uint256 origin = m.origin;
        if (!_alive(origin, m.originEpoch)) {
            emit MarchLost(marchId);
            return;
        }
        uint256 from = m.kind == MarchKind.SiegeJoin ? _sieges[m.target].target : m.target;
        bool counted = m.kind == MarchKind.Raid || m.kind == MarchKind.Scout || m.kind == MarchKind.Siege;
        uint256 travel = _returnTravel(origin, from, m.units);
        Citadel storage home = _citadels[origin];
        if (travel == 0) {
            _addUnits(origin, m.units);
            home.vault += uint128(loot);
            if (counted) home.outgoing--;
            emit MarchCompleted(marchId);
            return;
        }
        if (!counted) home.outgoing++; // a returning march is always outgoing for its home
        _queueReturn(m, from, travel, loot);
    }

    /// @dev 0 = home at once: from an adjacent CITADEL, during distortion, or from a CITADEL that has since left the
    /// grid or an AO that was disconnected meanwhile (nowhere to travel from).
    function _returnTravel(uint256 origin, uint256 from, uint64[4] memory units) private view returns (uint256) {
        Citadel storage home = _citadels[origin];
        Citadel storage there = _citadels[from];
        if (!there.lit || _instant(home, there)) return 0;
        if (home.ao != there.ao && (aoState[home.ao] != AOState.Connected || aoState[there.ao] != AOState.Connected)) {
            return 0;
        }
        return _distance(home, there) * _secsPerTile(units, _stats(origin));
    }

    function _queueReturn(March storage m, uint256 from, uint256 travel, uint256 loot) private {
        uint256 id = ++marchCount;
        March storage r = _marches[id];
        r.kind = MarchKind.Return;
        r.arriveAt = uint64(Math.max(block.timestamp, m.arriveAt) + travel);
        r.origin = m.origin;
        r.target = from;
        r.originEpoch = m.originEpoch;
        r.targetEpoch = epochOf[from];
        r.units = m.units;
        r.loot = uint128(loot);
        r.sender = m.sender;
        emit MarchSent(id, MarchKind.Return, from, m.origin, r.arriveAt, m.units);
    }

    // ================================================================ internals: battle

    struct Fight {
        uint64[4] units; // attackers in; survivors out
        uint64[4] attLost;
        uint64[4] defLost;
        bool won;
        uint256 loot;
        uint256 fee;
    }

    /// @dev Raid: total attack vs total defense, decided in one battle. The loser is wiped out; the winner loses
    /// (weaker / stronger)^1.5 of every unit type, reduced by its weapons repair. Survivors carry DK home.
    /// Returns the DK the survivors carry (loot minus the resolver's fee); f.units becomes the survivors.
    function _raidBattle(uint256 marchId, uint256 fromId, uint256 toId, Fight memory f, bool payResolver)
        private
        returns (uint256)
    {
        _raidLosses(fromId, toId, f);
        uint256 capacity;
        for (uint8 t; t < FLEET_TYPES; ++t) {
            f.units[t] -= f.attLost[t];
            capacity += uint256(f.units[t]) * fleetTypes[t].carry * 1 ether;
        }
        _applyLosses(fromId, toId, f.attLost, f.defLost);

        Citadel storage d = _citadels[toId];
        f.loot = Math.min(capacity, d.vault);
        d.vault -= uint128(f.loot);
        f.fee = payResolver ? f.loot * config.resolverFeeBps / BPS : 0;
        if (f.fee != 0) drakma.mint(msg.sender, f.fee);
        emit RaidResolved(marchId, fromId, toId, f.won, f.attLost, f.defLost, f.loot, f.fee);
        return f.loot - f.fee;
    }

    function _raidLosses(uint256 fromId, uint256 toId, Fight memory f) private {
        Stats memory sa = _stats(fromId);
        Stats memory sd = _stats(toId);
        _uniques(sa, sd, f.units, toId);
        uint64[4] memory gar = _garrison[toId];
        uint256 atk = _attack(sa, f.units, false);
        uint256 def = _defense(sd, gar, false);
        f.won = atk > def;
        uint256 loss = f.won ? _lossRatio(def, atk, sa.repairBps) : _lossRatio(atk, def, sd.repairBps);
        for (uint8 t; t < FLEET_TYPES; ++t) {
            f.attLost[t] = f.won ? _applyLoss(f.units[t], loss) : f.units[t];
            f.defLost[t] = f.won ? gar[t] : _applyLoss(gar[t], loss);
        }
    }

    /// @dev Scouts vs the defender's scouts. Success reveals the target in a ScoutReport.
    function _scoutBattle(uint256 marchId, uint256 fromId, uint256 toId, uint64[4] memory units)
        private
        returns (uint64[4] memory survivors)
    {
        Stats memory sa = _stats(fromId);
        Stats memory sd = _stats(toId);
        uint64[4] memory gar = _garrison[toId];
        uint8 S = Traits.DALAA_MAX;
        uint256 atk = uint256(units[S]) * (BPS + sa.scoutBps);
        uint256 def = uint256(gar[S]) * (BPS + sd.scoutBps);
        uint64[4] memory attLost;
        uint64[4] memory defLost;
        bool success = atk > def;
        if (success) {
            attLost[S] = _applyLoss(units[S], _lossRatio(def, atk, 0));
            defLost[S] = gar[S];
        } else {
            attLost[S] = units[S];
            defLost[S] = _applyLoss(gar[S], _lossRatio(atk, def, 0));
        }
        survivors[S] = units[S] - attLost[S];
        _applyLosses(fromId, toId, attLost, defLost);
        _report(marchId, fromId, toId, success);
    }

    function _report(uint256 marchId, uint256 fromId, uint256 toId, bool success) private {
        if (success) {
            Citadel storage d = _citadels[toId];
            emit ScoutReport(marchId, fromId, toId, true, _garrison[toId], d.vault, d.levels);
        } else {
            uint64[4] memory none;
            uint8[6] memory nothing;
            emit ScoutReport(marchId, fromId, toId, false, none, 0, nothing);
        }
    }

    // ================================================================ internals: siege

    function _startSiege(
        uint256 marchId,
        uint256 fromId,
        uint256 toId,
        uint64[4] memory units,
        uint256 pilot,
        address attacker
    ) private {
        uint256 siegeId = ++siegeCount;
        Siege storage g = _sieges[siegeId];
        g.active = true;
        g.attacker = attacker;
        g.faction = _citadels[fromId].faction;
        g.origin = fromId;
        g.target = toId;
        g.originEpoch = epochOf[fromId];
        g.targetEpoch = epochOf[toId];
        g.pilot = pilot;
        g.start = uint64(block.timestamp);
        g.units = units;
        _citadels[toId].besieged++;
        marchId; // the march that carried the army, for indexers
        emit SiegeStarted(siegeId, fromId, toId, pilot);
    }
}
