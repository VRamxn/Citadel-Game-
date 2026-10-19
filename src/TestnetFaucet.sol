// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Drakma} from "./Drakma.sol";

/// @notice TESTNET ONLY (L2): 5M DRAKMA once per address, standing in for the mainnet carry-over claim.
contract TestnetFaucet is Ownable {
    Drakma public immutable drakma;
    uint256 public constant DK_PER_DRIP = 5_000_000 ether;
    mapping(address => bool) public dripped;

    error AlreadyDripped();

    constructor(address owner_, Drakma drakma_) Ownable(owner_) {
        drakma = drakma_;
    }

    function drip() external {
        if (dripped[msg.sender]) revert AlreadyDripped();
        dripped[msg.sender] = true;
        drakma.mint(msg.sender, DK_PER_DRIP);
    }

    function grantDrakma(address to, uint256 amount) external onlyOwner {
        drakma.mint(to, amount);
    }
}

/// @notice TESTNET ONLY (L1): a stand-in for one of the original mainnet collections, so the bridge can be played end
/// to end on Sepolia. Anyone can take a starter kit from MockOriginalsFaucet; the owner can mint specific ids.
contract MockOriginal is ERC721, Ownable {
    uint256 public immutable max;
    address public faucet;

    error NotFaucet();
    error OutOfRange();

    constructor(string memory name_, string memory symbol_, uint256 max_, address owner_)
        ERC721(name_, symbol_)
        Ownable(owner_)
    {
        max = max_;
    }

    function setFaucet(address faucet_) external onlyOwner {
        faucet = faucet_;
    }

    function mint(address to, uint256 id) external {
        if (msg.sender != faucet && msg.sender != owner()) revert NotFaucet();
        if (id >= max) revert OutOfRange();
        _mint(to, id);
    }

    function exists(uint256 id) external view returns (bool) {
        return _ownerOf(id) != address(0);
    }
}

/// @notice TESTNET ONLY (L1): stand-in for the original PILOT, with the same on-chain record the vault reads at deposit
/// (levels, sovereignty, sovereignCounter). The owner sets them to mirror test scenarios.
contract MockOriginalPilot is MockOriginal {
    mapping(uint256 => uint8) public levels;
    mapping(uint256 => bool) private _sovereign;
    mapping(uint256 => uint8) private _charges;
    mapping(uint256 => uint8) private _kult;
    uint8 public sovereignCounter;

    constructor(address owner_) MockOriginal("PILOT (testnet original)", "PILOT", 2048, owner_) {}

    function setRecord(uint256 id, uint8 level, bool sovereign, uint8 charges, uint8 kult) external onlyOwner {
        levels[id] = level;
        _sovereign[id] = sovereign;
        _charges[id] = charges;
        _kult[id] = kult;
    }

    function setSovereignCounter(uint8 n) external onlyOwner {
        sovereignCounter = n;
    }

    function getSovereign(uint256 id) external view returns (bool, uint8, uint8) {
        return (_sovereign[id], _charges[id], _kult[id]);
    }
}

/// @notice TESTNET ONLY (L1): 2 original-style CITADEL and 2 PILOT once per address, the next free ids.
contract MockOriginalsFaucet {
    MockOriginal public immutable citadel;
    MockOriginal public immutable pilot;
    uint256 public nextCitadel;
    uint256 public nextPilot;
    mapping(address => bool) public dripped;

    event Dripped(address indexed to, uint256[2] citadels, uint256[2] pilots);

    error AlreadyDripped();

    constructor(MockOriginal citadel_, MockOriginal pilot_) {
        citadel = citadel_;
        pilot = pilot_;
    }

    function drip() external {
        if (dripped[msg.sender]) revert AlreadyDripped();
        dripped[msg.sender] = true;
        uint256[2] memory cs;
        uint256[2] memory ps;
        for (uint256 i; i < 2; ++i) {
            cs[i] = _next(citadel, true);
            ps[i] = _next(pilot, false);
        }
        emit Dripped(msg.sender, cs, ps);
    }

    function _next(MockOriginal t, bool isCitadel) private returns (uint256 id) {
        id = isCitadel ? nextCitadel : nextPilot;
        while (t.exists(id)) ++id;
        t.mint(msg.sender, id);
        if (isCitadel) nextCitadel = id + 1;
        else nextPilot = id + 1;
    }
}
