// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IOPMessenger} from "./IOPMessenger.sol";

/// @notice LOCAL/TEST ONLY: plays both sides of the OP Stack messenger on a single chain and delivers every message
/// immediately, so the vault and the L2 bridge can run side by side on anvil and in tests.
contract LocalMessenger is IOPMessenger {
    address private _sender;

    error Failed(bytes reason);

    function sendMessage(address target, bytes calldata message, uint32) external {
        address prev = _sender;
        _sender = msg.sender;
        (bool ok, bytes memory ret) = target.call(message);
        _sender = prev;
        if (!ok) revert Failed(ret);
    }

    function xDomainMessageSender() external view returns (address) {
        return _sender;
    }
}
