// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
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
import {DrakmaClaim, DrakmaClaimRelayL1} from "../src/DrakmaClaim.sol";
import {CitadelBridgeL2} from "../src/bridge/CitadelBridgeL2.sol";
import {CitadelVaultL1} from "../src/bridge/CitadelVaultL1.sol";
import {IOPMessenger, IBridgeableNFT, IBridgedPilot, ISeatKeeper} from "../src/bridge/IOPMessenger.sol";
import {IDrakma, IGameView, ICitadelNFT, IPilotNFT, IMentatNFT} from "../src/interfaces/IGameAssets.sol";

/// @notice Deploys and wires CITADEL. The game runs on an OP Stack L2 (Base); the original CITADEL and PILOT stay in a
/// vault on Ethereum while their copies play on L2. Every call must come from `admin` (a broadcaster in a script, a
/// prank in tests). Cross-chain wiring is done by the `_link*` helpers once both sides exist.
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
        CitadelBridgeL2 bridge;
        DrakmaClaim claim;
        TestnetFaucet faucet; // testnets only (zero on mainnet)
        address economy;
        address war;
        address siege;
        address views;
    }

    struct L1Deployment {
        CitadelVaultL1 vault;
        DrakmaClaimRelayL1 claimRelay;
    }

    string internal constant CITADEL_URI =
        "https://gateway.pinata.cloud/ipfs/QmXXC2PHUeiFtUFVdLNnYodWUNdZnK2jbT8prE6R51mGT6/";

    /// @dev The L2 side: game, tokens, politics, bridge endpoint and carry-over claim.
    function _deployL2(
        address admin,
        address treasury,
        uint16 radius,
        IOPMessenger messenger,
        DrakmaClaim.Terms memory claimTerms,
        bool testnet
    ) internal returns (Deployment memory d) {
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

        d.technocracy = new Technocracy(admin, IPilotNFT(address(d.pilot)), IDrakma(address(d.drakma)), treasury);
        d.technocracy.setGame(IGameView(address(d.game)));
        d.council = new SovereignCouncil(
            IPilotNFT(address(d.pilot)), IGameView(address(d.game)), ISovereignCount(address(d.technocracy))
        );
        d.bridge = new CitadelBridgeL2(
            admin,
            messenger,
            IBridgeableNFT(address(d.citadel)),
            IBridgedPilot(address(d.pilot)),
            ISeatKeeper(address(d.technocracy))
        );
        d.technocracy.setBridge(address(d.bridge));
        d.claim = new DrakmaClaim(admin, claimTerms, IDrakma(address(d.drakma)), messenger);
        if (testnet) d.faucet = new TestnetFaucet(admin, d.drakma);

        Drakma dk = d.drakma;
        dk.grantRole(dk.MINTER_ROLE(), address(d.game));
        dk.grantRole(dk.MINTER_ROLE(), address(d.technocracy));
        dk.grantRole(dk.MINTER_ROLE(), address(d.claim));
        if (testnet) dk.grantRole(dk.MINTER_ROLE(), address(d.faucet));
        dk.grantRole(dk.BURNER_ROLE(), address(d.game));
        dk.grantRole(dk.BURNER_ROLE(), address(d.pilot));
        dk.grantRole(dk.BURNER_ROLE(), address(d.mentat));
        dk.grantRole(dk.BURNER_ROLE(), address(d.technocracy));

        d.citadel.grantRole(d.citadel.BRIDGE_ROLE(), address(d.bridge));
        d.citadel.grantRole(d.citadel.GAME_ROLE(), address(d.game));

        PilotNFT p = d.pilot;
        p.grantRole(p.BRIDGE_ROLE(), address(d.bridge));
        p.grantRole(p.MINTER_ROLE(), address(d.game));
        p.grantRole(p.GAME_ROLE(), address(d.game));
        p.grantRole(p.POLITICS_ROLE(), address(d.technocracy));

        d.mentat.grantRole(d.mentat.MINTER_ROLE(), address(d.techTree));
    }

    /// @dev The community treasury: DRAKMA held by the GRID MAELSTROM council, spent only by sovereign vote (a proposal
    /// that calls drakma.transfer). It replaces the whitepaper's share "withheld by the development team". The admin
    /// mints it once and gives the minter role straight back.
    function _fundCouncil(Deployment memory d, address admin, uint256 amount) internal {
        Drakma dk = d.drakma;
        dk.grantRole(dk.MINTER_ROLE(), admin);
        dk.mint(address(d.council), amount);
        dk.renounceRole(dk.MINTER_ROLE(), admin);
    }

    /// @dev Route the game's and the technocracy's fee share (25-30% of seats, overthrows and bribes) to the council too.
    function _councilIsTreasury(Deployment memory d) internal {
        ViewModule(address(d.game)).setTreasury(address(d.council));
        d.technocracy.setTreasury(address(d.council));
    }

    /// @dev The L1 side: the vault for the originals and the claim relay for L1-only wallets.
    function _deployL1(
        address admin,
        IOPMessenger messenger,
        IERC721 citadelOriginal,
        IERC721 pilotOriginal,
        address l2Claim
    ) internal returns (L1Deployment memory l1) {
        l1.vault = new CitadelVaultL1(admin, messenger, citadelOriginal, pilotOriginal);
        l1.claimRelay = new DrakmaClaimRelayL1(messenger, l2Claim);
    }

    /// @dev Wire both sides together (each setter works once and then renounces ownership).
    function _linkL1(L1Deployment memory l1, address l2Bridge) internal {
        l1.vault.setL2Bridge(l2Bridge);
    }

    function _linkL2(Deployment memory d, address l1Vault, address l1Relay) internal {
        d.bridge.setL1Vault(l1Vault);
        d.claim.setL1Relay(l1Relay);
    }

    function _loadTraits(CitadelNFT citadel, bytes memory traits) internal {
        _chunks(address(citadel), traits, 6, 128);
    }

    /// @dev 2-byte records per original PILOT id: subjugation, death. Levels, sovereignty and KULT arrive over the bridge.
    function _loadPilotTraits(PilotNFT pilot, bytes memory traits) internal {
        _chunks(address(pilot), traits, 2, 400);
    }

    /// @dev Freeze the metadata traits of both collections.
    function _lockTraits(Deployment memory d) internal {
        d.citadel.lockTraits();
        d.pilot.lockTraits();
    }

    function _chunks(address nft, bytes memory data, uint256 recordBytes, uint256 perTx) private {
        uint256 chunk = perTx * recordBytes;
        for (uint256 start; start < data.length; start += chunk) {
            uint256 len = data.length - start < chunk ? data.length - start : chunk;
            bytes memory part = new bytes(len);
            for (uint256 i; i < len; ++i) {
                part[i] = data[start + i];
            }
            CitadelNFT(nft).setTraits(start / recordBytes, part); // same selector on both NFTs
        }
    }
}
