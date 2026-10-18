// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IDrakma} from "./interfaces/IGameAssets.sol";
import {IOPMessenger} from "./bridge/IOPMessenger.sol";

/// @title DRAKMA carry-over claim (L2)
/// @notice Each wallet in the snapshot claims its old DRAKMA balance 1:1 plus an equal share for every wallet, as new
/// DRAKMA, once. Leaves are OpenZeppelin standard Merkle leaves of (address account, uint256 amount), built by
/// script/snapshot.mjs. EOAs claim directly on L2; wallets that only exist on L1 (Safes, other contracts) claim through
/// DrakmaClaimRelayL1, which tells this contract who they are via the rollup messenger and where to send the DRAKMA.
contract DrakmaClaim is Ownable {
    bytes32 public immutable root;
    IDrakma public immutable drakma;
    IOPMessenger public immutable messenger;
    address public l1Relay;
    mapping(address => bool) public claimed;

    event Claimed(address indexed account, address indexed recipient, uint256 amount);

    error AlreadyClaimed();
    error BadProof();
    error NotRelay();
    error AlreadySet();

    constructor(address owner_, bytes32 root_, IDrakma drakma_, IOPMessenger messenger_) Ownable(owner_) {
        root = root_;
        drakma = drakma_;
        messenger = messenger_;
    }

    function setL1Relay(address relay) external onlyOwner {
        if (l1Relay != address(0)) revert AlreadySet();
        l1Relay = relay;
        renounceOwnership();
    }

    function claim(uint256 amount, bytes32[] calldata proof) external {
        _claim(msg.sender, msg.sender, amount, proof);
    }

    function claimFromL1(address account, address recipient, uint256 amount, bytes32[] calldata proof) external {
        if (msg.sender != address(messenger) || messenger.xDomainMessageSender() != l1Relay) revert NotRelay();
        _claim(account, recipient, amount, proof);
    }

    function _claim(address account, address recipient, uint256 amount, bytes32[] calldata proof) private {
        if (claimed[account]) revert AlreadyClaimed();
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        if (!MerkleProof.verifyCalldata(proof, root, leaf)) revert BadProof();
        claimed[account] = true;
        drakma.mint(recipient, amount);
        emit Claimed(account, recipient, amount);
    }
}

/// @notice L1 side of the claim for wallets that can't sign on L2: the caller is the snapshot account.
contract DrakmaClaimRelayL1 {
    IOPMessenger public immutable messenger;
    address public immutable l2Claim;

    constructor(IOPMessenger messenger_, address l2Claim_) {
        messenger = messenger_;
        l2Claim = l2Claim_;
    }

    function claimTo(address recipient, uint256 amount, bytes32[] calldata proof) external {
        messenger.sendMessage(
            l2Claim,
            abi.encodeCall(DrakmaClaim.claimFromL1, (msg.sender, recipient, amount, proof)),
            uint32(200_000 + 3_000 * proof.length)
        );
    }
}
