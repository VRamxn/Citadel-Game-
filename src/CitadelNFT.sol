// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ICitadelTraits} from "./interfaces/IGameAssets.sol";
import {Traits} from "./lib/Traits.sol";

/// @notice Testnet stand-in for the mainnet CITADEL collection (0xaf08134ea12494dc3aaa7f1efb23a8753b7f84c9).
/// The mainnet contract keeps traits off-chain in IPFS metadata; here they are loaded on-chain from a snapshot
/// of that metadata so every testnet CITADEL #n has the same SEKT/SHIELD/ENGINE/WEAPON/TECH as mainnet #n.
contract CitadelNFT is ERC721, AccessControl, ICitadelTraits {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public constant MAX_CITADEL = 1024;
    uint256 private constant TRAIT_BYTES = 6;

    mapping(uint256 => Traits.CitadelTraits) private _traits;
    string private _base;

    error UnknownCitadel(uint256 id);
    error BadTraits();

    constructor(address admin, string memory baseURI) ERC721("CITADEL", "CITADEL") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _base = baseURI;
    }

    /// @notice Loads packed traits for ids [startId, startId + data.length / 6).
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
            if (
                t.sekt >= Traits.SEKT_COUNT || t.shield >= Traits.TRAIT_COUNT || t.engine >= Traits.TRAIT_COUNT
                    || t.weapon >= Traits.TRAIT_COUNT || t.tech >= Traits.TRAIT_COUNT
            ) revert BadTraits();
            _traits[startId + i] = t;
        }
    }

    function mint(address to, uint256 id) external onlyRole(MINTER_ROLE) {
        if (!_traits[id].exists) revert UnknownCitadel(id);
        _mint(to, id);
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

    function _baseURI() internal view override returns (string memory) {
        return _base;
    }

    function supportsInterface(bytes4 id) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(id);
    }
}
