// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";
import {Base} from "./Base.t.sol";

/// @notice Gas of the main actions, for docs. `forge test --match-contract GasReport -vv`
contract GasReport is Base {
    function _g(string memory what, uint256 before) internal view {
        console.log(what, before - gasleft());
    }

    function test_gas() public {
        uint256 g;
        uint8 tech = _techOf(0);
        vm.prank(alice);
        g = gasleft();
        eco.lite(0, 0, 5, 0, 0, tech, none);
        _g("lite (no PILOT)", g);
        _lite(bob, 1, 6, 0, 1);
        _lite(carol, 2, -6, 0, 2);
        skip(1 hours);

        vm.startPrank(alice);
        g = gasleft();
        eco.build(0, B_ACADEMY);
        _g("build", g);
        g = gasleft();
        eco.hurryBuild(0);
        _g("hurryBuild", g);
        g = gasleft();
        eco.train(0, SIF, 500);
        _g("train", g);
        eco.hurryTraining(0, SIF);
        vm.stopPrank();
        skip(7 days);

        vm.prank(alice);
        g = gasleft();
        eco.claim(0);
        _g("claim", g);

        vm.prank(alice);
        g = gasleft();
        war.raid(0, 1, _units(100, 0, 0, 0));
        _g("raid (adjacent, instant)", g);

        vm.prank(alice);
        g = gasleft();
        uint256 m = war.raid(0, 2, _units(100, 0, 0, 0));
        _g("raid (send)", g);
        skip(6 hours);
        vm.prank(keeper);
        g = gasleft();
        war.resolve(m);
        _g("resolve raid", g);
        skip(6 hours);
        g = gasleft();
        war.resolve(m + 1);
        _g("resolve return", g);

        vm.prank(alice);
        g = gasleft();
        war.siege(0, 1, _units(300, 0, 0, 0), 0);
        _g("siege (start, adjacent)", g);
        skip(1 hours);
        g = gasleft();
        sie.advanceSiege(1, 1);
        _g("advanceSiege, 1 wave", g);
        skip(24 hours);
        g = gasleft();
        sie.advanceSiege(1, 24);
        _g("advanceSiege, 24 waves", g);
    }
}
