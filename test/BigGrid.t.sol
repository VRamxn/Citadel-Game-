// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Stack} from "../script/Stack.sol";
import {ViewModule} from "../src/game/ViewModule.sol";
import {Hex} from "../src/lib/Hex.sol";
import {LocalMessenger} from "../src/bridge/LocalMessenger.sol";

/// @notice The default 36-radius grid: 3,997 tiles with a golden core and six outer mining fields.
contract BigGridTest is Test, Stack {
    function test_hotspotLayoutAtRadius36() public {
        address admin = makeAddr("admin");
        vm.startPrank(admin);
        Deployment memory d = _deployL2(admin, admin, 36, new LocalMessenger(), bytes32(0), true);
        vm.stopPrank();
        ViewModule v = ViewModule(address(d.game));
        uint256 tiles;
        uint256 boosted;
        for (int16 q = -36; q <= 36; ++q) {
            for (int16 r = -36; r <= 36; ++r) {
                if (Hex.fromCenter(q, r) > 36) continue;
                tiles++;
                if (v.tileBps(0, q, r) > 10_000) boosted++;
            }
        }
        assertEq(tiles, 3_997);
        assertGt(boosted * 100 / tiles, 9);
        assertLt(boosted * 100 / tiles, 16);
        assertEq(v.tileBps(0, 0, 0), 12_500); // core
        assertEq(v.tileBps(0, 21, 0), 12_000); // a field centre, 60% out
        assertEq(v.tileBps(0, 0, -21), 12_000);
        assertEq(v.tileBps(0, 30, 0), 10_000); // the frontier
    }
}
