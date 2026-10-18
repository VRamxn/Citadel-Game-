// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Base} from "./Base.t.sol";
import {GameStorage} from "../src/game/GameStorage.sol";
import {Technocracy} from "../src/Technocracy.sol";
import {TechTree} from "../src/TechTree.sol";
import {Traits, Tech} from "../src/lib/Traits.sol";

contract TechTreeTest is Base {
    function test_researchNeedsAKeyRelik() public {
        _lite(bob, 1, 8, 0, 1); // ELEKT researching PRESERVATIVE for AUTONOMOUS ZONE, no key
        skip(10 days);
        (uint256 points,, uint256 keys, uint256 done) = d.techTree.pool(1, 0);
        assertEq(keys, 0);
        assertEq(points, 0);
        assertEq(done, 0);

        _give(alice, 4); // RELIK, PRESERVATIVE
        _lite(alice, 4, -8, 0, 1);
        skip(1 days);
        (points,, keys,) = d.techTree.pool(1, 0);
        assertEq(keys, 1);
        // bob 4000 x 2 x 2 (own tech) + relik 4000 x 16 x 2
        assertEq(points, 16_000 + 128_000);
        assertTrue(Tech.has(d.techTree.bits(1), Tech.TESLAPHORESIS));
    }

    function test_techUnlocksUniqueAbility() public {
        _give(alice, 4);
        _lite(alice, 4, -8, 0, 1);
        uint256 before = view_.statsOf(4).siegeDefBps;
        skip(5 days); // 640k points: 3 techs (cumulative 600k) => PRESERVATIONAL FIELD => DAG SGIATH unique
        assertTrue(Tech.has(d.techTree.bits(1), Tech.PRESERVATIONAL_FIELD));
        assertEq(view_.statsOf(4).siegeDefBps, before + 500);
    }

    function test_atomicEngineUnlocksDalaa() public {
        _lite(alice, 0, 8, 0, 0); // RELIK, PROPULSION
        _buildTo(alice, 0, B_ACADEMY, 1);
        skip(3 days); // 384k: SUBLIGHT + ATOMIC ENGINE
        vm.prank(alice);
        eco.train(0, DALAA, 5);
        skip(10 minutes);
        assertEq(view_.garrisonOf(0)[DALAA], 5);
    }

    function test_factionsResearchSeparately() public {
        _lite(alice, 0, 8, 0, 0);
        skip(3 days);
        assertGt(d.techTree.bits(0), 0);
        assertEq(d.techTree.bits(1), 0);
    }

    function test_branchMentat() public {
        _give(alice, 4);
        _lite(alice, 4, -8, 0, 1);
        vm.prank(alice);
        vm.expectRevert(TechTree.BranchIncomplete.selector);
        d.techTree.claimBranchMentat(0, 4);
        skip(25 days); // 7 techs: 2.8M points at 128k/day
        vm.prank(alice);
        uint256 m = d.techTree.claimBranchMentat(0, 4);
        assertEq(d.mentat.ownerOf(m), alice);
    }
}

contract TechnocracyTest is Base {
    Technocracy t;

    function setUp() public override {
        super.setUp();
        t = d.technocracy;
    }

    /// @dev A carried-over sovereign: an original PILOT whose traits say sovereign, seated at launch.
    function _born(address who) internal returns (uint256 id) {
        id = _pilotT(
            who, Traits.PilotTraits({generation: 0, subjugation: 0, kult: 0, level: 0, sovereign: true, death: false})
        );
        uint256[] memory ids = new uint256[](1);
        ids[0] = id;
        vm.prank(admin);
        t.seedSovereigns(ids, 0);
    }

    function test_carriedOverSovereignsAreSeatedOnce() public {
        uint256 a = _pilotT(
            alice, Traits.PilotTraits({generation: 0, subjugation: 0, kult: 3, level: 4, sovereign: true, death: false})
        );
        uint256 b = _pilotT(
            bob, Traits.PilotTraits({generation: 0, subjugation: 1, kult: 2, level: 0, sovereign: true, death: false})
        );
        uint256 plain = _pilot(carol, 0, 0);
        uint256[] memory ids = new uint256[](2);
        (ids[0], ids[1]) = (a, b);
        vm.prank(admin);
        t.seedSovereigns(ids, 1); // b bought its seat on mainnet
        assertEq(t.sovereignCount(), 2);
        assertEq(t.boughtSeats(), 1);
        assertEq(d.pilot.traitsOf(a).level, 4); // bought levels carried over
        vm.prank(admin);
        vm.expectRevert(Technocracy.AlreadyClaimed.selector);
        t.seedSovereigns(ids, 1);
        assertFalse(d.pilot.traitsOf(plain).sovereign);
    }

    function test_seedRejectsNonSovereigns() public {
        uint256 plain = _pilot(carol, 0, 0);
        uint256[] memory ids = new uint256[](1);
        ids[0] = plain;
        vm.prank(admin);
        vm.expectRevert(Technocracy.NotSovereign.selector);
        t.seedSovereigns(ids, 0);
    }

    function test_unbridgedSovereignCanStillBeOverthrown() public {
        // a carried-over sovereign that never crossed to L2 holds its seat; an insurgent can still take it
        vm.startPrank(admin);
        d.pilot.setTraits(500, abi.encodePacked(uint8(0), uint8(0), uint8(0), uint8(1), uint8(0)));
        uint256[] memory ids = new uint256[](1);
        ids[0] = 500;
        t.seedSovereigns(ids, 0);
        vm.stopPrank();
        uint256 c = _pilot(carol, 0, 0);
        vm.prank(carol);
        t.overthrow(500, c);
        assertTrue(d.pilot.traitsOf(c).sovereign);
        assertFalse(d.pilot.traitsOf(500).sovereign);
        vm.expectRevert(); // originals' seats are never vacated
        t.vacate(500);
    }

    function test_buySeatBribeAndOverthrow() public {
        uint256 p = _pilot(bob, 0, 0);
        vm.prank(bob);
        t.becomeSovereign(p);
        assertTrue(d.pilot.traitsOf(p).sovereign);
        // 25% of 4M, plus the 70% collective share since no other seat exists yet to receive it
        assertEq(d.drakma.balanceOf(treasury), 3_800_000 ether);

        vm.startPrank(bob);
        t.bribe(3, p);
        t.bribe(4, p);
        vm.stopPrank();
        uint256 copies = d.pilot.traitsOf(p).subjugation == Traits.SUBJ_POTENTATE_COERCION
            || d.pilot.traitsOf(p).subjugation == Traits.SUBJ_TECHNOCRAT_ARMAMENT
            ? 2
            : 1;
        assertEq(t.activeBribes(p), 2 * copies);
        assertEq(t.overthrowCost(p), 4_000_000 ether + 2 * copies * 1_000_000 ether);

        uint256 c = _pilot(carol, 0, 0);
        vm.prank(carol);
        t.overthrow(p, c);
        assertFalse(d.pilot.traitsOf(p).sovereign);
        assertTrue(d.pilot.traitsOf(c).sovereign);
        assertEq(t.sovereignCount(), 1);

        skip(91 days);
        assertEq(t.activeBribes(c), 0);
    }

    function test_collectiveShares() public {
        uint256 a = _born(alice);
        uint256 b = _pilot(bob, 0, 0);
        vm.prank(bob);
        t.becomeSovereign(b); // 70% of 4M goes to alice's seat
        assertEq(t.pendingCollective(a), 2_800_000 ether);
        vm.prank(alice);
        vm.expectRevert();
        t.claimCollective(a);
        skip(30 days);
        uint256 before = d.drakma.balanceOf(alice);
        vm.prank(alice);
        t.claimCollective(a);
        assertEq(d.drakma.balanceOf(alice) - before, 2_800_000 ether);
    }

    function test_kultShares() public {
        uint256 a = _born(alice);
        uint256 b = _pilot(bob, 0, 0);
        t.registerKult(b);
        uint8 k = d.pilot.traitsOf(b).kult;
        vm.prank(alice);
        t.bribe(k, a);
        assertEq(t.pendingKult(b), 60_000 ether);
        uint256 before = d.drakma.balanceOf(bob);
        vm.prank(bob);
        t.claimKult(b);
        assertEq(d.drakma.balanceOf(bob) - before, 60_000 ether);
    }

    function test_councilGovernsTheGame() public {
        uint256 a = _born(alice);
        vm.prank(admin);
        d.game.transferOwnership(address(d.council));
        vm.prank(alice);
        uint256 id =
            d.council.propose(a, address(d.game), abi.encodeWithSignature("acceptOwnership()"), "take the levers");
        d.council.execute(id); // 1 of 1 seat voted yes
        assertEq(d.game.owner(), address(d.council));

        GameStorage.Config memory c = _cfg();
        c.distortion = true;
        vm.prank(alice);
        id = d.council.propose(a, address(d.game), abi.encodeCall(view_.setConfig, (c)), "total war");
        d.council.execute(id);
        assertTrue(_cfg().distortion);
    }

    function test_vacateDestroyedSovereignSeat() public {
        // a GEN1 sovereign PILOT dies in a failed siege; its seat can be freed and bought again
        _lite(alice, 0, 5, 0, 0);
        _lite(bob, 1, 6, 0, 1);
        uint256 p = _pilot(alice, 0, 1);
        vm.prank(alice);
        t.becomeSovereign(p);
        assertEq(t.sovereignCount(), 1);
        assertEq(t.boughtSeats(), 1);
        _army(alice, 0, SIF, 5);
        _army(bob, 1, THROT, 20);
        vm.prank(alice);
        war.siege(0, 1, _units(5, 0, 0, 0), p + 1);
        skip(1 hours);
        sie.advanceSiege(1, 1);
        vm.expectRevert();
        d.pilot.ownerOf(p);

        vm.expectRevert(Technocracy.NotSovereign.selector);
        t.vacate(12345); // never a sovereign
        t.vacate(p);
        assertEq(t.sovereignCount(), 0);
        assertEq(t.boughtSeats(), 0);
        vm.expectRevert(Technocracy.NotSovereign.selector);
        t.vacate(p); // only once
    }

    function test_councilNeedsAMajorityAndOneVotePerSeat() public {
        uint256 a = _born(alice);
        uint256 b = _pilot(bob, 0, 0);
        vm.prank(bob);
        t.becomeSovereign(b);
        uint256 c = _pilot(carol, 0, 0);
        vm.prank(carol);
        t.becomeSovereign(c); // 3 seats
        vm.prank(alice);
        uint256 id = d.council.propose(a, address(d.game), abi.encodeWithSignature("startSeason()"), "season 2");
        vm.expectRevert(); // 1 of 3
        d.council.execute(id);
        vm.prank(alice);
        vm.expectRevert(); // already voted (proposer's yes)
        d.council.vote(id, a, true);
        vm.prank(bob);
        d.council.vote(id, b, false);
        vm.prank(carol);
        d.council.vote(id, c, true); // 2 of 3
        // the council doesn't own the game yet: the call itself fails
        vm.expectRevert();
        d.council.execute(id);
        skip(8 days);
        vm.prank(carol);
        vm.expectRevert(); // voting closed
        d.council.vote(id, c, true);
    }

    function test_nonSovereignCannotPropose() public {
        uint256 b = _pilot(bob, 0, 0);
        vm.prank(bob);
        vm.expectRevert();
        d.council.propose(b, address(d.game), "", "");
    }
}
