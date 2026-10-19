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

/// @notice What the original PILOT contract (0xD653B9f4...) records on-chain for each PILOT.
struct PilotOrigin {
    uint8 level;
    bool sovereign;
    uint8 charges; // bribes the sovereign made (its KULT is only meaningful if > 0)
    uint8 kult;
}

/// @notice The original PILOT contract's on-chain views, read by the vault at deposit.
interface IOriginalPilot {
    function levels(uint256 id) external view returns (uint8);
    function getSovereign(uint256 id) external view returns (bool isSovereign, uint8 chargeCount, uint8 kult);
    function sovereignCounter() external view returns (uint8);
}

interface IBridgedPilot {
    /// @return arrivedSovereign true if this was the PILOT's first arrival and it came in sovereign
    function bridgeMint(address to, uint256 id, PilotOrigin calldata origin) external returns (bool arrivedSovereign);
    function bridgeBurn(uint256 id) external;
    function ownerOf(uint256 id) external view returns (address);
}

interface ISeatKeeper {
    function seatArrival(uint256 pilotId) external;
    function noteOriginalBought(uint256 count) external;
}

interface ICitadelBridgeL2 {
    /// @param origins for PILOT: abi.encode(PilotOrigin[] origins, uint8 sovereignCounter) read from the original
    /// contract on L1; empty for CITADEL
    function finalizeDeposit(uint8 collection, uint256[] calldata ids, address to, bytes calldata origins) external;
}

interface ICitadelVaultL1 {
    function finalizeWithdrawal(uint8 collection, uint256[] calldata ids, address to) external;
}
