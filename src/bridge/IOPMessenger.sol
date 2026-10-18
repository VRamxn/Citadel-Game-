// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice The OP Stack CrossDomainMessenger (Base, Optimism, ...). On L1 it's the L1CrossDomainMessenger proxy of the
/// chain; on L2 it's the predeploy at 0x4200000000000000000000000000000000000007.
interface IOPMessenger {
    function sendMessage(address target, bytes calldata message, uint32 minGasLimit) external;
    function xDomainMessageSender() external view returns (address);
}

interface IBridgeableNFT {
    function bridgeMint(address to, uint256 id) external;
    function bridgeBurn(uint256 id) external;
    function ownerOf(uint256 id) external view returns (address);
}

interface ICitadelBridgeL2 {
    function finalizeDeposit(uint8 collection, uint256[] calldata ids, address to) external;
}

interface ICitadelVaultL1 {
    function finalizeWithdrawal(uint8 collection, uint256[] calldata ids, address to) external;
}
