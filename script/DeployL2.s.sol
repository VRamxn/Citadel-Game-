// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Stack} from "./Stack.sol";
import {IOPMessenger} from "../src/bridge/IOPMessenger.sol";
import {DrakmaClaim} from "../src/DrakmaClaim.sol";

/// @notice Step 1 of 3 — the game on the L2 (Base or Base Sepolia).
///   forge script script/DeployL2.s.sol --rpc-url base_sepolia --account deployer --broadcast --verify
/// Env:
///   TESTNET       true on Base Sepolia (adds the DRAKMA faucet). Default true.
/// The DRAKMA carry-over root and its terms come from data/claims.json (script/snapshot.mjs <block>); required on mainnet.
///   GRID_RADIUS   default 80 (19,441 tiles).
///   COUNCIL_DK    whole DRAKMA minted to the GRID MAELSTROM council's treasury. Default 1,000,000,000.
///   TREASURY      where the game's fee share goes. Default: the council.
/// Loads and locks the original CITADEL and PILOT metadata traits. PILOT levels and sovereignty arrive over the bridge,
/// read on L1 from the original contract. Writes deployments/<chainId>.json.
contract DeployL2 is Script, Stack {
    address constant L2_MESSENGER = 0x4200000000000000000000000000000000000007;

    function run() external returns (Deployment memory d) {
        bool testnet = vm.envOr("TESTNET", true);
        DrakmaClaim.Terms memory terms;
        try vm.readFile("data/claims.json") returns (string memory c) {
            terms = DrakmaClaim.Terms({
                root: vm.parseJsonBytes32(c, ".root"),
                snapshotBlock: vm.parseUint(vm.parseJsonString(c, ".block")),
                maxCarryOver: vm.parseUint(vm.parseJsonString(c, ".maxCarryOver")) * 1 ether,
                flatPerWallet: vm.parseUint(vm.parseJsonString(c, ".flatPerWallet")) * 1 ether
            });
            require(testnet || !vm.parseJsonBool(c, ".preview"), "mainnet needs a launch snapshot, not a preview");
        } catch {
            require(testnet, "data/claims.json required on mainnet (node script/snapshot.mjs <block>)");
        }
        bytes memory citadelTraits = vm.readFileBinary("data/citadel-traits.bin");
        bytes memory pilotTraits = vm.readFileBinary("data/pilot-traits.bin");

        vm.startBroadcast();
        address admin = msg.sender;
        address feeTreasury = vm.envOr("TREASURY", address(0));
        d = _deployL2(
            admin,
            feeTreasury == address(0) ? admin : feeTreasury,
            uint16(vm.envOr("GRID_RADIUS", uint256(80))),
            IOPMessenger(vm.envOr("L2_MESSENGER", L2_MESSENGER)),
            terms,
            testnet
        );
        _loadTraits(d.citadel, citadelTraits);
        _loadPilotTraits(d.pilot, pilotTraits);
        _lockTraits(d);
        _fundCouncil(d, admin, vm.envOr("COUNCIL_DK", uint256(1_000_000_000)) * 1 ether);
        if (feeTreasury == address(0)) _councilIsTreasury(d);
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
