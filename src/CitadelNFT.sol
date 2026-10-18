// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Traits} from "./lib/Traits.sol";

/// @notice CITADEL on the game's L2. #0–1023 are the original mainnet CITADEL (0xaf08134ea12494dc3aaa7f1efb23a8753b7f84c9)
/// bridged over: only the bridge mints and burns them, and their traits are loaded on-chain from a snapshot of the
/// original metadata. GEN1+ CITADEL (#1024 and up) are native to the L2, created in-game by PILOT that colonize or
/// capture grid, and can be destroyed when sieged.
contract CitadelNFT is ERC721, AccessControl {
    using Strings for uint256;

    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    bytes32 public constant GAME_ROLE = keccak256("GAME_ROLE");
    uint256 public constant MAX_CITADEL = 1024; // GEN0 supply, capped forever
    uint256 private constant TRAIT_BYTES = 6;

    mapping(uint256 => Traits.CitadelTraits) private _traits;
    uint256 public nextGenerated = MAX_CITADEL;
    string private _base;

    error UnknownCitadel(uint256 id);
    error BadTraits();

    constructor(address admin, string memory baseURI) ERC721("CITADEL", "CITADEL") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _base = baseURI;
    }

    /// @notice Loads packed GEN0 traits for ids [startId, startId + data.length / 6).
    /// Each record is 6 bytes: generation, sekt, shield, engine, weapon, tech.
    function setTraits(uint256 startId, bytes calldata data) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (data.length % TRAIT_BYTES != 0) revert BadTraits();
        uint256 n = data.length / TRAIT_BYTES;
        if (startId + n > MAX_CITADEL) revert BadTraits();
        for (uint256 i; i < n; ++i) {
            uint256 o = i * TRAIT_BYTES;
            Traits.CitadelTraits memory t = Traits.CitadelTraits({
                generation: uint8(data[o]),
                sekt: uint8(data[o + 1]),
                shield: uint8(data[o + 2]),
                engine: uint8(data[o + 3]),
                weapon: uint8(data[o + 4]),
                tech: uint8(data[o + 5]),
                exists: true
            });
            _validate(t);
            _traits[startId + i] = t;
        }
    }

    /// @notice Mint the L2 copy of an original CITADEL deposited in the L1 vault.
    function bridgeMint(address to, uint256 id) external onlyRole(BRIDGE_ROLE) {
        if (id >= MAX_CITADEL || !_traits[id].exists) revert UnknownCitadel(id);
        _mint(to, id);
    }

    /// @notice Burn the L2 copy of an original CITADEL that is being bridged back to L1.
    function bridgeBurn(uint256 id) external onlyRole(BRIDGE_ROLE) {
        if (id >= MAX_CITADEL) revert BadTraits();
        _burn(id);
    }

    /// @notice Mint a GEN1+ CITADEL created in-game.
    function mintGenerated(address to, Traits.CitadelTraits calldata t)
        external
        onlyRole(GAME_ROLE)
        returns (uint256 id)
    {
        if (t.generation == 0) revert BadTraits();
        _validate(t);
        id = nextGenerated++;
        _traits[id] = t;
        _traits[id].exists = true;
        _mint(to, id);
    }

    /// @notice Destroy a GEN1+ CITADEL leveled in a siege. GEN0 can never be destroyed.
    function burn(uint256 id) external onlyRole(GAME_ROLE) {
        if (id < MAX_CITADEL) revert BadTraits();
        _burn(id);
    }

    function exists(uint256 id) external view returns (bool) {
        return _ownerOf(id) != address(0);
    }

    function traitsOf(uint256 id) external view returns (Traits.CitadelTraits memory) {
        if (!_traits[id].exists) revert UnknownCitadel(id);
        return _traits[id];
    }

    function setBaseURI(string calldata baseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _base = baseURI;
    }

    /// @notice GEN0 points at the original mainnet metadata. GEN1+ has no artwork yet.
    function tokenURI(uint256 id) public view override returns (string memory) {
        _requireOwned(id);
        return id < MAX_CITADEL ? string.concat(_base, id.toString()) : "";
    }

    function _validate(Traits.CitadelTraits memory t) private pure {
        if (
            t.sekt >= Traits.SEKT_COUNT || t.shield >= Traits.TRAIT_COUNT || t.engine >= Traits.TRAIT_COUNT
                || t.weapon >= Traits.TRAIT_COUNT || t.tech >= Traits.TRAIT_COUNT
        ) revert BadTraits();
    }

    function supportsInterface(bytes4 id) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(id);
    }
}
