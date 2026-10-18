// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {GameBase} from "./GameBase.sol";
import {GameStorage} from "./GameStorage.sol";
import {Hex} from "../lib/Hex.sol";
import {Traits, Tech} from "../lib/Traits.sol";
import {Rand} from "../lib/Rand.sol";
import {IGameView} from "../interfaces/IGameAssets.sol";

/// @title CITADEL views and admin levers. Runs by delegatecall from CitadelGame against its storage.
contract ViewModule is GameBase, IGameView {
    event ConfigUpdated(Config config);
    event FleetTypeUpdated(uint8 indexed fleetType, FleetType stats);
    event BuildingCostUpdated(uint8 indexed building, uint128 cost, uint32 time);
    event TileBpsUpdated(uint8 ao, int16 q, int16 r, uint32 bps);
    event AOStateChanged(uint8 indexed ao, AOState state);
    event SeasonStarted(uint32 indexed season);

    error BadConfig();

    constructor() GameStorage(msg.sender) {}

    function selectors() external pure returns (bytes4[] memory s) {
        s = new bytes4[](29);
        s[0] = this.getConfig.selector;
        s[1] = this.citadel.selector;
        s[2] = this.statsOf.selector;
        s[3] = this.miningRate.selector;
        s[4] = this.pilotsOf.selector;
        s[5] = this.trainingOf.selector;
        s[6] = this.constructionOf.selector;
        s[7] = this.garrisonOf.selector;
        s[8] = this.vaultOf.selector;
        s[9] = this.citadelAt.selector;
        s[10] = this.tileBps.selector;
        s[11] = this.walletLevel.selector;
        s[12] = this.buildCost.selector;
        s[13] = this.pilotMintCost.selector;
        s[14] = this.controllerOfCitadel.selector;
        s[15] = this.controllerOfPilot.selector;
        s[16] = this.placement.selector;
        s[17] = this.setConfig.selector;
        s[18] = this.setFleetType.selector;
        s[19] = this.setBuildingCost.selector;
        s[20] = this.setTileBps.selector;
        s[21] = this.setAOState.selector;
        s[22] = this.startSeason.selector;
        s[23] = this.setTreasury.selector;
        s[24] = this.march.selector;
        s[25] = this.siegeOf.selector;
        s[26] = this.researchRate.selector;
        s[27] = this.controllerOfMentat.selector;
        s[28] = this.savedLevels.selector;
    }

    // ================================================================ views

    function getConfig() external view returns (Config memory) {
        return config;
    }

    /// @notice A CITADEL's state, with a finished construction applied even before it is settled on-chain.
    function citadel(uint256 citadelId) external view returns (Citadel memory c) {
        c = _citadels[citadelId];
        if (c.lit) {
            c.levels = _levelsNow(citadelId);
            c.vault = uint128(_vaultNow(citadelId));
        }
    }

    function statsOf(uint256 citadelId) external view returns (Stats memory) {
        return _stats(citadelId);
    }

    /// @notice Current DRAKMA production per day.
    function miningRate(uint256 citadelId) external view returns (uint256) {
        Citadel storage c = _citadels[citadelId];
        return c.lit ? _miningPerDay(c, _stats(citadelId)) : 0;
    }

    function pilotsOf(uint256 citadelId) external view returns (uint256[] memory) {
        return _pilots[citadelId];
    }

    function trainingOf(uint256 citadelId) external view returns (Batch[4] memory) {
        return _training[citadelId];
    }

    /// @notice The construction in progress, or an empty one if none (or if it has already finished).
    function constructionOf(uint256 citadelId) external view returns (Construction memory k) {
        k = _construction[citadelId];
        if (k.end != 0 && k.end <= block.timestamp) delete k;
    }

    /// @notice Garrison including units whose training has finished but not yet been settled on-chain.
    function garrisonOf(uint256 citadelId) external view returns (uint64[4] memory g) {
        g = _garrison[citadelId];
        for (uint8 t; t < FLEET_TYPES; ++t) {
            Batch memory b = _training[citadelId][t];
            g[t] += _finished(b) - b.done;
        }
    }

    /// @notice Unclaimed DK including mining since the last on-chain sync.
    function vaultOf(uint256 citadelId) external view returns (uint256) {
        return _citadels[citadelId].lit ? _vaultNow(citadelId) : 0;
    }

    function citadelAt(uint8 ao, int16 q, int16 r) external view returns (bool occupied, uint256 citadelId) {
        uint256 v = _occupant[Hex.key(ao, q, r)];
        return (v != 0, v == 0 ? 0 : v - 1);
    }

    /// @notice Mining multiple of a tile in basis points (10000 = 1x). The center of each AO is a hotspot.
    function tileBps(uint8 ao, int16 q, int16 r) external view returns (uint256) {
        return _tileBps(ao, q, r);
    }

    function walletLevel(address wallet) external view returns (uint256) {
        return Math.sqrt(walletScore[wallet]);
    }

    function buildCost(uint8 building, uint8 level) external view returns (uint256 cost, uint256 time) {
        return _buildCost(building, level);
    }

    function pilotMintCost(uint256 citadelId) external view returns (uint256) {
        return _pilotMintCost(citadelId);
    }

    function march(uint256 marchId) external view returns (March memory) {
        return _marches[marchId];
    }

    function siegeOf(uint256 siegeId) external view returns (Siege memory) {
        return _sieges[siegeId];
    }

    /// @notice Research points per day this CITADEL contributes to its faction's tech branch.
    function researchRate(uint256 citadelId) external view returns (uint256) {
        Citadel storage c = _citadels[citadelId];
        return c.lit ? _researchPerDay(c) : 0;
    }

    function controllerOfMentat(uint256 mentatId) external view returns (address) {
        address o = mentatNft.ownerOf(mentatId);
        return o == address(this) ? _mentatController[mentatId] : o;
    }

    function controllerOfCitadel(uint256 citadelId) external view returns (address) {
        address o = citadelNft.ownerOf(citadelId);
        return o == address(this) ? _citadels[citadelId].owner : o;
    }

    function controllerOfPilot(uint256 pilotId) external view returns (address) {
        address o = pilotNft.ownerOf(pilotId);
        return o == address(this) ? _pilotController[pilotId] : o;
    }

    function placement(uint256 citadelId) external view returns (bool, uint8, uint8) {
        Citadel storage c = _citadels[citadelId];
        return (c.lit, c.faction, c.research);
    }

    // ================================================================ admin (balance levers)
    // Ownership is meant to move to the SOVEREIGN COLLECTIVE (see SovereignCouncil).

    function setConfig(Config calldata c) external onlyOwner {
        if (
            c.resolverFeeBps > BPS || c.claimInterval == 0 || c.defectionWindow == 0 || c.siegeWaveSecs == 0
                || c.siegeMinWaves == 0 || c.maxPilots == 0
        ) revert BadConfig();
        config = c;
        emit ConfigUpdated(c);
    }

    function setFleetType(uint8 fleetType, FleetType calldata f) external onlyOwner {
        if (fleetType >= FLEET_TYPES) revert BadFleetType();
        if (f.op == 0 || f.secsPerTile == 0 || f.trainSecs == 0) revert BadConfig();
        fleetTypes[fleetType] = f;
        emit FleetTypeUpdated(fleetType, f);
    }

    function setBuildingCost(uint8 building, uint128 cost, uint32 time) external onlyOwner {
        if (building >= BUILDINGS || time == 0) revert BadConfig();
        buildingBaseCost[building] = cost;
        buildingBaseTime[building] = time;
        emit BuildingCostUpdated(building, cost, time);
    }

    /// @notice Shift hotspots. bps = 0 restores the default layout for that tile.
    function setTileBps(uint8 ao, int16 q, int16 r, uint32 bps) external onlyOwner {
        if (Hex.fromCenter(q, r) > radius) revert OffGrid();
        _tileBpsOverride[Hex.key(ao, q, r)] = bps;
        emit TileBpsUpdated(ao, q, r, bps);
    }

    /// @notice Open a new astronomical object (Isolated during its ladder season) or connect it to the others.
    function setAOState(uint8 ao, AOState state) external onlyOwner {
        aoState[ao] = state;
        emit AOStateChanged(ao, state);
    }

    function startSeason() external onlyOwner {
        emit SeasonStarted(++season);
    }

    function setTreasury(address treasury_) external onlyOwner {
        treasury = treasury_;
    }
}
