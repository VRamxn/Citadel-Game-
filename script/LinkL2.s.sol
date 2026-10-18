// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {CitadelBridgeL2} from "../src/bridge/CitadelBridgeL2.sol";
import {DrakmaClaim} from "../src/DrakmaClaim.sol";

/// @notice Step 3 of 3 — tell the L2 bridge and claim where the L1 vault and relay are. Both setters work once.
///   L2_DEPLOYMENT=deployments/84532.json L1_DEPLOYMENT=deployments/11155111-l1.json \
///     forge script script/LinkL2.s.sol --rpc-url base_sepolia --account deployer --broadcast
contract LinkL2 is Script {
    function run() external {
        string memory l2 = vm.readFile(vm.envString("L2_DEPLOYMENT"));
        string memory l1 = vm.readFile(vm.envString("L1_DEPLOYMENT"));
        vm.startBroadcast();
        CitadelBridgeL2(vm.parseJsonAddress(l2, ".bridge")).setL1Vault(vm.parseJsonAddress(l1, ".vault"));
        DrakmaClaim(vm.parseJsonAddress(l2, ".claim")).setL1Relay(vm.parseJsonAddress(l1, ".claimRelay"));
        vm.stopBroadcast();
    }
}
