// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IDrakma} from "./interfaces/IGameAssets.sol";
import {Traits} from "./lib/Traits.sol";

/// @notice Testnet PILOT. Traits are on-chain (as they were on mainnet): SUBJUGATION, KULT, LEVEL, SOVEREIGNTY, DEATH.
/// GEN0 is capped at 2048 (THE PILOT post). Later generations are minted in-game with FLEET POINTS.
contract PilotNFT is ERC721, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant GAME_ROLE = keccak256("GAME_ROLE"); // may burn PILOT destroyed in a failed siege
    bytes32 public constant POLITICS_ROLE = keccak256("POLITICS_ROLE"); // sets SOVEREIGNTY
    uint256 public constant MAX_GEN0 = 2048;
    uint8 public constant MAX_LEVEL = 9;
    /// @notice Uplevel cost = LEVEL_COST * target level (THE PILOT post: 100k, 200k, ... 900k DK).
    uint256 public constant LEVEL_COST = 100_000 ether;

    IDrakma public immutable drakma;
    uint256 public totalMinted;
    uint256 public gen0Minted;
    mapping(uint256 => Traits.PilotTraits) private _traits;

    event Upleveled(uint256 indexed pilotId, uint8 level);
    event SovereigntyChanged(uint256 indexed pilotId, bool sovereign);

    error NotOwner();
    error MaxLevel();
    error SoldOut();
    error UnknownPilot(uint256 id);

    constructor(address admin, IDrakma drakma_) ERC721("PILOT", "PILOT") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        drakma = drakma_;
    }

    function mint(address to, Traits.PilotTraits calldata t) external onlyRole(MINTER_ROLE) returns (uint256 id) {
        if (t.generation == 0 && gen0Minted++ >= MAX_GEN0) revert SoldOut();
        id = totalMinted++;
        _traits[id] = t;
        _mint(to, id);
    }

    function burn(uint256 id) external onlyRole(GAME_ROLE) {
        _burn(id);
    }

    function setSovereign(uint256 id, bool sovereign) external onlyRole(POLITICS_ROLE) {
        _requireOwned(id);
        _traits[id].sovereign = sovereign;
        emit SovereigntyChanged(id, sovereign);
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
