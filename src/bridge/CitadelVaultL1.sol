// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IOPMessenger, ICitadelBridgeL2, IOriginalPilot, PilotOrigin} from "./IOPMessenger.sol";

/// @title CITADEL vault (Ethereum L1)
/// @notice Holds the original CITADEL (0xaf08134e...) and PILOT (0xD653B9f4...) NFTs while they're in play on the L2.
/// Depositing sends a message through the OP Stack messenger that mints the same ids on L2; bridging back burns them on
/// L2 and, once the withdrawal is proven and finalized on L1 (the rollup's challenge period), releases the originals
/// here. The vault has no admin power over deposited NFTs: only a message from the L2 bridge can release them.
///
/// For PILOT the vault also reads what the original contract records on-chain — LEVEL and SOVEREIGNTY (with the KULT a
/// sovereign bribed) — and sends it along, so what holders bought on mainnet arrives on L2 trustlessly.
contract CitadelVaultL1 is Ownable {
    uint8 public constant CITADEL = 0;
    uint8 public constant PILOT = 1;
    uint32 public constant BASE_GAS = 100_000;
    uint32 public constant GAS_PER_TOKEN = 120_000;
    uint256 public constant MAX_BATCH = 50;

    IOPMessenger public immutable messenger;
    IERC721 public immutable citadel;
    IERC721 public immutable pilot;
    address public l2Bridge;

    event Deposited(address indexed from, address indexed to, uint8 collection, uint256[] ids);
    event Released(address indexed to, uint8 collection, uint256[] ids);

    error BadCollection();
    error BadBatch();
    error NotBridge();
    error AlreadySet();

    constructor(address owner_, IOPMessenger messenger_, IERC721 citadel_, IERC721 pilot_) Ownable(owner_) {
        messenger = messenger_;
        citadel = citadel_;
        pilot = pilot_;
    }

    /// @notice Wire the L2 bridge once, then the owner has nothing left to do.
    function setL2Bridge(address l2Bridge_) external onlyOwner {
        if (l2Bridge != address(0)) revert AlreadySet();
        l2Bridge = l2Bridge_;
        renounceOwnership();
    }

    /// @notice Lock originals here and mint them to `to` on L2. Approve this vault for the collection first.
    function deposit(uint8 collection, uint256[] calldata ids, address to) external {
        if (ids.length == 0 || ids.length > MAX_BATCH) revert BadBatch();
        IERC721 t = _token(collection);
        for (uint256 i; i < ids.length; ++i) {
            t.transferFrom(msg.sender, address(this), ids[i]); // reverts unless the caller owns or is approved
        }
        bytes memory origins = collection == PILOT ? _pilotOrigins(ids) : bytes("");
        messenger.sendMessage(
            l2Bridge,
            abi.encodeCall(ICitadelBridgeL2.finalizeDeposit, (collection, ids, to, origins)),
            BASE_GAS + GAS_PER_TOKEN * uint32(ids.length)
        );
        emit Deposited(msg.sender, to, collection, ids);
    }

    /// @notice Called by the messenger when an L2 withdrawal is finalized.
    function finalizeWithdrawal(uint8 collection, uint256[] calldata ids, address to) external {
        if (msg.sender != address(messenger) || messenger.xDomainMessageSender() != l2Bridge) revert NotBridge();
        IERC721 t = _token(collection);
        for (uint256 i; i < ids.length; ++i) {
            t.transferFrom(address(this), to, ids[i]);
        }
        emit Released(to, collection, ids);
    }

    function _pilotOrigins(uint256[] calldata ids) private view returns (bytes memory) {
        IOriginalPilot p = IOriginalPilot(address(pilot));
        PilotOrigin[] memory o = new PilotOrigin[](ids.length);
        for (uint256 i; i < ids.length; ++i) {
            (bool sovereign, uint8 charges, uint8 kult) = p.getSovereign(ids[i]);
            o[i] = PilotOrigin({level: p.levels(ids[i]), sovereign: sovereign, charges: charges, kult: kult});
        }
        return abi.encode(o, p.sovereignCounter());
    }

    function _token(uint8 collection) private view returns (IERC721) {
        if (collection == CITADEL) return citadel;
        if (collection == PILOT) return pilot;
        revert BadCollection();
    }
}
