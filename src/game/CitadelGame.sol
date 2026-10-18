// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {GameStorage} from "./GameStorage.sol";
import {ICitadelNFT, IPilotNFT, IMentatNFT, IDrakma, ITechTree} from "../interfaces/IGameAssets.sol";

interface IModule {
    function selectors() external pure returns (bytes4[] memory);
}

/// @title CITADEL — a fully on-chain post-human war game on a hexagonal grid.
/// @notice The game's single address. It holds all state (GameStorage) and routes each call by selector to the module
/// that implements it, by delegatecall: EconomyModule (grid, buildings, training, claims, generations), WarModule
/// (raids, scouting, reinforcement, siege orders), SiegeModule (siege battles) and ViewModule (views, admin levers).
/// Modules exist only to stay under the 24KB contract size limit. See docs/RULES.md for the rules.
contract CitadelGame is GameStorage {
    mapping(bytes4 => address) public moduleOf;

    event ModuleInstalled(address indexed module, uint256 selectors);

    error UnknownSelector(bytes4 selector);

    constructor(
        address owner_,
        ICitadelNFT citadel_,
        IPilotNFT pilot_,
        IMentatNFT mentat_,
        IDrakma drakma_,
        ITechTree techTree_,
        address treasury_,
        uint16 radius_
    ) GameStorage(owner_) {
        citadelNft = citadel_;
        pilotNft = pilot_;
        mentatNft = mentat_;
        drakma = drakma_;
        techTree = techTree_;
        treasury = treasury_;
        radius = radius_;
        season = 1;
        aoState[0] = AOState.Connected;
        // OP/DP/cost/train from the 0xCITADEL alpha post; DALAA MAX, carry and speed are designed (docs/RULES.md).
        fleetTypes[0] = FleetType(10, 5, 40, 30 minutes, 5 minutes, 1, 20 ether); // SIF GATTACA
        fleetTypes[1] = FleetType(5, 40, 20, 45 minutes, 15 minutes, 2, 40 ether); // MHRUDVOG THROT
        fleetTypes[2] = FleetType(500, 250, 200, 60 minutes, 60 minutes, 5, 800 ether); // DREBENTRAAKHT
        fleetTypes[3] = FleetType(2, 2, 5, 10 minutes, 2 minutes, 1, 8 ether); // DALAA MAX

        // CITADEL, MINE, SHIELD, ENGINE, WEAPON, ACADEMY — level L costs base x COST_MULT[L], takes base x TIME_MULT[L]/10
        buildingBaseCost = [uint128(20_000 ether), 10_000 ether, 15_000 ether, 15_000 ether, 15_000 ether, 2_000 ether];
        buildingBaseTime = [uint32(2 hours), 1 hours, 90 minutes, 90 minutes, 90 minutes, 20 minutes];

        config = Config({
            baseDkPerDay: 4_000 ether, // x SEKT multiplier = the EXORDIUM daily rates (8k ELEKT .. 64k RELIK)
            claimInterval: 7 days,
            defectionWindow: 24 hours,
            resolverFeeBps: 1_000,
            fortificationBps: 5_000,
            maxPilots: 8,
            distortion: false,
            siegeWaveSecs: 1 hours,
            siegeMinWaves: 48,
            siegeAttritionBps: 1_000,
            structureDp: 100,
            colonizeCost: 250_000 ether,
            pilotFleetPoints: 10_000,
            hurryBps: 20_000,
            aoGapTiles: 12,
            researchPerDay: 4_000
        });
    }

    /// @notice Route every selector a module reports to it. Re-installing a module replaces those routes.
    function install(address module) external onlyOwner {
        bytes4[] memory s = IModule(module).selectors();
        for (uint256 i; i < s.length; ++i) {
            moduleOf[s[i]] = module;
        }
        emit ModuleInstalled(module, s.length);
    }

    fallback() external {
        address m = moduleOf[msg.sig];
        if (m == address(0)) revert UnknownSelector(msg.sig);
        assembly {
            calldatacopy(0, 0, calldatasize())
            let ok := delegatecall(gas(), m, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch ok
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}
