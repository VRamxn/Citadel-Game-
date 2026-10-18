// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Deploy} from "./Deploy.s.sol";
import {EconomyModule} from "../src/game/EconomyModule.sol";
import {ViewModule} from "../src/game/ViewModule.sol";
import {GameStorage} from "../src/game/GameStorage.sol";
import {Hex} from "../src/lib/Hex.sol";

/// @notice LOCAL ONLY (anvil). Deploys the system, then seeds a living world: eight anvil accounts take their faucet
/// kit, light CITADEL around the grid in all four factions and start building. Uses the real trait snapshot if
/// data/citadel-traits.bin exists, synthetic traits otherwise. The grid is the full 80-radius map with 128 players.
///   anvil &  forge script script/DevDeploy.s.sol --rpc-url local --broadcast --gas-estimate-multiplier 300
/// (forge simulates all seeding txs in one block, which underestimates gas once they land in separate blocks)
contract DevDeploy is Deploy {
    string constant MNEMONIC = "test test test test test test test test test test test junk";
    uint16 constant RADIUS = 80;
    uint256 constant BOTS = 120; // extra players scattered over the frontier (anvil accounts 20..139)

    function run() external override returns (Deployment memory d) {
        uint256 adminKey = vm.deriveKey(MNEMONIC, 0);
        bytes memory traits;
        try vm.readFileBinary("data/citadel-traits.bin") returns (bytes memory b) {
            traits = b;
        } catch {}
        if (traits.length != 1024 * 6) traits = _synthetic();

        vm.startBroadcast(adminKey);
        address admin = vm.addr(adminKey);
        d = _deploy(admin, admin, RADIUS);
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
        _seedFrontier(d, adminKey);
        _write(d);
    }

    /// @dev BOTS more players, each with one CITADEL lit somewhere between 9 and 76 tiles out (the centre stays free for
    /// the e2e playtests), in all four factions. Anvil only funds its first 10 accounts, so the admin pays their gas.
    function _seedFrontier(Deployment memory d, uint256 adminKey) internal {
        EconomyModule eco = EconomyModule(address(d.game));
        ViewModule v = ViewModule(address(d.game));
        for (uint256 i; i < BOTS; ++i) {
            uint256 key = vm.deriveKey(MNEMONIC, uint32(20 + i));
            address bot = vm.addr(key);
            vm.broadcast(adminKey);
            payable(bot).transfer(5 ether);

            uint256 firstPilot = d.pilot.totalMinted();
            uint256 from = d.faucet.nextCitadel();
            vm.startBroadcast(key);
            d.faucet.drip();
            d.citadel.setApprovalForAll(address(d.game), true);
            d.pilot.setApprovalForAll(address(d.game), true);
            uint256 citadelId = from;
            while (d.citadel.ownerOf(citadelId) != bot) ++citadelId;
            (int16 q, int16 r) = _frontierTile(v, i);
            uint256[] memory pilots = new uint256[](1);
            pilots[0] = firstPilot;
            eco.lite(citadelId, 0, q, r, uint8(i % 4), d.citadel.traitsOf(citadelId).tech, pilots);
            eco.build(citadelId, 5);
            vm.stopBroadcast();
        }
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
