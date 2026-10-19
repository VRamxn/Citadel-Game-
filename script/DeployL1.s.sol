// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Stack} from "./Stack.sol";
import {IOPMessenger} from "../src/bridge/IOPMessenger.sol";
import {MockOriginal, MockOriginalPilot, MockOriginalsFaucet} from "../src/TestnetFaucet.sol";

/// @notice Step 2 of 3 — the vault on Ethereum (or Sepolia), pointed at the L2 deployment from step 1.
///   L2_DEPLOYMENT=deployments/84532.json forge script script/DeployL1.s.sol --rpc-url sepolia --account deployer --broadcast --verify
/// On mainnet the vault holds the original CITADEL and PILOT. On Sepolia it deploys stand-ins for them (with a faucet).
/// Writes deployments/<l1ChainId>-l1.json.
contract DeployL1 is Script, Stack {
    address constant CITADEL = 0xaF08134eA12494dc3AAA7f1EFB23A8753B7F84c9;
    address constant PILOT = 0xD653B9f4ec70658402B9634E7E0eAFcc64138Cad;
    address constant BASE_MESSENGER = 0x866E82a600A1414e583f7F13623F1aC5d58b0Afa; // Base, on Ethereum
    address constant BASE_SEPOLIA_MESSENGER = 0xC34855F4De64F1840e5686e64278da901e261f20; // Base Sepolia, on Sepolia

    function run() external returns (L1Deployment memory l1) {
        string memory l2 = vm.readFile(vm.envString("L2_DEPLOYMENT"));
        address l2Bridge = vm.parseJsonAddress(l2, ".bridge");
        address l2Claim = vm.parseJsonAddress(l2, ".claim");
        bool mainnet = block.chainid == 1;

        vm.startBroadcast();
        address admin = msg.sender;
        address citadel = CITADEL;
        address pilot = PILOT;
        address faucet;
        if (!mainnet) {
            MockOriginal c = new MockOriginal("CITADEL (testnet original)", "CITADEL", 1024, admin);
            MockOriginalPilot p = new MockOriginalPilot(admin);
            MockOriginalsFaucet f = new MockOriginalsFaucet(c, p);
            c.setFaucet(address(f));
            p.setFaucet(address(f));
            (citadel, pilot, faucet) = (address(c), address(p), address(f));
        }
        IOPMessenger messenger =
            IOPMessenger(vm.envOr("L1_MESSENGER", mainnet ? BASE_MESSENGER : BASE_SEPOLIA_MESSENGER));
        l1 = _deployL1(admin, messenger, IERC721(citadel), IERC721(pilot), l2Claim);
        _linkL1(l1, l2Bridge);
        vm.stopBroadcast();

        string memory j = "l1";
        vm.serializeUint(j, "chainId", block.chainid);
        vm.serializeUint(j, "block", block.number);
        vm.serializeAddress(j, "citadelOriginal", citadel);
        vm.serializeAddress(j, "pilotOriginal", pilot);
        vm.serializeAddress(j, "originalsFaucet", faucet);
        vm.serializeAddress(j, "messenger", address(messenger));
        vm.serializeAddress(j, "claimRelay", address(l1.claimRelay));
        string memory out = vm.serializeAddress(j, "vault", address(l1.vault));
        vm.writeJson(out, string.concat("deployments/", vm.toString(block.chainid), "-l1.json"));
        console.log("vault", address(l1.vault));
    }
}
