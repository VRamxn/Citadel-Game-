// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IOPMessenger, IBridgeableNFT, ICitadelVaultL1} from "./IOPMessenger.sol";

/// @title CITADEL bridge (L2)
/// @notice Mints the L2 copies of original CITADEL and PILOT when the L1 vault says they were deposited, and burns them
/// to send them home. On L2 the game uses these copies exactly like any other token; GEN1+ tokens are L2-native and
/// never cross.
contract CitadelBridgeL2 is Ownable {
    uint8 public constant CITADEL = 0;
    uint8 public constant PILOT = 1;
    uint32 public constant BASE_GAS = 100_000;
    uint32 public constant GAS_PER_TOKEN = 60_000;
    uint256 public constant MAX_BATCH = 50;

    IOPMessenger public immutable messenger;
    IBridgeableNFT public immutable citadel;
    IBridgeableNFT public immutable pilot;
    address public l1Vault;

    event DepositFinalized(address indexed to, uint8 collection, uint256[] ids);
    event WithdrawalInitiated(address indexed from, address indexed to, uint8 collection, uint256[] ids);

    error BadCollection();
    error BadBatch();
    error NotVault();
    error NotOwner(uint256 id);
    error AlreadySet();

    constructor(address owner_, IOPMessenger messenger_, IBridgeableNFT citadel_, IBridgeableNFT pilot_)
        Ownable(owner_)
    {
        messenger = messenger_;
        citadel = citadel_;
        pilot = pilot_;
    }

    function setL1Vault(address l1Vault_) external onlyOwner {
        if (l1Vault != address(0)) revert AlreadySet();
        l1Vault = l1Vault_;
        renounceOwnership();
    }

    function finalizeDeposit(uint8 collection, uint256[] calldata ids, address to) external {
        if (msg.sender != address(messenger) || messenger.xDomainMessageSender() != l1Vault) revert NotVault();
        IBridgeableNFT t = _token(collection);
        for (uint256 i; i < ids.length; ++i) {
            t.bridgeMint(to, ids[i]);
        }
        emit DepositFinalized(to, collection, ids);
    }

    /// @notice Send originals home to `to` on L1. They must be in your wallet (unlite them from the grid first).
    /// After the rollup's challenge period, prove and finalize the withdrawal on L1 to receive them.
    function withdraw(uint8 collection, uint256[] calldata ids, address to) external {
        if (ids.length == 0 || ids.length > MAX_BATCH) revert BadBatch();
        IBridgeableNFT t = _token(collection);
        for (uint256 i; i < ids.length; ++i) {
            if (t.ownerOf(ids[i]) != msg.sender) revert NotOwner(ids[i]);
            t.bridgeBurn(ids[i]);
        }
        messenger.sendMessage(
            l1Vault,
            abi.encodeCall(ICitadelVaultL1.finalizeWithdrawal, (collection, ids, to)),
            BASE_GAS + GAS_PER_TOKEN * uint32(ids.length)
        );
        emit WithdrawalInitiated(msg.sender, to, collection, ids);
    }

    function _token(uint8 collection) private view returns (IBridgeableNFT) {
        if (collection == CITADEL) return citadel;
        if (collection == PILOT) return pilot;
        revert BadCollection();
    }
}
