// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {GameBase} from "./GameBase.sol";
import {GameStorage} from "./GameStorage.sol";
import {Hex} from "../lib/Hex.sol";
import {Traits, Tech} from "../lib/Traits.sol";
import {Rand} from "../lib/Rand.sol";

/// @title CITADEL economy: lighting CITADEL to the grid, buildings, fleet training, claims, PILOT minting, colonization
/// and MENTAT. Runs by delegatecall from CitadelGame against its storage.
contract EconomyModule is GameBase {
    event FactionChanged(uint256 indexed citadelId, uint8 faction);
    event ResearchChanged(uint256 indexed citadelId, uint8 branch);
    event MentatAttached(uint256 indexed citadelId, uint256 indexed mentatId);
    event BuildStarted(uint256 indexed citadelId, uint8 building, uint8 level, uint64 end, uint256 cost);
    event Hurried(uint256 indexed citadelId, uint8 what, uint8 index, uint256 price); // what: 0 build, 1 training
    event TrainingQueued(uint256 indexed citadelId, uint8 fleetType, uint64 amount, uint256 cost);
    event Claimed(uint256 indexed citadelId, address indexed to, uint256 amount);
    event PilotMinted(uint256 indexed citadelId, uint256 indexed pilotId, uint8 generation, uint256 fleetPointsSpent);
    event Colonized(uint256 indexed citadelId, uint256 indexed pilotId, address indexed owner);
    event ConfigUpdated(Config config);
    event FleetTypeUpdated(uint8 indexed fleetType, FleetType stats);
    event BuildingCostUpdated(uint8 indexed building, uint128 cost, uint32 time);
    event TileBpsUpdated(uint8 ao, int16 q, int16 r, uint32 bps);
    event AOStateChanged(uint8 indexed ao, AOState state);
    event SeasonStarted(uint32 indexed season);

    error TooManyPilots();
    error Engaged();
    error ClaimCooldown(uint64 availableAt);
    error Busy();
    error Idle();
    error MaxLevel();
    error NeedsCitadelLevel(uint8 level);
    error NeedsAcademy(uint8 level);
    error NeedsTech();
    error NotFactionGrid();
    error NotEnoughFleetPoints(uint256 cost);
    error HasMentat();
    error BadConfig();
    error NotPilotOwner();

    constructor() GameStorage(msg.sender) {}

    function selectors() external pure returns (bytes4[] memory s) {
        s = new bytes4[](12);
        s[0] = this.lite.selector;
        s[1] = this.unlite.selector;
        s[2] = this.setFaction.selector;
        s[3] = this.setResearch.selector;
        s[4] = this.attachMentat.selector;
        s[5] = this.build.selector;
        s[6] = this.hurryBuild.selector;
        s[7] = this.train.selector;
        s[8] = this.hurryTraining.selector;
        s[9] = this.claim.selector;
        s[10] = this.mintPilot.selector;
        s[11] = this.colonize.selector;
    }

    // ================================================================ grid

    /// @notice Light a CITADEL (and up to maxPilots PILOT from your wallet) to a free tile. Mining starts at once.
    function lite(
        uint256 citadelId,
        uint8 ao,
        int16 q,
        int16 r,
        uint8 faction,
        uint8 research,
        uint256[] calldata pilotIds
    ) external nonReentrant {
        if (pilotIds.length > config.maxPilots) revert TooManyPilots();
        // transferFrom(msg.sender, ...) reverts unless the caller owns the token.
        citadelNft.transferFrom(msg.sender, address(this), citadelId);
        for (uint256 i; i < pilotIds.length; ++i) {
            pilotNft.transferFrom(msg.sender, address(this), pilotIds[i]);
        }
        _place(citadelId, msg.sender, Spot(ao, q, r, faction, research), pilotIds, false);
    }

    /// @notice Take a CITADEL off the grid. Not while any march or siege involves it. The vault is paid out if a claim
    /// is available, otherwise forfeited; garrison, training, construction and building levels are lost.
    function unlite(uint256 citadelId) external nonReentrant {
        Citadel storage c = _owned(citadelId);
        if (c.incoming != 0 || c.outgoing != 0 || c.besieged != 0) revert Engaged();
        _sync(citadelId);
        bool canClaim = block.timestamp >= uint256(c.lastClaim) + config.claimInterval;
        address owner_ = c.owner;
        uint256 vault = _remove(citadelId, false);
        if (canClaim && vault != 0) drakma.mint(owner_, vault);
        emit Unlit(citadelId, owner_, canClaim ? vault : 0, canClaim ? 0 : vault);
    }

    function setFaction(uint256 citadelId, uint8 faction) external nonReentrant {
        Citadel storage c = _owned(citadelId);
        if (faction >= FACTIONS) revert BadFaction();
        if (c.incoming != 0 || c.outgoing != 0 || c.besieged != 0) revert Engaged();
        _sync(citadelId);
        c.faction = faction;
        _registerResearch(citadelId, c);
        emit FactionChanged(citadelId, faction);
    }

    function setResearch(uint256 citadelId, uint8 branch) external nonReentrant {
        Citadel storage c = _owned(citadelId);
        if (branch >= Tech.BRANCHES) revert BadFaction();
        c.research = branch;
        _registerResearch(citadelId, c);
        emit ResearchChanged(citadelId, branch);
    }

    /// @notice Lite a MENTAT from your wallet into a CITADEL (one per CITADEL; it leaves with the CITADEL).
    function attachMentat(uint256 citadelId, uint256 mentatId) external nonReentrant {
        Citadel storage c = _owned(citadelId);
        if (c.mentat != 0) revert HasMentat();
        _sync(citadelId);
        mentatNft.transferFrom(msg.sender, address(this), mentatId);
        c.mentat = mentatId + 1;
        _mentatController[mentatId] = msg.sender;
        emit MentatAttached(citadelId, mentatId);
    }

    // ================================================================ economy

    /// @notice Start upgrading a building one level. One construction at a time per CITADEL. Buildings other than the
    /// CITADEL itself can't exceed the CITADEL's level (level 1 is always allowed).
    function build(uint256 citadelId, uint8 building) external nonReentrant {
        Citadel storage c = _owned(citadelId);
        if (building >= BUILDINGS) revert BadConfig();
        _sync(citadelId);
        if (_construction[citadelId].end != 0) revert Busy();
        uint8 level = c.levels[building] + 1;
        if (level > MAX_BUILDING_LEVEL) revert MaxLevel();
        if (building != B_CITADEL && level > 1 && level > c.levels[B_CITADEL]) revert NeedsCitadelLevel(level);
        (uint256 cost, uint256 time) = _buildCost(building, level);
        drakma.gameBurn(msg.sender, cost);
        uint64 end = uint64(block.timestamp + time);
        _construction[citadelId] = Construction(building, level, uint64(block.timestamp), end, uint128(cost));
        emit BuildStarted(citadelId, building, level, end, cost);
    }

    /// @notice Finish the current construction now for hurryBps of the remaining share of its cost.
    function hurryBuild(uint256 citadelId) external nonReentrant {
        _owned(citadelId);
        _sync(citadelId);
        Construction memory k = _construction[citadelId];
        if (k.end == 0) revert Idle();
        uint256 price =
            Math.ceilDiv(uint256(k.cost) * (k.end - block.timestamp) * config.hurryBps, uint256(k.end - k.start) * BPS);
        drakma.gameBurn(msg.sender, price);
        _construction[citadelId].end = uint64(block.timestamp);
        _sync(citadelId);
        emit Hurried(citadelId, 0, k.building, price);
    }

    /// @notice Queue fleet. Needs a FLEET ACADEMY of the fleet type's level; DALAA MAX also needs the Atomic Engine tech.
    function train(uint256 citadelId, uint8 fleetType, uint64 amount) external nonReentrant {
        Citadel storage c = _owned(citadelId);
        if (fleetType >= FLEET_TYPES) revert BadFleetType();
        if (amount == 0) revert NoUnits();
        _sync(citadelId);
        FleetType memory f = fleetTypes[fleetType];
        uint8 academy = c.levels[B_ACADEMY];
        if (academy < f.academy) revert NeedsAcademy(f.academy);
        Stats memory s = _stats(citadelId);
        if (fleetType == Traits.DALAA_MAX && !s.dalaa) revert NeedsTech();

        uint256 cost = uint256(f.cost) * amount;
        drakma.gameBurn(msg.sender, cost);

        Batch storage b = _training[citadelId][fleetType];
        if (b.done == b.total) {
            uint256 speed = BPS + 500 * (uint256(academy) - 1) + s.trainBps[fleetType];
            uint32 unitSecs = uint32(Math.max(1, uint256(f.trainSecs) * BPS / speed));
            _training[citadelId][fleetType] = Batch(amount, 0, uint64(block.timestamp), unitSecs);
        } else {
            b.total += amount; // queued behind the units already in training
        }
        emit TrainingQueued(citadelId, fleetType, amount, cost);
    }

    /// @notice Finish a fleet type's training queue now for hurryBps of the remaining units' cost.
    function hurryTraining(uint256 citadelId, uint8 fleetType) external nonReentrant {
        _owned(citadelId);
        if (fleetType >= FLEET_TYPES) revert BadFleetType();
        _sync(citadelId);
        Batch storage b = _training[citadelId][fleetType];
        uint64 left = b.total - b.done;
        if (left == 0) revert Idle();
        uint256 price = uint256(left) * fleetTypes[fleetType].cost * config.hurryBps / BPS;
        drakma.gameBurn(msg.sender, price);
        _garrison[citadelId][fleetType] += left;
        b.done = b.total;
        emit Hurried(citadelId, 1, fleetType, price);
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

    // ================================================================ generations

    /// @notice Spend FLEET POINTS to mint a next-generation PILOT to your wallet. The price doubles with every PILOT
    /// this CITADEL has minted and triples with every generation.
    function mintPilot(uint256 citadelId) external nonReentrant returns (uint256 pilotId) {
        Citadel storage c = _owned(citadelId);
        uint256 cost = _pilotMintCost(citadelId);
        if (fleetPoints[citadelId] < cost) revert NotEnoughFleetPoints(cost);
        fleetPoints[citadelId] -= uint128(cost);
        pilotsMintedBy[citadelId]++;
        uint8 gen = c.generation + 1;
        pilotId = pilotNft.mint(msg.sender, Rand.pilot(Rand.seed(_nonce++), gen));
        emit PilotMinted(citadelId, pilotId, gen, cost);
    }

    /// @notice Found a new CITADEL with a PILOT from your wallet on a free tile within 2 of your faction's CITADEL.
    /// The CITADEL is GEN max(1, PILOT generation) — no new GEN0 can ever be made.
    function colonize(uint256 pilotId, uint8 ao, int16 q, int16 r, uint8 faction)
        external
        nonReentrant
        returns (uint256 citadelId)
    {
        if (faction >= FACTIONS) revert BadFaction();
        _checkTile(ao, q, r);
        if (!_factionNear(ao, q, r, faction)) revert NotFactionGrid();
        pilotNft.transferFrom(msg.sender, address(this), pilotId);
        drakma.gameBurn(msg.sender, config.colonizeCost);
        uint8 gen = pilotNft.traitsOf(pilotId).generation;
        citadelId = _found(msg.sender, gen == 0 ? 1 : gen, Spot(ao, q, r, faction, 0), pilotId, false);
        emit Colonized(citadelId, pilotId, msg.sender);
    }

    function _factionNear(uint8 ao, int16 q, int16 r, uint8 faction) private view returns (bool) {
        for (int16 dq = -2; dq <= 2; ++dq) {
            for (int16 dr = -2; dr <= 2; ++dr) {
                if (Hex.distance(0, 0, dq, dr) > 2 || (dq == 0 && dr == 0)) continue;
                uint256 occ = _occupant[Hex.key(ao, q + dq, r + dr)];
                if (occ != 0 && _citadels[occ - 1].faction == faction) return true;
            }
        }
        return false;
    }
}
