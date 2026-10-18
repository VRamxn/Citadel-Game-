// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Stack} from "./Stack.sol";
import {EconomyModule} from "../src/game/EconomyModule.sol";
import {ViewModule} from "../src/game/ViewModule.sol";
import {GameStorage} from "../src/game/GameStorage.sol";
import {Hex} from "../src/lib/Hex.sol";
import {LocalMessenger} from "../src/bridge/LocalMessenger.sol";
import {MockOriginal, MockOriginalsFaucet} from "../src/TestnetFaucet.sol";

/// @notice LOCAL ONLY (anvil). Both sides of the bridge on one chain — stand-ins for the original CITADEL and PILOT, the
/// L1 vault, the L2 game — linked by a LocalMessenger that delivers instantly. Then it seeds a living world the way real
/// players arrive: originals are deposited through the vault and their L2 copies are lit to the grid.
///   anvil &  forge script script/DevDeploy.s.sol --rpc-url local --broadcast --gas-estimate-multiplier 300
/// (forge simulates all seeding txs in one block, which underestimates gas once they land in separate blocks)
contract DevDeploy is Script, Stack {
    string constant MNEMONIC = "test test test test test test test test test test test junk";
    uint16 constant RADIUS = 80;
    uint256 constant BOTS = 120; // extra players scattered over the frontier (anvil accounts 20..139)

    Deployment d;
    L1Deployment l1;
    MockOriginal origCitadel;
    MockOriginal origPilot;
    MockOriginalsFaucet origFaucet;
    uint256 adminKey;

    function run() external {
        adminKey = vm.deriveKey(MNEMONIC, 0);
        address admin = vm.addr(adminKey);

        vm.startBroadcast(adminKey);
        LocalMessenger messenger = new LocalMessenger();
        origCitadel = new MockOriginal("CITADEL (local original)", "CITADEL", 1024, admin);
        origPilot = new MockOriginal("PILOT (local original)", "PILOT", 2048, admin);
        origFaucet = new MockOriginalsFaucet(origCitadel, origPilot);
        origCitadel.setFaucet(address(origFaucet));
        origPilot.setFaucet(address(origFaucet));
        d = _deployL2(admin, admin, RADIUS, messenger, bytes32(0), true);
        l1 = _deployL1(admin, messenger, IERC721(address(origCitadel)), IERC721(address(origPilot)), address(d.claim));
        _linkL1(l1, address(d.bridge));
        _linkL2(d, address(l1.vault), address(l1.claimRelay));
        _loadTraits(d.citadel, _citadelTraits());
        _loadPilotTraits(d.pilot, _pilotTraits());
        _seedSovereigns();
        GameStorage.Config memory c = ViewModule(address(d.game)).getConfig();
        c.claimInterval = 1 hours; // a quicker world for local play
        ViewModule(address(d.game)).setConfig(c);
        vm.stopBroadcast();

        // eight fixed players near the core (the e2e playtests rely on #70 at (-3,1) and #900 at (5,2))
        uint256[8] memory picks = [uint256(3), 70, 200, 500, 600, 700, 800, 900];
        int16[2][8] memory spots = [
            [int16(3), int16(-1)],
            [int16(-3), int16(1)],
            [int16(0), int16(4)],
            [int16(1), int16(-5)],
            [int16(6), int16(-6)],
            [int16(-6), int16(2)],
            [int16(-2), int16(-4)],
            [int16(5), int16(2)]
        ];
        for (uint256 i; i < 8; ++i) {
            _arrive(vm.deriveKey(MNEMONIC, uint32(i + 1)), picks[i], i, spots[i][0], spots[i][1], uint8(i % 4));
        }
        // the frontier
        ViewModule v = ViewModule(address(d.game));
        for (uint256 i; i < BOTS; ++i) {
            uint256 key = vm.deriveKey(MNEMONIC, uint32(20 + i));
            vm.broadcast(adminKey);
            payable(vm.addr(key)).transfer(5 ether);
            (int16 q, int16 r) = _frontierTile(v, i);
            _arrive(key, 1000 - i, 8 + i, q, r, uint8(i % 4));
        }
        _write();
    }

    /// @dev A player's first day: receive originals on "L1", bridge them, take the DRAKMA faucet, lite, build.
    function _arrive(uint256 key, uint256 citadelId, uint256 pilotId, int16 q, int16 r, uint8 faction) internal {
        address who = vm.addr(key);
        vm.startBroadcast(adminKey);
        origCitadel.mint(who, citadelId);
        origPilot.mint(who, pilotId);
        vm.stopBroadcast();

        vm.startBroadcast(key);
        uint256[] memory c = new uint256[](1);
        c[0] = citadelId;
        uint256[] memory p = new uint256[](1);
        p[0] = pilotId;
        origCitadel.setApprovalForAll(address(l1.vault), true);
        origPilot.setApprovalForAll(address(l1.vault), true);
        l1.vault.deposit(0, c, who);
        l1.vault.deposit(1, p, who);
        d.faucet.drip();
        d.citadel.setApprovalForAll(address(d.game), true);
        d.pilot.setApprovalForAll(address(d.game), true);
        d.mentat.setApprovalForAll(address(d.game), true);
        EconomyModule eco = EconomyModule(address(d.game));
        eco.lite(citadelId, 0, q, r, faction, d.citadel.traitsOf(citadelId).tech, p);
        eco.build(citadelId, 5); // FLEET ACADEMY
        vm.stopBroadcast();
    }

    function _frontierTile(ViewModule v, uint256 i) internal view returns (int16 q, int16 r) {
        for (uint256 n;; ++n) {
            uint256 h = uint256(keccak256(abi.encode(i, n)));
            q = int16(int256(h % 153) - 76);
            r = int16(int256((h >> 16) % 153) - 76);
            uint256 dist = Hex.fromCenter(q, r);
            if (dist < 9 || dist > 76) continue;
            (bool occupied,) = v.citadelAt(0, q, r);
            if (!occupied) return (q, r);
        }
    }

    function _seedSovereigns() internal {
        try vm.readFile("data/sovereigns.json") returns (string memory s) {
            d.technocracy.seedSovereigns(vm.parseJsonUintArray(s, ".ids"), vm.parseJsonUint(s, ".bought"));
        } catch {}
    }

    function _citadelTraits() internal view returns (bytes memory t) {
        try vm.readFileBinary("data/citadel-traits.bin") returns (bytes memory b) {
            if (b.length == 1024 * 6) return b;
        } catch {}
        t = new bytes(1024 * 6); // synthetic: SEKT by id band like the mainnet supply
        for (uint256 i; i < 1024; ++i) {
            uint256 s = uint256(keccak256(abi.encode(i)));
            t[i * 6 + 1] = bytes1(uint8(i < 64 ? 0 : i < 192 ? 1 : i < 448 ? 2 : 3));
            for (uint256 k; k < 4; ++k) {
                t[i * 6 + 2 + k] = bytes1(uint8((s >> (16 * k)) % 8));
            }
        }
    }

    function _pilotTraits() internal view returns (bytes memory t) {
        try vm.readFileBinary("data/pilot-traits.bin") returns (bytes memory b) {
            if (b.length > 0) return b;
        } catch {}
        t = new bytes(1140 * 5); // synthetic until the snapshot is packed
        for (uint256 i; i < 1140; ++i) {
            uint256 s = uint256(keccak256(abi.encode("pilot", i)));
            t[i * 5] = bytes1(uint8(s % 8));
            t[i * 5 + 1] = bytes1(uint8((s >> 8) % 8));
        }
    }

    function _write() internal {
        string memory j = "dev";
        vm.serializeUint(j, "chainId", block.chainid);
        vm.serializeUint(j, "block", 0);
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
        vm.serializeAddress(j, "vault", address(l1.vault));
        vm.serializeAddress(j, "citadelOriginal", address(origCitadel));
        vm.serializeAddress(j, "pilotOriginal", address(origPilot));
        vm.serializeAddress(j, "originalsFaucet", address(origFaucet));
        string memory out = vm.serializeAddress(j, "game", address(d.game));
        vm.writeJson(out, "deployments/31337.json");
        console.log("game", address(d.game));
    }
}
