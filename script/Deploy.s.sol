// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {CitadelGame} from "../src/CitadelGame.sol";
import {CitadelNFT} from "../src/CitadelNFT.sol";
import {PilotNFT} from "../src/PilotNFT.sol";
import {Drakma} from "../src/Drakma.sol";
import {TestnetFaucet} from "../src/TestnetFaucet.sol";
import {IDrakma} from "../src/interfaces/IGameAssets.sol";

/// @notice Deploys the full testnet stack and loads the mainnet CITADEL traits.
///   forge script script/Deploy.s.sol --rpc-url sepolia --account deployer --broadcast --verify
contract Deploy is Script {
    uint16 constant GRID_RADIUS = 12; // 469 tiles
    uint256 constant TRAIT_CHUNK = 128;
    string constant CITADEL_URI = "https://gateway.pinata.cloud/ipfs/QmXXC2PHUeiFtUFVdLNnYodWUNdZnK2jbT8prE6R51mGT6/";

    function run() external {
        bytes memory traits = vm.readFileBinary("data/citadel-traits.bin");
        require(traits.length == 1024 * 6, "run script/pack_traits.py first");

        vm.startBroadcast();
        address admin = msg.sender;

        Drakma dk = new Drakma(admin);
        CitadelNFT cit = new CitadelNFT(admin, CITADEL_URI);
        PilotNFT pil = new PilotNFT(admin, IDrakma(address(dk)));
        CitadelGame game = new CitadelGame(admin, address(cit), address(pil), IDrakma(address(dk)), GRID_RADIUS);
        TestnetFaucet faucet = new TestnetFaucet(admin, cit, pil, dk);

        dk.grantRole(dk.MINTER_ROLE(), address(game));
        dk.grantRole(dk.BURNER_ROLE(), address(game));
        dk.grantRole(dk.BURNER_ROLE(), address(pil));
        dk.grantRole(dk.MINTER_ROLE(), address(faucet));
        cit.grantRole(cit.MINTER_ROLE(), address(faucet));
        pil.grantRole(pil.MINTER_ROLE(), address(faucet));

        for (uint256 start; start < 1024; start += TRAIT_CHUNK) {
            cit.setTraits(start, _slice(traits, start * 6, TRAIT_CHUNK * 6));
        }
        vm.stopBroadcast();

        console.log("DRAKMA      ", address(dk));
        console.log("CITADEL     ", address(cit));
        console.log("PILOT       ", address(pil));
        console.log("CitadelGame ", address(game));
        console.log("Faucet      ", address(faucet));

        string memory json = "deploy";
        vm.serializeAddress(json, "drakma", address(dk));
        vm.serializeAddress(json, "citadel", address(cit));
        vm.serializeAddress(json, "pilot", address(pil));
        vm.serializeAddress(json, "game", address(game));
        string memory out = vm.serializeAddress(json, "faucet", address(faucet));
        vm.writeJson(out, string.concat("deployments/", vm.toString(block.chainid), ".json"));
    }

    function _slice(bytes memory b, uint256 from, uint256 len) private pure returns (bytes memory out) {
        out = new bytes(len);
        for (uint256 i; i < len; ++i) {
            out[i] = b[from + i];
        }
    }
}
