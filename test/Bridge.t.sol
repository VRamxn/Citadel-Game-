// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Stack} from "../script/Stack.sol";
import {LocalMessenger} from "../src/bridge/LocalMessenger.sol";
import {CitadelVaultL1} from "../src/bridge/CitadelVaultL1.sol";
import {CitadelBridgeL2} from "../src/bridge/CitadelBridgeL2.sol";
import {MockOriginal} from "../src/TestnetFaucet.sol";
import {DrakmaClaim} from "../src/DrakmaClaim.sol";
import {EconomyModule} from "../src/game/EconomyModule.sol";
import {Traits} from "../src/lib/Traits.sol";

/// @notice Originals on "L1" (mock collections in a vault) and their copies on "L2", linked by a LocalMessenger that
/// delivers both directions instantly — the same contracts that run on Ethereum and Base.
contract BridgeTest is Test, Stack {
    address admin = makeAddr("admin");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    LocalMessenger messenger;
    MockOriginal origCitadel;
    MockOriginal origPilot;
    Deployment d;
    L1Deployment l1;

    function setUp() public {
        vm.startPrank(admin);
        messenger = new LocalMessenger();
        origCitadel = new MockOriginal("CITADEL", "CITADEL", 1024, admin);
        origPilot = new MockOriginal("PILOT", "PILOT", 2048, admin);
        d = _deployL2(admin, admin, 12, messenger, _root(), false);
        l1 = _deployL1(admin, messenger, IERC721(address(origCitadel)), IERC721(address(origPilot)), address(d.claim));
        _linkL1(l1, address(d.bridge));
        _linkL2(d, address(l1.vault), address(l1.claimRelay));
        d.citadel.setTraits(0, hex"000300000000000300000000");
        d.pilot.setTraits(0, abi.encodePacked(uint8(2), uint8(5), uint8(7), uint8(1), uint8(0))); // lvl 7 sovereign
        origCitadel.mint(alice, 0);
        origCitadel.mint(alice, 1);
        origPilot.mint(alice, 0);
        vm.stopPrank();
    }

    function _deposit(address who, uint8 collection, uint256 id, address to) internal {
        MockOriginal t = collection == 0 ? origCitadel : origPilot;
        uint256[] memory ids = new uint256[](1);
        ids[0] = id;
        vm.startPrank(who);
        t.setApprovalForAll(address(l1.vault), true);
        l1.vault.deposit(collection, ids, to);
        vm.stopPrank();
    }

    function test_depositMintsOnL2AndWithdrawReleasesOnL1() public {
        _deposit(alice, 0, 0, alice);
        assertEq(origCitadel.ownerOf(0), address(l1.vault));
        assertEq(d.citadel.ownerOf(0), alice);

        uint256[] memory ids = new uint256[](1);
        vm.prank(alice);
        d.bridge.withdraw(0, ids, bob); // home to bob on L1
        assertEq(origCitadel.ownerOf(0), bob);
        vm.expectRevert();
        d.citadel.ownerOf(0);
    }

    function test_pilotKeepsWhatItBought() public {
        _deposit(alice, 1, 0, alice);
        Traits.PilotTraits memory t = d.pilot.traitsOf(0);
        assertEq(t.level, 7);
        assertTrue(t.sovereign);
        assertEq(t.subjugation, 2);
        // a round trip keeps the traits
        uint256[] memory ids = new uint256[](1);
        vm.prank(alice);
        d.bridge.withdraw(1, ids, alice);
        _deposit(alice, 1, 0, alice);
        assertEq(d.pilot.traitsOf(0).level, 7);
    }

    function test_onlyTheVaultCanMintAndOnlyTheBridgeCanRelease() public {
        uint256[] memory ids = new uint256[](1);
        vm.expectRevert(CitadelBridgeL2.NotVault.selector);
        d.bridge.finalizeDeposit(0, ids, alice);
        vm.expectRevert(CitadelVaultL1.NotBridge.selector);
        l1.vault.finalizeWithdrawal(0, ids, alice);
        // a message from anyone else through the messenger is refused too
        vm.expectRevert();
        messenger.sendMessage(address(d.bridge), abi.encodeCall(CitadelBridgeL2.finalizeDeposit, (0, ids, alice)), 0);
    }

    function test_cantWithdrawWhatYouDontHoldOrWhatIsLit() public {
        _deposit(alice, 0, 1, alice);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(CitadelBridgeL2.NotOwner.selector, 1));
        d.bridge.withdraw(0, ids, bob);

        vm.startPrank(alice);
        d.citadel.setApprovalForAll(address(d.game), true);
        uint256[] memory none;
        EconomyModule(address(d.game)).lite(1, 0, 4, 4, 0, 0, none);
        vm.expectRevert(abi.encodeWithSelector(CitadelBridgeL2.NotOwner.selector, 1)); // the game holds it
        d.bridge.withdraw(0, ids, alice);
        vm.stopPrank();
    }

    function test_vaultHasNoOwnerAfterLinking() public view {
        assertEq(l1.vault.owner(), address(0));
        assertEq(d.bridge.owner(), address(0));
    }

    // ------------------------------------------------------------ DRAKMA carry-over claim

    uint256 constant ALICE_AMOUNT = 1_250_000 ether; // old balance + flat share
    uint256 constant BOB_AMOUNT = 250_000 ether; // flat share only

    function _leaf(address a, uint256 amount) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(a, amount))));
    }

    function _root() internal view returns (bytes32) {
        bytes32 x = _leaf(alice, ALICE_AMOUNT);
        bytes32 y = _leaf(bob, BOB_AMOUNT);
        return x < y ? keccak256(abi.encodePacked(x, y)) : keccak256(abi.encodePacked(y, x));
    }

    function test_claimOnceWithAProof() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = _leaf(bob, BOB_AMOUNT);
        vm.prank(alice);
        d.claim.claim(ALICE_AMOUNT, proof);
        assertEq(d.drakma.balanceOf(alice), ALICE_AMOUNT);
        vm.prank(alice);
        vm.expectRevert(DrakmaClaim.AlreadyClaimed.selector);
        d.claim.claim(ALICE_AMOUNT, proof);
        bytes32[] memory bobProof = new bytes32[](1);
        bobProof[0] = _leaf(alice, ALICE_AMOUNT);
        vm.prank(bob);
        vm.expectRevert(DrakmaClaim.BadProof.selector);
        d.claim.claim(BOB_AMOUNT * 2, bobProof); // can't claim more than the snapshot says
    }

    function test_l1OnlyWalletClaimsThroughTheRelay() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = _leaf(alice, ALICE_AMOUNT);
        address l2Wallet = makeAddr("bob on L2");
        vm.prank(bob);
        l1.claimRelay.claimTo(l2Wallet, BOB_AMOUNT, proof);
        assertEq(d.drakma.balanceOf(l2Wallet), BOB_AMOUNT);
        assertTrue(d.claim.claimed(bob));
    }
}
