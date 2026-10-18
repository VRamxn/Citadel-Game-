// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Base} from "./Base.t.sol";
import {GameStorage} from "../src/game/GameStorage.sol";
import {BattleBase} from "../src/game/BattleBase.sol";
import {Traits} from "../src/lib/Traits.sol";

contract WarTest is Base {
    function setUp() public override {
        super.setUp();
        _lite(alice, 0, 5, 0, 0);
        _lite(bob, 1, 6, 0, 1); // adjacent to alice
        _lite(carol, 2, -6, 0, 2); // 11 tiles from alice
    }

    // ------------------------------------------------------------ raids

    function test_adjacentRaidIsInstant() public {
        _army(alice, 0, SIF, 100);
        skip(1 days);
        uint256 bobVault = view_.vaultOf(1);
        vm.prank(alice);
        assertEq(war.raid(0, 1, _units(100, 0, 0, 0)), 0);
        // bob has only his structure (100 DP): alice wins, loses a few, carries up to 40 DK each
        uint64 left = view_.garrisonOf(0)[SIF];
        assertLt(left, 100);
        assertGt(left, 90);
        assertEq(view_.vaultOf(1), bobVault - uint256(left) * 40 ether);
    }

    function test_structureRepelsTinyRaids() public {
        _army(alice, 0, SIF, 5); // 50 OP x 1.1 < 100 DP structure
        vm.prank(alice);
        war.raid(0, 1, _units(5, 0, 0, 0));
        assertEq(view_.garrisonOf(0)[SIF], 0);
    }

    function test_fortifiedDefendersWin() public {
        _army(alice, 0, SIF, 30);
        _army(bob, 1, THROT, 20); // 800 DP x (1 + 50% fort + 25% throt + shield) >> 330 OP
        vm.prank(alice);
        war.raid(0, 1, _units(30, 0, 0, 0));
        assertEq(view_.garrisonOf(0)[SIF], 0);
        assertGt(view_.garrisonOf(1)[THROT], 15);
        assertGt(d.game.fleetPoints(1), 0);
    }

    function test_distantRaidTravelsAndPaysResolver() public {
        _army(alice, 0, SIF, 200);
        skip(2 days);
        vm.prank(alice);
        uint256 m = war.raid(0, 2, _units(200, 0, 0, 0));
        // alice's PROPULSION RELIK has researched SUBLIGHT PROPULSION by now: +5% speed
        assertEq(view_.statsOf(0).speedBps[SIF], 500);
        assertEq(view_.march(m).arriveAt, block.timestamp + 11 * uint256(1714));

        vm.expectRevert();
        war.resolve(m);
        vm.prank(carol);
        vm.expectRevert(); // can't run from an incoming raid
        eco.unlite(2);

        skip(11 * 30 minutes);
        vm.prank(keeper);
        war.resolve(m);
        assertGt(d.drakma.balanceOf(keeper), 0);
        GameStorage.March memory ret = view_.march(m + 1);
        assertEq(uint8(ret.kind), uint8(GameStorage.MarchKind.Return));
        assertGt(ret.loot, 0);

        skip(11 * 30 minutes);
        uint256 vault = view_.vaultOf(0);
        war.resolve(m + 1);
        assertGt(view_.vaultOf(0), vault + ret.loot - 1);
        assertEq(view_.citadel(0).outgoing, 0);
    }

    function test_unresolvedRaidDefects() public {
        _army(alice, 0, SIF, 50);
        vm.prank(alice);
        uint256 m = war.raid(0, 2, _units(50, 0, 0, 0));
        skip(11 * 30 minutes + 24 hours + 1);
        war.resolve(m);
        assertEq(view_.garrisonOf(2)[SIF], 50);
        assertEq(view_.citadel(0).outgoing, 0);
        assertEq(view_.citadel(2).incoming, 0);
    }

    function test_reinforcementsArriveAndDefend() public {
        _army(alice, 0, SIF, 300);
        _army(bob, 1, THROT, 100);
        vm.prank(alice);
        uint256 raidId = war.raid(0, 2, _units(300, 0, 0, 0)); // 11 tiles
        vm.prank(bob);
        uint256 rein = war.reinforce(1, 2, _units(0, 100, 0, 0)); // 12 tiles at 45 min
        skip(11 * 30 minutes);
        vm.expectRevert(); // reinforcements still on the way
        war.resolve(rein);
        war.resolve(raidId); // carol undefended: alice wins
        skip(12 * 45 minutes);
        war.resolve(rein);
        assertEq(view_.garrisonOf(2)[THROT], 100);
    }

    function test_scoutReport() public {
        // grant DALAA via config: make them need no tech by testing the scout path through fleet type 3
        vm.prank(admin);
        view_.setFleetType(DALAA, GameStorage.FleetType(2, 2, 5, 10 minutes, 2 minutes, 1, 8 ether));
        // DALAA still needs ATOMIC ENGINE; research it with alice's PROPULSION RELIK
        skip(3 days);
        assertTrue(view_.statsOf(0).dalaa);
        _army(alice, 0, DALAA, 10);
        vm.recordLogs();
        vm.prank(alice);
        war.scout(0, 1, _units(0, 0, 0, 10)); // adjacent: instant
        assertEq(view_.garrisonOf(0)[DALAA], 10); // no enemy scouts: no losses
        vm.prank(alice);
        vm.expectRevert(BattleBase.ScoutsOnly.selector);
        war.scout(0, 1, _units(1, 0, 0, 0));
    }

    function test_returningFleetLostIfHomeLeveled() public {
        // covered in SiegeTest; here: a raid on a target that left the grid comes straight home
        _army(alice, 0, SIF, 20);
        vm.prank(alice);
        uint256 m = war.raid(0, 2, _units(20, 0, 0, 0));
        skip(11 * 30 minutes);
        war.resolve(m);
        assertEq(view_.citadel(2).incoming, 0);
    }

    function test_noFleetPointsForFightingYourself() public {
        _give(alice, 5);
        _lite(alice, 5, 4, 0, 0); // adjacent to alice's CITADEL 0
        _army(alice, 0, SIF, 200);
        _army(alice, 5, SIF, 50);
        vm.prank(alice);
        war.raid(0, 5, _units(200, 0, 0, 0));
        assertEq(view_.garrisonOf(5)[SIF], 0);
        assertEq(d.game.fleetPoints(0), 0);
    }

    function testFuzz_raidOneSideWiped(uint64 att, uint64 def) public {
        att = uint64(bound(att, 1, 400));
        def = uint64(bound(def, 0, 200));
        _army(alice, 0, SIF, att);
        if (def > 0) _army(bob, 1, THROT, def);
        vm.prank(alice);
        war.raid(0, 1, _units(att, 0, 0, 0));
        uint64 a = view_.garrisonOf(0)[SIF];
        uint64 b = view_.garrisonOf(1)[THROT];
        assertLe(a, att);
        assertLe(b, def);
        assertTrue(a == 0 || b == 0, "exactly one side is wiped out");
    }
}
