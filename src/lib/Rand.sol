// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Traits} from "./Traits.sol";

/// @notice Trait rolls. Seeds come from block.prevrandao, which a validator can bias: acceptable for a testnet,
/// to be replaced with VRF before anything of value depends on it.
library Rand {
    function seed(uint256 nonce) internal view returns (uint256) {
        return uint256(keccak256(abi.encode(block.prevrandao, block.timestamp, msg.sender, nonce)));
    }

    /// @notice PILOT traits with the rarities of THE PILOT post (out of 2048).
    function pilot(uint256 s, uint8 generation) internal pure returns (Traits.PilotTraits memory t) {
        t.generation = generation;
        t.subjugation = pick(s % 2048, [uint16(1024), 512, 256, 128, 64, 32, 16, 16]);
        t.kult = pick((s >> 16) % 2048, [uint16(512), 256, 256, 256, 256, 256, 128, 128]);
        t.death = (s >> 32) % 2048 < 64;
    }

    /// @notice GEN1+ CITADEL traits: ELEKT, components skewed towards the weaker tiers, uniform tech.
    function citadel(uint256 s, uint8 generation) internal pure returns (Traits.CitadelTraits memory t) {
        uint16[8] memory w = [uint16(40), 25, 15, 8, 5, 4, 2, 1];
        t.generation = generation;
        t.sekt = Traits.SEKT_ELEKT;
        t.shield = pick(s % 100, w);
        t.engine = pick((s >> 16) % 100, w);
        t.weapon = pick((s >> 32) % 100, w);
        t.tech = uint8((s >> 48) % 8);
        t.exists = true;
    }

    function pick(uint256 roll, uint16[8] memory weights) internal pure returns (uint8) {
        uint256 acc;
        for (uint8 i; i < 8; ++i) {
            acc += weights[i];
            if (roll < acc) return i;
        }
        return 7;
    }
}
