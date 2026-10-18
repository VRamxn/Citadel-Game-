// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IDrakma} from "./interfaces/IGameAssets.sol";
import {Traits} from "./lib/Traits.sol";

/// @notice MENTAT, the intelligence network and first expansion NFT. Lit to a CITADEL it amplifies shield, engine,
/// weapon system and DRAKMA production, and widens the faction's vision. 128 GEN0 exist: 64 claimable by RELIK
/// owners and 64 emitted by RELIK as their faction completes tech branches (see TechTree).
contract MentatNFT is ERC721, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public constant MAX_GEN0 = 128;
    uint8 public constant MAX_LEVEL = 9;
    uint256 public constant LEVEL_COST = 250_000 ether;

    IDrakma public immutable drakma;
    uint256 public totalMinted;
    uint256 public gen0Minted;
    mapping(uint256 => Traits.MentatTraits) private _traits;

    event Upleveled(uint256 indexed mentatId, uint8 level);

    error NotOwner();
    error MaxLevel();
    error SoldOut();
    error UnknownMentat(uint256 id);

    constructor(address admin, IDrakma drakma_) ERC721("MENTAT", "MENTAT") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        drakma = drakma_;
    }

    function mint(address to, Traits.MentatTraits calldata t) external onlyRole(MINTER_ROLE) returns (uint256 id) {
        if (t.generation == 0 && gen0Minted++ >= MAX_GEN0) revert SoldOut();
        id = totalMinted++;
        _traits[id] = t;
        _mint(to, id);
    }

    /// @notice Raise a MENTAT one level for 250k DK x target level. It must be in the caller's wallet.
    function uplevel(uint256 id) external {
        if (ownerOf(id) != msg.sender) revert NotOwner();
        Traits.MentatTraits storage t = _traits[id];
        if (t.level >= MAX_LEVEL) revert MaxLevel();
        uint8 next = t.level + 1;
        drakma.gameBurn(msg.sender, LEVEL_COST * next);
        t.level = next;
        emit Upleveled(id, next);
    }

    function traitsOf(uint256 id) external view returns (Traits.MentatTraits memory) {
        if (_ownerOf(id) == address(0)) revert UnknownMentat(id);
        return _traits[id];
    }

    function supportsInterface(bytes4 id) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(id);
    }
}
