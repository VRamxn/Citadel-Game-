// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {CitadelNFT} from "./CitadelNFT.sol";
import {PilotNFT} from "./PilotNFT.sol";
import {Drakma} from "./Drakma.sol";
import {Traits} from "./lib/Traits.sol";

/// @notice TESTNET ONLY. Hands each address a starter kit once, matching the 0xCITADEL alpha:
/// 2 CITADEL, 2 PILOT, 5M DK. PILOT traits use block randomness, which is fine for a testnet and
/// must be replaced (e.g. VRF) before anything of value depends on it.
contract TestnetFaucet is Ownable {
    CitadelNFT public immutable citadel;
    PilotNFT public immutable pilot;
    Drakma public immutable drakma;

    uint256 public constant CITADEL_PER_DRIP = 2;
    uint256 public constant PILOT_PER_DRIP = 2;
    uint256 public constant DK_PER_DRIP = 5_000_000 ether;

    /// @notice Next CITADEL id to hand out. Ids reserved for specific holders via grantCitadel are skipped.
    uint256 public nextCitadel;
    uint256 private _nonce;
    mapping(address => bool) public dripped;

    event Dripped(address indexed to, uint256[] citadels, uint256[] pilots);

    error AlreadyDripped();
    error OutOfCitadel();

    constructor(address owner_, CitadelNFT citadel_, PilotNFT pilot_, Drakma drakma_) Ownable(owner_) {
        citadel = citadel_;
        pilot = pilot_;
        drakma = drakma_;
    }

    function drip() external {
        if (dripped[msg.sender]) revert AlreadyDripped();
        dripped[msg.sender] = true;

        uint256[] memory cs = new uint256[](CITADEL_PER_DRIP);
        for (uint256 i; i < CITADEL_PER_DRIP; ++i) {
            uint256 id = nextCitadel;
            while (id < citadel.MAX_CITADEL() && citadel.exists(id)) ++id;
            if (id >= citadel.MAX_CITADEL()) revert OutOfCitadel();
            citadel.mint(msg.sender, id);
            cs[i] = id;
            nextCitadel = id + 1;
        }

        uint256[] memory ps = new uint256[](PILOT_PER_DRIP);
        for (uint256 i; i < PILOT_PER_DRIP; ++i) {
            ps[i] = pilot.mint(msg.sender, _randomPilot());
        }

        drakma.mint(msg.sender, DK_PER_DRIP);
        emit Dripped(msg.sender, cs, ps);
    }

    /// @notice Give a mainnet holder their own CITADEL id on testnet.
    function grantCitadel(address to, uint256 id) external onlyOwner {
        citadel.mint(to, id);
    }

    function grantPilot(address to, Traits.PilotTraits calldata t) external onlyOwner returns (uint256) {
        return pilot.mint(to, t);
    }

    function grantDrakma(address to, uint256 amount) external onlyOwner {
        drakma.mint(to, amount);
    }

    /// @dev Rarities from THE PILOT post (out of 2048).
    function _randomPilot() private returns (Traits.PilotTraits memory t) {
        uint256 seed = uint256(keccak256(abi.encode(block.prevrandao, msg.sender, _nonce++)));
        t.subjugation = _pick(seed % 2048, [uint16(1024), 512, 256, 128, 64, 32, 16, 16]);
        t.kult = _pick((seed >> 16) % 2048, [uint16(512), 256, 256, 256, 256, 256, 128, 128]);
        t.death = (seed >> 32) % 2048 < 64;
    }

    function _pick(uint256 roll, uint16[8] memory weights) private pure returns (uint8) {
        uint256 acc;
        for (uint8 i; i < 8; ++i) {
            acc += weights[i];
            if (roll < acc) return i;
        }
        return 7;
    }
}
