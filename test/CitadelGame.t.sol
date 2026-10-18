// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CitadelGame} from "../src/CitadelGame.sol";
import {CitadelNFT} from "../src/CitadelNFT.sol";
import {PilotNFT} from "../src/PilotNFT.sol";
import {Drakma} from "../src/Drakma.sol";
import {TestnetFaucet} from "../src/TestnetFaucet.sol";
import {IDrakma} from "../src/interfaces/IGameAssets.sol";
import {Hex} from "../src/lib/Hex.sol";
import {Traits} from "../src/lib/Traits.sol";

contract CitadelGameTest is Test {
    Drakma dk;
    CitadelNFT cit;
    PilotNFT pil;
    CitadelGame game;
    TestnetFaucet faucet;

    address admin = makeAddr("admin");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address keeper = makeAddr("keeper");

    uint256[] none;

    function setUp() public {
        vm.startPrank(admin);
        dk = new Drakma(admin);
        cit = new CitadelNFT(admin, "");
        pil = new PilotNFT(admin, IDrakma(address(dk)));
        game = new CitadelGame(admin, address(cit), address(pil), IDrakma(address(dk)), 12);
        faucet = new TestnetFaucet(admin, cit, pil, dk);

        dk.grantRole(dk.MINTER_ROLE(), address(game));
        dk.grantRole(dk.BURNER_ROLE(), address(game));
        dk.grantRole(dk.BURNER_ROLE(), address(pil));
        dk.grantRole(dk.MINTER_ROLE(), address(faucet));
        cit.grantRole(cit.MINTER_ROLE(), address(faucet));
        pil.grantRole(pil.MINTER_ROLE(), address(faucet));

        // ids 0..3: ELEKT, DAG SGIATH shield, HAG GOTOR engine, RRAKATAKHT FUROR weapon (weakest everything)
        cit.setTraits(0, hex"000300000000000300000000000300000000000300000000");
        vm.stopPrank();

        vm.prank(admin);
        faucet.grantCitadel(alice, 0);
        vm.prank(admin);
        faucet.grantCitadel(bob, 1);
        vm.startPrank(admin);
        faucet.grantDrakma(alice, 5_000_000 ether);
        faucet.grantDrakma(bob, 5_000_000 ether);
        vm.stopPrank();

        vm.prank(alice);
        cit.setApprovalForAll(address(game), true);
        vm.prank(bob);
        cit.setApprovalForAll(address(game), true);
    }

    function _lite(address who, uint256 id, int16 q, int16 r) internal {
        vm.prank(who);
        game.lite(id, q, r, 0, none);
    }

    function _trainNow(address who, uint256 id, uint8 t, uint64 n) internal {
        vm.prank(who);
        game.train(id, t, n);
        (,,,, uint32 trainSecs,) = game.fleetTypes(t);
        skip(uint256(trainSecs) * n);
    }

    // ------------------------------------------------------------ hex

    function test_hexDistance() public pure {
        assertEq(Hex.distance(0, 0, 0, 0), 0);
        assertEq(Hex.distance(0, 0, 1, 0), 1);
        assertEq(Hex.distance(0, 0, 0, 1), 1);
        assertEq(Hex.distance(0, 0, 1, -1), 1);
        assertEq(Hex.distance(0, 0, 1, 1), 2);
        assertEq(Hex.distance(-3, 0, 3, 0), 6);
        assertEq(Hex.distance(2, -5, -1, 4), 9);
    }

    function test_hexKeyUnique() public pure {
        assertTrue(Hex.key(1, -1) != Hex.key(-1, 1));
        assertTrue(Hex.key(0, -1) != Hex.key(-1, 0));
    }

    // ------------------------------------------------------------ lite / mining

    function test_liteRejectsOffGridAndOccupied() public {
        vm.prank(alice);
        vm.expectRevert(CitadelGame.OffGrid.selector);
        game.lite(0, 13, 0, 0, none);

        _lite(alice, 0, 5, 0);
        vm.prank(bob);
        vm.expectRevert(CitadelGame.TileOccupied.selector);
        game.lite(1, 5, 0, 0, none);
    }

    function test_liteRequiresOwnership() public {
        vm.prank(bob);
        vm.expectRevert();
        game.lite(0, 5, 0, 0, none);
    }

    function test_miningMatchesExordiumRate() public {
        _lite(alice, 0, 8, 0); // plain 1x tile
        skip(1 days);
        // ELEKT: 4000 * 2 = 8000 DK/day, matching the EXORDIUM rate
        assertEq(game.vaultOf(0), 8_000 ether);
    }

    function test_hotspotMinesMore() public {
        _lite(alice, 0, 0, 0); // center: 1.25x
        skip(1 days);
        assertEq(game.vaultOf(0), 10_000 ether);
    }

    function test_claimCooldown() public {
        _lite(alice, 0, 8, 0);
        skip(1 days);
        vm.prank(alice);
        vm.expectRevert();
        game.claim(0);

        skip(6 days);
        uint256 before = dk.balanceOf(alice);
        vm.prank(alice);
        game.claim(0);
        assertEq(dk.balanceOf(alice) - before, 56_000 ether);
        assertEq(game.vaultOf(0), 0);
    }

    // ------------------------------------------------------------ training

    function test_trainingCostAndTime() public {
        _lite(alice, 0, 8, 0);
        uint256 before = dk.balanceOf(alice);
        vm.prank(alice);
        game.train(0, 0, 10);
        assertEq(before - dk.balanceOf(alice), 200 ether);

        assertEq(game.garrisonOf(0)[0], 0);
        skip(5 minutes * 4);
        assertEq(game.garrisonOf(0)[0], 4);
        skip(5 minutes * 100);
        assertEq(game.garrisonOf(0)[0], 10);
    }

    function test_trainingQueuesBehindCurrentBatch() public {
        _lite(alice, 0, 8, 0);
        vm.prank(alice);
        game.train(0, 0, 2);
        skip(5 minutes);
        vm.prank(alice);
        game.train(0, 0, 2);
        assertEq(game.garrisonOf(0)[0], 1);
        skip(15 minutes);
        assertEq(game.garrisonOf(0)[0], 4);
    }

    // ------------------------------------------------------------ raids

    function test_adjacentRaidIsInstantAndLoots() public {
        _lite(alice, 0, 5, 0);
        _lite(bob, 1, 6, 0); // adjacent
        _trainNow(alice, 0, 0, 100);
        skip(1 days);
        uint256 bobVault = game.vaultOf(1);

        vm.prank(alice);
        uint256 marchId = game.raid(0, 1, [uint64(100), 0, 0]);
        assertEq(marchId, 0);

        // undefended: no losses, 100 SIF carry 40 DK each = 4000 DK
        assertEq(game.garrisonOf(0)[0], 100);
        assertEq(game.vaultOf(1), bobVault - 4_000 ether);
        assertGt(game.vaultOf(0), 4_000 ether);
    }

    function test_defenderWinsWipesAttacker() public {
        _lite(alice, 0, 5, 0);
        _lite(bob, 1, 6, 0);
        _trainNow(alice, 0, 0, 10); // 10 SIF: 100 OP base
        _trainNow(bob, 1, 1, 10); // 10 MHRUDVOG: 400 DP base, +50% fort +shield

        vm.prank(alice);
        game.raid(0, 1, [uint64(10), 0, 0]);
        assertEq(game.garrisonOf(0)[0], 0);
        uint64 bobLeft = game.garrisonOf(1)[1];
        assertGt(bobLeft, 0);
        assertLt(bobLeft, 10);
    }

    function test_attackerWinsTakesPartialLosses() public {
        _lite(alice, 0, 5, 0);
        _lite(bob, 1, 6, 0);
        _trainNow(alice, 0, 2, 2); // 2 DREBENTRAAKHT: 1000 OP base
        _trainNow(bob, 1, 0, 10); // 10 SIF: 50 DP base

        vm.prank(alice);
        game.raid(0, 1, [uint64(0), 0, 2]);
        assertEq(game.garrisonOf(1)[0], 0);
        // loss ratio is small but rounds up to 1 unit
        assertEq(game.garrisonOf(0)[2], 1);
        assertGt(game.citadel(0).fleetPoints, 0);
    }

    function test_distantRaidTravelsResolvesAndReturns() public {
        _lite(alice, 0, -4, 0);
        _lite(bob, 1, 4, 0); // distance 8
        _trainNow(alice, 0, 0, 50);
        skip(1 days);

        vm.prank(alice);
        uint256 marchId = game.raid(0, 1, [uint64(50), 0, 0]);
        assertEq(game.march(marchId).arriveAt, block.timestamp + 8 * 30 minutes);

        vm.expectRevert();
        game.resolveRaid(marchId);

        // bob can't run away from an incoming raid
        vm.prank(bob);
        vm.expectRevert(CitadelGame.Engaged.selector);
        game.unlite(1);

        skip(4 hours);
        vm.prank(keeper);
        game.resolveRaid(marchId);
        // 50 SIF * 40 = 2000 DK loot, 10% to the keeper
        assertEq(dk.balanceOf(keeper), 200 ether);

        uint256 returnId = marchId + 1;
        CitadelGame.March memory ret = game.march(returnId);
        assertEq(uint8(ret.kind), uint8(CitadelGame.MarchKind.Return));
        assertEq(ret.loot, 1_800 ether);

        skip(4 hours);
        uint256 vaultBefore = game.vaultOf(0);
        game.completeMarch(returnId);
        assertEq(game.garrisonOf(0)[0], 50);
        assertEq(game.vaultOf(0), vaultBefore + 1_800 ether);
        assertEq(game.citadel(0).outgoing, 0);
    }

    function test_unresolvedRaidDefects() public {
        _lite(alice, 0, -4, 0);
        _lite(bob, 1, 4, 0);
        _trainNow(alice, 0, 0, 50);

        vm.prank(alice);
        uint256 marchId = game.raid(0, 1, [uint64(50), 0, 0]);
        skip(4 hours + 24 hours + 1);
        game.resolveRaid(marchId);
        assertEq(game.garrisonOf(1)[0], 50);
        assertEq(game.citadel(0).outgoing, 0);
        assertEq(game.citadel(1).incoming, 0);
    }

    function test_reinforcementsDefend() public {
        address carol = makeAddr("carol");
        vm.prank(admin);
        faucet.grantCitadel(carol, 2);
        vm.prank(admin);
        faucet.grantDrakma(carol, 5_000_000 ether);
        vm.prank(carol);
        cit.setApprovalForAll(address(game), true);

        _lite(alice, 0, -6, 0);
        _lite(bob, 1, 4, 0);
        _lite(carol, 2, 5, 0); // bob's neighbour
        _trainNow(alice, 0, 0, 100);
        _trainNow(carol, 2, 1, 50);

        vm.prank(alice);
        uint256 raidId = game.raid(0, 1, [uint64(100), 0, 0]); // 10 tiles away, 5h
        vm.prank(carol);
        game.reinforce(2, 1, [uint64(0), 50, 0]); // adjacent: instant
        assertEq(game.garrisonOf(1)[1], 50);

        skip(5 hours);
        game.resolveRaid(raidId);
        assertEq(game.garrisonOf(0)[0], 0, "attacker wiped");
        assertEq(game.citadel(0).outgoing, 0);
    }

    function test_globalDistortionMakesEveryRaidInstant() public {
        _lite(alice, 0, -6, 0);
        _lite(bob, 1, 6, 0);
        _trainNow(alice, 0, 0, 10);

        CitadelGame.Config memory c;
        (c.baseDkPerDay, c.claimInterval, c.defectionWindow, c.resolverFeeBps, c.fortificationBps, c.maxPilots,) =
            game.config();
        c.distortion = true;
        vm.prank(admin);
        game.setConfig(c);

        vm.prank(alice);
        assertEq(game.raid(0, 1, [uint64(10), 0, 0]), 0);
    }

    // ------------------------------------------------------------ pilots

    function test_pilotsBoostAndReturnOnUnlite() public {
        vm.prank(admin);
        uint256 p = faucet.grantPilot(
            alice,
            Traits.PilotTraits({generation: 0, subjugation: 2, kult: 0, level: 0, sovereign: false, death: false})
        );
        vm.prank(alice);
        pil.setApprovalForAll(address(game), true);

        uint256[] memory ps = new uint256[](1);
        ps[0] = p;
        vm.prank(alice);
        game.lite(0, 8, 0, 0, ps);
        assertEq(pil.ownerOf(p), address(game));

        skip(1 days);
        // DREDGE NOBILITY level 0: +20% mining
        assertEq(game.vaultOf(0), 9_600 ether);

        skip(7 days);
        vm.prank(alice);
        game.unlite(0);
        assertEq(pil.ownerOf(p), alice);
        assertEq(cit.ownerOf(0), alice);
    }

    function test_pilotUplevelCost() public {
        vm.prank(admin);
        uint256 p = faucet.grantPilot(
            alice,
            Traits.PilotTraits({generation: 0, subjugation: 0, kult: 0, level: 0, sovereign: false, death: false})
        );
        uint256 before = dk.balanceOf(alice);
        vm.startPrank(alice);
        pil.uplevel(p);
        pil.uplevel(p);
        vm.stopPrank();
        assertEq(before - dk.balanceOf(alice), 300_000 ether);
        assertEq(pil.traitsOf(p).level, 2);
    }

    function test_unliteForfeitsVaultBeforeClaimWindow() public {
        _lite(alice, 0, 8, 0);
        skip(1 days);
        uint256 before = dk.balanceOf(alice);
        vm.prank(alice);
        game.unlite(0);
        assertEq(dk.balanceOf(alice), before);
    }

    // ------------------------------------------------------------ faucet

    function test_faucetDripOnce() public {
        address dave = makeAddr("dave");
        vm.prank(dave);
        faucet.drip();
        assertEq(cit.balanceOf(dave), 2);
        assertEq(pil.balanceOf(dave), 2);
        assertEq(dk.balanceOf(dave), 5_000_000 ether);
        // ids 0 and 1 were granted in setUp, so the drip skipped to 2 and 3
        assertEq(cit.ownerOf(2), dave);
        assertEq(cit.ownerOf(3), dave);

        vm.prank(dave);
        vm.expectRevert(TestnetFaucet.AlreadyDripped.selector);
        faucet.drip();
    }

    // ------------------------------------------------------------ invariants of the battle math

    function testFuzz_raidConservesOrDestroysUnits(uint64 att, uint64 def) public {
        att = uint64(bound(att, 1, 500));
        def = uint64(bound(def, 0, 500));
        _lite(alice, 0, 5, 0);
        _lite(bob, 1, 6, 0);
        _trainNow(alice, 0, 0, att);
        if (def > 0) _trainNow(bob, 1, 1, def);

        vm.prank(alice);
        game.raid(0, 1, [att, 0, 0]);
        uint64 a = game.garrisonOf(0)[0];
        uint64 d = game.garrisonOf(1)[1];
        assertLe(a, att);
        assertLe(d, def);
        assertTrue(a == 0 || d == 0, "exactly one side is wiped out");
    }
}
