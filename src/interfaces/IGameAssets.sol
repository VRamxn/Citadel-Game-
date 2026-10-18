// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Traits} from "../lib/Traits.sol";

interface ICitadelTraits {
    function traitsOf(uint256 citadelId) external view returns (Traits.CitadelTraits memory);
}

interface IPilotTraits {
    function traitsOf(uint256 pilotId) external view returns (Traits.PilotTraits memory);
}

interface IDrakma {
    function mint(address to, uint256 amount) external;
    function gameBurn(address from, uint256 amount) external;
}
