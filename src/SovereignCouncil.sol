// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPilotNFT, IGameView} from "./interfaces/IGameAssets.sol";

interface ISovereignCount {
    function sovereignCount() external view returns (uint256);
}

/// @title GRID MAELSTROM — the SOVEREIGN COLLECTIVE's council.
/// @notice Sovereign PILOT propose and vote on arbitrary calls (one vote per sovereign seat). A proposal passes with a
/// majority of all seats filled when it was made, within the voting period, and then anyone can execute it. Owning the
/// game contracts through this council is how the economic levers pass to the sovereigns, as the posts intended:
/// transfer ownership to the council, then have the council accept it with a proposal.
contract SovereignCouncil {
    uint256 public constant VOTING_PERIOD = 7 days;

    struct Proposal {
        address proposer;
        address target;
        bytes data;
        string description;
        uint64 deadline;
        uint32 seats; // sovereign seats filled when proposed
        uint32 yes;
        uint32 no;
        bool executed;
    }

    IPilotNFT public immutable pilot;
    IGameView public immutable game;
    ISovereignCount public immutable technocracy;

    Proposal[] private _proposals;
    mapping(uint256 => mapping(uint256 => bool)) public voted; // proposal => pilot => voted

    event Proposed(uint256 indexed id, uint256 indexed pilotId, address target, bytes data, string description);
    event Voted(uint256 indexed id, uint256 indexed pilotId, bool support);
    event Executed(uint256 indexed id);

    error NotSovereign();
    error Closed();
    error AlreadyVoted();
    error NotPassed();
    error CallFailed(bytes reason);

    constructor(IPilotNFT pilot_, IGameView game_, ISovereignCount technocracy_) {
        pilot = pilot_;
        game = game_;
        technocracy = technocracy_;
    }

    function propose(uint256 pilotId, address target, bytes calldata data, string calldata description)
        external
        returns (uint256 id)
    {
        _requireSovereign(pilotId);
        id = _proposals.length;
        _proposals.push(
            Proposal({
                proposer: msg.sender,
                target: target,
                data: data,
                description: description,
                deadline: uint64(block.timestamp + VOTING_PERIOD),
                seats: uint32(technocracy.sovereignCount()),
                yes: 0,
                no: 0,
                executed: false
            })
        );
        emit Proposed(id, pilotId, target, data, description);
        _vote(id, pilotId, true);
    }

    function vote(uint256 id, uint256 pilotId, bool support) external {
        _requireSovereign(pilotId);
        _vote(id, pilotId, support);
    }

    function execute(uint256 id) external {
        Proposal storage p = _proposals[id];
        if (p.executed || !passed(id)) revert NotPassed();
        p.executed = true;
        (bool ok, bytes memory ret) = p.target.call(p.data);
        if (!ok) revert CallFailed(ret);
        emit Executed(id);
    }

    function passed(uint256 id) public view returns (bool) {
        Proposal storage p = _proposals[id];
        return uint256(p.yes) * 2 > p.seats;
    }

    function proposal(uint256 id) external view returns (Proposal memory) {
        return _proposals[id];
    }

    function proposalCount() external view returns (uint256) {
        return _proposals.length;
    }

    function _vote(uint256 id, uint256 pilotId, bool support) private {
        Proposal storage p = _proposals[id];
        if (block.timestamp > p.deadline || p.executed) revert Closed();
        if (voted[id][pilotId]) revert AlreadyVoted();
        voted[id][pilotId] = true;
        if (support) p.yes++;
        else p.no++;
        emit Voted(id, pilotId, support);
    }

    function _requireSovereign(uint256 pilotId) private view {
        if (game.controllerOfPilot(pilotId) != msg.sender || !pilot.traitsOf(pilotId).sovereign) revert NotSovereign();
    }
}
