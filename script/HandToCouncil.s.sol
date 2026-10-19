// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Give every remaining admin power to the GRID MAELSTROM council, so the game is governed on-chain by sovereign
/// vote from then on. Run it once balancing is done:
///   L2_DEPLOYMENT=deployments/8453.json forge script script/HandToCouncil.s.sol --rpc-url base --account deployer --broadcast
/// - TechTree and Technocracy: ownership moves to the council immediately.
/// - The tokens (DRAKMA, CITADEL, PILOT, MENTAT): the council gets DEFAULT_ADMIN_ROLE and the deployer renounces it.
/// - The game (Ownable2Step): ownership is offered; the council takes it with a proposal calling
///   `acceptOwnership()` on the game. Until then the deployer still holds the game's levers.
contract HandToCouncil is Script {
    function run() external {
        string memory j = vm.readFile(vm.envString("L2_DEPLOYMENT"));
        address council = vm.parseJsonAddress(j, ".council");
        address[4] memory tokens = [
            vm.parseJsonAddress(j, ".drakma"),
            vm.parseJsonAddress(j, ".citadel"),
            vm.parseJsonAddress(j, ".pilot"),
            vm.parseJsonAddress(j, ".mentat")
        ];
        vm.startBroadcast();
        Ownable(vm.parseJsonAddress(j, ".techTree")).transferOwnership(council);
        Ownable(vm.parseJsonAddress(j, ".technocracy")).transferOwnership(council);
        for (uint256 i; i < tokens.length; ++i) {
            AccessControl t = AccessControl(tokens[i]);
            t.grantRole(0x00, council);
            t.renounceRole(0x00, msg.sender);
        }
        Ownable(vm.parseJsonAddress(j, ".game")).transferOwnership(council);
        vm.stopBroadcast();
    }
}
