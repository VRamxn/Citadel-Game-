// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ITechTree, IGameView, ICitadelNFT, IMentatNFT} from "./interfaces/IGameAssets.sol";
import {Traits, Tech} from "./lib/Traits.sol";

/// @notice The CITADEL tech tree (EXORDIUM post). Every lit CITADEL researches one branch for its faction; research
/// points accrue per faction and branch, and technologies within a branch are discovered in order.
///
/// A faction only makes progress in a branch while at least one RELIK whose tech property is that branch is lit in
/// the faction and researching it — RELIK hold the keys (पक्ष). That makes RELIK the most protected and most sieged
/// CITADEL in the game.
///
/// MENTAT: each RELIK can claim one GEN0 MENTAT (64), and a faction's key RELIK can claim one when the faction
/// completes a branch.
contract TechTree is ITechTree, Ownable {
    struct Pool {
        uint128 points;
        uint64 last;
        uint32 keys; // RELIK keys researching this branch for this faction
        uint128 ratePerDay;
    }

    struct Registration {
        bool active;
        uint8 faction;
        uint8 branch;
        bool key;
        uint128 ratePerDay;
    }

    address public game;
    ICitadelNFT public immutable citadel;
    IMentatNFT public immutable mentat;
    /// @notice Technology k (0-based) of a branch costs techBaseCost x (k + 1) points.
    uint256 public techBaseCost = 100_000;

    mapping(uint8 => mapping(uint8 => Pool)) private _pools; // faction => branch
    mapping(uint256 => Registration) public registrationOf;
    mapping(uint256 => bool) public relikMentatClaimed;
    mapping(uint8 => mapping(uint8 => bool)) public branchMentatClaimed;

    event Registered(uint256 indexed citadelId, uint8 faction, uint8 branch, uint256 ratePerDay, bool key);
    event MentatClaimed(uint256 indexed mentatId, uint256 indexed relikId, uint8 faction, uint8 branch);
    event TechBaseCostUpdated(uint256 cost);

    error OnlyGame();
    error NotRelik();
    error NotController();
    error AlreadyClaimed();
    error BranchIncomplete();
    error NotKey();
    error GameSet();

    modifier onlyGame() {
        if (msg.sender != game) revert OnlyGame();
        _;
    }

    constructor(address owner_, ICitadelNFT citadel_, IMentatNFT mentat_) Ownable(owner_) {
        citadel = citadel_;
        mentat = mentat_;
    }

    function setGame(address game_) external onlyOwner {
        if (game != address(0)) revert GameSet();
        game = game_;
    }

    function setTechBaseCost(uint256 cost) external onlyOwner {
        // checkpoint nothing: completed techs are derived from points, so a cost change re-derives progress
        techBaseCost = cost;
        emit TechBaseCostUpdated(cost);
    }

    // ------------------------------------------------------------------ game hooks

    function register(uint256 citadelId, uint8 faction, uint8 branch, uint256 ratePerDay, bool key) external onlyGame {
        _unregister(citadelId);
        Pool storage p = _checkpoint(faction, branch);
        p.ratePerDay += uint128(ratePerDay);
        if (key) p.keys++;
        registrationOf[citadelId] = Registration(true, faction, branch, key, uint128(ratePerDay));
        emit Registered(citadelId, faction, branch, ratePerDay, key);
    }

    function unregister(uint256 citadelId) external onlyGame {
        _unregister(citadelId);
    }

    function _unregister(uint256 citadelId) private {
        Registration memory r = registrationOf[citadelId];
        if (!r.active) return;
        Pool storage p = _checkpoint(r.faction, r.branch);
        p.ratePerDay -= r.ratePerDay;
        if (r.key) p.keys--;
        delete registrationOf[citadelId];
    }

    function _checkpoint(uint8 faction, uint8 branch) private returns (Pool storage p) {
        p = _pools[faction][branch];
        p.points = uint128(_points(p));
        p.last = uint64(block.timestamp);
    }

    function _points(Pool storage p) private view returns (uint256) {
        if (p.keys == 0 || p.last == 0) return p.points;
        return p.points + uint256(p.ratePerDay) * (block.timestamp - p.last) / 1 days;
    }

    // ------------------------------------------------------------------ views

    function pool(uint8 faction, uint8 branch)
        external
        view
        returns (uint256 points, uint256 ratePerDay, uint256 keys, uint256 completed)
    {
        Pool storage p = _pools[faction][branch];
        points = _points(p);
        return (points, p.ratePerDay, p.keys, _completed(branch, points));
    }

    /// @notice Number of technologies discovered in a branch with `points` research.
    function _completed(uint8 branch, uint256 points) private view returns (uint256 n) {
        (, uint256 count) = Tech.branch(branch);
        // cumulative cost of the first n techs = base x n(n+1)/2
        while (n < count && techBaseCost * (n + 1) * (n + 2) / 2 <= points) {
            ++n;
        }
    }

    /// @notice Points needed for the next technology in a branch (0 = branch complete).
    function nextCost(uint8 faction, uint8 branch) external view returns (uint256) {
        (, uint256 count) = Tech.branch(branch);
        uint256 n = _completed(branch, _points(_pools[faction][branch]));
        return n == count ? 0 : techBaseCost * (n + 1) * (n + 2) / 2;
    }

    function bits(uint8 faction) external view returns (uint64 b) {
        for (uint8 br; br < Tech.BRANCHES; ++br) {
            (uint256 first,) = Tech.branch(br);
            uint256 n = _completed(br, _points(_pools[faction][br]));
            for (uint256 i; i < n; ++i) {
                b |= uint64(1) << uint64(first + i);
            }
        }
    }

    // ------------------------------------------------------------------ MENTAT

    /// @notice Each GEN0 RELIK may claim one GEN0 MENTAT.
    function claimRelikMentat(uint256 relikId) external returns (uint256 mentatId) {
        Traits.CitadelTraits memory t = citadel.traitsOf(relikId);
        if (t.generation != 0 || t.sekt != Traits.SEKT_RELIK) revert NotRelik();
        if (IGameView(game).controllerOfCitadel(relikId) != msg.sender) revert NotController();
        if (relikMentatClaimed[relikId]) revert AlreadyClaimed();
        relikMentatClaimed[relikId] = true;
        mentatId = mentat.mint(msg.sender, Traits.MentatTraits(0, 0));
        emit MentatClaimed(mentatId, relikId, 255, 255);
    }

    /// @notice When a faction completes a branch, the owner of a key RELIK researching it may claim one MENTAT.
    function claimBranchMentat(uint8 branch, uint256 relikId) external returns (uint256 mentatId) {
        Traits.CitadelTraits memory t = citadel.traitsOf(relikId);
        if (t.generation != 0 || t.sekt != Traits.SEKT_RELIK || t.tech != branch) revert NotKey();
        (bool lit, uint8 faction, uint8 research) = IGameView(game).placement(relikId);
        if (!lit || research != branch) revert NotKey();
        if (IGameView(game).controllerOfCitadel(relikId) != msg.sender) revert NotController();
        (, uint256 count) = Tech.branch(branch);
        if (_completed(branch, _points(_pools[faction][branch])) < count) revert BranchIncomplete();
        if (branchMentatClaimed[faction][branch]) revert AlreadyClaimed();
        branchMentatClaimed[faction][branch] = true;
        mentatId = mentat.mint(msg.sender, Traits.MentatTraits(0, 0));
        emit MentatClaimed(mentatId, relikId, faction, branch);
    }
}
