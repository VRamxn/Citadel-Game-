// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPilotNFT, ICitadelNFT, IDrakma, IGameView} from "./interfaces/IGameAssets.sol";
import {Traits} from "./lib/Traits.sol";
import {Rand} from "./lib/Rand.sol";

/// @title The WARLORD TECHNOCRACY — CITADEL's tokenized political system (THE WARLORD TECHNOCRACY post).
/// @notice 128 sovereign PILOT form the SOVEREIGN COLLECTIVE: 64 born sovereign when claimed by a RELIK, 64 seats bought
/// for 4M DK. Sovereigns can't be sieged and lead sieges at 2x; they take a cut of the game's DK sinks. Any PILOT can
/// overthrow a sovereign for 4M + 1M per active bribe; sovereigns protect themselves by bribing the 8 KULT, and bribes
/// decay after 90 days. Also hosts the PILOT claim: every GEN0 CITADEL may claim one PILOT for 64,000 DK.
contract Technocracy is Ownable {
    uint256 public constant SEATS = 128;
    uint256 public constant BOUGHT_SEATS = 64;
    uint256 public constant SEAT_COST = 4_000_000 ether;
    uint256 public constant BRIBE_COST = 100_000 ether;
    uint256 public constant BRIBE_MULTIPLE = 10;
    uint256 public constant BRIBE_DECAY = 90 days;
    uint256 public constant MAX_BRIBES = 16;
    uint256 public constant PILOT_CLAIM_COST = 64_000 ether;
    uint256 public constant COLLECTIVE_INTERVAL = 30 days;
    uint256 private constant ACC = 1e18;

    IPilotNFT public immutable pilot;
    ICitadelNFT public immutable citadel;
    IDrakma public immutable drakma;
    IGameView public game;
    address public treasury;

    uint256 public sovereignCount;
    uint256 public boughtSeats;
    mapping(uint256 => bool) public citadelClaimedPilot;
    mapping(uint256 => uint64[16]) private _bribes; // expiry timestamps, ring buffer
    mapping(uint256 => uint8) private _bribeCursor;

    uint256 public collectivePerSeat; // accumulated DK per seat, x ACC
    mapping(uint256 => uint256) private _seatDebt;
    mapping(uint256 => uint64) public lastCollected;

    uint256[8] public kultPerMember; // accumulated DK per registered PILOT of each KULT, x ACC
    uint256[8] public kultMembers;
    mapping(uint256 => bool) public kultRegistered;
    mapping(uint256 => uint256) private _kultDebt;

    event PilotClaimed(uint256 indexed citadelId, uint256 indexed pilotId, bool sovereign);
    event SovereignSeated(uint256 indexed pilotId, address indexed by, uint256 paid);
    event Bribed(uint256 indexed pilotId, uint8 indexed kult, uint256 activeBribes);
    event Overthrown(uint256 indexed sovereignId, uint256 indexed insurgentId, uint256 paid);
    event SeatVacated(uint256 indexed pilotId);
    event CollectiveClaimed(uint256 indexed pilotId, address indexed to, uint256 amount);
    event KultRegistered(uint256 indexed pilotId, uint8 kult);
    event KultClaimed(uint256 indexed pilotId, address indexed to, uint256 amount);

    error NotController();
    error AlreadyClaimed();
    error NotGen0();
    error AlreadySovereign();
    error NotSovereign();
    error SeatsFull();
    error TooEarly(uint64 at);
    error BadKult();
    error NotRegistered();
    error StillExists();

    constructor(address owner_, IPilotNFT pilot_, ICitadelNFT citadel_, IDrakma drakma_, address treasury_)
        Ownable(owner_)
    {
        pilot = pilot_;
        citadel = citadel_;
        drakma = drakma_;
        treasury = treasury_;
    }

    function setGame(IGameView game_) external onlyOwner {
        game = game_;
    }

    function setTreasury(address treasury_) external onlyOwner {
        treasury = treasury_;
    }

    // ------------------------------------------------------------------ PILOT claim

    /// @notice Claim the PILOT of a GEN0 CITADEL you control (in your wallet or lit by you) for 64,000 DK.
    /// A RELIK's PILOT is born sovereign while seats remain.
    function claimPilot(uint256 citadelId) external returns (uint256 pilotId) {
        if (game.controllerOfCitadel(citadelId) != msg.sender) revert NotController();
        Traits.CitadelTraits memory t = citadel.traitsOf(citadelId);
        if (t.generation != 0) revert NotGen0();
        if (citadelClaimedPilot[citadelId]) revert AlreadyClaimed();
        citadelClaimedPilot[citadelId] = true;
        drakma.gameBurn(msg.sender, PILOT_CLAIM_COST);

        Traits.PilotTraits memory p = Rand.pilot(Rand.seed(citadelId), 0);
        bool born = t.sekt == Traits.SEKT_RELIK && sovereignCount < SEATS;
        p.sovereign = born;
        pilotId = pilot.mint(msg.sender, p);
        if (born) _seat(pilotId);
        emit PilotClaimed(citadelId, pilotId, born);
    }

    // ------------------------------------------------------------------ the collective

    /// @notice Buy one of the 64 open seats for 4M DK.
    function becomeSovereign(uint256 pilotId) external {
        _requireController(pilotId);
        if (pilot.traitsOf(pilotId).sovereign) revert AlreadySovereign();
        if (boughtSeats >= BOUGHT_SEATS || sovereignCount >= SEATS) revert SeatsFull();
        boughtSeats++;
        _pay(SEAT_COST);
        pilot.setSovereign(pilotId, true);
        _seat(pilotId);
        emit SovereignSeated(pilotId, msg.sender, SEAT_COST);
    }

    /// @notice Bribe a KULT on behalf of a sovereign. 100k DK; the charge lasts 90 days. A POTENTATE COERCION or
    /// TECHNOCRAT ARMAMENT sovereign — the militant arms of the technocracy — counts each bribe twice.
    function bribe(uint8 kult, uint256 sovereignId) external {
        if (kult >= 8) revert BadKult();
        Traits.PilotTraits memory t = pilot.traitsOf(sovereignId);
        if (!t.sovereign) revert NotSovereign();
        drakma.gameBurn(msg.sender, BRIBE_COST);
        // 60% to the KULT, 30% treasury, 5% collective, 5% burned
        _toKult(kult, BRIBE_COST * 6_000 / 10_000);
        drakma.mint(treasury, BRIBE_COST * 3_000 / 10_000);
        _toCollective(BRIBE_COST * 500 / 10_000);
        uint256 copies =
            t.subjugation == Traits.SUBJ_POTENTATE_COERCION || t.subjugation == Traits.SUBJ_TECHNOCRAT_ARMAMENT ? 2 : 1;
        for (uint256 i; i < copies; ++i) {
            uint8 c = _bribeCursor[sovereignId];
            _bribes[sovereignId][c] = uint64(block.timestamp + BRIBE_DECAY);
            _bribeCursor[sovereignId] = uint8((c + 1) % MAX_BRIBES);
        }
        emit Bribed(sovereignId, kult, activeBribes(sovereignId));
    }

    /// @notice Overthrow a sovereign with one of your PILOT: pay the collective 4M DK + 1M per active bribe.
    function overthrow(uint256 sovereignId, uint256 insurgentId) external {
        _requireController(insurgentId);
        if (!pilot.traitsOf(sovereignId).sovereign) revert NotSovereign();
        if (pilot.traitsOf(insurgentId).sovereign) revert AlreadySovereign();
        uint256 cost = overthrowCost(sovereignId);
        // the fallen sovereign is paid what it was owed before it falls
        _payCollective(sovereignId, game.controllerOfPilot(sovereignId));
        _unseat(sovereignId);
        _pay(cost);
        pilot.setSovereign(insurgentId, true);
        _seat(insurgentId);
        emit Overthrown(sovereignId, insurgentId, cost);
    }

    /// @notice Free the seat of a sovereign PILOT that no longer exists (destroyed in a failed siege).
    function vacate(uint256 pilotId) external {
        try pilot.ownerOf(pilotId) returns (address) {
            revert StillExists();
        } catch {}
        if (_seatDebt[pilotId] == 0 && lastCollected[pilotId] == 0) revert NotSovereign();
        delete _seatDebt[pilotId];
        delete lastCollected[pilotId];
        sovereignCount--;
        if (boughtSeats > 0) boughtSeats--; // the seat can be bought again
        emit SeatVacated(pilotId);
    }

    /// @notice A sovereign collects its share of the collective's DK, at most every 30 days.
    function claimCollective(uint256 pilotId) external {
        _requireController(pilotId);
        if (!pilot.traitsOf(pilotId).sovereign) revert NotSovereign();
        uint64 at = lastCollected[pilotId] + uint64(COLLECTIVE_INTERVAL);
        if (block.timestamp < at) revert TooEarly(at);
        _payCollective(pilotId, msg.sender);
    }

    function overthrowCost(uint256 sovereignId) public view returns (uint256) {
        return SEAT_COST + activeBribes(sovereignId) * BRIBE_MULTIPLE * BRIBE_COST;
    }

    function activeBribes(uint256 pilotId) public view returns (uint256 n) {
        uint64[16] storage b = _bribes[pilotId];
        for (uint256 i; i < MAX_BRIBES; ++i) {
            if (b[i] > block.timestamp) ++n;
        }
    }

    function pendingCollective(uint256 pilotId) external view returns (uint256) {
        return pilot.traitsOf(pilotId).sovereign ? (collectivePerSeat - _seatDebt[pilotId]) / ACC : 0;
    }

    // ------------------------------------------------------------------ KULT

    /// @notice Enrol a PILOT in its KULT's share of bribes from now on.
    function registerKult(uint256 pilotId) external {
        if (kultRegistered[pilotId]) revert AlreadyClaimed();
        uint8 k = pilot.traitsOf(pilotId).kult;
        kultRegistered[pilotId] = true;
        kultMembers[k]++;
        _kultDebt[pilotId] = kultPerMember[k];
        emit KultRegistered(pilotId, k);
    }

    function claimKult(uint256 pilotId) external {
        _requireController(pilotId);
        if (!kultRegistered[pilotId]) revert NotRegistered();
        uint8 k = pilot.traitsOf(pilotId).kult;
        uint256 owed = (kultPerMember[k] - _kultDebt[pilotId]) / ACC;
        _kultDebt[pilotId] = kultPerMember[k];
        if (owed != 0) drakma.mint(msg.sender, owed);
        emit KultClaimed(pilotId, msg.sender, owed);
    }

    function pendingKult(uint256 pilotId) external view returns (uint256) {
        if (!kultRegistered[pilotId]) return 0;
        uint8 k = pilot.traitsOf(pilotId).kult;
        return (kultPerMember[k] - _kultDebt[pilotId]) / ACC;
    }

    // ------------------------------------------------------------------ internals

    function _requireController(uint256 pilotId) private view {
        if (game.controllerOfPilot(pilotId) != msg.sender) revert NotController();
    }

    function _seat(uint256 pilotId) private {
        sovereignCount++;
        _seatDebt[pilotId] = collectivePerSeat;
        lastCollected[pilotId] = uint64(block.timestamp);
    }

    function _unseat(uint256 pilotId) private {
        pilot.setSovereign(pilotId, false);
        delete _bribes[pilotId];
        delete _seatDebt[pilotId];
        delete lastCollected[pilotId];
        sovereignCount--;
    }

    function _payCollective(uint256 pilotId, address to) private {
        uint256 owed = (collectivePerSeat - _seatDebt[pilotId]) / ACC;
        _seatDebt[pilotId] = collectivePerSeat;
        lastCollected[pilotId] = uint64(block.timestamp);
        if (owed != 0 && to != address(0)) drakma.mint(to, owed);
        emit CollectiveClaimed(pilotId, to, owed);
    }

    /// @dev Sovereignty and overthrow payments: 70% collective, 25% treasury, 5% burned.
    function _pay(uint256 amount) private {
        drakma.gameBurn(msg.sender, amount);
        _toCollective(amount * 7_000 / 10_000);
        drakma.mint(treasury, amount * 2_500 / 10_000);
    }

    function _toCollective(uint256 amount) private {
        if (sovereignCount == 0) drakma.mint(treasury, amount);
        else collectivePerSeat += amount * ACC / sovereignCount;
    }

    function _toKult(uint8 kult, uint256 amount) private {
        if (kultMembers[kult] == 0) drakma.mint(treasury, amount);
        else kultPerMember[kult] += amount * ACC / kultMembers[kult];
    }
}
