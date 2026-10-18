// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Base} from "./Base.t.sol";
import {GameBase} from "../src/game/GameBase.sol";
import {GameStorage} from "../src/game/GameStorage.sol";
import {EconomyModule} from "../src/game/EconomyModule.sol";
import {CitadelGame} from "../src/game/CitadelGame.sol";
import {Hex} from "../src/lib/Hex.sol";
import {Traits} from "../src/lib/Traits.sol";

contract EconomyTest is Base {
    // ------------------------------------------------------------ hex / routing

    function test_hexDistance() public pure {
        assertEq(Hex.distance(0, 0, 1, -1), 1);
        assertEq(Hex.distance(0, 0, 1, 1), 2);
        assertEq(Hex.distance(2, -5, -1, 4), 9);
        assertTrue(Hex.key(0, 1, -1) != Hex.key(1, 1, -1));
    }

    function test_batchedViews() public {
        _lite(alice, 0, 4, 4, 0);
        _lite(bob, 1, -4, 4, 1);
        uint256[] memory ids = new uint256[](3);
        (ids[0], ids[1], ids[2]) = (0, 1, 2);
        GameStorage.Citadel[] memory cs = view_.citadelsOf(ids);
        assertTrue(cs[0].lit && cs[1].lit && !cs[2].lit);
        assertEq(cs[1].owner, bob);
    }

    function test_unknownSelectorReverts() public {
        (bool ok,) = address(d.game).call(abi.encodeWithSignature("nope()"));
        assertFalse(ok);
    }

    function test_onlyOwnerInstalls() public {
        vm.expectRevert();
        d.game.install(d.economy);
    }

    // ------------------------------------------------------------ lite

    function test_liteRules() public {
        vm.startPrank(alice);
        vm.expectRevert(GameBase.OffGrid.selector);
        eco.lite(0, 0, 13, 0, 0, 3, none);
        vm.expectRevert(GameBase.AOClosed.selector);
        eco.lite(0, 1, 0, 0, 0, 3, none);
        vm.expectRevert(GameBase.BadFaction.selector);
        eco.lite(0, 0, 0, 0, 4, 3, none);
        vm.stopPrank();

        _lite(alice, 0, 5, 0, 0);
        vm.prank(bob);
        vm.expectRevert(GameBase.TileOccupied.selector);
        eco.lite(1, 0, 5, 0, 0, 0, none);

        vm.prank(bob);
        vm.expectRevert();
        eco.lite(0, 0, 6, 0, 0, 0, none); // not bob's
    }

    function test_unliteReturnsEverythingAfterClaimWindow() public {
        uint256 p = _pilot(alice, Traits.SUBJ_SIF_COMMANDER, 0);
        uint256[] memory ps = new uint256[](1);
        ps[0] = p;
        vm.prank(alice);
        eco.lite(0, 0, 4, 4, 0, 3, ps);
        assertEq(d.pilot.ownerOf(p), address(d.game));
        assertEq(view_.controllerOfPilot(p), alice);
        skip(7 days);
        uint256 vault = view_.vaultOf(0);
        uint256 before = d.drakma.balanceOf(alice);
        vm.prank(alice);
        eco.unlite(0);
        assertEq(d.citadel.ownerOf(0), alice);
        assertEq(d.pilot.ownerOf(p), alice);
        assertEq(d.drakma.balanceOf(alice) - before, vault);
        assertEq(view_.walletLevel(alice), 0);
    }

    // ------------------------------------------------------------ mining

    function test_miningMatchesExordiumRates() public {
        _lite(alice, 0, 4, 4, 0); // RELIK on a 1x tile
        _lite(bob, 1, -4, 4, 0); // ELEKT on a 1x tile
        skip(1 days);
        assertEq(view_.vaultOf(0), 64_000 ether);
        assertEq(view_.vaultOf(1), 8_000 ether);
    }

    function test_hotspotAndMines() public {
        _lite(bob, 1, 0, 0, 0); // center: 1.25x
        assertEq(view_.miningRate(1), 10_000 ether);
        _buildTo(bob, 1, B_MINE, 1);
        assertEq(view_.miningRate(1), 11_000 ether); // +10% per mine level
    }

    function test_claimCooldown() public {
        _lite(bob, 1, 4, 4, 0);
        skip(1 days);
        vm.prank(bob);
        vm.expectRevert();
        eco.claim(1);
        skip(6 days);
        uint256 before = d.drakma.balanceOf(bob);
        vm.prank(bob);
        eco.claim(1);
        assertEq(d.drakma.balanceOf(bob) - before, 56_000 ether);
    }

    // ------------------------------------------------------------ buildings

    function test_buildTakesTimeAndCosts() public {
        _lite(bob, 1, 4, 4, 0);
        (uint256 cost, uint256 time) = view_.buildCost(B_ACADEMY, 1);
        assertEq(cost, 2_000 ether);
        assertEq(time, 20 minutes);
        uint256 before = d.drakma.balanceOf(bob);
        vm.prank(bob);
        eco.build(1, B_ACADEMY);
        assertEq(before - d.drakma.balanceOf(bob), cost);
        vm.prank(bob);
        vm.expectRevert(EconomyModule.Busy.selector);
        eco.build(1, B_MINE);
        skip(time);
        vm.prank(bob);
        eco.build(1, B_MINE); // settles the academy first
        assertEq(view_.citadel(1).levels[B_ACADEMY], 1);
    }

    function test_buildingsCappedByCitadelLevel() public {
        _lite(bob, 1, 4, 4, 0);
        _buildTo(bob, 1, B_MINE, 1);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(EconomyModule.NeedsCitadelLevel.selector, 2));
        eco.build(1, B_MINE);
        _buildTo(bob, 1, B_CITADEL, 2);
        _buildTo(bob, 1, B_MINE, 2);
        assertEq(view_.citadel(1).levels[B_MINE], 2);
    }

    function test_hurryCostsDoubleTheRemainingShare() public {
        _lite(bob, 1, 4, 4, 0);
        vm.prank(bob);
        eco.build(1, B_CITADEL); // 20k, 2h
        skip(1 hours);
        uint256 before = d.drakma.balanceOf(bob);
        vm.prank(bob);
        eco.hurryBuild(1);
        assertEq(before - d.drakma.balanceOf(bob), 20_000 ether); // half remaining x 2
        assertEq(view_.citadel(1).levels[B_CITADEL], 1);
    }

    function test_levelsTravelWithTheCitadel() public {
        _lite(bob, 1, 4, 4, 0);
        _buildTo(bob, 1, B_CITADEL, 3);
        _buildTo(bob, 1, B_MINE, 2);
        skip(7 days);
        vm.prank(bob);
        eco.unlite(1);
        assertEq(d.game.walletScore(bob), 0);
        // sold on the secondary market, lit again by its new owner: the upgrades come with it
        vm.prank(bob);
        d.citadel.transferFrom(bob, carol, 1);
        _lite(carol, 1, -8, 0, 2);
        assertEq(view_.citadel(1).levels[B_CITADEL], 3);
        assertEq(view_.citadel(1).levels[B_MINE], 2);
        assertEq(d.game.walletScore(carol), 50 + 9 + 4);
    }

    function test_walletScoreGrowsNonLinearly() public {
        _lite(bob, 1, 4, 4, 0);
        assertEq(d.game.walletScore(bob), 50);
        _buildTo(bob, 1, B_CITADEL, 3);
        assertEq(d.game.walletScore(bob), 59);
        assertEq(view_.walletLevel(bob), 7);
    }

    // ------------------------------------------------------------ training

    function test_trainingNeedsAcademy() public {
        _lite(bob, 1, 4, 4, 0);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(EconomyModule.NeedsAcademy.selector, 1));
        eco.train(1, SIF, 1);
        _buildTo(bob, 1, B_ACADEMY, 1);
        vm.prank(bob);
        eco.train(1, SIF, 10);
        skip(5 minutes * 4);
        assertEq(view_.garrisonOf(1)[SIF], 4);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(EconomyModule.NeedsAcademy.selector, 2));
        eco.train(1, THROT, 1);
    }

    function test_dalaaNeedsAtomicEngine() public {
        _lite(bob, 1, 4, 4, 0);
        _buildTo(bob, 1, B_ACADEMY, 1);
        vm.prank(bob);
        vm.expectRevert(EconomyModule.NeedsTech.selector);
        eco.train(1, DALAA, 1);
    }

    function test_academyLevelsSpeedTraining() public {
        _lite(bob, 1, 4, 4, 0);
        _buildTo(bob, 1, B_CITADEL, 3);
        _buildTo(bob, 1, B_ACADEMY, 3);
        vm.prank(bob);
        eco.train(1, SIF, 1);
        // 5 min / 1.10
        assertEq(view_.trainingOf(1)[SIF].unitSecs, 272);
    }

    // ------------------------------------------------------------ generations

    function test_colonizeNeedsFactionGrid() public {
        _lite(alice, 0, 0, 0, 2);
        uint256 p = _pilot(alice, 0, 0);
        vm.startPrank(alice);
        vm.expectRevert(EconomyModule.NotFactionGrid.selector);
        eco.colonize(p, 0, 6, 0, 2);
        vm.expectRevert(EconomyModule.NotFactionGrid.selector);
        eco.colonize(p, 0, 2, 0, 1); // wrong faction
        uint256 id = eco.colonize(p, 0, 2, 0, 2);
        vm.stopPrank();
        assertEq(id, 1024);
        GameStorage.Citadel memory c = view_.citadel(id);
        assertEq(c.generation, 1);
        assertEq(c.owner, alice);
        assertEq(view_.pilotsOf(id)[0], p);
        // GEN1 ELEKT: 4000 x 2 / 10, on a 1.15x tile, +20% from its HERMETIC STRACHT PILOT on a hotspot
        assertEq(view_.miningRate(id), 1_104 ether);
    }

    function test_mintPilotWithFleetPoints() public {
        _lite(alice, 0, 5, 0, 0);
        _lite(bob, 1, 6, 0, 1);
        _army(bob, 1, SIF, 2_000);
        _army(alice, 0, SIF, 4_000);
        vm.prank(alice);
        war.raid(0, 1, _units(4_000, 0, 0, 0)); // wipes bob's 2000 SIF = 40k DK of fleet
        assertEq(d.game.fleetPoints(0), 40_000);
        assertEq(view_.pilotMintCost(0), 10_000);
        vm.prank(alice);
        uint256 p = eco.mintPilot(0);
        assertEq(d.pilot.traitsOf(p).generation, 1);
        assertEq(view_.pilotMintCost(0), 20_000);
        assertEq(d.game.fleetPoints(0), 30_000);
    }

    // ------------------------------------------------------------ AOs

    function test_isolatedAOCannotBeReached() public {
        vm.prank(admin);
        view_.setAOState(1, GameStorage.AOState.Isolated);
        _lite(alice, 0, 0, 0, 0);
        vm.prank(bob);
        eco.lite(1, 1, 0, 0, 1, 0, none);
        _army(alice, 0, SIF, 10);
        vm.prank(alice);
        vm.expectRevert(GameBase.Unreachable.selector);
        war.raid(0, 1, _units(10, 0, 0, 0));

        vm.prank(admin);
        view_.setAOState(1, GameStorage.AOState.Connected);
        vm.prank(admin);
        view_.setAOState(0, GameStorage.AOState.Connected);
        vm.prank(alice);
        uint256 m = war.raid(0, 1, _units(10, 0, 0, 0));
        assertEq(view_.march(m).arriveAt, block.timestamp + 12 * 30 minutes); // 0 tiles + 12 AO gap
    }

    function test_distortionDoesNotCrossIsolatedAOs() public {
        vm.prank(admin);
        view_.setAOState(1, GameStorage.AOState.Isolated);
        _lite(alice, 0, 0, 0, 0);
        vm.prank(bob);
        eco.lite(1, 1, 0, 0, 1, 0, none);
        _army(alice, 0, SIF, 10);
        GameStorage.Config memory c = _cfg();
        c.distortion = true;
        vm.prank(admin);
        view_.setConfig(c);
        vm.prank(alice);
        vm.expectRevert(GameBase.Unreachable.selector);
        war.raid(0, 1, _units(10, 0, 0, 0));
    }

    // ------------------------------------------------------------ MENTAT

    function test_relikMentatBoostsProduction() public {
        _lite(alice, 0, 4, 4, 0);
        uint256 before = view_.miningRate(0);
        vm.prank(alice);
        uint256 m = d.techTree.claimRelikMentat(0);
        vm.prank(alice);
        vm.expectRevert();
        d.techTree.claimRelikMentat(0);
        vm.prank(alice);
        eco.attachMentat(0, m);
        assertEq(view_.miningRate(0), before * 11 / 10);
        assertGt(view_.statsOf(0).defBps, 0);
    }
}
