// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CitadelGame} from "../src/game/CitadelGame.sol";
import {EconomyModule} from "../src/game/EconomyModule.sol";
import {WarModule} from "../src/game/WarModule.sol";
import {SiegeModule} from "../src/game/SiegeModule.sol";
import {ViewModule} from "../src/game/ViewModule.sol";
import {CitadelNFT} from "../src/CitadelNFT.sol";
import {PilotNFT} from "../src/PilotNFT.sol";
import {MentatNFT} from "../src/MentatNFT.sol";
import {Drakma} from "../src/Drakma.sol";
import {TechTree} from "../src/TechTree.sol";
import {Technocracy} from "../src/Technocracy.sol";
import {SovereignCouncil, ISovereignCount} from "../src/SovereignCouncil.sol";
import {TestnetFaucet} from "../src/TestnetFaucet.sol";
import {IDrakma, IGameView, ICitadelNFT, IPilotNFT, IMentatNFT} from "../src/interfaces/IGameAssets.sol";

/// @notice Deploys and wires the whole CITADEL system. Every call must come from `admin` (a broadcaster in a script,
/// a prank in tests).
abstract contract Stack {
    struct Deployment {
        Drakma drakma;
        CitadelNFT citadel;
        PilotNFT pilot;
        MentatNFT mentat;
        TechTree techTree;
        CitadelGame game;
        Technocracy technocracy;
        SovereignCouncil council;
        TestnetFaucet faucet;
        address economy;
        address war;
        address siege;
        address views;
    }

    string internal constant CITADEL_URI =
        "https://gateway.pinata.cloud/ipfs/QmXXC2PHUeiFtUFVdLNnYodWUNdZnK2jbT8prE6R51mGT6/";

    function _deploy(address admin, address treasury, uint16 radius) internal returns (Deployment memory d) {
        d.drakma = new Drakma(admin);
        d.citadel = new CitadelNFT(admin, CITADEL_URI);
        d.pilot = new PilotNFT(admin, IDrakma(address(d.drakma)));
        d.mentat = new MentatNFT(admin, IDrakma(address(d.drakma)));
        d.techTree = new TechTree(admin, ICitadelNFT(address(d.citadel)), IMentatNFT(address(d.mentat)));
        d.game = new CitadelGame(
            admin,
            ICitadelNFT(address(d.citadel)),
            IPilotNFT(address(d.pilot)),
            IMentatNFT(address(d.mentat)),
            IDrakma(address(d.drakma)),
            d.techTree,
            treasury,
            radius
        );
        d.economy = address(new EconomyModule());
        d.war = address(new WarModule());
        d.siege = address(new SiegeModule());
        d.views = address(new ViewModule());
        d.game.install(d.economy);
        d.game.install(d.war);
        d.game.install(d.siege);
        d.game.install(d.views);
        d.techTree.setGame(address(d.game));

        d.technocracy = new Technocracy(
            admin, IPilotNFT(address(d.pilot)), ICitadelNFT(address(d.citadel)), IDrakma(address(d.drakma)), treasury
        );
        d.technocracy.setGame(IGameView(address(d.game)));
        d.council = new SovereignCouncil(
            IPilotNFT(address(d.pilot)), IGameView(address(d.game)), ISovereignCount(address(d.technocracy))
        );
        d.faucet = new TestnetFaucet(admin, d.citadel, d.pilot, d.drakma);

        Drakma dk = d.drakma;
        dk.grantRole(dk.MINTER_ROLE(), address(d.game));
        dk.grantRole(dk.MINTER_ROLE(), address(d.technocracy));
        dk.grantRole(dk.MINTER_ROLE(), address(d.faucet));
        dk.grantRole(dk.BURNER_ROLE(), address(d.game));
        dk.grantRole(dk.BURNER_ROLE(), address(d.pilot));
        dk.grantRole(dk.BURNER_ROLE(), address(d.mentat));
        dk.grantRole(dk.BURNER_ROLE(), address(d.technocracy));

        d.citadel.grantRole(d.citadel.MINTER_ROLE(), address(d.faucet));
        d.citadel.grantRole(d.citadel.GAME_ROLE(), address(d.game));

        PilotNFT p = d.pilot;
        p.grantRole(p.MINTER_ROLE(), address(d.game));
        p.grantRole(p.MINTER_ROLE(), address(d.faucet));
        p.grantRole(p.MINTER_ROLE(), address(d.technocracy));
        p.grantRole(p.GAME_ROLE(), address(d.game));
        p.grantRole(p.POLITICS_ROLE(), address(d.technocracy));

        d.mentat.grantRole(d.mentat.MINTER_ROLE(), address(d.techTree));
    }

    function _loadTraits(CitadelNFT citadel, bytes memory traits) internal {
        uint256 chunk = 128 * 6;
        for (uint256 start; start < traits.length; start += chunk) {
            uint256 len = traits.length - start < chunk ? traits.length - start : chunk;
            bytes memory part = new bytes(len);
            for (uint256 i; i < len; ++i) {
                part[i] = traits[start + i];
            }
            citadel.setTraits(start / 6, part);
        }
    }
}
