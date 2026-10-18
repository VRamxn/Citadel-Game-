// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Deploy} from "./Deploy.s.sol";
import {EconomyModule} from "../src/game/EconomyModule.sol";
import {ViewModule} from "../src/game/ViewModule.sol";
import {GameStorage} from "../src/game/GameStorage.sol";

/// @notice LOCAL ONLY (anvil). Deploys the system, then seeds a living world: eight anvil accounts take their faucet
/// kit, light CITADEL around the grid in all four factions and start building. Uses the real trait snapshot if
/// data/citadel-traits.bin exists, synthetic traits otherwise.
///   anvil &  forge script script/DevDeploy.s.sol --rpc-url local --broadcast
contract DevDeploy is Deploy {
    string constant MNEMONIC = "test test test test test test test test test test test junk";

    function run() external override returns (Deployment memory d) {
        uint256 adminKey = vm.deriveKey(MNEMONIC, 0);
        bytes memory traits;
        try vm.readFileBinary("data/citadel-traits.bin") returns (bytes memory b) {
            traits = b;
        } catch {}
        if (traits.length != 1024 * 6) traits = _synthetic();

        vm.startBroadcast(adminKey);
        address admin = vm.addr(adminKey);
        d = _deploy(admin, admin, 12);
        _loadTraits(d.citadel, traits);
        // a quicker world for local play: faster claims and sieges
        GameStorage.Config memory c = ViewModule(address(d.game)).getConfig();
        c.claimInterval = 1 hours;
        ViewModule(address(d.game)).setConfig(c);
        vm.stopBroadcast();

        // hand the faucet's queue a mix of SEKT so the seeded world looks like the real one
        vm.startBroadcast(adminKey);
        uint256[8] memory picks = [uint256(3), 70, 200, 500, 600, 700, 800, 900];
        for (uint256 i; i < 8; ++i) {
            d.faucet.grantCitadel(vm.addr(vm.deriveKey(MNEMONIC, uint32(i + 1))), picks[i]);
        }
        vm.stopBroadcast();

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
            uint256 key = vm.deriveKey(MNEMONIC, uint32(i + 1));
            vm.startBroadcast(key);
            d.faucet.drip();
            d.citadel.setApprovalForAll(address(d.game), true);
            d.pilot.setApprovalForAll(address(d.game), true);
            d.mentat.setApprovalForAll(address(d.game), true);
            uint256 citadelId = picks[i];
            uint256[] memory pilots = new uint256[](1);
            pilots[0] = 2 * i;
            EconomyModule eco = EconomyModule(address(d.game));
            uint8 faction = uint8(i % 4);
            eco.lite(citadelId, 0, spots[i][0], spots[i][1], faction, d.citadel.traitsOf(citadelId).tech, pilots);
            eco.build(citadelId, 5); // FLEET ACADEMY
            vm.stopBroadcast();
        }
        _write(d);
    }

    /// @dev SEKT by id band like the mainnet supply (64 / 128 / 256 / 576); components weighted to the weak tiers.
    function _synthetic() internal pure returns (bytes memory t) {
        t = new bytes(1024 * 6);
        for (uint256 i; i < 1024; ++i) {
            uint256 s = uint256(keccak256(abi.encode(i)));
            uint8 sekt = i < 64 ? 0 : i < 192 ? 1 : i < 448 ? 2 : 3;
            t[i * 6 + 1] = bytes1(sekt);
            t[i * 6 + 2] = bytes1(_tier(s));
            t[i * 6 + 3] = bytes1(_tier(s >> 16));
            t[i * 6 + 4] = bytes1(_tier(s >> 32));
            t[i * 6 + 5] = bytes1(uint8((s >> 48) % 8));
        }
    }

    function _tier(uint256 s) private pure returns (uint8) {
        uint256 r = s % 100;
        uint16[8] memory w = [uint16(40), 25, 15, 8, 5, 4, 2, 1];
        uint256 acc;
        for (uint8 i; i < 8; ++i) {
            acc += w[i];
            if (r < acc) return i;
        }
        return 7;
    }
}
