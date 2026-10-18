// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Traits} from "../lib/Traits.sol";

interface ICitadelNFT is IERC721 {
    function traitsOf(uint256 citadelId) external view returns (Traits.CitadelTraits memory);
    function mintGenerated(address to, Traits.CitadelTraits calldata t) external returns (uint256);
    function burn(uint256 citadelId) external;
    function MAX_CITADEL() external view returns (uint256);
}

interface IPilotNFT is IERC721 {
    function traitsOf(uint256 pilotId) external view returns (Traits.PilotTraits memory);
    function mint(address to, Traits.PilotTraits calldata t) external returns (uint256);
    function burn(uint256 pilotId) external;
    function setSovereign(uint256 pilotId, bool sovereign) external;
}

interface IMentatNFT is IERC721 {
    function traitsOf(uint256 mentatId) external view returns (Traits.MentatTraits memory);
    function mint(address to, Traits.MentatTraits calldata t) external returns (uint256);
}

interface IDrakma {
    function mint(address to, uint256 amount) external;
    function gameBurn(address from, uint256 amount) external;
}

interface ITechTree {
    function register(uint256 citadelId, uint8 faction, uint8 branch, uint256 ratePerDay, bool isKey) external;
    function unregister(uint256 citadelId) external;
    function bits(uint8 faction) external view returns (uint64);
}

/// @notice What the satellite contracts (tech tree, technocracy) need to know about the game.
interface IGameView {
    /// @notice Who controls a CITADEL: its wallet owner, or the player who lit it to the grid.
    function controllerOfCitadel(uint256 citadelId) external view returns (address);
    /// @notice Who controls a PILOT: its wallet owner, or the player whose CITADEL/siege holds it.
    function controllerOfPilot(uint256 pilotId) external view returns (address);
    /// @notice (lit, faction, research branch) of a CITADEL.
    function placement(uint256 citadelId) external view returns (bool lit, uint8 faction, uint8 research);
}
