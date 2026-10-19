// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IDrakma} from "./interfaces/IGameAssets.sol";
import {Traits} from "./lib/Traits.sol";
import {Rand} from "./lib/Rand.sol";
import {PilotOrigin} from "./bridge/IOPMessenger.sol";

/// @notice PILOT on the game's L2.
/// #0–2047 are the original mainnet PILOT (0xD653B9f4ec70658402B9634E7E0eAFcc64138Cad) bridged over: only the bridge
/// mints and burns them. SUBJUGATION and DEATH exist only in the original IPFS metadata, so they are loaded once from a
/// snapshot and then locked. Everything the original contract records on-chain — LEVEL, SOVEREIGNTY, a sovereign's
/// KULT — arrives with the PILOT in the bridge message, read on L1 by the vault, and is applied on its first arrival.
/// A KULT nobody recorded is rolled here, from keccak256("CITADEL PILOT", id). From then on the L2 state is the PILOT's
/// own, and it survives round trips over the bridge.
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
    uint256 private constant TRAIT_BYTES = 2; // subjugation, death (0/1)

    IDrakma public immutable drakma;
    uint256 public nextNative = ORIGINALS;
    mapping(uint256 => Traits.PilotTraits) private _traits;
    mapping(uint256 => bool) private _loaded; // SUBJUGATION/DEATH known (originals) or minted (native)
    mapping(uint256 => bool) public arrived; // an original's on-chain record has been applied
    bool public traitsLocked;

    event Upleveled(uint256 indexed pilotId, uint8 level);
    event SovereigntyChanged(uint256 indexed pilotId, bool sovereign);

    error NotOwner();
    error MaxLevel();
    error BadTraits();
    error UnknownPilot(uint256 id);
    error Locked();

    constructor(address admin, IDrakma drakma_) ERC721("PILOT", "PILOT") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        drakma = drakma_;
    }

    /// @notice Load SUBJUGATION and DEATH of original PILOT [startId, startId + data.length / 2) from the metadata
    /// snapshot (data/pilot-traits.bin). Until lockTraits().
    function setTraits(uint256 startId, bytes calldata data) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (traitsLocked) revert Locked();
        if (data.length % TRAIT_BYTES != 0) revert BadTraits();
        uint256 n = data.length / TRAIT_BYTES;
        if (startId + n > ORIGINALS) revert BadTraits();
        for (uint256 i; i < n; ++i) {
            uint256 id = startId + i;
            uint8 subj = uint8(data[i * TRAIT_BYTES]);
            if (subj >= 8 || arrived[id]) revert BadTraits();
            _traits[id].subjugation = subj;
            _traits[id].death = data[i * TRAIT_BYTES + 1] != 0;
            _loaded[id] = true;
        }
    }

    /// @notice Freeze the metadata traits forever.
    function lockTraits() external onlyRole(DEFAULT_ADMIN_ROLE) {
        traitsLocked = true;
    }

    /// @notice Mint the L2 copy of an original PILOT deposited in the L1 vault. On its first arrival, apply what the
    /// original contract records (read on L1 by the vault); later arrivals keep the PILOT's L2 state.
    /// @return arrivedSovereign true on a first arrival as a sovereign (the bridge then seats it)
    function bridgeMint(address to, uint256 id, PilotOrigin calldata o)
        external
        onlyRole(BRIDGE_ROLE)
        returns (bool arrivedSovereign)
    {
        if (id >= ORIGINALS || !_loaded[id]) revert UnknownPilot(id);
        if (!arrived[id]) {
            arrived[id] = true;
            Traits.PilotTraits storage t = _traits[id];
            t.level = o.level > MAX_LEVEL ? MAX_LEVEL : o.level;
            t.sovereign = o.sovereign;
            // a KULT is on record only for a sovereign that bribed one; otherwise roll it, publicly and fixed
            t.kult = o.sovereign && o.charges > 0 && o.kult < 8 ? o.kult : rolledKult(id);
            arrivedSovereign = o.sovereign;
        }
        _mint(to, id);
    }

    /// @notice The KULT of an original PILOT the original contract never recorded one for.
    function rolledKult(uint256 id) public pure returns (uint8) {
        uint256 seed = uint256(keccak256(abi.encodePacked("CITADEL PILOT", id)));
        return Rand.pick((seed >> 16) % 2048, [uint16(512), 256, 256, 256, 256, 256, 128, 128]);
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

    /// @notice Traits of any known PILOT. An original that hasn't arrived yet shows its metadata traits only.
    function traitsOf(uint256 id) external view returns (Traits.PilotTraits memory) {
        if (!_loaded[id]) revert UnknownPilot(id);
        return _traits[id];
    }

    function supportsInterface(bytes4 id) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(id);
    }
}
