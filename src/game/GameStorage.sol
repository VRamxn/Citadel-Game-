// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ICitadelNFT, IPilotNFT, IMentatNFT, IDrakma, ITechTree} from "../interfaces/IGameAssets.sol";

/// @notice Every piece of CITADEL game state, shared by CitadelGame (core) and WarModule, which runs by delegatecall
/// from CitadelGame. Both contracts inherit this exact layout. Append new state at the end only.
abstract contract GameStorage is Ownable2Step {
    uint8 public constant FLEET_TYPES = 4; // SIF GATTACA, MHRUDVOG THROT, DREBENTRAAKHT, DALAA MAX
    uint8 public constant FACTIONS = 4; // NETWORK STATE, AUTONOMOUS ZONE, SANCTION, ANNEXATION
    uint8 public constant BUILDINGS = 6; // CITADEL, MINE, SHIELD, ENGINE, WEAPON, ACADEMY
    uint8 public constant MAX_BUILDING_LEVEL = 10;
    uint8 internal constant B_CITADEL = 0;
    uint8 internal constant B_MINE = 1;
    uint8 internal constant B_SHIELD = 2;
    uint8 internal constant B_ENGINE = 3;
    uint8 internal constant B_WEAPON = 4;
    uint8 internal constant B_ACADEMY = 5;
    uint256 internal constant BPS = 10_000;
    uint256 internal constant WAD = 1e18;

    enum MarchKind {
        None,
        Raid,
        Return,
        Reinforce,
        Scout,
        Siege,
        SiegeJoin
    }

    enum AOState {
        Closed,
        Isolated, // open, but marches can't cross to or from other AOs (a ladder season in progress)
        Connected
    }

    struct FleetType {
        uint32 op; // offense points per unit
        uint32 dp; // defense points per unit
        uint32 carry; // whole DK carried home per surviving unit
        uint32 secsPerTile; // travel speed; a march moves at its slowest unit
        uint32 trainSecs; // base training time per unit
        uint8 academy; // FLEET ACADEMY level required to train
        uint128 cost; // DK (wei) per unit
    }

    struct Config {
        uint128 baseDkPerDay; // before SEKT, generation, tile and bonus multipliers
        uint32 claimInterval; // min seconds between claims of one CITADEL
        uint32 defectionWindow; // an arrived raid unresolved for this long defects to the defender
        uint16 resolverFeeBps; // share of loot paid to whoever resolves a travelling raid
        uint16 fortificationBps; // defensive bonus for all fleet stationed in a CITADEL
        uint8 maxPilots; // per CITADEL
        bool distortion; // grid-wide subgrid distortion: every march is instant
        uint32 siegeWaveSecs; // one siege battle per wave
        uint16 siegeMinWaves; // fastest possible siege, in waves (48 x 1h = the whitepaper's 48h)
        uint16 siegeAttritionBps; // share of the weaker side's... see WarModule._wave
        uint32 structureDp; // a CITADEL's own defense = structureDp x (level+1)^2
        uint128 colonizeCost; // DK to found a CITADEL with a PILOT
        uint128 pilotFleetPoints; // FLEET POINTS for the first next-gen PILOT a CITADEL mints
        uint16 hurryBps; // hurry price as a share of the remaining part of the original cost
        uint16 aoGapTiles; // extra distance when marching between connected AOs
        uint128 researchPerDay; // research points per CITADEL per day, before SEKT/generation multipliers
    }

    struct Citadel {
        address owner;
        bool lit;
        bool doomRiot; // captured by a DEATH PILOT: 2x production until ejected
        uint8 ao;
        int16 q;
        int16 r;
        uint8 faction;
        uint8 research; // tech branch this CITADEL researches
        // traits, cached at lite
        uint8 generation;
        uint8 sekt;
        uint8 shield;
        uint8 engine;
        uint8 weapon;
        uint8 tech;
        uint64 lastSync;
        uint64 lastClaim;
        // PILOT bonuses, summed at lite (bps)
        uint32 pilotOff;
        uint32 pilotDef;
        uint32 pilotMine;
        uint32 pilotHermetic;
        uint32 pilotScout;
        uint32 pilotResearch;
        uint32 incoming; // unresolved raids, scouts and reinforcements headed here
        uint32 outgoing; // this CITADEL's marches and sieges still out
        uint32 besieged; // active sieges against this CITADEL
        uint128 vault; // mined + looted DK not yet claimed; raidable
        uint256 mentat; // MENTAT id + 1, 0 = none
        uint8[6] levels; // building levels
    }

    struct Batch {
        uint64 total;
        uint64 done;
        uint64 start;
        uint32 unitSecs;
    }

    struct Construction {
        uint8 building; // 255 = idle
        uint8 level; // level being built
        uint64 start;
        uint64 end;
        uint128 cost;
    }

    struct March {
        MarchKind kind;
        bool done;
        uint64 arriveAt;
        uint256 origin;
        uint256 target; // CITADEL id, or siege id for SiegeJoin
        uint32 originEpoch;
        uint32 targetEpoch;
        uint64[4] units;
        uint128 loot;
        address sender;
        uint256 pilot; // PILOT id + 1 leading a siege, 0 = none
    }

    struct Siege {
        bool active;
        address attacker;
        uint8 faction;
        uint256 origin;
        uint256 target;
        uint32 originEpoch;
        uint32 targetEpoch;
        uint256 pilot; // PILOT id + 1, 0 = none (a siege without a PILOT can only level)
        uint64 start;
        uint32 waves; // waves fought so far
        int32 progress; // 0..10000
        uint64[4] units;
    }

    // ---- wiring
    ICitadelNFT public citadelNft;
    IPilotNFT public pilotNft;
    IMentatNFT public mentatNft;
    IDrakma public drakma;
    ITechTree public techTree;
    address public treasury;

    // ---- rules
    uint16 public radius; // each AO is every tile within this hex distance of (0, 0)
    uint32 public season;
    Config internal config;
    FleetType[4] public fleetTypes;
    uint128[6] public buildingBaseCost;
    uint32[6] public buildingBaseTime;
    mapping(uint8 => AOState) public aoState;
    mapping(uint64 => uint32) internal _tileBpsOverride; // tile key => bps, 0 = default layout

    // ---- world
    mapping(uint256 => Citadel) internal _citadels;
    mapping(uint256 => uint64[4]) internal _garrison;
    mapping(uint256 => Batch[4]) internal _training;
    mapping(uint256 => Construction) internal _construction;
    mapping(uint256 => uint256[]) internal _pilots;
    mapping(uint64 => uint256) internal _occupant; // tile key => citadelId + 1
    mapping(uint256 => address) internal _pilotController; // PILOT in game custody => player
    mapping(uint256 => address) internal _mentatController;

    // persistent per CITADEL id (survive unlite/relite)
    mapping(uint256 => uint32) public epochOf;
    mapping(uint256 => uint128) public fleetPoints;
    mapping(uint256 => uint16) public pilotsMintedBy;

    mapping(address => uint256) public walletScore;

    uint256 public marchCount;
    mapping(uint256 => March) internal _marches;
    uint256 public siegeCount;
    mapping(uint256 => Siege) internal _sieges;

    uint256 internal _nonce;

    /// @notice Building levels of a CITADEL that left the grid peacefully. They travel with the NFT — the whitepaper's
    /// "a lvl 10 CITADEL [is] more valuable than a lvl 1 CITADEL ... extracted on secondary markets" — and come back
    /// when it is lit again. Being leveled in a siege wipes them.
    mapping(uint256 => uint8[6]) public savedLevels;

    constructor(address owner_) Ownable(owner_) {}
}
