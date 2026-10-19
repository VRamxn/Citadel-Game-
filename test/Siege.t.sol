// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Base} from "./Base.t.sol";
import {GameStorage} from "../src/game/GameStorage.sol";
import {BattleBase} from "../src/game/BattleBase.sol";
import {Traits} from "../src/lib/Traits.sol";

contract SiegeTest is Base {
    uint256 pilotA;

    function setUp() public override {
        super.setUp();
        _lite(alice, 0, 5, 0, 0);
        _lite(bob, 1, 6, 0, 1); // adjacent to alice
        pilotA = _pilot(alice, Traits.SUBJ_SIF_COMMANDER, 0);
    }

    function _advanceAll(uint256 siegeId) internal {
        for (uint256 i; i < 10 && view_.siegeOf(siegeId).active; ++i) {
            skip(48 hours);
            sie.advanceSiege(siegeId, 200);
        }
    }

    function test_successfulSiegeCapturesTheTile() public {
        _buildTo(bob, 1, B_CITADEL, 1); // upgrades that the siege will wipe
        _army(alice, 0, SIF, 2_000);
        skip(1 days);
        vm.prank(alice);
        war.siege(0, 1, _units(2_000, 0, 0, 0), pilotA + 1);
        assertEq(d.game.siegeCount(), 1);
        assertEq(view_.citadel(1).besieged, 1);

        // can't finish faster than 48 waves
        skip(47 hours);
        sie.advanceSiege(1, 100);
        assertTrue(view_.siegeOf(1).active);
        assertLt(view_.siegeOf(1).progress, 10_000);

        uint256 aliceDk = d.drakma.balanceOf(alice);
        uint256 keeperDk = d.drakma.balanceOf(address(this));
        _advanceAll(1);
        assertGt(d.drakma.balanceOf(address(this)), keeperDk); // the wave bounty pays whoever fights them
        GameStorage.Siege memory g = view_.siegeOf(1);
        assertFalse(g.active);
        assertGe(g.waves, 48);

        // bob's GEN0 CITADEL is leveled and back in his wallet, its upgrades gone; alice got his vault
        assertEq(d.citadel.ownerOf(1), bob);
        assertEq(d.game.savedLevels(1, 0), 0);
        assertFalse(view_.citadel(1).lit);
        assertGt(d.drakma.balanceOf(alice), aliceDk);
        // alice's PILOT founded a GEN1 CITADEL on the tile, garrisoned by the survivors
        (bool occ, uint256 newId) = view_.citadelAt(0, 6, 0);
        assertTrue(occ);
        assertEq(newId, 1024);
        assertEq(view_.citadel(newId).owner, alice);
        assertEq(view_.citadel(newId).generation, 1);
        assertEq(view_.citadel(newId).faction, 0);
        assertEq(view_.pilotsOf(newId)[0], pilotA);
        assertGt(view_.garrisonOf(newId)[SIF], 1_500);
        assertEq(view_.citadel(0).outgoing, 0);
    }

    function test_failedSiegeGen0PilotRetreats() public {
        _army(alice, 0, SIF, 10); // 110 OP vs bob's 100 DP structure + 300 fortified THROT
        _army(bob, 1, THROT, 10);
        vm.prank(alice);
        war.siege(0, 1, _units(10, 0, 0, 0), pilotA + 1);
        skip(1 hours);
        sie.advanceSiege(1, 10);
        assertFalse(view_.siegeOf(1).active);
        assertEq(d.pilot.ownerOf(pilotA), alice);
        assertEq(view_.garrisonOf(0)[SIF], 0);
        assertEq(view_.citadel(1).besieged, 0);
    }

    function test_failedSiegeDestroysGen1Pilot() public {
        uint256 p1 = _pilot(alice, 0, 1);
        _army(alice, 0, SIF, 10);
        _army(bob, 1, THROT, 10);
        vm.prank(alice);
        war.siege(0, 1, _units(10, 0, 0, 0), p1 + 1);
        skip(1 hours);
        sie.advanceSiege(1, 10);
        vm.expectRevert();
        d.pilot.ownerOf(p1);
    }

    function test_siegeWithoutPilotOnlyLevels() public {
        _army(alice, 0, SIF, 2_000);
        vm.prank(alice);
        war.siege(0, 1, _units(2_000, 0, 0, 0), 0);
        _advanceAll(1);
        (bool occ,) = view_.citadelAt(0, 6, 0);
        assertFalse(occ);
        assertGt(view_.garrisonOf(0)[SIF], 1_500); // army came home
    }

    function test_sovereignCannotBeSieged() public {
        uint256 sov = _pilotT(
            carol, Traits.PilotTraits({generation: 0, subjugation: 0, kult: 0, level: 0, sovereign: true, death: false})
        );
        uint256[] memory ps = new uint256[](1);
        ps[0] = sov;
        vm.prank(carol);
        eco.lite(2, 0, 4, 0, 2, 1, ps); // adjacent to alice
        _army(alice, 0, SIF, 100);
        vm.prank(alice);
        vm.expectRevert(BattleBase.SovereignProtected.selector);
        war.siege(0, 2, _units(100, 0, 0, 0), 0);
    }

    function test_besiegedCannotReinforceOrLeave() public {
        _lite(carol, 2, 7, 0, 1);
        _army(bob, 1, SIF, 10);
        _army(alice, 0, SIF, 2_000);
        vm.prank(alice);
        war.siege(0, 1, _units(2_000, 0, 0, 0), 0);
        vm.startPrank(bob);
        vm.expectRevert(BattleBase.Besieged.selector);
        war.reinforce(1, 2, _units(10, 0, 0, 0));
        vm.expectRevert();
        eco.unlite(1);
        vm.stopPrank();
        // but bob's ally can reinforce him
        _army(carol, 2, THROT, 50);
        vm.prank(carol);
        war.reinforce(2, 1, _units(0, 50, 0, 0));
        assertEq(view_.garrisonOf(1)[THROT], 50);
    }

    function test_joinSiege() public {
        _lite(carol, 2, 4, 0, 0); // alice's ally, adjacent to alice but 2 from bob
        _army(alice, 0, SIF, 500);
        _army(carol, 2, SIF, 500);
        vm.prank(alice);
        war.siege(0, 1, _units(500, 0, 0, 0), 0);
        vm.prank(carol);
        uint256 m = war.joinSiege(1, 2, _units(500, 0, 0, 0));
        assertGt(m, 0);
        skip(2 * 30 minutes);
        war.resolve(m);
        assertEq(view_.siegeOf(1).units[SIF], 1_000);
    }

    function test_gen1CitadelLeveledIsDestroyed() public {
        _army(alice, 0, SIF, 2_000);
        vm.prank(alice);
        war.siege(0, 1, _units(2_000, 0, 0, 0), pilotA + 1);
        _advanceAll(1);
        uint256 gen1 = 1024;
        // bob takes it back without a PILOT
        _lite(bob, 1, 7, 0, 1);
        _army(bob, 1, DREB, 40);
        vm.prank(bob);
        war.siege(1, gen1, _units(0, 0, 40, 0), 0);
        _advanceAll(2);
        assertFalse(view_.siegeOf(2).active);
        vm.expectRevert();
        d.citadel.ownerOf(gen1);
        assertEq(d.pilot.ownerOf(pilotA), alice); // the PILOT inside goes home
    }

    function test_distantSiegeMarchesFirst() public {
        _lite(carol, 2, -6, 0, 2);
        _army(alice, 0, SIF, 100);
        vm.prank(alice);
        uint256 m = war.siege(0, 2, _units(100, 0, 0, 0), pilotA + 1);
        assertGt(m, 0);
        assertEq(d.game.siegeCount(), 0);
        skip(11 * 30 minutes);
        war.resolve(m);
        assertEq(d.game.siegeCount(), 1);
        assertEq(view_.siegeOf(1).pilot, pilotA + 1);
    }
}
