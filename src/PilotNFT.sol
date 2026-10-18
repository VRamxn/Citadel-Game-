// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IDrakma} from "./interfaces/IGameAssets.sol";
import {Traits} from "./lib/Traits.sol";

/// @notice PILOT on the game's L2.
/// #0–2047 are the original mainnet PILOT (0xD653B9f4ec70658402B9634E7E0eAFcc64138Cad) bridged over: only the bridge
/// mints and burns them. Their traits are loaded from a snapshot: revealed SUBJUGATION/DEATH from the original
/// metadata, and LEVEL and SOVEREIGNTY carried over from the original contract — what holders bought, they keep. Traits
/// live here by id, so they survive a round trip over the bridge.
/// #2048 and up are GEN1+ PILOT native to the L2, minted by the game with FLEET POINTS.
contract PilotNFT is ERC721, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE"); // the game: GEN1+ only
    bytes32 public constant GAME_ROLE = keccak256("GAME_ROLE"); // may burn PILOT destroyed in a failed siege
    bytes32 public constant POLITICS_ROLE = keccak256("POLITICS_ROLE"); // sets SOVEREIGNTY
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    uint256 public constant ORIGINALS = 2048; // id space of the original collection
    uint8 public constant MAX_LEVEL = 9;
    /// @notice Uplevel cost = LEVEL_COST * target level (THE PILOT post: 100k, 200k, ... 900k DK).
    uint256 public constant LEVEL_COST = 100_000 ether;
    uint256 private constant TRAIT_BYTES = 5; // subjugation, kult, level, flags (1 sovereign | 2 death), generation

    IDrakma public immutable drakma;
    uint256 public nextNative = ORIGINALS;
    mapping(uint256 => Traits.PilotTraits) private _traits;
    mapping(uint256 => bool) private _loaded;

    event Upleveled(uint256 indexed pilotId, uint8 level);
    event SovereigntyChanged(uint256 indexed pilotId, bool sovereign);

    error NotOwner();
    error MaxLevel();
    error BadTraits();
    error UnknownPilot(uint256 id);

    constructor(address admin, IDrakma drakma_) ERC721("PILOT", "PILOT") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        drakma = drakma_;
    }

    /// @notice Load packed traits of original PILOT [startId, startId + data.length / 5). Once per id.
    function setTraits(uint256 startId, bytes calldata data) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (data.length % TRAIT_BYTES != 0) revert BadTraits();
        uint256 n = data.length / TRAIT_BYTES;
        if (startId + n > ORIGINALS) revert BadTraits();
        for (uint256 i; i < n; ++i) {
            uint256 id = startId + i;
            if (_loaded[id]) revert BadTraits();
            uint256 o = i * TRAIT_BYTES;
            uint8 flags = uint8(data[o + 3]);
            Traits.PilotTraits memory t = Traits.PilotTraits({
                subjugation: uint8(data[o]),
                kult: uint8(data[o + 1]),
                level: uint8(data[o + 2]),
                sovereign: flags & 1 != 0,
                death: flags & 2 != 0,
                generation: uint8(data[o + 4])
            });
            if (t.subjugation >= 8 || t.kult >= 8 || t.level > MAX_LEVEL) revert BadTraits();
            _traits[id] = t;
            _loaded[id] = true;
        }
    }

    /// @notice Mint the L2 copy of an original PILOT deposited in the L1 vault.
    function bridgeMint(address to, uint256 id) external onlyRole(BRIDGE_ROLE) {
        if (id >= ORIGINALS || !_loaded[id]) revert UnknownPilot(id);
        _mint(to, id);
    }

    /// @notice Burn the L2 copy of an original PILOT being bridged back. Its traits stay here for its return.
    function bridgeBurn(uint256 id) external onlyRole(BRIDGE_ROLE) {
        if (id >= ORIGINALS) revert UnknownPilot(id);
        _burn(id);
    }

    /// @notice Mint a GEN1+ PILOT (the game, paid in FLEET POINTS).
    function mint(address to, Traits.PilotTraits calldata t) external onlyRole(MINTER_ROLE) returns (uint256 id) {
        if (t.generation == 0) revert BadTraits();
        id = nextNative++;
        _traits[id] = t;
        _loaded[id] = true;
        _mint(to, id);
    }

    function burn(uint256 id) external onlyRole(GAME_ROLE) {
        _burn(id);
    }

    /// @notice Sovereignty is a seat in the collective, held even while an original PILOT is still on L1.
    function setSovereign(uint256 id, bool sovereign) external onlyRole(POLITICS_ROLE) {
        if (!_loaded[id]) revert UnknownPilot(id);
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

    /// @notice Traits of any known PILOT, bridged over or not.
    function traitsOf(uint256 id) external view returns (Traits.PilotTraits memory) {
        if (!_loaded[id]) revert UnknownPilot(id);
        return _traits[id];
    }

    function supportsInterface(bytes4 id) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(id);
    }
}
