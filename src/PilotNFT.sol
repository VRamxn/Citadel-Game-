// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IPilotTraits, IDrakma} from "./interfaces/IGameAssets.sol";
import {Traits} from "./lib/Traits.sol";

/// @notice Testnet PILOT. Traits are on-chain (as they were on mainnet): SUBJUGATION, KULT, LEVEL, SOVEREIGNTY, DEATH.
contract PilotNFT is ERC721, AccessControl, IPilotTraits {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public constant MAX_GEN0 = 2048;
    uint8 public constant MAX_LEVEL = 9;
    /// @notice Uplevel cost = LEVEL_COST * target level (THE PILOT post: 100k, 200k, ... 900k DK).
    uint256 public constant LEVEL_COST = 100_000 ether;

    IDrakma public immutable drakma;
    uint256 public totalMinted;
    mapping(uint256 => Traits.PilotTraits) private _traits;

    event Upleveled(uint256 indexed pilotId, uint8 level);

    error NotOwner();
    error MaxLevel();
    error SoldOut();
    error UnknownPilot(uint256 id);

    constructor(address admin, IDrakma drakma_) ERC721("PILOT", "PILOT") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        drakma = drakma_;
    }

    function mint(address to, Traits.PilotTraits calldata t) external onlyRole(MINTER_ROLE) returns (uint256 id) {
        if (totalMinted >= MAX_GEN0) revert SoldOut();
        id = totalMinted++;
        _traits[id] = t;
        _mint(to, id);
    }

    /// @notice Spend DK to raise a PILOT one level. The PILOT must be in the caller's wallet (not lit to the grid).
    function uplevel(uint256 id) external {
        if (ownerOf(id) != msg.sender) revert NotOwner();
        Traits.PilotTraits storage t = _traits[id];
        if (t.level >= MAX_LEVEL) revert MaxLevel();
        uint8 next = t.level + 1;
        drakma.gameBurn(msg.sender, LEVEL_COST * next);
        t.level = next;
        emit Upleveled(id, next);
    }

    function traitsOf(uint256 id) external view returns (Traits.PilotTraits memory) {
        if (_ownerOf(id) == address(0)) revert UnknownPilot(id);
        return _traits[id];
    }

    function supportsInterface(bytes4 id) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(id);
    }
}
