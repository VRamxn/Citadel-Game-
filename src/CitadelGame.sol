// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ICitadelTraits, IPilotTraits, IDrakma} from "./interfaces/IGameAssets.sol";
import {Hex} from "./lib/Hex.sol";
import {Traits} from "./lib/Traits.sol";

/// @title CITADEL — fully on-chain post-human war game on a hexagonal grid.
/// @notice Implements the 0xCITADEL alpha (v0.1) ruleset: lite CITADEL + PILOT to the grid, mine DRAKMA,
/// train FLEET, raid, reinforce, claim. Siege, sovereignty and the tech tree are later milestones.
/// See docs/RULES.md for the formulas and where each number comes from.
///
/// All state is evaluated lazily: mining and training progress are settled whenever a CITADEL is touched
/// (`_sync`), so no keeper is required except to resolve marches, which anyone may do (and is paid to).
contract CitadelGame is Ownable2Step, ReentrancyGuard {
    uint8 public constant FLEET_TYPES = 3; // 0 SIF GATTACA, 1 MHRUDVOG THROT, 2 DREBENTRAAKHT
    uint8 public constant FACTIONS = 4; // 0 NETWORK STATE, 1 AUTONOMOUS ZONE, 2 SANCTION, 3 ANNEXATION
    uint256 private constant BPS = 10_000;
    uint256 private constant WAD = 1e18;

    enum MarchKind {
        None,
        Raid,
        Return,
        Reinforce
    }

    struct FleetType {
        uint32 op; // offense points per unit
        uint32 dp; // defense points per unit
        uint32 carry; // whole DK carried home per surviving unit
        uint32 secsPerTile; // travel speed; a march moves at its slowest unit
        uint32 trainSecs; // training time per unit
        uint128 cost; // DK (wei) per unit
    }

    struct Config {
        uint128 baseDkPerDay; // before SEKT, tile and bonus multipliers
        uint32 claimInterval; // min seconds between claims of one CITADEL
        uint32 defectionWindow; // an arrived raid unresolved for this long defects to the defender
        uint16 resolverFeeBps; // share of loot paid to whoever resolves a travelling raid
        uint16 fortificationBps; // defensive bonus for fleet stationed in a CITADEL
        uint8 maxPilots; // per CITADEL
        bool distortion; // grid-wide subgrid distortion: every march is instant
    }

    struct Citadel {
        address owner;
        int16 q;
        int16 r;
        uint8 faction;
        uint8 sektMultiplier;
        bool lit;
        uint64 lastSync;
        uint64 lastClaim;
        uint32 mineBps;
        uint32 hermeticBps; // mining bonus that only applies on hotspot tiles
        uint32 offBps;
        uint32 defBps;
        uint32 repairBps;
        uint32 incoming; // unresolved raids + reinforcements headed here
        uint32 outgoing; // this CITADEL's raids still out (travelling or returning)
        uint128 vault; // mined + looted DK not yet claimed; raidable
        uint128 fleetPoints;
    }

    struct Batch {
        uint64 total;
        uint64 done;
        uint64 start;
        uint32 unitSecs;
    }

    struct March {
        MarchKind kind;
        bool done;
        uint64 arriveAt;
        uint256 origin;
        uint256 target;
        uint64[3] units;
        uint128 loot;
    }

    IERC721 public immutable citadelNft;
    IERC721 public immutable pilotNft;
    IDrakma public immutable drakma;
    /// @notice Grid is every tile within this hex distance of (0, 0): 3R(R+1)+1 tiles.
    uint16 public immutable radius;

    Config public config;
    FleetType[3] public fleetTypes;
    uint256 public marchCount;

    mapping(uint256 => Citadel) private _citadels;
    mapping(uint256 => uint64[3]) private _garrison;
    mapping(uint256 => Batch[3]) private _training;
    mapping(uint256 => uint256[]) private _pilots;
    mapping(uint256 => March) private _marches;
    mapping(uint32 => uint256) private _occupant; // tile key => citadelId + 1
    mapping(uint32 => uint32) private _tileBpsOverride; // 0 = use default hotspot layout

    event Lit(uint256 indexed citadelId, address indexed owner, int16 q, int16 r, uint8 faction, uint256[] pilots);
    event Unlit(uint256 indexed citadelId, address indexed owner, uint256 paidOut, uint256 forfeited);
    event FactionChanged(uint256 indexed citadelId, uint8 faction);
    event TrainingQueued(uint256 indexed citadelId, uint8 fleetType, uint64 amount, uint256 cost);
    event Claimed(uint256 indexed citadelId, address indexed to, uint256 amount);
    event MarchSent(
        uint256 indexed marchId,
        MarchKind kind,
        uint256 indexed origin,
        uint256 indexed target,
        uint64 arriveAt,
        uint64[3] units
    );
    event MarchCompleted(uint256 indexed marchId);
    event RaidResolved(
        uint256 indexed marchId,
        uint256 indexed attacker,
        uint256 indexed defender,
        bool attackerWon,
        uint64[3] attackerLost,
        uint64[3] defenderLost,
        uint256 loot,
        uint256 resolverFee
    );
    event Defected(uint256 indexed marchId, uint256 indexed attacker, uint256 indexed defender, uint64[3] units);
    event Reinforced(uint256 indexed marchId, uint256 indexed origin, uint256 indexed target, uint64[3] units);
    event ConfigUpdated(Config config);
    event FleetTypeUpdated(uint8 indexed fleetType, FleetType stats);
    event TileBpsUpdated(int16 q, int16 r, uint32 bps);

    error NotCitadelOwner(uint256 citadelId);
    error NotLit(uint256 citadelId);
    error OffGrid();
    error TileOccupied();
    error BadFaction();
    error BadFleetType();
    error TooManyPilots();
    error NoUnits();
    error NotEnoughUnits(uint8 fleetType);
    error SameCitadel();
    error Engaged();
    error ClaimCooldown(uint64 availableAt);
    error BadMarch();
    error NotArrived(uint64 arriveAt);
    error BadConfig();

    constructor(address owner_, address citadel_, address pilot_, IDrakma drakma_, uint16 radius_) Ownable(owner_) {
        citadelNft = IERC721(citadel_);
        pilotNft = IERC721(pilot_);
        drakma = drakma_;
        radius = radius_;

        // Fleet stats from the 0xCITADEL alpha post. Carry and speed were never published — see docs/RULES.md.
        fleetTypes[0] = FleetType(10, 5, 40, 30 minutes, 5 minutes, 20 ether); // SIF GATTACA
        fleetTypes[1] = FleetType(5, 40, 20, 45 minutes, 15 minutes, 40 ether); // MHRUDVOG THROT
        fleetTypes[2] = FleetType(500, 250, 200, 60 minutes, 60 minutes, 800 ether); // DREBENTRAAKHT

        config = Config({
            baseDkPerDay: 4_000 ether, // x SEKT multiplier = EXORDIUM daily rates (8k ELEKT .. 64k RELIK)
            claimInterval: 7 days,
            defectionWindow: 24 hours,
            resolverFeeBps: 1_000,
            fortificationBps: 5_000,
            maxPilots: 8,
            distortion: false
        });
    }

    // ---------------------------------------------------------------- grid

    function lite(uint256 citadelId, int16 q, int16 r, uint8 faction, uint256[] calldata pilotIds)
        external
        nonReentrant
    {
        if (faction >= FACTIONS) revert BadFaction();
        if (Hex.fromCenter(q, r) > radius) revert OffGrid();
        uint32 k = Hex.key(q, r);
        if (_occupant[k] != 0) revert TileOccupied();
        if (pilotIds.length > config.maxPilots) revert TooManyPilots();

        // transferFrom(msg.sender, ...) reverts unless the caller owns the token.
        citadelNft.transferFrom(msg.sender, address(this), citadelId);
        Traits.CitadelTraits memory t = ICitadelTraits(address(citadelNft)).traitsOf(citadelId);

        uint256 off = Traits.weaponBps(t.weapon);
        uint256 def = Traits.shieldBps(t.shield) * (BPS + Traits.engineRechargeBps(t.engine)) / BPS;
        uint256 mine;
        uint256 hermetic;
        if (t.shield == Traits.SHIELD_MYSTERIUM) mine += 500;
        if (t.engine == Traits.ENGINE_STROGOTHT) mine += 100;
        if (t.engine == Traits.ENGINE_DREADNAUGHT) mine += 500;

        for (uint256 i; i < pilotIds.length; ++i) {
            pilotNft.transferFrom(msg.sender, address(this), pilotIds[i]);
            Traits.PilotTraits memory p = IPilotTraits(address(pilotNft)).traitsOf(pilotIds[i]);
            uint256 b = Traits.pilotBps(p.level);
            off += b;
            def += b;
            if (p.subjugation == Traits.SUBJ_DREDGE_NOBILITY) mine += b;
            else if (p.subjugation == Traits.SUBJ_HERMETIC_STRACHT) hermetic += b;
            else if (p.subjugation == Traits.SUBJ_CRHONA_THROT) def += b;
            else if (p.subjugation == Traits.SUBJ_SIF_COMMANDER) off += b;
        }
        _pilots[citadelId] = pilotIds;

        _citadels[citadelId] = Citadel({
            owner: msg.sender,
            q: q,
            r: r,
            faction: faction,
            sektMultiplier: uint8(Traits.sektMultiplier(t.sekt)),
            lit: true,
            lastSync: uint64(block.timestamp),
            lastClaim: uint64(block.timestamp),
            mineBps: uint32(mine),
            hermeticBps: uint32(hermetic),
            offBps: uint32(off),
            defBps: uint32(def),
            repairBps: uint32(Traits.engineRepairBps(t.engine)),
            incoming: 0,
            outgoing: 0,
            vault: 0,
            fleetPoints: 0
        });
        _occupant[k] = citadelId + 1;
        emit Lit(citadelId, msg.sender, q, r, faction, pilotIds);
    }

    /// @notice Remove a CITADEL and its PILOT from the grid. Not allowed while any march involves it.
    /// The vault is paid out if a claim is available, otherwise it is forfeited. Garrison and training are disbanded.
    function unlite(uint256 citadelId) external nonReentrant {
        Citadel storage c = _owned(citadelId);
        if (c.incoming != 0 || c.outgoing != 0) revert Engaged();
        _sync(citadelId);

        uint256 vault = c.vault;
        bool canClaim = block.timestamp >= uint256(c.lastClaim) + config.claimInterval;
        address owner_ = c.owner;
        uint256[] memory pilots = _pilots[citadelId];

        delete _occupant[Hex.key(c.q, c.r)];
        delete _citadels[citadelId];
        delete _garrison[citadelId];
        delete _training[citadelId];
        delete _pilots[citadelId];

        if (canClaim && vault != 0) drakma.mint(owner_, vault);
        citadelNft.transferFrom(address(this), owner_, citadelId);
        for (uint256 i; i < pilots.length; ++i) {
            pilotNft.transferFrom(address(this), owner_, pilots[i]);
        }
        emit Unlit(citadelId, owner_, canClaim ? vault : 0, canClaim ? 0 : vault);
    }

    function setFaction(uint256 citadelId, uint8 faction) external {
        Citadel storage c = _owned(citadelId);
        if (faction >= FACTIONS) revert BadFaction();
        if (c.incoming != 0 || c.outgoing != 0) revert Engaged();
        c.faction = faction;
        emit FactionChanged(citadelId, faction);
    }

    // ---------------------------------------------------------------- economy

    function train(uint256 citadelId, uint8 fleetType, uint64 amount) external nonReentrant {
        _owned(citadelId);
        if (fleetType >= FLEET_TYPES) revert BadFleetType();
        if (amount == 0) revert NoUnits();
        _sync(citadelId);

        FleetType memory f = fleetTypes[fleetType];
        uint256 cost = uint256(f.cost) * amount;
        drakma.gameBurn(msg.sender, cost);

        Batch storage b = _training[citadelId][fleetType];
        if (b.done == b.total) {
            _training[citadelId][fleetType] = Batch(amount, 0, uint64(block.timestamp), f.trainSecs);
        } else {
            b.total += amount; // queued behind the units already in training
        }
        emit TrainingQueued(citadelId, fleetType, amount, cost);
    }

    function claim(uint256 citadelId) external nonReentrant {
        Citadel storage c = _owned(citadelId);
        _sync(citadelId);
        uint64 availableAt = c.lastClaim + config.claimInterval;
        if (block.timestamp < availableAt) revert ClaimCooldown(availableAt);
        uint256 amount = c.vault;
        c.vault = 0;
        c.lastClaim = uint64(block.timestamp);
        if (amount != 0) drakma.mint(msg.sender, amount);
        emit Claimed(citadelId, msg.sender, amount);
    }

    // ---------------------------------------------------------------- war

    /// @notice Raid another CITADEL's unclaimed DK. Adjacent targets (or any target during grid distortion)
    /// resolve in this transaction; otherwise the fleet travels and anyone can resolve it on arrival.
    /// @return marchId 0 for an instant raid.
    function raid(uint256 fromId, uint256 toId, uint64[3] calldata units)
        external
        nonReentrant
        returns (uint256 marchId)
    {
        Citadel storage a = _owned(fromId);
        Citadel storage d = _lit(toId);
        if (fromId == toId) revert SameCitadel();
        _sync(fromId);
        _takeUnits(fromId, units);

        uint256 dist = Hex.distance(a.q, a.r, d.q, d.r);
        if (dist <= 1 || config.distortion) {
            _sync(toId);
            (uint64[3] memory survivors, uint256 carried) = _fight(0, fromId, toId, units, false);
            _addUnits(fromId, survivors);
            a.vault += uint128(carried);
            return 0;
        }

        marchId = ++marchCount;
        uint64 arriveAt = uint64(block.timestamp + dist * _slowest(units));
        _marches[marchId] = March(MarchKind.Raid, false, arriveAt, fromId, toId, units, 0);
        a.outgoing++;
        d.incoming++;
        emit MarchSent(marchId, MarchKind.Raid, fromId, toId, arriveAt, units);
    }

    /// @notice Resolve a raid that has arrived. Callable by anyone; the caller earns `resolverFeeBps` of the loot.
    /// If the raid sat unresolved past the defection window, the attacking fleet defects to the defender instead.
    function resolveRaid(uint256 marchId) external nonReentrant {
        March storage m = _marches[marchId];
        if (m.kind != MarchKind.Raid || m.done) revert BadMarch();
        if (block.timestamp < m.arriveAt) revert NotArrived(m.arriveAt);
        m.done = true;

        uint256 fromId = m.origin;
        uint256 toId = m.target;
        Citadel storage a = _citadels[fromId];
        Citadel storage d = _citadels[toId];
        d.incoming--;
        _sync(toId);

        if (block.timestamp > uint256(m.arriveAt) + config.defectionWindow) {
            _addUnits(toId, m.units);
            a.outgoing--;
            emit Defected(marchId, fromId, toId, m.units);
            return;
        }

        (uint64[3] memory survivors, uint256 carried) = _fight(marchId, fromId, toId, m.units, true);
        if (survivors[0] == 0 && survivors[1] == 0 && survivors[2] == 0) {
            a.outgoing--;
            return;
        }
        uint256 dist = Hex.distance(a.q, a.r, d.q, d.r);
        uint256 returnId = ++marchCount;
        uint64 arriveAt = uint64(m.arriveAt + dist * _slowest(survivors));
        _marches[returnId] = March(MarchKind.Return, false, arriveAt, fromId, toId, survivors, uint128(carried));
        emit MarchSent(returnId, MarchKind.Return, toId, fromId, arriveAt, survivors);
    }

    /// @notice Send fleet to any lit CITADEL (yours, your faction's, anyone's). The units join its garrison.
    function reinforce(uint256 fromId, uint256 toId, uint64[3] calldata units)
        external
        nonReentrant
        returns (uint256 marchId)
    {
        Citadel storage a = _owned(fromId);
        Citadel storage d = _lit(toId);
        if (fromId == toId) revert SameCitadel();
        _sync(fromId);
        _takeUnits(fromId, units);

        uint256 dist = Hex.distance(a.q, a.r, d.q, d.r);
        if (dist <= 1 || config.distortion) {
            _addUnits(toId, units);
            emit Reinforced(0, fromId, toId, units);
            return 0;
        }

        marchId = ++marchCount;
        uint64 arriveAt = uint64(block.timestamp + dist * _slowest(units));
        _marches[marchId] = March(MarchKind.Reinforce, false, arriveAt, fromId, toId, units, 0);
        d.incoming++;
        emit MarchSent(marchId, MarchKind.Reinforce, fromId, toId, arriveAt, units);
    }

    /// @notice Land a returning raid or a reinforcement that has arrived. Callable by anyone.
    function completeMarch(uint256 marchId) external nonReentrant {
        March storage m = _marches[marchId];
        if ((m.kind != MarchKind.Return && m.kind != MarchKind.Reinforce) || m.done) revert BadMarch();
        if (block.timestamp < m.arriveAt) revert NotArrived(m.arriveAt);
        m.done = true;

        if (m.kind == MarchKind.Return) {
            Citadel storage home = _citadels[m.origin];
            home.outgoing--;
            home.vault += m.loot;
            _addUnits(m.origin, m.units);
        } else {
            _citadels[m.target].incoming--;
            _addUnits(m.target, m.units);
            emit Reinforced(marchId, m.origin, m.target, m.units);
        }
        emit MarchCompleted(marchId);
    }

    // ---------------------------------------------------------------- views

    function citadel(uint256 citadelId) external view returns (Citadel memory) {
        return _citadels[citadelId];
    }

    function pilotsOf(uint256 citadelId) external view returns (uint256[] memory) {
        return _pilots[citadelId];
    }

    function march(uint256 marchId) external view returns (March memory) {
        return _marches[marchId];
    }

    function trainingOf(uint256 citadelId) external view returns (Batch[3] memory) {
        return _training[citadelId];
    }

    /// @notice Garrison including units whose training has finished but not yet been settled on-chain.
    function garrisonOf(uint256 citadelId) external view returns (uint64[3] memory g) {
        g = _garrison[citadelId];
        for (uint8 t; t < FLEET_TYPES; ++t) {
            Batch memory b = _training[citadelId][t];
            g[t] += _finished(b) - b.done;
        }
    }

    /// @notice Unclaimed DK including mining since the last on-chain sync.
    function vaultOf(uint256 citadelId) external view returns (uint256) {
        Citadel storage c = _citadels[citadelId];
        if (!c.lit) return 0;
        return c.vault + _accrued(c);
    }

    function citadelAt(int16 q, int16 r) external view returns (bool occupied, uint256 citadelId) {
        uint256 v = _occupant[Hex.key(q, r)];
        return (v != 0, v == 0 ? 0 : v - 1);
    }

    /// @notice Mining multiple of a tile in basis points (10000 = 1x). The center of the grid is a hotspot.
    function tileBps(int16 q, int16 r) public view returns (uint256) {
        uint32 o = _tileBpsOverride[Hex.key(q, r)];
        if (o != 0) return o;
        uint256 d = Hex.fromCenter(q, r);
        if (d <= 1) return 12_500;
        if (d <= 3) return 11_500;
        if (d <= 4) return 10_500;
        return 10_000;
    }

    function inGrid(int16 q, int16 r) external view returns (bool) {
        return Hex.fromCenter(q, r) <= radius;
    }

    // ---------------------------------------------------------------- admin (balance levers)
    // Ownership is meant to move to the SOVEREIGN COLLECTIVE once that milestone ships.

    function setConfig(Config calldata c) external onlyOwner {
        if (c.resolverFeeBps > BPS || c.claimInterval == 0 || c.defectionWindow == 0) revert BadConfig();
        config = c;
        emit ConfigUpdated(c);
    }

    function setFleetType(uint8 fleetType, FleetType calldata f) external onlyOwner {
        if (fleetType >= FLEET_TYPES) revert BadFleetType();
        if (f.op == 0 || f.secsPerTile == 0 || f.trainSecs == 0) revert BadConfig();
        fleetTypes[fleetType] = f;
        emit FleetTypeUpdated(fleetType, f);
    }

    /// @notice Shift hotspots. bps = 0 restores the default layout for that tile.
    function setTileBps(int16 q, int16 r, uint32 bps) external onlyOwner {
        if (Hex.fromCenter(q, r) > radius) revert OffGrid();
        _tileBpsOverride[Hex.key(q, r)] = bps;
        emit TileBpsUpdated(q, r, bps);
    }

    // ---------------------------------------------------------------- internals

    function _owned(uint256 citadelId) private view returns (Citadel storage c) {
        c = _citadels[citadelId];
        if (!c.lit || c.owner != msg.sender) revert NotCitadelOwner(citadelId);
    }

    function _lit(uint256 citadelId) private view returns (Citadel storage c) {
        c = _citadels[citadelId];
        if (!c.lit) revert NotLit(citadelId);
    }

    /// @dev Settles mining into the vault and finished training into the garrison.
    function _sync(uint256 citadelId) private {
        Citadel storage c = _citadels[citadelId];
        c.vault += uint128(_accrued(c));
        c.lastSync = uint64(block.timestamp);
        for (uint8 t; t < FLEET_TYPES; ++t) {
            Batch storage b = _training[citadelId][t];
            uint64 fin = _finished(b);
            if (fin > b.done) {
                _garrison[citadelId][t] += fin - b.done;
                b.done = fin;
            }
        }
    }

    function _accrued(Citadel storage c) private view returns (uint256) {
        uint256 elapsed = block.timestamp - c.lastSync;
        if (elapsed == 0) return 0;
        uint256 tile = tileBps(c.q, c.r);
        uint256 bonus = BPS + c.mineBps + (tile > BPS ? c.hermeticBps : 0);
        return elapsed * config.baseDkPerDay * c.sektMultiplier * tile * bonus / (BPS * BPS * 1 days);
    }

    function _finished(Batch memory b) private view returns (uint64) {
        if (b.total == b.done) return b.done;
        uint256 n = (block.timestamp - b.start) / b.unitSecs;
        return n >= b.total ? b.total : uint64(n);
    }

    function _takeUnits(uint256 citadelId, uint64[3] calldata units) private {
        if (units[0] == 0 && units[1] == 0 && units[2] == 0) revert NoUnits();
        uint64[3] storage g = _garrison[citadelId];
        for (uint8 t; t < FLEET_TYPES; ++t) {
            if (g[t] < units[t]) revert NotEnoughUnits(t);
            g[t] -= units[t];
        }
    }

    function _addUnits(uint256 citadelId, uint64[3] memory units) private {
        uint64[3] storage g = _garrison[citadelId];
        for (uint8 t; t < FLEET_TYPES; ++t) {
            g[t] += units[t];
        }
    }

    function _slowest(uint64[3] memory units) private view returns (uint256 s) {
        for (uint8 t; t < FLEET_TYPES; ++t) {
            if (units[t] != 0 && fleetTypes[t].secsPerTile > s) s = fleetTypes[t].secsPerTile;
        }
    }

    /// @dev Battle: total attack vs total defense. The loser is wiped out; the winner loses
    /// (loserPower / winnerPower)^1.5 of every unit type, reduced by its engine's weapons repair.
    /// Survivors carry DK out of the defender's vault. See docs/RULES.md.
    function _fight(uint256 marchId, uint256 fromId, uint256 toId, uint64[3] memory units, bool payResolver)
        private
        returns (uint64[3] memory survivors, uint256 carried)
    {
        Citadel storage a = _citadels[fromId];
        Citadel storage d = _citadels[toId];
        uint64[3] storage g = _garrison[toId];

        uint256 attack;
        uint256 defense;
        for (uint8 t; t < FLEET_TYPES; ++t) {
            attack += uint256(units[t]) * fleetTypes[t].op;
            defense += uint256(g[t]) * fleetTypes[t].dp;
        }
        attack = attack * (BPS + a.offBps) / BPS;
        defense = defense * (BPS + config.fortificationBps + d.defBps) / BPS;

        bool attackerWon = attack > defense;
        uint64[3] memory attLost;
        uint64[3] memory defLost;
        if (attackerWon) {
            uint256 loss = _lossRatio(defense, attack, a.repairBps);
            for (uint8 t; t < FLEET_TYPES; ++t) {
                attLost[t] = _applyLoss(units[t], loss);
                defLost[t] = g[t];
            }
        } else {
            uint256 loss = _lossRatio(attack, defense, d.repairBps);
            for (uint8 t; t < FLEET_TYPES; ++t) {
                attLost[t] = units[t];
                defLost[t] = _applyLoss(g[t], loss);
            }
        }

        uint256 capacity;
        uint256 attValueLost;
        uint256 defValueLost;
        for (uint8 t; t < FLEET_TYPES; ++t) {
            survivors[t] = units[t] - attLost[t];
            g[t] -= defLost[t];
            capacity += uint256(survivors[t]) * fleetTypes[t].carry * 1 ether;
            attValueLost += uint256(attLost[t]) * fleetTypes[t].cost;
            defValueLost += uint256(defLost[t]) * fleetTypes[t].cost;
        }
        // FLEET POINTS = DK value of enemy fleet destroyed, in whole DK.
        a.fleetPoints += uint128(defValueLost / 1 ether);
        d.fleetPoints += uint128(attValueLost / 1 ether);

        uint256 loot = Math.min(capacity, d.vault);
        d.vault -= uint128(loot);
        uint256 fee = payResolver ? loot * config.resolverFeeBps / BPS : 0;
        if (fee != 0) drakma.mint(msg.sender, fee);
        carried = loot - fee;

        emit RaidResolved(marchId, fromId, toId, attackerWon, attLost, defLost, loot, fee);
    }

    /// @dev (weaker / stronger)^1.5 in WAD, reduced by repairBps. Requires weaker <= stronger, stronger > 0.
    function _lossRatio(uint256 weaker, uint256 stronger, uint256 repairBps) private pure returns (uint256) {
        uint256 r = weaker * WAD / stronger;
        uint256 loss = r * Math.sqrt(r * WAD) / WAD;
        return loss * (BPS - Math.min(repairBps, BPS)) / BPS;
    }

    /// @dev Units lost from a stack, rounding losses up so a winner can't take zero losses from a real fight.
    function _applyLoss(uint64 n, uint256 loss) private pure returns (uint64) {
        if (loss == 0 || n == 0) return 0;
        uint256 lost = Math.ceilDiv(uint256(n) * loss, WAD);
        return lost > n ? n : uint64(lost);
    }
}
