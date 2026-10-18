// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Axial-coordinate hex math. A tile is (q, r); the implicit third cube coordinate is s = -q - r.
/// The grid is a hexagon of tiles centered on (0, 0) with a fixed radius.
library Hex {
    function distance(int16 q1, int16 r1, int16 q2, int16 r2) internal pure returns (uint256) {
        int256 dq = int256(q1) - int256(q2);
        int256 dr = int256(r1) - int256(r2);
        int256 ds = -dq - dr;
        return (_abs(dq) + _abs(dr) + _abs(ds)) / 2;
    }

    function fromCenter(int16 q, int16 r) internal pure returns (uint256) {
        return distance(q, r, 0, 0);
    }

    /// @notice Packs a coordinate into a single storage key.
    function key(int16 q, int16 r) internal pure returns (uint32) {
        return (uint32(uint16(q)) << 16) | uint32(uint16(r));
    }

    function _abs(int256 x) private pure returns (uint256) {
        return uint256(x >= 0 ? x : -x);
    }
}
