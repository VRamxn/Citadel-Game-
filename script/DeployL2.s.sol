// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Stack} from "./Stack.sol";
import {IOPMessenger} from "../src/bridge/IOPMessenger.sol";

/// @notice Step 1 of 3 — the game on the L2 (Base or Base Sepolia).
///   forge script script/DeployL2.s.sol --rpc-url base_sepolia --account deployer --broadcast --verify
/// Env:
///   TESTNET       true on Base Sepolia (adds the DRAKMA faucet). Default true.
///   CLAIM_ROOT    Merkle root of the DRAKMA carry-over (data/claims.json, script/snapshot.mjs). Required on mainnet.
///   GRID_RADIUS   default 80 (19,441 tiles).    TREASURY   default: deployer.
/// Loads the original CITADEL and PILOT traits and seats the carried-over sovereigns. Writes deployments/<chainId>.json.
contract DeployL2 is Script, Stack {
    address constant L2_MESSENGER = 0x4200000000000000000000000000000000000007;

    function run() external returns (Deployment memory d) {
        bool testnet = vm.envOr("TESTNET", true);
        bytes32 root = vm.envOr("CLAIM_ROOT", bytes32(0));
        require(testnet || root != bytes32(0), "CLAIM_ROOT required on mainnet");
        bytes memory citadelTraits = vm.readFileBinary("data/citadel-traits.bin");
        bytes memory pilotTraits = vm.readFileBinary("data/pilot-traits.bin");
        string memory sov = vm.readFile("data/sovereigns.json");
        uint256[] memory sovereigns = vm.parseJsonUintArray(sov, ".ids");
        uint256 bought = vm.parseJsonUint(sov, ".bought");

        vm.startBroadcast();
        address admin = msg.sender;
        d = _deployL2(
            admin,
            vm.envOr("TREASURY", admin),
            uint16(vm.envOr("GRID_RADIUS", uint256(80))),
            IOPMessenger(vm.envOr("L2_MESSENGER", L2_MESSENGER)),
            root,
            testnet
        );
        _loadTraits(d.citadel, citadelTraits);
        _loadPilotTraits(d.pilot, pilotTraits);
        d.technocracy.seedSovereigns(sovereigns, bought);
        vm.stopBroadcast();

        string memory j = "l2";
        vm.serializeUint(j, "chainId", block.chainid);
        vm.serializeUint(j, "block", block.number);
        vm.serializeAddress(j, "drakma", address(d.drakma));
        vm.serializeAddress(j, "citadel", address(d.citadel));
        vm.serializeAddress(j, "pilot", address(d.pilot));
        vm.serializeAddress(j, "mentat", address(d.mentat));
        vm.serializeAddress(j, "techTree", address(d.techTree));
        vm.serializeAddress(j, "technocracy", address(d.technocracy));
        vm.serializeAddress(j, "council", address(d.council));
        vm.serializeAddress(j, "bridge", address(d.bridge));
        vm.serializeAddress(j, "claim", address(d.claim));
        vm.serializeAddress(j, "faucet", address(d.faucet));
        string memory out = vm.serializeAddress(j, "game", address(d.game));
        vm.writeJson(out, string.concat("deployments/", vm.toString(block.chainid), ".json"));
        console.log("game", address(d.game));
    }
}
