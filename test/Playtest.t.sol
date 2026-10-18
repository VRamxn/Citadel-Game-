// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";
import {Base} from "./Base.t.sol";
import {GameStorage} from "../src/game/GameStorage.sol";

/// @notice A 30-day economic playtest with 8 scripted players (2 per faction) on a crowded core. Not a pass/fail test:
/// run `forge test --match-contract Playtest -vv` and read the log to judge pacing and balance.
contract Playtest is Base {
    uint256 constant PLAYERS = 8;
    uint256 constant DAYS = 30;
    uint256 constant TICK = 6 hours;

    address[8] who;
    uint256[8] ids;
    uint256[] open;
    uint256 raids;
    uint256 raidWins;
    uint256 sieges;
    uint256 captures;
    mapping(uint256 => uint256) won;

    function setUp() public override {
        super.setUp();
        // CITADEL #0 (RELIK), #1..#3 used by Base; give players #4..#11
        int16[2][8] memory at = [
            [int16(0), int16(0)],
            [int16(2), int16(-1)],
            [int16(-2), int16(1)],
            [int16(1), int16(1)],
            [int16(-1), int16(-1)],
            [int16(3), int16(0)],
            [int16(-3), int16(0)],
            [int16(0), int16(3)]
        ];
        for (uint256 i; i < PLAYERS; ++i) {
            who[i] = makeAddr(string.concat("p", vm.toString(i)));
            ids[i] = 4 + i;
            _give(who[i], ids[i]);
            // drop the Base fixture's 50M: start like the testnet faucet, 5M
            uint256 extra = d.drakma.balanceOf(who[i]) - 5_000_000 ether;
            vm.prank(who[i]);
            d.drakma.burn(extra);
            _lite(who[i], ids[i], at[i][0], at[i][1], uint8(i % 4));
        }
    }

    function test_playtest30Days() public {
        uint256 supply0 = d.drakma.totalSupply();
        for (uint256 t; t < DAYS * 1 days / TICK; ++t) {
            skip(TICK);
            _resolveOpen();
            for (uint256 i; i < PLAYERS; ++i) {
                _turn(i, t);
            }
            if ((t + 1) % (4 * 5) == 0) _report((t + 1) * TICK / 1 days);
        }
        console.log("--------------------------------------------------");
        console.log("raids", raids, "won", raidWins);
        console.log("sieges", sieges, "captures", captures);
        console.log("DK supply change (whole DK):");
        console.logInt((int256(d.drakma.totalSupply()) - int256(supply0)) / 1e18);
        for (uint8 f; f < 4; ++f) {
            console.log("faction", f, "tech bits", uint256(d.techTree.bits(f)));
        }
    }

    function _turn(uint256 i, uint256 t) internal {
        uint256 id = ids[i];
        if (!view_.citadel(id).lit) return; // leveled
        address p = who[i];
        vm.startPrank(p);
        // claim when possible
        GameStorage.Citadel memory c = view_.citadel(id);
        if (block.timestamp >= c.lastClaim + _cfg().claimInterval) {
            try eco.claim(id) {}
            catch (bytes memory e) {
                _fail("claim", i, e);
            }
        }
        // build: academy -> mine -> citadel -> weapon/shield, cheapest affordable first
        if (view_.constructionOf(id).end == 0) {
            uint8[6] memory order = [5, 1, 0, 1, 4, 2];
            for (uint256 k; k < order.length; ++k) {
                uint8 b = order[k];
                uint8 lv = view_.citadel(id).levels[b];
                if (lv >= 10 || (b != 0 && lv + 1 > 1 && lv + 1 > view_.citadel(id).levels[0])) continue;
                (uint256 cost,) = view_.buildCost(b, lv + 1);
                if (cost * 3 < d.drakma.balanceOf(p)) {
                    try eco.build(id, b) {}
                    catch (bytes memory e) {
                        _fail("build", i, e);
                    }
                    break;
                }
            }
        }
        // train: spend a fifth of the wallet on SIF, some THROT for defense once possible
        uint256 bal = d.drakma.balanceOf(p);
        if (view_.citadel(id).levels[5] >= 1) {
            uint64 n = uint64(bal / (i % 2 == 0 ? 3 : 8) / 20 ether);
            if (n > 0) {
                try eco.train(id, SIF, n > 2000 ? 2000 : n) {}
                catch (bytes memory e) {
                    _fail("train sif", i, e);
                }
            }
        }
        if (view_.citadel(id).levels[5] >= 2 && i % 2 == 1) {
            uint64 n = uint64(bal / 10 / 40 ether);
            if (n > 0) {
                try eco.train(id, THROT, n > 500 ? 500 : n) {}
                catch (bytes memory e) {
                    _fail("train throt", i, e);
                }
            }
        }
        vm.stopPrank();
        // every day, attack the richest-looking enemy we beat on paper
        if (i % 2 == 0 && t % 4 == i % 4) _attack(i);
    }

    function _attack(uint256 i) internal {
        uint256 id = ids[i];
        uint64 sif = view_.garrisonOf(id)[SIF];
        if (sif < 50) return;
        uint256 best;
        uint256 bestVault;
        for (uint256 j; j < PLAYERS; ++j) {
            uint256 o = ids[j];
            if (j == i || !view_.citadel(o).lit || view_.citadel(o).faction == view_.citadel(id).faction) continue;
            uint64[4] memory g = view_.garrisonOf(o);
            GameStorage.Citadel memory oc = view_.citadel(o);
            // rough defense: fortified fleet + structure, with ~80% bonuses
            uint256 def = (uint256(g[0]) * 5 + uint256(g[1]) * 70 + uint256(g[2]) * 250) * 13 / 10 + 100
                * (uint256(oc.levels[0]) + 1) ** 2 * 13 / 10;
            if (uint256(sif) * 11 > def * 12 / 10 && view_.vaultOf(o) > bestVault) {
                (best, bestVault) = (o, view_.vaultOf(o));
            }
        }
        if (bestVault == 0) return;
        uint64 send = sif;
        vm.prank(who[i]);
        uint256 m;
        try war.raid(id, best, _units(send, 0, 0, 0)) returns (uint256 x) {
            m = x;
        } catch (bytes memory e) {
            _fail("raid", i, e);
            return;
        }
        raids++;
        if (m != 0) open.push(m);
        else if (view_.garrisonOf(id)[SIF] > 0) raidWins++;
        // a big enough army besieges once (no PILOT: level only)
        uint64 left = view_.garrisonOf(id)[SIF];
        if (left > 2_000 && won[id] == 0 && view_.citadel(id).besieged == 0 && view_.citadel(best).lit) {
            vm.prank(who[i]);
            try war.siege(id, best, _units(left, 0, 0, 0), 0) {
                sieges++;
                won[id] = 1;
            } catch {}
        }
    }

    function _resolveOpen() internal {
        for (uint256 k; k < open.length; ++k) {
            GameStorage.March memory m = view_.march(open[k]);
            if (m.done || m.arriveAt > block.timestamp) continue;
            vm.prank(keeper);
            try war.resolve(open[k]) {}
            catch (bytes memory e) {
                _fail("resolve", open[k], e);
            }
            if (m.kind == GameStorage.MarchKind.Raid && view_.march(open[k] + 1).kind == GameStorage.MarchKind.Return) {
                raidWins++;
                open.push(open[k] + 1);
            }
        }
        for (uint256 s = 1; s <= d.game.siegeCount(); ++s) {
            GameStorage.Siege memory g = view_.siegeOf(s);
            if (!g.active) continue;
            if ((block.timestamp - g.start) / 1 hours > g.waves) {
                try sie.advanceSiege(s, 48) {}
                catch (bytes memory e) {
                    _fail("advance", s, e);
                }
                if (!view_.siegeOf(s).active && !view_.citadel(g.target).lit) captures++;
            }
        }
    }

    function _fail(string memory what, uint256 i, bytes memory e) internal pure {
        console.log("FAIL", what, i);
        console.logBytes(e);
    }

    function _report(uint256 day) internal view {
        console.log("== day", day);
        for (uint256 i; i < PLAYERS; ++i) {
            uint256 id = ids[i];
            GameStorage.Citadel memory c = view_.citadel(id);
            if (!c.lit) {
                console.log("  player", i, "LEVELED");
                continue;
            }
            uint64[4] memory g = view_.garrisonOf(id);
            console.log(
                string.concat(
                    "  p",
                    vm.toString(i),
                    " wallet ",
                    vm.toString(d.drakma.balanceOf(who[i]) / 1e18),
                    " vault ",
                    vm.toString(view_.vaultOf(id) / 1e18),
                    " rate/day ",
                    vm.toString(view_.miningRate(id) / 1e18),
                    " L[cit,mine,acad] ",
                    vm.toString(c.levels[0]),
                    ",",
                    vm.toString(c.levels[1]),
                    ",",
                    vm.toString(c.levels[5]),
                    " SIF ",
                    vm.toString(g[0]),
                    " THROT ",
                    vm.toString(g[1]),
                    " FP ",
                    vm.toString(d.game.fleetPoints(id))
                )
            );
        }
    }
}
