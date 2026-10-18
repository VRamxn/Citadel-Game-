// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Stack} from "../script/Stack.sol";
import {CitadelGame} from "../src/game/CitadelGame.sol";
import {EconomyModule} from "../src/game/EconomyModule.sol";
import {WarModule} from "../src/game/WarModule.sol";
import {SiegeModule} from "../src/game/SiegeModule.sol";
import {ViewModule} from "../src/game/ViewModule.sol";
import {GameStorage} from "../src/game/GameStorage.sol";
import {GameBase} from "../src/game/GameBase.sol";
import {Traits} from "../src/lib/Traits.sol";

/// @notice Shared fixture: the full system, with hand-picked GEN0 traits for CITADEL #0..15:
///  #0  RELIK, tech PROPULSION      #1  ELEKT, tech PRESERVATIVE   #2  ELEKT, tech MILITANT
///  #3  ELEKT, tech POSTHUMANISM    #4  RELIK, tech PRESERVATIVE   #5..15 ELEKT, tech PRESERVATIVE
/// All have the weakest shield/engine/weapon (DAG SGIATH / HAG GOTOR / RRAKATAKHT FUROR) unless noted.
abstract contract Base is Test, Stack {
    Deployment d;
    EconomyModule eco;
    WarModule war;
    SiegeModule sie;
    ViewModule view_;

    address admin = makeAddr("admin");
    address treasury = makeAddr("treasury");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address carol = makeAddr("carol");
    address keeper = makeAddr("keeper");

    uint8 constant SIF = 0;
    uint8 constant THROT = 1;
    uint8 constant DREB = 2;
    uint8 constant DALAA = 3;
    uint8 constant B_CITADEL = 0;
    uint8 constant B_MINE = 1;
    uint8 constant B_ACADEMY = 5;

    uint256[] none;

    function setUp() public virtual {
        vm.startPrank(admin);
        d = _deploy(admin, treasury, 12);
        bytes memory t = new bytes(16 * 6);
        for (uint256 i; i < 16; ++i) {
            t[i * 6 + 1] = bytes1(uint8(Traits.SEKT_ELEKT));
        }
        t[0 * 6 + 1] = bytes1(uint8(0)); // #0 RELIK
        t[0 * 6 + 5] = bytes1(uint8(3)); //    PROPULSION
        t[2 * 6 + 5] = bytes1(uint8(1)); // #2 MILITANT
        t[3 * 6 + 5] = bytes1(uint8(4)); // #3 POSTHUMANISM
        t[4 * 6 + 1] = bytes1(uint8(0)); // #4 RELIK, PRESERVATIVE
        d.citadel.setTraits(0, t);
        vm.stopPrank();

        eco = EconomyModule(address(d.game));
        war = WarModule(address(d.game));
        sie = SiegeModule(address(d.game));
        view_ = ViewModule(address(d.game));

        _give(alice, 0);
        _give(bob, 1);
        _give(carol, 2);
    }

    function _give(address who, uint256 citadelId) internal {
        vm.startPrank(admin);
        d.faucet.grantCitadel(who, citadelId);
        d.faucet.grantDrakma(who, 50_000_000 ether);
        vm.stopPrank();
        vm.startPrank(who);
        d.citadel.setApprovalForAll(address(d.game), true);
        d.pilot.setApprovalForAll(address(d.game), true);
        d.mentat.setApprovalForAll(address(d.game), true);
        vm.stopPrank();
    }

    function _pilot(address who, uint8 subjugation, uint8 generation) internal returns (uint256 id) {
        vm.prank(admin);
        id = d.faucet
            .grantPilot(
                who,
                Traits.PilotTraits({
                    generation: generation, subjugation: subjugation, kult: 0, level: 0, sovereign: false, death: false
                })
            );
    }

    function _lite(address who, uint256 id, int16 q, int16 r, uint8 faction) internal {
        uint8 tech = _techOf(id);
        vm.prank(who);
        eco.lite(id, 0, q, r, faction, tech, none);
    }

    function _techOf(uint256 id) internal view returns (uint8) {
        return d.citadel.traitsOf(id).tech;
    }

    /// @dev Build a building to `level`, hurrying each step.
    function _buildTo(address who, uint256 id, uint8 building, uint8 level) internal {
        while (view_.citadel(id).levels[building] < level) {
            vm.startPrank(who);
            eco.build(id, building);
            eco.hurryBuild(id);
            vm.stopPrank();
        }
    }

    /// @dev Train and hurry `n` units, building the academy they need first.
    function _army(address who, uint256 id, uint8 t, uint64 n) internal {
        (,,,,, uint8 academy,) = d.game.fleetTypes(t);
        if (academy > 1) _buildTo(who, id, B_CITADEL, academy);
        _buildTo(who, id, B_ACADEMY, academy);
        vm.startPrank(who);
        eco.train(id, t, n);
        eco.hurryTraining(id, t);
        vm.stopPrank();
    }

    function _units(uint64 sif, uint64 throt, uint64 dreb, uint64 dalaa) internal pure returns (uint64[4] memory u) {
        u = [sif, throt, dreb, dalaa];
    }

    function _cfg() internal view returns (GameStorage.Config memory) {
        return view_.getConfig();
    }
}
