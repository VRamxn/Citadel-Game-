// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Stack} from "./Stack.sol";

/// @notice Deploys the full system, loads the mainnet CITADEL traits and writes deployments/<chainid>.json.
///   forge script script/Deploy.s.sol --rpc-url sepolia --account deployer --broadcast --verify
/// Env: GRID_RADIUS (default 36: 3,997 tiles), TREASURY (default: deployer).
contract Deploy is Script, Stack {
    function run() external virtual returns (Deployment memory d) {
        bytes memory traits = vm.readFileBinary("data/citadel-traits.bin");
        require(traits.length == 1024 * 6, "run script/pack_traits.py first");
        uint16 radius = uint16(vm.envOr("GRID_RADIUS", uint256(36)));

        vm.startBroadcast();
        address admin = msg.sender;
        address treasury = vm.envOr("TREASURY", admin);
        d = _deploy(admin, treasury, radius);
        _loadTraits(d.citadel, traits);
        vm.stopBroadcast();

        _write(d);
    }

    function _write(Deployment memory d) internal {
        string memory j = "deploy";
        vm.serializeUint(j, "chainId", block.chainid);
        vm.serializeUint(j, "block", block.number);
        vm.serializeAddress(j, "drakma", address(d.drakma));
        vm.serializeAddress(j, "citadel", address(d.citadel));
        vm.serializeAddress(j, "pilot", address(d.pilot));
        vm.serializeAddress(j, "mentat", address(d.mentat));
        vm.serializeAddress(j, "techTree", address(d.techTree));
        vm.serializeAddress(j, "technocracy", address(d.technocracy));
        vm.serializeAddress(j, "council", address(d.council));
        vm.serializeAddress(j, "faucet", address(d.faucet));
        string memory out = vm.serializeAddress(j, "game", address(d.game));
        string memory path = string.concat("deployments/", vm.toString(block.chainid), ".json");
        vm.writeJson(out, path);
        console.log("game", address(d.game));
        console.log("written", path);
    }
}
